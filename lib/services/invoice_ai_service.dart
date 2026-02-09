import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/invoice_models.dart';

class InvoiceAiService {
  String _stripExceptionPrefix(String s) {
    var out = s.trim();
    if (out.startsWith('Exception: ')) {
      out = out.substring('Exception: '.length).trim();
    }
    if (out.startsWith('Error: ')) {
      out = out.substring('Error: '.length).trim();
    }
    return out;
  }

  String _summarizeError(Object e) {
    if (e is FirebaseFunctionsException) {
      final code = (e.code).toString().trim();
      final msg = (e.message ?? '').toString().trim();
      return msg.isEmpty
          ? (code.isEmpty ? 'FirebaseFunctionsException' : code)
          : (code.isEmpty ? msg : '$code: $msg');
    }
    return _stripExceptionPrefix(e.toString());
  }

  bool _looksMissingOrBlocked(Object e) {
    if (e is FirebaseFunctionsException) {
      final code = e.code.toLowerCase();
      final msg = (e.message ?? '').toUpperCase();
      return code == 'not-found' ||
          code == 'unimplemented' ||
          msg.contains('NOT_FOUND') ||
          msg.contains('UNIMPLEMENTED');
    }

    final s = e.toString().toUpperCase();
    return s.contains('NOT_FOUND') ||
        s.contains('NOT-FOUND') ||
        s.contains('UNIMPLEMENTED') ||
        s.contains('404');
  }

  Future<InvoiceDraft> draftInvoice({required InvoiceDraft current}) async {
    final payload = <String, dynamic>{'invoice': current.toJson()};

    // cloud_functions has no Windows/Linux plugin implementation.
    // Use callable where supported, HTTP endpoint otherwise.
    final useCallable =
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    if (useCallable) {
      try {
        if (kDebugMode) {
          final pid = FirebaseFunctions.instance.app.options.projectId;
          debugPrint('[InvoiceAi] callable draftInvoice (projectId=$pid)');
        }

        final callable = FirebaseFunctions.instance.httpsCallable(
          'draftInvoice',
        );
        final resp = await callable.call(payload);
        final data = resp.data;
        if (data is Map) {
          return InvoiceDraft.fromJson(
            data.map((k, v) => MapEntry(k.toString(), v)),
          );
        }
        throw Exception('Unexpected AI response');
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[InvoiceAi] callable failed: ${_summarizeError(e)}');
        }

        // If callable is missing/blocked (or we can't classify the failure),
        // try the HTTP endpoint as a reliable fallback.
        try {
          return await _draftInvoiceViaHttp(payload);
        } catch (httpErr) {
          final callableSummary = _summarizeError(e);
          final httpSummary = _summarizeError(httpErr);

          // Prefer showing the HTTP error because it tends to be the most
          // actionable (status, auth, deployment, etc.).
          if (_looksMissingOrBlocked(e)) {
            throw Exception('AI assist unavailable: $httpSummary');
          }
          throw Exception(
            'AI assist unavailable: $httpSummary (callable: $callableSummary)',
          );
        }
      }
    }

    return _draftInvoiceViaHttp(payload);
  }

  Future<InvoiceDraft> _draftInvoiceViaHttp(
    Map<String, dynamic> payload,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Sign in required');
    }

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.trim().isEmpty) {
      throw Exception('Auth token unavailable');
    }

    final functions = FirebaseFunctions.instance;
    final projectId = functions.app.options.projectId;
    if (projectId.trim().isEmpty) {
      throw Exception('Firebase projectId missing');
    }

    const useEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
    final host = (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
        ? '10.0.2.2'
        : 'localhost';

    final uri = useEmulators
        ? Uri.parse('http://$host:5001/$projectId/us-central1/draftInvoiceHttp')
        : Uri.parse(
            'https://us-central1-$projectId.cloudfunctions.net/draftInvoiceHttp',
          );

    if (kDebugMode) {
      debugPrint('[InvoiceAi] http POST $uri');
    }

    final resp = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 25));

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final raw = resp.body.toString();
      final snippet = raw.trim().isEmpty
          ? ''
          : (raw.length > 400 ? raw.substring(0, 400) : raw);

      final upper = snippet.toUpperCase();
      final looksLikeHtml =
          snippet.contains('<html') || snippet.contains('<HTML');
      final isNotFoundPage =
          upper.contains('404 PAGE NOT FOUND') ||
          upper.contains('ERROR: PAGE NOT FOUND');

      String message = 'AI invoice failed (HTTP ${resp.statusCode})';
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final err = decoded['error'];
          final code = decoded['code'];
          final errStr = err is String ? err.trim() : err?.toString().trim();
          final codeStr = code is String
              ? code.trim()
              : code?.toString().trim();

          if (errStr != null && errStr.isNotEmpty) {
            message = errStr;
            if (codeStr != null && codeStr.isNotEmpty) {
              message = '$message ($codeStr)';
            }
          }
        }
      } catch (_) {
        // Response wasn't JSON (often an HTML 404/500 page). Keep status + snippet.
      }

      if (snippet.isNotEmpty && !message.contains('HTTP')) {
        // Still attach status for non-obvious server failures.
        message = '$message (HTTP ${resp.statusCode})';
      }

      if (kDebugMode) {
        debugPrint('[InvoiceAi] http error ${resp.statusCode}: $snippet');
      }

      // If we didn't get a structured error, keep the UI readable.
      if (!kReleaseMode && message.contains('HTTP')) {
        if (looksLikeHtml && isNotFoundPage) {
          throw Exception(
            'AI endpoint not found (HTTP 404). Deploy Cloud Functions (draftInvoiceHttp) to this Firebase project.',
          );
        }
        if (looksLikeHtml) {
          throw Exception(
            '$message: Server returned HTML (check deploy/config).',
          );
        }
        if (snippet.isNotEmpty) {
          throw Exception('$message: ${_stripExceptionPrefix(snippet)}');
        }
      }
      throw Exception(message);
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) {
      throw Exception('Unexpected AI response');
    }

    return InvoiceDraft.fromJson(
      decoded.map((k, v) => MapEntry(k.toString(), v)),
    );
  }
}
