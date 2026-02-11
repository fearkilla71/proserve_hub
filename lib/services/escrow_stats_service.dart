import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for aggregating escrow statistics used by social proof
/// banners and streak calculations.
class EscrowStatsService {
  final _col = FirebaseFirestore.instance.collection('escrow_bookings');

  // ── Cache fields (5-min cache) ──
  DateTime? _lastFetch;
  Map<String, dynamic> _cached = {};

  /// Get aggregate stats for social proof.
  /// Returns: totalBookings, totalSavings, avgSavings, avgSavingsPercent, avgRating, ratingCount
  Future<Map<String, dynamic>> getAggregateStats() async {
    if (_lastFetch != null &&
        DateTime.now().difference(_lastFetch!).inMinutes < 5 &&
        _cached.isNotEmpty) {
      return _cached;
    }

    // Count funded / released bookings
    final snap = await _col
        .where(
          'status',
          whereIn: [
            'funded',
            'customerConfirmed',
            'contractorConfirmed',
            'released',
          ],
        )
        .orderBy('createdAt', descending: true)
        .limit(500)
        .get();

    int totalBookings = snap.docs.length;
    double totalSavings = 0;
    double savingsPercentSum = 0;
    int savingsCount = 0;
    double ratingSum = 0;
    int ratingCount = 0;

    for (final doc in snap.docs) {
      final d = doc.data();
      final savings = (d['savingsAmount'] as num?)?.toDouble();
      final savingsPct = (d['savingsPercent'] as num?)?.toDouble();
      final rating = (d['priceFairnessRating'] as num?)?.toInt();

      if (savings != null && savings > 0) {
        totalSavings += savings;
        savingsCount++;
      }
      if (savingsPct != null && savingsPct > 0) {
        savingsPercentSum += savingsPct;
      }
      if (rating != null) {
        ratingSum += rating;
        ratingCount++;
      }
    }

    _cached = {
      'totalBookings': totalBookings,
      'totalSavings': totalSavings,
      'avgSavings': savingsCount > 0 ? (totalSavings / savingsCount) : 0.0,
      'avgSavingsPercent': savingsCount > 0
          ? (savingsPercentSum / savingsCount)
          : 0.0,
      'avgRating': ratingCount > 0 ? (ratingSum / ratingCount) : 0.0,
      'ratingCount': ratingCount,
    };
    _lastFetch = DateTime.now();
    return _cached;
  }

  /// Get a customer's escrow booking streak (funded/released count).
  Future<int> getCustomerStreak(String customerId) async {
    final snap = await _col
        .where('customerId', isEqualTo: customerId)
        .where(
          'status',
          whereIn: [
            'funded',
            'customerConfirmed',
            'contractorConfirmed',
            'released',
          ],
        )
        .get();
    return snap.docs.length;
  }

  /// Get a contractor's total escrow completions.
  Future<int> getContractorCompletions(String contractorId) async {
    final snap = await _col
        .where('contractorId', isEqualTo: contractorId)
        .where('status', isEqualTo: 'released')
        .get();
    return snap.docs.length;
  }

  /// Get a customer's loyalty discount based on streak.
  /// 0 bookings: 0%, 3+: 3%, 5+: 5%, 10+: 8%
  Future<double> getLoyaltyDiscount(String customerId) async {
    final streak = await getCustomerStreak(customerId);
    if (streak >= 10) return 0.08;
    if (streak >= 5) return 0.05;
    if (streak >= 3) return 0.03;
    return 0.0;
  }

  /// Get recent ratings for social proof.
  Future<List<Map<String, dynamic>>> getRecentRatings({int limit = 5}) async {
    final snap = await _col
        .where('priceFairnessRating', isGreaterThan: 0)
        .orderBy('priceFairnessRating')
        .orderBy('ratedAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  /// Invalidate cache (e.g. after new booking or rating).
  void invalidateCache() {
    _lastFetch = null;
    _cached = {};
  }
}
