import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Manages the customer's saved/favorite contractors.
///
/// Favourites are stored as a Firestore subcollection:
///   `users/{uid}/favorites/{contractorId}`
class FavoritesService {
  FavoritesService._();
  static final FavoritesService instance = FavoritesService._();

  final _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _favoritesRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('favorites');

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Returns a real-time stream of favorite contractor IDs.
  Stream<Set<String>> watchFavorites() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();

    return _favoritesRef(
      uid,
    ).snapshots().map((snap) => snap.docs.map((d) => d.id).toSet());
  }

  /// Check if a specific contractor is favourited.
  Future<bool> isFavorite(String contractorId) async {
    final uid = _uid;
    if (uid == null) return false;

    final doc = await _favoritesRef(uid).doc(contractorId).get();
    return doc.exists;
  }

  /// Toggle favorite status. Returns the new state.
  Future<bool> toggle(String contractorId) async {
    final uid = _uid;
    if (uid == null) return false;

    final ref = _favoritesRef(uid).doc(contractorId);
    final doc = await ref.get();

    if (doc.exists) {
      await ref.delete();
      return false;
    } else {
      await ref.set({'addedAt': FieldValue.serverTimestamp()});
      return true;
    }
  }

  /// Add a contractor to favorites.
  Future<void> add(String contractorId) async {
    final uid = _uid;
    if (uid == null) return;

    await _favoritesRef(
      uid,
    ).doc(contractorId).set({'addedAt': FieldValue.serverTimestamp()});
  }

  /// Remove a contractor from favorites.
  Future<void> remove(String contractorId) async {
    final uid = _uid;
    if (uid == null) return;

    await _favoritesRef(uid).doc(contractorId).delete();
  }
}
