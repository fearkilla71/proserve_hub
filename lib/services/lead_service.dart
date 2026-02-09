import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:proserve_hub/utils/payment_error_mapper.dart';

class LeadService {
  Future<int?> unlockLead({
    required String jobId,
    required bool exclusive,
  }) async {
    final trimmedJobId = jobId.trim();
    if (trimmedJobId.isEmpty) {
      throw Exception('jobId required');
    }

    final useCallable =
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    if (useCallable) {
      try {
        final callable = FirebaseFunctions.instance.httpsCallable('unlockLead');
        final response = await callable.call(<String, dynamic>{
          'jobId': trimmedJobId,
          'exclusive': exclusive,
        });

        final data = response.data;
        if (data is Map) {
          final credits = data['credits'];
          if (credits is num) return credits.toInt();
        }
        return null;
      } catch (e) {
        throw Exception(humanizePaymentError(e));
      }
    }

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
      'https://us-central1-$projectId.cloudfunctions.net/unlockLeadHttp',
    );

    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'jobId': trimmedJobId, 'exclusive': exclusive}),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      String message = 'Unlock failed';
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
    if (decoded is Map) {
      final credits = decoded['credits'];
      if (credits is num) return credits.toInt();
    }

    return null;
  }

  Future<int?> unlockExclusiveLead({required String jobId}) async {
    return unlockLead(jobId: jobId, exclusive: true);
  }
}
