import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

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

      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        throw Exception('Could not open onboarding link');
      }
    } catch (e, stack) {
      // ignore: avoid_print
      print('[ConnectService.startOnboarding] ERROR: $e');
      // ignore: avoid_print
      print('[ConnectService.startOnboarding] STACK: $stack');
      rethrow;
    }
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

    // ignore: avoid_print
    print('[ConnectService] HTTP response status: ${resp.statusCode}');
    // ignore: avoid_print
    print('[ConnectService] HTTP response body: ${resp.body}');

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
