import 'package:cloud_firestore/cloud_firestore.dart';

/// Point values for different actions.
const int pointsPerJobBooked = 100;
const int pointsPerReviewLeft = 25;
const int pointsPerReferral = 200;
const int pointsPerRepeatBooking = 50;

/// XP values for contractor actions.
const int xpPerJobCompleted = 150;
const int xpPerFiveStarReview = 50;
const int xpPerMilestoneCompleted = 20;
const int xpPerPhotoUploaded = 10;
const int xpPerQuoteSubmitted = 15;

/// Contractor level thresholds (total XP).
const List<Map<String, dynamic>> contractorLevels = [
  {'level': 1, 'label': 'Bronze', 'xpNeeded': 0, 'icon': '🥉'},
  {'level': 2, 'label': 'Silver', 'xpNeeded': 500, 'icon': '🥈'},
  {'level': 3, 'label': 'Gold', 'xpNeeded': 1500, 'icon': '🥇'},
  {'level': 4, 'label': 'Platinum', 'xpNeeded': 3500, 'icon': '💎'},
  {'level': 5, 'label': 'Diamond', 'xpNeeded': 7000, 'icon': '👑'},
  {'level': 6, 'label': 'Elite', 'xpNeeded': 15000, 'icon': '🔥'},
];

/// Reward tiers for homeowner points.
const List<Map<String, dynamic>> rewardTiers = [
  {'points': 500, 'label': '\$5 off next job', 'discount': 5},
  {'points': 1000, 'label': '\$15 off next job', 'discount': 15},
  {'points': 2000, 'label': '\$30 off next job', 'discount': 30},
  {'points': 5000, 'label': 'Free basic service', 'discount': 100},
];

/// Loyalty & gamification service.
///
/// Firestore structure:
///   users/{uid}
///     - loyaltyPoints: int
///     - totalPointsEarned: int
///     - pointsRedeemed: int
///
///   contractors/{uid}
///     - xp: int
///     - level: int
///     - levelLabel: String
///
///   loyalty_events/{eventId}
///     - uid: String
///     - type: 'earn' | 'redeem'
///     - action: String (e.g. 'job_booked', 'review_left')
///     - points: int (positive for earn, negative for redeem)
///     - description: String
///     - createdAt: Timestamp
///
///   leaderboard (computed from contractors by XP)
class LoyaltyService {
  LoyaltyService._();
  static final instance = LoyaltyService._();

  final _db = FirebaseFirestore.instance;

  // ── Homeowner Points ──

  /// Award points to a homeowner.
  Future<void> awardPoints({
    required String userId,
    required int points,
    required String action,
    required String description,
  }) async {
    final userRef = _db.collection('users').doc(userId);
    final eventRef = _db.collection('loyalty_events').doc();

    await _db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      final data = userSnap.data() ?? {};
      final current = (data['loyaltyPoints'] as num?)?.toInt() ?? 0;
      final totalEarned = (data['totalPointsEarned'] as num?)?.toInt() ?? 0;

      tx.update(userRef, {
        'loyaltyPoints': current + points,
        'totalPointsEarned': totalEarned + points,
      });

      tx.set(eventRef, {
        'uid': userId,
        'type': 'earn',
        'action': action,
        'points': points,
        'description': description,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Redeem points for a reward.
  Future<bool> redeemPoints({
    required String userId,
    required int points,
    required String rewardLabel,
  }) async {
    final userRef = _db.collection('users').doc(userId);
    final eventRef = _db.collection('loyalty_events').doc();

    bool success = false;
    await _db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      final data = userSnap.data() ?? {};
      final current = (data['loyaltyPoints'] as num?)?.toInt() ?? 0;

      if (current < points) {
        success = false;
        return;
      }

      final redeemed = (data['pointsRedeemed'] as num?)?.toInt() ?? 0;

      tx.update(userRef, {
        'loyaltyPoints': current - points,
        'pointsRedeemed': redeemed + points,
      });

      tx.set(eventRef, {
        'uid': userId,
        'type': 'redeem',
        'action': 'reward_redeemed',
        'points': -points,
        'description': rewardLabel,
        'createdAt': FieldValue.serverTimestamp(),
      });

      success = true;
    });

    return success;
  }

  /// Get user's current loyalty points.
  Future<Map<String, int>> getPoints(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    final data = doc.data() ?? {};
    return {
      'current': (data['loyaltyPoints'] as num?)?.toInt() ?? 0,
      'totalEarned': (data['totalPointsEarned'] as num?)?.toInt() ?? 0,
      'redeemed': (data['pointsRedeemed'] as num?)?.toInt() ?? 0,
    };
  }

  /// Stream loyalty events for a user.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchEvents(String userId) {
    return _db
        .collection('loyalty_events')
        .where('uid', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  // ── Contractor XP ──

  /// Award XP to a contractor.
  Future<void> awardXP({
    required String contractorId,
    required int xp,
    required String action,
    required String description,
  }) async {
    final cRef = _db.collection('contractors').doc(contractorId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(cRef);
      final data = snap.data() ?? {};
      final currentXP = (data['xp'] as num?)?.toInt() ?? 0;
      final newXP = currentXP + xp;

      // Calculate new level
      final newLevel = _calculateLevel(newXP);

      tx.update(cRef, {
        'xp': newXP,
        'level': newLevel['level'],
        'levelLabel': newLevel['label'],
      });
    });

    // Log the event
    await _db.collection('loyalty_events').add({
      'uid': contractorId,
      'type': 'earn',
      'action': action,
      'points': xp,
      'description': description,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Map<String, dynamic> _calculateLevel(int xp) {
    Map<String, dynamic> result = contractorLevels.first;
    for (final level in contractorLevels) {
      if (xp >= (level['xpNeeded'] as int)) {
        result = level;
      }
    }
    return result;
  }

  /// Get contractor XP and level.
  Future<Map<String, dynamic>> getContractorLevel(String contractorId) async {
    final doc = await _db.collection('contractors').doc(contractorId).get();
    final data = doc.data() ?? {};
    final xp = (data['xp'] as num?)?.toInt() ?? 0;
    final level = _calculateLevel(xp);

    // Calculate progress to next level
    final currentThreshold = level['xpNeeded'] as int;
    final nextLevelIdx = contractorLevels.indexOf(level) + 1;
    final nextThreshold = nextLevelIdx < contractorLevels.length
        ? contractorLevels[nextLevelIdx]['xpNeeded'] as int
        : currentThreshold;
    final progressToNext = nextThreshold > currentThreshold
        ? (xp - currentThreshold) / (nextThreshold - currentThreshold)
        : 1.0;

    return {
      'xp': xp,
      'level': level['level'],
      'levelLabel': level['label'],
      'levelIcon': level['icon'],
      'progressToNext': progressToNext,
      'xpToNext': nextThreshold - xp,
      'nextLevelLabel': nextLevelIdx < contractorLevels.length
          ? contractorLevels[nextLevelIdx]['label']
          : 'Max',
    };
  }

  // ── Leaderboard ──

  /// Get top contractors by XP (seasonal leaderboard).
  Future<List<Map<String, dynamic>>> getLeaderboard({int limit = 20}) async {
    final snap = await _db
        .collection('contractors')
        .orderBy('xp', descending: true)
        .limit(limit)
        .get();

    return snap.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'name': data['publicName'] ?? data['name'] ?? 'Unknown',
        'xp': (data['xp'] as num?)?.toInt() ?? 0,
        'level': (data['level'] as num?)?.toInt() ?? 1,
        'levelLabel': data['levelLabel'] ?? 'Bronze',
        'totalJobsCompleted':
            (data['totalJobsCompleted'] as num?)?.toInt() ?? 0,
        'avgRating': (data['avgRating'] as num?)?.toDouble() ?? 0,
      };
    }).toList();
  }
}
