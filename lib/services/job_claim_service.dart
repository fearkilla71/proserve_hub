import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class JobClaimService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  JobClaimService({FirebaseFirestore? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  Future<void> claimJob(String jobId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Please sign in to claim jobs');
    }

    // Desktop (Windows/Linux) has seen native crashes during Firestore transactions.
    // Use a server-side transaction via HTTP Cloud Function on those platforms.
    final useHttpEndpoint =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux);

    if (useHttpEndpoint) {
      await _claimJobHttp(jobId: jobId.trim(), user: user);
      return;
    }

    final uid = user.uid;

    final userRef = _db.collection('users').doc(uid);
    final jobRef = _db.collection('job_requests').doc(jobId);

    try {
      await _db.runTransaction((tx) async {
        final userSnap = await tx.get(userRef);
        final jobSnap = await tx.get(jobRef);

        if (!userSnap.exists) {
          throw Exception('User profile missing');
        }
        if (!jobSnap.exists) {
          throw Exception('Job not found');
        }

        final userData = userSnap.data() ?? <String, dynamic>{};
        final jobData = jobSnap.data() ?? <String, dynamic>{};

        final acceptedQuoteId =
            (jobData['acceptedQuoteId'] as String?)?.trim() ?? '';
        final acceptedBidId =
            (jobData['acceptedBidId'] as String?)?.trim() ?? '';
        final hasMutualAgreement =
            acceptedQuoteId.isNotEmpty || acceptedBidId.isNotEmpty;

        final role = (userData['role'] as String?)?.trim().toLowerCase();
        if (role != 'contractor') {
          throw Exception('Only contractors can claim jobs');
        }

        if (jobData['claimed'] == true) {
          throw Exception('Job already claimed');
        }

        if (!hasMutualAgreement) {
          throw Exception(
            'This job can only be claimed after a quote/bid is accepted.',
          );
        }

        assert(() {
          // Debug-only diagnostics to help track down rules mismatches.
          // (These do not run in release mode.)
          // ignore: avoid_print
          print(
            '[claimJob] uid=$uid role=${userData['role']} jobId=$jobId claimed=${jobData['claimed']} status=${jobData['status']} '
            'keys=${jobData.keys.toList()} paymentIntentId=${jobData['paymentIntentId']} fundedAt=${jobData['fundedAt']} completedAt=${jobData['completedAt']}',
          );
          return true;
        }());

        final company = (userData['company'] as String?)?.trim() ?? '';
        final name = (userData['name'] as String?)?.trim() ?? '';
        final claimedByName = company.isNotEmpty
            ? company
            : (name.isNotEmpty ? name : uid);

        tx.update(jobRef, {
          'claimed': true,
          'claimedBy': uid,
          'claimedByName': claimedByName,
          'status': 'accepted',
          'claimedAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception(
          'Missing permissions to claim this job. Make sure your user role is contractor and the job is claimable.',
        );
      }
      rethrow;
    }
  }

  Future<void> _claimJobHttp({
    required String jobId,
    required User user,
  }) async {
    if (jobId.isEmpty) {
      throw Exception('jobId required');
    }

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.trim().isEmpty) {
      throw Exception('Auth token unavailable');
    }

    final projectId = Firebase.app().options.projectId;
    if (projectId.trim().isEmpty) {
      throw Exception('Firebase projectId missing');
    }

    final uri = Uri.parse(
      'https://us-central1-$projectId.cloudfunctions.net/claimJobHttp',
    );

    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'jobId': jobId}),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      String message = 'Claim failed';
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
}
