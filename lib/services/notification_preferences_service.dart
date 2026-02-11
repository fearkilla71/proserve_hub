import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Manages per-user notification preferences stored in Firestore.
class NotificationPreferencesService {
  static final _firestore = FirebaseFirestore.instance;

  static const defaultPrefs = <String, bool>{
    'messages': true,
    'bids': true,
    'jobUpdates': true,
    'reviews': true,
    'referrals': true,
    'promotions': true,
  };

  static DocumentReference<Map<String, dynamic>> _prefsDoc() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Not signed in');
    return _firestore.collection('users').doc(uid);
  }

  /// Stream the current notification preferences map.
  static Stream<Map<String, bool>> stream() {
    return _prefsDoc().snapshots().map((snap) {
      final data = snap.data();
      final stored =
          (data?['notificationPrefs'] as Map<String, dynamic>?) ?? {};
      return {
        for (final key in defaultPrefs.keys)
          key: stored[key] as bool? ?? defaultPrefs[key]!,
      };
    });
  }

  /// Update a single preference toggle.
  static Future<void> setPreference(String key, bool value) async {
    await _prefsDoc().set({
      'notificationPrefs': {key: value},
    }, SetOptions(merge: true));
  }

  /// Fetch current preferences once.
  static Future<Map<String, bool>> get() async {
    final snap = await _prefsDoc().get();
    final stored =
        (snap.data()?['notificationPrefs'] as Map<String, dynamic>?) ?? {};
    return {
      for (final key in defaultPrefs.keys)
        key: stored[key] as bool? ?? defaultPrefs[key]!,
    };
  }
}
