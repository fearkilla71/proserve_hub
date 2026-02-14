import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Generates sequential, auto-incrementing invoice numbers per contractor.
///
/// Format: INV-YYYY-NNNNNN (e.g. INV-2025-000001)
///
/// Uses a Firestore counter document to guarantee uniqueness even across
/// multiple devices. Falls back to a timestamp-based number if Firestore
/// is unavailable.
class InvoiceNumberService {
  static final _firestore = FirebaseFirestore.instance;

  /// Returns the next invoice number for the currently signed-in user.
  ///
  /// Increments the counter atomically in Firestore so two concurrent
  /// calls will never produce the same number.
  static Future<String> nextInvoiceNumber() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _fallbackNumber();

    try {
      final counterRef = _firestore
          .collection('contractors')
          .doc(user.uid)
          .collection('settings')
          .doc('invoice_counter');

      final next = await _firestore.runTransaction<int>((tx) async {
        final snap = await tx.get(counterRef);
        final current = (snap.data()?['lastNumber'] as int?) ?? 0;
        final nextNum = current + 1;
        tx.set(counterRef, {'lastNumber': nextNum}, SetOptions(merge: true));
        return nextNum;
      });

      final year = DateTime.now().year;
      return 'INV-$year-${next.toString().padLeft(6, '0')}';
    } catch (_) {
      return _fallbackNumber();
    }
  }

  /// Timestamp-based fallback so invoice creation never blocks on Firestore.
  static String _fallbackNumber() {
    final now = DateTime.now();
    final ts = now.millisecondsSinceEpoch.toString().substring(5);
    return 'INV-${now.year}-$ts';
  }
}
