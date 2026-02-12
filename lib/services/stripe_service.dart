import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:proserve_hub/utils/payment_error_mapper.dart';

class StripeService {
  // Optional build-time override:
  // flutter run/build --dart-define=CONTRACTOR_PRO_STRIPE_PAYMENT_LINK="https://buy.stripe.com/..."
  static const String _contractorProStripePaymentLinkOverride =
      String.fromEnvironment('CONTRACTOR_PRO_STRIPE_PAYMENT_LINK');

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  Future<void> payForJob({required String jobId}) async {
    final result = await _callFunction(
      callableName: 'createCheckoutSession',
      httpName: 'createCheckoutSessionHttp',
      params: {'jobId': jobId.trim()},
    );
    await _launchCheckoutUrl(result['url'], label: 'Payment');
  }

  Future<void> buyLeadPack({required String packId}) async {
    final result = await _callFunction(
      callableName: 'createLeadPackCheckoutSession',
      httpName: 'createLeadPackCheckoutSessionHttp',
      params: {'packId': packId.trim()},
    );
    await _launchCheckoutUrl(result['url'], label: 'Payment');
  }

  /// Opens Stripe Checkout to fund an escrow booking.
  Future<String?> payForEscrow({required String escrowId}) async {
    final result = await _callFunction(
      callableName: 'createEscrowCheckoutSession',
      httpName: 'createEscrowCheckoutSessionHttp',
      params: {'escrowId': escrowId.trim()},
    );
    await _launchCheckoutUrl(result['url'], label: 'Escrow Payment');
    return result['sessionId'];
  }

  /// Triggers contractor payout after escrow is released.
  Future<Map<String, String>> releaseEscrowFunds({
    required String escrowId,
  }) async {
    return _callFunction(
      callableName: 'releaseEscrowFunds',
      httpName: 'releaseEscrowFundsHttp',
      params: {'escrowId': escrowId.trim()},
    );
  }

  /// Issues a full Stripe refund for an escrow booking.
  Future<Map<String, String>> refundEscrow({required String escrowId}) async {
    return _callFunction(
      callableName: 'refundEscrow',
      httpName: 'refundEscrowHttp',
      params: {'escrowId': escrowId.trim()},
    );
  }

  Future<void> payForContractorSubscription() async {
    final overrideUrl = _contractorProStripePaymentLinkOverride.trim();
    if (overrideUrl.isNotEmpty) {
      await _launchCheckoutUrl(overrideUrl, label: 'Subscription');
      return;
    }

    try {
      final result = await _callFunction(
        callableName: 'createContractorSubscriptionCheckoutSession',
        httpName: 'createContractorSubscriptionCheckoutSessionHttp',
        params: <String, dynamic>{},
      );
      await _launchCheckoutUrl(result['url'], label: 'Subscription');
    } catch (e) {
      throw Exception(
        'Subscription checkout failed. Please try again in a moment.\n\nDetails: $e',
      );
    }
  }

  Future<bool> syncContractorProEntitlement() async {
    final result = await _callFunction(
      callableName: 'syncContractorProEntitlement',
      httpName: 'syncContractorProEntitlementHttp',
      params: <String, dynamic>{},
    );
    return result['active'] == 'true';
  }

  // ---------------------------------------------------------------------------
  // Unified function invocation — callable + HTTP fallback
  // ---------------------------------------------------------------------------

  /// Whether the current platform supports Firebase callable functions.
  static bool get _useCallable =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  /// Calls a Cloud Function via the callable SDK when supported, falling back
  /// to an authenticated HTTP POST on Windows / Linux.
  ///
  /// Returns a `Map<String, String>` with whatever the function returned
  /// (typically `url` and `sessionId`).
  Future<Map<String, String>> _callFunction({
    required String callableName,
    required String httpName,
    required Map<String, dynamic> params,
  }) async {
    if (_useCallable) {
      try {
        final callable = FirebaseFunctions.instance.httpsCallable(callableName);
        final response = await callable.call(params);
        return _extractResult(response.data);
      } on FirebaseFunctionsException catch (e) {
        // Callable can fail for lots of reasons (App Check, auth, region
        // mismatch …). Try the HTTP endpoint as a fallback.
        try {
          return await _callHttp(httpName, params);
        } catch (httpError) {
          final base = humanizePaymentError(e);
          throw Exception(
            '$base\n\n(Details: code=${e.code}, message=${e.message})\nHTTP fallback: $httpError',
          );
        }
      } catch (e) {
        try {
          return await _callHttp(httpName, params);
        } catch (httpError) {
          throw Exception(
            '${humanizePaymentError(e)}\n\nHTTP fallback: $httpError',
          );
        }
      }
    }

    // Desktop (Windows / Linux) — go straight to HTTP.
    return _callHttp(httpName, params);
  }

  /// Authenticated HTTP POST to a Cloud Function endpoint.
  Future<Map<String, String>> _callHttp(
    String functionName,
    Map<String, dynamic> params,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Sign in required');

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.trim().isEmpty) {
      throw Exception('Auth token unavailable');
    }

    final projectId = FirebaseFunctions.instance.app.options.projectId;
    if (projectId.trim().isEmpty) {
      throw Exception('Firebase projectId missing');
    }

    final uri = Uri.parse(
      'https://us-central1-$projectId.cloudfunctions.net/$functionName',
    );

    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode(params),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      String message = 'Request failed';
      try {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map && decoded['error'] is String) {
          message = decoded['error'] as String;
        }
      } catch (_) {
        // ignore
      }
      throw Exception('$message (HTTP ${resp.statusCode})');
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) {
      throw Exception('Unexpected response format');
    }

    return _extractResult(decoded);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Map<String, String> _extractResult(dynamic data) {
    if (data is! Map) return {};
    final result = <String, String>{};
    if (data['url'] != null) result['url'] = data['url'].toString();
    if (data['sessionId'] != null) {
      result['sessionId'] = data['sessionId'].toString();
    }
    if (data['active'] != null) {
      result['active'] = data['active'].toString();
    }
    return result;
  }

  Future<void> _launchCheckoutUrl(
    String? url, {
    String label = 'Payment',
  }) async {
    if (url == null || url.trim().isEmpty) {
      throw Exception('$label link unavailable');
    }

    final uri = Uri.tryParse(url.trim());
    if (uri == null) throw Exception('Invalid $label URL');

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) throw Exception('Could not open $label page');
  }
}
