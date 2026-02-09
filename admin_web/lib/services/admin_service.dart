import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AdminService {
  Future<Map<String, dynamic>> grantLeadCredits({
    required String targetUid,
    required int delta,
  }) async {
    final safeTarget = targetUid.trim();
    if (safeTarget.isEmpty) {
      throw Exception('targetUid required');
    }
    if (delta == 0) {
      throw Exception('delta must not be 0');
    }

    final supportsCallable =
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    if (supportsCallable) {
      try {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'grantLeadCredits',
        );
        final response = await callable.call(<String, dynamic>{
          'targetUid': safeTarget,
          'delta': delta,
        });

        final data = response.data;
        if (data is Map) {
          return Map<String, dynamic>.from(data);
        }
        return <String, dynamic>{};
      } on FirebaseFunctionsException {
        // Fall through to HTTP.
      } catch (_) {
        // Fall through to HTTP.
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
      'https://us-central1-$projectId.cloudfunctions.net/grantLeadCreditsHttp',
    );

    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'targetUid': safeTarget, 'delta': delta}),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      try {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map && decoded['error'] != null) {
          throw Exception(decoded['error'].toString());
        }
      } catch (_) {
        // ignore
      }
      throw Exception('Request failed (${resp.statusCode})');
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> removeFreeSignupCredits({
    int freeCredits = 3,
    bool dryRun = false,
  }) async {
    if (freeCredits < 0) {
      throw Exception('freeCredits must be >= 0');
    }

    final supportsCallable =
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    if (supportsCallable) {
      try {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'removeFreeSignupCredits',
        );
        final response = await callable.call(<String, dynamic>{
          'freeCredits': freeCredits,
          'dryRun': dryRun,
        });

        final data = response.data;
        if (data is Map) {
          return Map<String, dynamic>.from(data);
        }
        return <String, dynamic>{};
      } on FirebaseFunctionsException {
        // Fall through to HTTP.
      } catch (_) {
        // Fall through to HTTP.
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
      'https://us-central1-$projectId.cloudfunctions.net/removeFreeSignupCreditsHttp',
    );

    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode(<String, dynamic>{
        'freeCredits': freeCredits,
        'dryRun': dryRun,
      }),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      try {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map && decoded['error'] != null) {
          throw Exception(decoded['error'].toString());
        }
      } catch (_) {
        // ignore
      }
      throw Exception('Request failed (${resp.statusCode})');
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> hardDeleteUser({
    required String targetUid,
    String? reason,
  }) async {
    final safeTarget = targetUid.trim();
    if (safeTarget.isEmpty) {
      throw Exception('targetUid required');
    }

    final supportsCallable =
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    if (supportsCallable) {
      try {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'hardDeleteUser',
        );
        final response = await callable.call(<String, dynamic>{
          'targetUid': safeTarget,
          if (reason != null && reason.trim().isNotEmpty)
            'reason': reason.trim(),
        });

        final data = response.data;
        if (data is Map) {
          return Map<String, dynamic>.from(data);
        }
        return <String, dynamic>{};
      } on FirebaseFunctionsException {
        // Fall through to HTTP.
      } catch (_) {
        // Fall through to HTTP.
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
      'https://us-central1-$projectId.cloudfunctions.net/hardDeleteUserHttp',
    );

    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({
        'targetUid': safeTarget,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      }),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      try {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map && decoded['error'] != null) {
          throw Exception(decoded['error'].toString());
        }
      } catch (_) {
        // ignore
      }
      throw Exception('Request failed (${resp.statusCode})');
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return <String, dynamic>{};
  }
}
