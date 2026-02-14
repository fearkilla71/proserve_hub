import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Standalone expense tracker service — queries expenses across ALL jobs
/// for the current user, supports categories & tax-deductible flagging.
class StandaloneExpenseService {
  StandaloneExpenseService._();
  static final instance = StandaloneExpenseService._();

  final _fs = FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ── All Expenses for current user ──
  Stream<QuerySnapshot<Map<String, dynamic>>> watchAllExpenses() {
    return _fs
        .collection('job_expenses')
        .where('createdByUid', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ── Add standalone expense (not tied to a specific job) ──
  Future<void> addStandaloneExpense({
    required String vendor,
    required double amount,
    double? tax,
    String? category,
    String? notes,
    DateTime? receiptDate,
    bool taxDeductible = false,
    String? receiptUrl,
  }) async {
    await _fs.collection('job_expenses').add({
      'createdByUid': _uid,
      'vendor': vendor,
      'total': amount,
      'tax': tax ?? 0,
      'category': category ?? 'general',
      'notes': notes,
      'receiptDate': receiptDate != null
          ? Timestamp.fromDate(receiptDate)
          : FieldValue.serverTimestamp(),
      'taxDeductible': taxDeductible,
      'receiptUrl': receiptUrl,
      'jobId': 'standalone', // marker for non-job expenses
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Toggle tax-deductible flag ──
  Future<void> toggleTaxDeductible(String expenseId, bool value) async {
    await _fs.collection('job_expenses').doc(expenseId).update({
      'taxDeductible': value,
    });
  }

  // ── Set category ──
  Future<void> setCategory(String expenseId, String category) async {
    await _fs.collection('job_expenses').doc(expenseId).update({
      'category': category,
    });
  }

  // ── Delete ──
  Future<void> deleteExpense(String expenseId) async {
    await _fs.collection('job_expenses').doc(expenseId).delete();
  }

  // ── Aggregation helpers ──
  Future<Map<String, double>> getCategoryTotals() async {
    final snap = await _fs
        .collection('job_expenses')
        .where('createdByUid', isEqualTo: _uid)
        .get();
    final totals = <String, double>{};
    for (final doc in snap.docs) {
      final cat = doc.data()['category'] as String? ?? 'general';
      final total = (doc.data()['total'] as num?)?.toDouble() ?? 0;
      totals[cat] = (totals[cat] ?? 0) + total;
    }
    return totals;
  }

  Future<double> getTaxDeductibleTotal() async {
    final snap = await _fs
        .collection('job_expenses')
        .where('createdByUid', isEqualTo: _uid)
        .where('taxDeductible', isEqualTo: true)
        .get();
    double total = 0;
    for (final doc in snap.docs) {
      total += (doc.data()['total'] as num?)?.toDouble() ?? 0;
    }
    return total;
  }

  static const categories = <String, String>{
    'general': 'General',
    'materials': 'Materials',
    'tools': 'Tools & Equipment',
    'fuel': 'Fuel & Mileage',
    'subcontractor': 'Subcontractor',
    'insurance': 'Insurance',
    'advertising': 'Advertising',
    'office': 'Office & Admin',
    'vehicle': 'Vehicle',
    'meals': 'Meals',
    'education': 'Education & Training',
    'other': 'Other',
  };
}
