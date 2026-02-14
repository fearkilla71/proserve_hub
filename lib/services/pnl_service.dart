import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Data model for a single month's P&L summary.
class MonthlyPnl {
  final DateTime month;
  final double revenue;
  final double materialCosts;
  final double laborCosts;
  final double otherExpenses;

  const MonthlyPnl({
    required this.month,
    required this.revenue,
    required this.materialCosts,
    required this.laborCosts,
    required this.otherExpenses,
  });

  double get totalExpenses => materialCosts + laborCosts + otherExpenses;
  double get netProfit => revenue - totalExpenses;
  double get marginPercent => revenue > 0 ? (netProfit / revenue) * 100 : 0;
}

/// Aggregated P&L data for a date range.
class PnlReport {
  final List<MonthlyPnl> months;
  final double totalRevenue;
  final double totalMaterialCosts;
  final double totalLaborCosts;
  final double totalOtherExpenses;
  final Map<String, double> expensesByCategory;

  const PnlReport({
    required this.months,
    required this.totalRevenue,
    required this.totalMaterialCosts,
    required this.totalLaborCosts,
    required this.totalOtherExpenses,
    required this.expensesByCategory,
  });

  double get totalExpenses =>
      totalMaterialCosts + totalLaborCosts + totalOtherExpenses;
  double get netProfit => totalRevenue - totalExpenses;
  double get marginPercent =>
      totalRevenue > 0 ? (netProfit / totalRevenue) * 100 : 0;
}

/// Service that aggregates revenue, expenses, and labor costs into a P&L
/// report for the current contractor.
class PnlService {
  PnlService._();
  static final instance = PnlService._();

  final _fs = FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Build a P&L report for the last [monthsBack] months.
  Future<PnlReport> buildReport({int monthsBack = 6}) async {
    final uid = _uid;
    if (uid == null) {
      return const PnlReport(
        months: [],
        totalRevenue: 0,
        totalMaterialCosts: 0,
        totalLaborCosts: 0,
        totalOtherExpenses: 0,
        expensesByCategory: {},
      );
    }

    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month - monthsBack + 1, 1);

    // ── 1. Revenue: completed jobs claimed by this contractor ──
    final jobsSnap = await _fs
        .collection('job_requests')
        .where('claimedBy', isEqualTo: uid)
        .where('status', whereIn: ['completed', 'paid'])
        .get();

    // ── 2. Expenses (job_expenses collection) ──
    final expensesSnap = await _fs
        .collection('job_expenses')
        .where('createdByUid', isEqualTo: uid)
        .get();

    // ── 3. Labor logs ──
    final laborSnap = await _fs
        .collection('contractors')
        .doc(uid)
        .collection('labor_logs')
        .get();

    // ── Bucket into months ──
    final buckets = <String, _MonthBucket>{};

    // Initialize empty buckets for all months in range.
    for (var i = 0; i < monthsBack; i++) {
      final m = DateTime(now.year, now.month - i, 1);
      final key = _monthKey(m);
      buckets[key] = _MonthBucket(month: m);
    }

    // Revenue
    for (final doc in jobsSnap.docs) {
      final data = doc.data();
      final completedAt = _toDateTime(data['completedAt'] ?? data['createdAt']);
      if (completedAt == null || completedAt.isBefore(cutoff)) continue;

      final price = _toDouble(
        data['price'] ?? data['agreedPrice'] ?? data['totalPrice'],
      );
      final key = _monthKey(completedAt);
      buckets.putIfAbsent(
        key,
        () => _MonthBucket(
          month: DateTime(completedAt.year, completedAt.month, 1),
        ),
      );
      buckets[key]!.revenue += price;
    }

    // Expenses
    final categoryTotals = <String, double>{};
    for (final doc in expensesSnap.docs) {
      final data = doc.data();
      final date = _toDateTime(data['receiptDate'] ?? data['createdAt']);
      if (date == null || date.isBefore(cutoff)) continue;

      final amount = _toDouble(data['total']);
      final category = (data['category'] as String? ?? 'general').toLowerCase();
      final key = _monthKey(date);
      buckets.putIfAbsent(
        key,
        () => _MonthBucket(month: DateTime(date.year, date.month, 1)),
      );

      if (category == 'materials' || category == 'material') {
        buckets[key]!.materialCosts += amount;
      } else {
        buckets[key]!.otherExpenses += amount;
      }

      categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
    }

    // Labor
    for (final doc in laborSnap.docs) {
      final data = doc.data();
      final date = _toDateTime(data['date'] ?? data['createdAt']);
      if (date == null || date.isBefore(cutoff)) continue;

      final cost = _toDouble(data['totalCost']);
      final key = _monthKey(date);
      buckets.putIfAbsent(
        key,
        () => _MonthBucket(month: DateTime(date.year, date.month, 1)),
      );
      buckets[key]!.laborCosts += cost;
    }

    // Sort chronologically
    final sortedKeys = buckets.keys.toList()..sort();
    final months = sortedKeys.map((k) {
      final b = buckets[k]!;
      return MonthlyPnl(
        month: b.month,
        revenue: b.revenue,
        materialCosts: b.materialCosts,
        laborCosts: b.laborCosts,
        otherExpenses: b.otherExpenses,
      );
    }).toList();

    double totalRev = 0, totalMat = 0, totalLab = 0, totalOther = 0;
    for (final m in months) {
      totalRev += m.revenue;
      totalMat += m.materialCosts;
      totalLab += m.laborCosts;
      totalOther += m.otherExpenses;
    }

    return PnlReport(
      months: months,
      totalRevenue: totalRev,
      totalMaterialCosts: totalMat,
      totalLaborCosts: totalLab,
      totalOtherExpenses: totalOther,
      expensesByCategory: categoryTotals,
    );
  }

  // ── Helpers ──

  String _monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  DateTime? _toDateTime(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }

  double _toDouble(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw) ?? 0;
    return 0;
  }
}

class _MonthBucket {
  final DateTime month;
  double revenue = 0;
  double materialCosts = 0;
  double laborCosts = 0;
  double otherExpenses = 0;

  _MonthBucket({required this.month});
}
