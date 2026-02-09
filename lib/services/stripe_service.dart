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

  Future<void> payForJob({required String jobId}) async {
    final result = await _createCheckoutSession(jobId: jobId);

    final url = result['url'];
    if (url == null || url.trim().isEmpty) {
      throw Exception('Payment link unavailable');
    }

    final uri = Uri.tryParse(url.trim());
    if (uri == null) {
      throw Exception('Invalid payment URL');
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      throw Exception('Could not open payment page');
    }
  }

  Future<void> buyLeadPack({required String packId}) async {
    final result = await _createLeadPackCheckoutSession(packId: packId);

    final url = result['url'];
    if (url == null || url.trim().isEmpty) {
      throw Exception('Payment link unavailable');
    }

    final uri = Uri.tryParse(url.trim());
    if (uri == null) {
      throw Exception('Invalid payment URL');
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      throw Exception('Could not open payment page');
    }
  }

  Future<void> payForContractorSubscription() async {
    String? url;
    final overrideUrl = _contractorProStripePaymentLinkOverride.trim();
    if (overrideUrl.isNotEmpty) {
      url = overrideUrl;
    } else {
      try {
        final result = await _createContractorSubscriptionCheckoutSession();
        url = result['url'];
      } catch (e) {
        throw Exception(
          'Subscription checkout failed. Please try again in a moment.\n\nDetails: $e',
        );
      }
    }

    if (url == null || url.trim().isEmpty) {
      throw Exception('Subscription checkout unavailable.');
    }

    final uri = Uri.tryParse(url.trim());
    if (uri == null) {
      throw Exception('Invalid subscription URL');
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      throw Exception('Could not open subscription page');
    }
  }

  Future<bool> syncContractorProEntitlement() async {
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
          'syncContractorProEntitlement',
        );
        final response = await callable.call(<String, dynamic>{});
        final data = response.data;
        final active = (data is Map ? data['active'] : null);
        return active == true;
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
      'https://us-central1-$projectId.cloudfunctions.net/syncContractorProEntitlementHttp',
    );

    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode(<String, dynamic>{}),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      String message = 'Subscription refresh failed';
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
      return false;
    }

    return decoded['active'] == true;
  }

  Future<Map<String, String>> _createCheckoutSession({
    required String jobId,
  }) async {
    final trimmedJobId = jobId.trim();
    if (trimmedJobId.isEmpty) {
      throw Exception('jobId required');
    }

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
          'createCheckoutSession',
        );
        final response = await callable.call(<String, dynamic>{
          'jobId': trimmedJobId,
        });
        final data = response.data;
        final url = (data is Map ? data['url'] : null) as String?;
        final sessionId = (data is Map ? data['sessionId'] : null) as String?;
        return {
          if (url != null) 'url': url.toString(),
          if (sessionId != null) 'sessionId': sessionId.toString(),
        };
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

    // Default region unless you deploy functions elsewhere.
    final uri = Uri.parse(
      'https://us-central1-$projectId.cloudfunctions.net/createCheckoutSessionHttp',
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
      String message = 'Payment request failed';
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
      throw Exception('Payment link unavailable');
    }

    final url = decoded['url']?.toString();
    final sessionId = decoded['sessionId']?.toString();
    return {
      if (url != null) 'url': url,
      if (sessionId != null) 'sessionId': sessionId,
    };
  }

  Future<Map<String, String>> _createLeadPackCheckoutSession({
    required String packId,
  }) async {
    final trimmedPackId = packId.trim();
    if (trimmedPackId.isEmpty) {
      throw Exception('packId required');
    }

    final useCallable =
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    if (useCallable) {
      try {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'createLeadPackCheckoutSession',
        );
        final response = await callable.call(<String, dynamic>{
          'packId': trimmedPackId,
        });
        final data = response.data;
        final url = (data is Map ? data['url'] : null) as String?;
        final sessionId = (data is Map ? data['sessionId'] : null) as String?;
        return {
          if (url != null) 'url': url.toString(),
          if (sessionId != null) 'sessionId': sessionId.toString(),
        };
      } on FirebaseFunctionsException catch (e) {
        // Callable can fail for common reasons (App Check enforcement, auth,
        // transient networking). Try the HTTP endpoint as a fallback.
        try {
          return await _createLeadPackCheckoutSessionHttp(
            packId: trimmedPackId,
          );
        } catch (httpError) {
          final base = humanizePaymentError(e);
          throw Exception(
            '$base\n\n(Details: code=${e.code}, message=${e.message})\nHTTP fallback: $httpError',
          );
        }
      } catch (e) {
        try {
          return await _createLeadPackCheckoutSessionHttp(
            packId: trimmedPackId,
          );
        } catch (httpError) {
          throw Exception(
            '${humanizePaymentError(e)}\n\nHTTP fallback: $httpError',
          );
        }
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

    return _createLeadPackCheckoutSessionHttp(packId: trimmedPackId);
  }

  Future<Map<String, String>> _createLeadPackCheckoutSessionHttp({
    required String packId,
  }) async {
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
      'https://us-central1-$projectId.cloudfunctions.net/createLeadPackCheckoutSessionHttp',
    );

    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'packId': packId}),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      String message = 'Payment request failed';
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
      throw Exception('Payment link unavailable');
    }

    final url = decoded['url']?.toString();
    final sessionId = decoded['sessionId']?.toString();
    return {
      if (url != null) 'url': url,
      if (sessionId != null) 'sessionId': sessionId,
    };
  }

  Future<Map<String, String>>
  _createContractorSubscriptionCheckoutSession() async {
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
          'createContractorSubscriptionCheckoutSession',
        );
        final response = await callable.call(<String, dynamic>{});
        final data = response.data;
        final url = (data is Map ? data['url'] : null) as String?;
        final sessionId = (data is Map ? data['sessionId'] : null) as String?;
        return {
          if (url != null) 'url': url.toString(),
          if (sessionId != null) 'sessionId': sessionId.toString(),
        };
      } on FirebaseFunctionsException catch (e) {
        // Callable can fail for common reasons (missing function, permission,
        // region mismatch, etc). Try the HTTP endpoint as a fallback so Android
        // builds can still work even if callable routing is misconfigured.
        try {
          return await _createContractorSubscriptionCheckoutSessionHttp();
        } catch (httpError) {
          final base = humanizePaymentError(e);
          throw Exception(
            '$base\n\n(Details: code=${e.code}, message=${e.message})\nHTTP fallback: $httpError',
          );
        }
      } catch (e) {
        try {
          return await _createContractorSubscriptionCheckoutSessionHttp();
        } catch (httpError) {
          throw Exception(
            '${humanizePaymentError(e)}\n\nHTTP fallback: $httpError',
          );
        }
      }
    }

    return _createContractorSubscriptionCheckoutSessionHttp();
  }

  Future<Map<String, String>>
  _createContractorSubscriptionCheckoutSessionHttp() async {
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
      'https://us-central1-$projectId.cloudfunctions.net/createContractorSubscriptionCheckoutSessionHttp',
    );

    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode(<String, dynamic>{}),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      String message = 'Subscription request failed';
      try {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map && decoded['error'] is String) {
          message = decoded['error'] as String;
        }
      } catch (_) {
        // ignore
      }
      throw Exception(
        '$message (HTTP ${resp.statusCode}). Ensure Cloud Function createContractorSubscriptionCheckoutSessionHttp is deployed.',
      );
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) {
      throw Exception('Subscription checkout link unavailable');
    }

    final url = decoded['url']?.toString();
    final sessionId = decoded['sessionId']?.toString();
    return {
      if (url != null) 'url': url,
      if (sessionId != null) 'sessionId': sessionId,
    };
  }
}
