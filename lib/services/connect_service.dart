import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class ConnectOnboardingException implements Exception {
  const ConnectOnboardingException(this.userMessage, {this.cause});

  final String userMessage;
  final Object? cause;

  @override
  String toString() => userMessage;
}

class ConnectService {
  Future<void> startOnboarding() async {
    try {
      final result = await _createOnboardingLink();
      final url = (result['url'] ?? '').toString().trim();
      if (url.isEmpty) {
        throw Exception('Onboarding link unavailable');
      }

      final uri = Uri.tryParse(url);
      if (uri == null) {
        throw Exception('Invalid onboarding URL');
      }

      var ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      }
      if (!ok) {
        throw Exception('Could not open onboarding link');
      }
    } catch (e, stack) {
      debugPrint('[ConnectService.startOnboarding] ERROR: $e');
      debugPrint('[ConnectService.startOnboarding] STACK: $stack');
      if (e is ConnectOnboardingException) rethrow;
      throw ConnectOnboardingException(_friendlyConnectMessage(e), cause: e);
    }
  }

  String _friendlyConnectMessage(Object error) {
    if (error is FirebaseFunctionsException) {
      final message = (error.message ?? '').trim();
      if (error.code == 'resource-exhausted') {
        final retryHint = _extractRetryHint(message);
        return retryHint == null
            ? 'Payout setup is temporarily unavailable. Please retry in a few minutes.'
            : 'Payout setup is temporarily unavailable. Try again after $retryHint.';
      }
      if (error.code == 'unauthenticated') {
        return 'Sign in again before connecting payouts.';
      }
      if (error.code == 'failed-precondition') {
        return message.isEmpty
            ? 'Payout setup is not ready for this account yet.'
            : message;
      }
      if (error.code == 'internal' || message.toUpperCase() == 'INTERNAL') {
        return 'Payout setup is temporarily unavailable. Please try again or contact support.';
      }
      if (message.isNotEmpty) return message;
    }

    final text = error
        .toString()
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .trim();
    final lower = text.toLowerCase();
    if (lower.contains('rate limit')) {
      final retryHint = _extractRetryHint(text);
      return retryHint == null
          ? 'Payout setup is temporarily unavailable. Please retry in a few minutes.'
          : 'Payout setup is temporarily unavailable. Try again after $retryHint.';
    }
    if (lower.contains('internal')) {
      return 'Payout setup is temporarily unavailable. Please try again or contact support.';
    }
    if (lower.contains('sign in') || lower.contains('auth')) {
      return 'Sign in again before connecting payouts.';
    }
    if (text.isNotEmpty) return text;
    return 'Could not open payout setup. Try again.';
  }

  String? _extractRetryHint(String message) {
    final match = RegExp(
      r'after\s+([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z?)',
      caseSensitive: false,
    ).firstMatch(message);
    return match?.group(1);
  }

  Future<Map<String, dynamic>> _createOnboardingLink() async {
    final useCallable =
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    if (useCallable) {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'createConnectOnboardingLink',
      );
      final resp = await callable.call(<String, dynamic>{});
      final data = resp.data;
      return data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
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
      'https://us-central1-$projectId.cloudfunctions.net/createConnectOnboardingLinkHttp',
    );

    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({}),
    );

    debugPrint('[ConnectService] HTTP response status: ${resp.statusCode}');
    debugPrint('[ConnectService] HTTP response body: ${resp.body}');

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      String message = 'Onboarding request failed';
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
      throw Exception('Onboarding link unavailable');
    }
    return Map<String, dynamic>.from(decoded);
  }
}
