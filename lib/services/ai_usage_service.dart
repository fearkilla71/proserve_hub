import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../widgets/contractor_portal_helpers.dart';

/// Tracks daily AI usage and enforces per-tier rate limits.
///
/// Firestore structure:
///   users/{uid}/ai_usage/{YYYY-MM-DD}
///     - renders: int
///     - estimates: int
///     - invoiceAi: int
///     - updatedAt: Timestamp
class AiUsageService {
  AiUsageService._();
  static final instance = AiUsageService._();

  final _fs = FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ── Daily limits per tier (0 = blocked, -1 = unlimited) ──
  static const Map<String, Map<String, int>> _limits = {
    'basic': {'renders': 1, 'estimates': 3, 'invoiceAi': 2},
    'pro': {'renders': 5, 'estimates': 10, 'invoiceAi': 10},
    'enterprise': {'renders': -1, 'estimates': -1, 'invoiceAi': -1},
  };

  /// Returns the daily limit for [feature] at [tier].
  /// -1 means unlimited.
  static int dailyLimit(String tier, String feature) {
    return _limits[tier]?[feature] ?? _limits['basic']![feature] ?? 0;
  }

  String _todayKey() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  DocumentReference<Map<String, dynamic>> _usageDoc() {
    return _fs
        .collection('users')
        .doc(_uid)
        .collection('ai_usage')
        .doc(_todayKey());
  }

  /// Get the current usage count for [feature] today.
  Future<int> getUsageToday(String feature) async {
    final uid = _uid;
    if (uid == null) return 0;
    final snap = await _usageDoc().get();
    if (!snap.exists) return 0;
    return (snap.data()?[feature] as num?)?.toInt() ?? 0;
  }

  /// Check whether the user can use [feature] based on their tier.
  /// Returns `null` if allowed, or an error message if rate-limited.
  Future<String?> checkLimit(String feature) async {
    final uid = _uid;
    if (uid == null) return 'Sign in required';

    // Look up user tier.
    final userSnap = await _fs.collection('users').doc(uid).get();
    final tier = effectiveSubscriptionTier(userSnap.data());
    final limit = dailyLimit(tier, feature);

    // Unlimited.
    if (limit < 0) return null;

    final used = await getUsageToday(feature);
    if (used >= limit) {
      final featureLabel = _featureLabel(feature);
      if (tier == 'pro') {
        return 'You\'ve used all $limit $featureLabel today. '
            'Upgrade to Enterprise for unlimited AI.';
      }
      return 'You\'ve used all $limit $featureLabel today. '
          'Upgrade your plan for more AI uses.';
    }

    return null;
  }

  /// Increment the usage counter for [feature].
  /// Call this AFTER a successful AI operation.
  Future<void> recordUsage(String feature) async {
    final uid = _uid;
    if (uid == null) return;
    await _usageDoc().set({
      feature: FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Get remaining uses for [feature] today.
  /// Returns -1 for unlimited.
  Future<int> remainingToday(String feature) async {
    final uid = _uid;
    if (uid == null) return 0;

    final userSnap = await _fs.collection('users').doc(uid).get();
    final tier = effectiveSubscriptionTier(userSnap.data());
    final limit = dailyLimit(tier, feature);

    if (limit < 0) return -1; // Unlimited.

    final used = await getUsageToday(feature);
    return (limit - used).clamp(0, limit);
  }

  String _featureLabel(String feature) {
    switch (feature) {
      case 'renders':
        return 'AI renders';
      case 'estimates':
        return 'AI estimates';
      case 'invoiceAi':
        return 'AI invoice drafts';
      default:
        return 'AI uses';
    }
  }
}
