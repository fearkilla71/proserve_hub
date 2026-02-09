import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;

import 'package:proserve_hub/utils/payment_error_mapper.dart';

class EscrowService {
  static bool get _supportsPaymentSheet {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> fundJob({required String jobId}) async {
    try {
      final result = await _createEscrowPayment(jobId: jobId);
      final clientSecret = result['clientSecret']?.toString().trim() ?? '';
      if (clientSecret.isEmpty) {
        throw Exception('Payment client secret unavailable');
      }

      if (!_supportsPaymentSheet) {
        // PaymentSheet is mobile-only. The server has created escrow; user can
        // complete payment from a mobile device.
        return;
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'ProServe Hub',
        ),
      );

      await Stripe.instance.presentPaymentSheet();
    } catch (e) {
      throw Exception(humanizePaymentError(e));
    }
  }

  Future<void> releaseJob({required String jobId}) async {
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
        final callable = FirebaseFunctions.instance.httpsCallable(
          'releaseEscrow',
        );
        await callable.call(<String, dynamic>{'jobId': trimmedJobId});
        return;
      } catch (e) {
        throw Exception(humanizePaymentError(e));
      }
    }

    // Callable isn't implemented on Windows/Linux, but customers may still use
    // desktop to mark completion.
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
      'https://us-central1-$projectId.cloudfunctions.net/releaseEscrowHttp',
    );

    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'jobId': trimmedJobId}),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      String message = 'Release request failed';
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
  }

  Future<Map<String, dynamic>> _createEscrowPayment({
    required String jobId,
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
        final callable = FirebaseFunctions.instance.httpsCallable(
          'createEscrowPayment',
        );
        final response = await callable.call(<String, dynamic>{
          'jobId': trimmedJobId,
        });
        final data = response.data;
        return data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
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
      'https://us-central1-$projectId.cloudfunctions.net/createEscrowPaymentHttp',
    );

    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'jobId': trimmedJobId}),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      String message = 'Escrow request failed';
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
      throw Exception('Escrow request failed');
    }
    return Map<String, dynamic>.from(decoded);
  }
}
