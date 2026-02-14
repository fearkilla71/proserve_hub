import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Manages the customer's trusted/curated contractor list.
///
/// Trusted pros are stored as a Firestore subcollection:
///   `users/{uid}/trusted_pros/{contractorId}`
///
/// Each doc stores:
///   - `trade`   (String)  — e.g. 'Painter', 'PW Tech'
///   - `note`    (String)  — private customer note
///   - `addedAt` (Timestamp)
class TrustedProsService {
  TrustedProsService._();
  static final TrustedProsService instance = TrustedProsService._();

  final _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _ref(String uid) =>
      _firestore.collection('users').doc(uid).collection('trusted_pros');

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Real-time stream of all trusted-pro documents.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchAll() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _ref(uid).snapshots();
  }

  /// Add a contractor to the trusted list.
  Future<void> add(
    String contractorId, {
    String trade = '',
    String note = '',
  }) async {
    final uid = _uid;
    if (uid == null) return;
    await _ref(uid).doc(contractorId).set({
      'trade': trade,
      'note': note,
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update trade/note for an existing trusted pro.
  Future<void> update(
    String contractorId, {
    String? trade,
    String? note,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final updates = <String, dynamic>{};
    if (trade != null) updates['trade'] = trade;
    if (note != null) updates['note'] = note;
    if (updates.isNotEmpty) {
      await _ref(uid).doc(contractorId).set(updates, SetOptions(merge: true));
    }
  }

  /// Remove a contractor from the trusted list.
  Future<void> remove(String contractorId) async {
    final uid = _uid;
    if (uid == null) return;
    await _ref(uid).doc(contractorId).delete();
  }

  /// Check whether a contractor is in the trusted list.
  Future<bool> isTrusted(String contractorId) async {
    final uid = _uid;
    if (uid == null) return false;
    final doc = await _ref(uid).doc(contractorId).get();
    return doc.exists;
  }
}
