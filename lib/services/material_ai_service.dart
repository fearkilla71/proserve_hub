import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MaterialAiSuggestion {
  final Map<String, int> quantities;
  final String assumptions;

  const MaterialAiSuggestion({
    required this.quantities,
    required this.assumptions,
  });

  factory MaterialAiSuggestion.fromJson(Map<String, dynamic> json) {
    final raw = json['quantities'];
    final quantities = <String, int>{};

    if (raw is Map) {
      for (final entry in raw.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        final asInt = value is num
            ? value.toInt()
            : int.tryParse(value.toString());
        if (asInt != null) {
          quantities[key] = asInt;
        }
      }
    }

    return MaterialAiSuggestion(
      quantities: quantities,
      assumptions: (json['assumptions'] ?? '').toString(),
    );
  }
}

class MaterialAiService {
  String? _extractDetailsMessage(Object? details) {
    if (details == null) return null;

    if (details is String) {
      final v = details.trim();
      return v.isEmpty ? null : v;
    }

    if (details is Map) {
      final message = details['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
      final error = details['error'];
      if (error is String && error.trim().isNotEmpty) {
        return error.trim();
      }
    }

    final v = details.toString().trim();
    return v.isEmpty ? null : v;
  }

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
      final codeRaw = (e.code).toString().trim();
      final code = codeRaw.toLowerCase();
      final msgRaw = (e.message ?? '').toString().trim();
      final detailsMsg = _extractDetailsMessage(e.details);

      String best = msgRaw;
      if (best.isEmpty || best.toUpperCase() == codeRaw.toUpperCase()) {
        best = detailsMsg ?? best;
      }
      if (best.toUpperCase() == 'INTERNAL') {
        best = detailsMsg ?? best;
      }

      if (code == 'internal' &&
          (best.isEmpty || best.toUpperCase() == 'INTERNAL')) {
        return 'AI service error. Try again in a minute.';
      }

      if (best.isEmpty) {
        return code.isEmpty ? 'AI suggestion failed' : code;
      }

      // Prefer showing the server message over redundant codes like "internal: INTERNAL".
      if (code.isNotEmpty && best.toUpperCase() != codeRaw.toUpperCase()) {
        if (code == 'permission-denied' ||
            code == 'unauthenticated' ||
            code == 'resource-exhausted') {
          return '$code: $best';
        }
      }
      return best;
    }
    return _stripExceptionPrefix(e.toString());
  }

  bool _shouldFallbackToHttp(Object e) {
    if (e is FirebaseFunctionsException) {
      final code = e.code.toLowerCase().trim();
      return code == 'internal' ||
          code == 'unavailable' ||
          code == 'deadline-exceeded' ||
          code == 'unknown';
    }
    final s = e.toString().toUpperCase();
    return s.contains('INTERNAL') || s.contains('UNAVAILABLE');
  }

  Future<MaterialAiSuggestion> _suggestViaHttp(
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

    final projectId = FirebaseFunctions.instance.app.options.projectId;
    if (projectId.trim().isEmpty) {
      throw Exception('Firebase projectId missing');
    }

    final uri = Uri.parse(
      'https://us-central1-$projectId.cloudfunctions.net/suggestMaterialQuantitiesHttp',
    );

    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode(payload),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      String message = 'AI suggestion failed';
      try {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map && decoded['error'] is String) {
          message = decoded['error'] as String;
        }
      } catch (_) {
        // ignore
      }
      throw Exception(message);
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) {
      throw Exception('Unexpected AI response');
    }

    return MaterialAiSuggestion.fromJson(
      decoded.map((k, v) => MapEntry(k.toString(), v)),
    );
  }

  Future<MaterialAiSuggestion> suggestQuantities({
    required String serviceType,
    required List<Map<String, dynamic>> materials,
    String notes = '',
  }) async {
    final payload = <String, dynamic>{
      'serviceType': serviceType,
      'materials': materials,
      'notes': notes,
    };

    // cloud_functions has no Windows/Linux plugin implementation.
    // Use callable where supported, HTTP endpoint otherwise.
    final useCallable =
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    if (useCallable) {
      try {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'suggestMaterialQuantities',
        );
        final resp = await callable.call(payload);
        final data = resp.data;
        if (data is Map) {
          return MaterialAiSuggestion.fromJson(
            data.map((k, v) => MapEntry(k.toString(), v)),
          );
        }
        throw Exception('Unexpected AI response');
      } on FirebaseFunctionsException catch (e) {
        if (_shouldFallbackToHttp(e)) {
          try {
            return await _suggestViaHttp(payload);
          } catch (httpErr) {
            throw Exception(_summarizeError(httpErr));
          }
        }
        throw Exception(_summarizeError(e));
      } catch (e) {
        if (_shouldFallbackToHttp(e)) {
          try {
            return await _suggestViaHttp(payload);
          } catch (httpErr) {
            throw Exception(_summarizeError(httpErr));
          }
        }
        throw Exception(_summarizeError(e));
      }
    }

    try {
      return await _suggestViaHttp(payload);
    } catch (e) {
      throw Exception(_summarizeError(e));
    }
  }
}
