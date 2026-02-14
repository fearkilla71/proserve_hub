import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for two-way reliability ratings.
/// Contractors rate homeowners after job completion.
///
/// Firestore structure:
///   users/{homeownerId}/reliability_ratings/{ratingId}
///     - contractorId: String
///     - jobId: String
///     - accessOnTime: int (1-5)
///     - communication: int (1-5)
///     - paymentPromptness: int (1-5)
///     - propertyCondition: int (1-5)
///     - overallScore: double (average of the 4)
///     - comment: String?
///     - createdAt: Timestamp
///
///   users/{homeownerId}  (aggregated)
///     - reliabilityScore: double (running average)
///     - reliabilityCount: int
class HomeownerReliabilityService {
  HomeownerReliabilityService._();
  static final instance = HomeownerReliabilityService._();

  final _db = FirebaseFirestore.instance;

  /// Submit a reliability rating for a homeowner.
  Future<void> rateHomeowner({
    required String homeownerId,
    required String jobId,
    required int accessOnTime,
    required int communication,
    required int paymentPromptness,
    required int propertyCondition,
    String? comment,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    final overall =
        (accessOnTime + communication + paymentPromptness + propertyCondition) /
        4.0;

    final ref = _db
        .collection('users')
        .doc(homeownerId)
        .collection('reliability_ratings')
        .doc();

    await ref.set({
      'contractorId': uid,
      'jobId': jobId,
      'accessOnTime': accessOnTime,
      'communication': communication,
      'paymentPromptness': paymentPromptness,
      'propertyCondition': propertyCondition,
      'overallScore': overall,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update aggregated score on user doc
    await _updateAggregatedScore(homeownerId);

    // Mark job as rated by contractor
    await _db.collection('job_requests').doc(jobId).update({
      'homeownerRatedByContractor': true,
      'homeownerReliabilityScore': overall,
    });
  }

  Future<void> _updateAggregatedScore(String homeownerId) async {
    final snap = await _db
        .collection('users')
        .doc(homeownerId)
        .collection('reliability_ratings')
        .get();

    if (snap.docs.isEmpty) return;

    double totalScore = 0;
    for (final doc in snap.docs) {
      totalScore += (doc.data()['overallScore'] as num?)?.toDouble() ?? 0;
    }

    final avg = totalScore / snap.docs.length;

    await _db.collection('users').doc(homeownerId).update({
      'reliabilityScore': double.parse(avg.toStringAsFixed(2)),
      'reliabilityCount': snap.docs.length,
    });
  }

  /// Get a homeowner's aggregated reliability score.
  Future<Map<String, dynamic>> getReliabilityScore(String homeownerId) async {
    final doc = await _db.collection('users').doc(homeownerId).get();
    final data = doc.data() ?? {};
    return {
      'score': (data['reliabilityScore'] as num?)?.toDouble() ?? 0,
      'count': (data['reliabilityCount'] as num?)?.toInt() ?? 0,
      'name': data['name'] ?? '',
    };
  }

  /// Check if contractor already rated this homeowner for a specific job.
  Future<bool> hasRated(String homeownerId, String jobId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    final snap = await _db
        .collection('users')
        .doc(homeownerId)
        .collection('reliability_ratings')
        .where('contractorId', isEqualTo: uid)
        .where('jobId', isEqualTo: jobId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  /// Stream all ratings for a homeowner.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchRatings(String homeownerId) {
    return _db
        .collection('users')
        .doc(homeownerId)
        .collection('reliability_ratings')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
