import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LaborAiEstimate {
  final double hours;
  final double hourlyRate;
  final double total;
  final String summary;
  final String assumptions;
  final double confidence;

  const LaborAiEstimate({
    required this.hours,
    required this.hourlyRate,
    required this.total,
    required this.summary,
    required this.assumptions,
    required this.confidence,
  });

  factory LaborAiEstimate.fromJson(Map<String, dynamic> json) {
    double toDouble(Object? value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0.0;
    }

    return LaborAiEstimate(
      hours: toDouble(json['hours']),
      hourlyRate: toDouble(json['hourlyRate']),
      total: toDouble(json['total']),
      summary: (json['summary'] ?? '').toString(),
      assumptions: (json['assumptions'] ?? '').toString(),
      confidence: toDouble(json['confidence']),
    );
  }
}

class LaborAiService {
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
        return code.isEmpty ? 'AI labor estimate failed' : code;
      }

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

  Future<LaborAiEstimate> _estimateViaHttp(Map<String, dynamic> payload) async {
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
      'https://us-central1-$projectId.cloudfunctions.net/estimateLaborFromInputsHttp',
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
      String message = 'AI labor estimate failed';
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

    return LaborAiEstimate.fromJson(
      decoded.map((k, v) => MapEntry(k.toString(), v)),
    );
  }

  Future<LaborAiEstimate> estimateLabor({
    required String serviceType,
    required String description,
    required Map<String, String> answers,
    required List<Map<String, dynamic>> materials,
    required double materialTotal,
    String? zip,
    String? urgency,
  }) async {
    final payload = <String, dynamic>{
      'service': serviceType,
      'zip': zip,
      'urgency': urgency,
      'description': description,
      'answers': answers,
      'materials': materials,
      'materialTotal': materialTotal,
    };

    final useCallable =
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    if (useCallable) {
      try {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'estimateLaborFromInputs',
        );
        final resp = await callable.call(payload);
        final data = resp.data;
        if (data is Map) {
          return LaborAiEstimate.fromJson(
            data.map((k, v) => MapEntry(k.toString(), v)),
          );
        }
        throw Exception('Unexpected AI response');
      } on FirebaseFunctionsException catch (e) {
        if (_shouldFallbackToHttp(e)) {
          try {
            return await _estimateViaHttp(payload);
          } catch (httpErr) {
            throw Exception(_summarizeError(httpErr));
          }
        }
        throw Exception(_summarizeError(e));
      } catch (e) {
        throw Exception(_summarizeError(e));
      }
    }

    try {
      return await _estimateViaHttp(payload);
    } catch (e) {
      throw Exception(_summarizeError(e));
    }
  }
}
