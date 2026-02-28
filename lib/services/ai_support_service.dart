import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service that calls the `aiSupportChat` Cloud Function.
///
/// Manages the conversation history and returns the AI reply.
class AiSupportService {
  AiSupportService._();
  static final instance = AiSupportService._();

  /// Send a message to the AI support assistant.
  ///
  /// [messages] is the full conversation history as a list of
  /// `{ 'role': 'user'|'assistant', 'content': '...' }` maps.
  ///
  /// Returns the AI reply text.
  Future<String> send(List<Map<String, String>> messages) async {
    final payload = <String, dynamic>{'messages': messages};

    // Use callable on mobile/web, HTTP fallback on desktop (Windows/Linux).
    final useCallable = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    Map<String, dynamic> result;

    if (useCallable) {
      try {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'aiSupportChat',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
        );
        final resp = await callable.call(payload);
        result = _deepCast(resp.data) as Map<String, dynamic>;
      } catch (e) {
        if (kDebugMode) debugPrint('[AiSupport] callable failed: $e');
        // Fall back to HTTP
        result = await _sendViaHttp(payload);
      }
    } else {
      result = await _sendViaHttp(payload);
    }

    final reply = (result['reply'] ?? '').toString().trim();
    if (reply.isEmpty) throw Exception('AI returned an empty response.');
    return reply;
  }

  Future<Map<String, dynamic>> _sendViaHttp(
    Map<String, dynamic> payload,
  ) async {
    final idToken =
        await FirebaseAuth.instance.currentUser?.getIdToken() ?? '';
    final url = Uri.parse(
      'https://us-central1-proserve-hub-ada0e.cloudfunctions.net/aiSupportChatHttp',
    );
    final resp = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (idToken.isNotEmpty) 'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode(payload),
    );
    if (resp.statusCode != 200) {
      throw Exception('Server error: ${resp.statusCode}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// Recursively casts nested maps from callable responses.
  static dynamic _deepCast(dynamic value) {
    if (value is Map) {
      return <String, dynamic>{
        for (final e in value.entries) e.key.toString(): _deepCast(e.value),
      };
    }
    if (value is List) return value.map(_deepCast).toList();
    return value;
  }
}
