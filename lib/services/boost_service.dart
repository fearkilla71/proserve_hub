import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Manages contractor listing boosts / featured placement.
///
/// Firestore schema on the contractor doc:
///   - `featured`  : bool   — whether the listing is currently boosted
///   - `boostEnd`  : Timestamp — when the current boost expires
///   - `boostPlan` : String — e.g. 'week', 'month'
class BoostService {
  final _db = FirebaseFirestore.instance;

  /// Duration   → price label shown to the user.
  static const plans = <String, BoostPlan>{
    'week': BoostPlan(
      id: 'week',
      label: '1 Week Boost',
      days: 7,
      priceLabel: r'$9.99',
    ),
    'month': BoostPlan(
      id: 'month',
      label: '1 Month Boost',
      days: 30,
      priceLabel: r'$29.99',
    ),
  };

  /// Returns the current contractor's boost status.
  Future<BoostStatus> getStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return BoostStatus.inactive;

    final doc = await _db.collection('contractors').doc(uid).get();
    final data = doc.data();
    if (data == null) return BoostStatus.inactive;

    final featured = data['featured'] == true;
    final boostEnd = data['boostEnd'] as Timestamp?;

    if (!featured || boostEnd == null) return BoostStatus.inactive;

    final expires = boostEnd.toDate();
    if (expires.isBefore(DateTime.now())) {
      // Boost expired — clean up.
      await _db.collection('contractors').doc(uid).update({
        'featured': false,
        'boostEnd': FieldValue.delete(),
        'boostPlan': FieldValue.delete(),
      });
      return BoostStatus.inactive;
    }

    return BoostStatus(
      active: true,
      expiresAt: expires,
      plan: data['boostPlan'] as String?,
    );
  }

  /// Activate a boost for the current contractor.
  ///
  /// In production this should be gated behind a payment (Stripe / IAP).
  /// For now, it writes the fields directly so the UI + browse sort work.
  Future<void> activateBoost(String planId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in.');

    final plan = plans[planId];
    if (plan == null) throw Exception('Unknown boost plan: $planId');

    final now = DateTime.now();
    final end = now.add(Duration(days: plan.days));

    await _db.collection('contractors').doc(uid).update({
      'featured': true,
      'boostEnd': Timestamp.fromDate(end),
      'boostPlan': planId,
      'boostedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Cancel an active boost early.
  Future<void> cancelBoost() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await _db.collection('contractors').doc(uid).update({
      'featured': false,
      'boostEnd': FieldValue.delete(),
      'boostPlan': FieldValue.delete(),
    });
  }
}

class BoostPlan {
  final String id;
  final String label;
  final int days;
  final String priceLabel;

  const BoostPlan({
    required this.id,
    required this.label,
    required this.days,
    required this.priceLabel,
  });
}

class BoostStatus {
  final bool active;
  final DateTime? expiresAt;
  final String? plan;

  const BoostStatus({this.active = false, this.expiresAt, this.plan});

  static const inactive = BoostStatus();
}
