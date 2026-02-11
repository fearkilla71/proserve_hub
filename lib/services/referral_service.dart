import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Manages referral codes and promo credit for customers.
///
/// Firestore structure:
///   `users/{uid}/referralCode`    – the user's unique referral code (String)
///   `referrals/{code}`            – doc mapping a code → owner uid
///   `users/{uid}/promoCredits`    – accumulated credit in dollars (num)
///   `users/{uid}/referralHistory` – subcollection of applied codes
class ReferralService {
  ReferralService._();
  static final ReferralService instance = ReferralService._();

  final _firestore = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Credit amount granted to both referrer and referred user.
  static const double creditAmount = 10.0;

  // ─── Code Generation ────────────────────────────────────────────────

  /// Get or create the current user's referral code.
  Future<String> getOrCreateCode() async {
    final uid = _uid;
    if (uid == null) throw Exception('Not signed in');

    final userDoc = await _firestore.collection('users').doc(uid).get();
    final existing = userDoc.data()?['referralCode'] as String?;
    if (existing != null && existing.isNotEmpty) return existing;

    // Generate a unique 8-char alphanumeric code.
    final code = _generateCode();
    await _firestore.collection('users').doc(uid).set({
      'referralCode': code,
    }, SetOptions(merge: true));

    // Register code → owner mapping.
    await _firestore.collection('referrals').doc(code).set({
      'ownerUid': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return code;
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // ─── Apply a Referral Code ──────────────────────────────────────────

  /// Apply another user's referral code. Returns an error message or null on success.
  Future<String?> applyCode(String code) async {
    final uid = _uid;
    if (uid == null) return 'Not signed in';

    final codeUpper = code.trim().toUpperCase();

    // Check code exists.
    final codeDoc = await _firestore
        .collection('referrals')
        .doc(codeUpper)
        .get();
    if (!codeDoc.exists) return 'Invalid referral code';

    final ownerUid = codeDoc.data()!['ownerUid'] as String;
    if (ownerUid == uid) return 'You cannot use your own referral code';

    // Check if already used.
    final historyRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('referralHistory');
    final existing = await historyRef.doc(codeUpper).get();
    if (existing.exists) return 'You have already used this code';

    // Apply credit to both users.
    final batch = _firestore.batch();

    // Credit referred user.
    batch.set(_firestore.collection('users').doc(uid), {
      'promoCredits': FieldValue.increment(creditAmount),
    }, SetOptions(merge: true));

    // Credit referrer.
    batch.set(_firestore.collection('users').doc(ownerUid), {
      'promoCredits': FieldValue.increment(creditAmount),
    }, SetOptions(merge: true));

    // Record in history.
    batch.set(historyRef.doc(codeUpper), {
      'code': codeUpper,
      'referrerUid': ownerUid,
      'credit': creditAmount,
      'appliedAt': FieldValue.serverTimestamp(),
    });

    // Increment usage count on the referral code doc.
    batch.update(_firestore.collection('referrals').doc(codeUpper), {
      'usageCount': FieldValue.increment(1),
    });

    // Record who used the code (for referrer's dashboard).
    batch.set(
      _firestore
          .collection('referrals')
          .doc(codeUpper)
          .collection('usedBy')
          .doc(uid),
      {
        'uid': uid,
        'credit': creditAmount,
        'appliedAt': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();
    return null; // success
  }

  // ─── Read credit ───────────────────────────────────────────────────

  /// Stream the current user's promo credit balance.
  Stream<double> watchCredits() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snap) => (snap.data()?['promoCredits'] as num?)?.toDouble() ?? 0);
  }

  // ─── Dashboard stats ──────────────────────────────────────────────

  /// Stream the usage count for the current user's referral code.
  Stream<int> watchMyCodeUsageCount(String code) {
    return _firestore
        .collection('referrals')
        .doc(code)
        .snapshots()
        .map((snap) => (snap.data()?['usageCount'] as int?) ?? 0);
  }

  /// Stream the list of people who used the current user's referral code.
  Stream<List<Map<String, dynamic>>> watchMyCodeUsedBy(String code) {
    return _firestore
        .collection('referrals')
        .doc(code)
        .collection('usedBy')
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) => d.data()).toList();
      list.sort((a, b) {
        final ta = a['appliedAt'] as Timestamp?;
        final tb = b['appliedAt'] as Timestamp?;
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });
      return list;
    });
  }

  /// Stream the current user's own referral history (codes they redeemed).
  Stream<List<Map<String, dynamic>>> watchMyRedemptions() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('referralHistory')
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) => d.data()).toList();
      list.sort((a, b) {
        final ta = a['appliedAt'] as Timestamp?;
        final tb = b['appliedAt'] as Timestamp?;
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });
      return list;
    });
  }
}
