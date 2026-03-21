import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/admin_theme.dart';
import '../../widgets/skeleton_loader.dart';

/// ---------------------------------------------------------------------------
/// Customer CRM Admin — LTV analytics, spending segmentation, health scores,
/// booking frequency, churn risk, and customer lifecycle management.
/// ---------------------------------------------------------------------------
class CustomerCrmAdminTab extends StatefulWidget {
  final bool canWrite;
  const CustomerCrmAdminTab({super.key, this.canWrite = false});

  @override
  State<CustomerCrmAdminTab> createState() => _CustomerCrmAdminTabState();
}

class _CustomerCrmAdminTabState extends State<CustomerCrmAdminTab> {
  StreamSubscription? _sub;
  bool _loading = true;
  List<Map<String, dynamic>> _customers = [];

  // filter
  String _segment = 'all'; // all | high | medium | low | churned
  String _search = '';

  // KPIs
  double _avgLtv = 0;
  int _highValue = 0;
  int _atRisk = 0;
  int _totalCustomers = 0;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _listen() {
    _sub = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'customer')
        .snapshots()
        .listen((snap) {
      final docs = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();

      double totalLtv = 0;
      int high = 0;
      int atRisk = 0;
      for (final c in docs) {
        final ltv = (c['lifetimeSpend'] as num?)?.toDouble() ?? 0;
        totalLtv += ltv;
        if (ltv > 1000) high++;
        final lastBooking = (c['lastBookingAt'] as Timestamp?)?.toDate();
        if (lastBooking != null &&
            DateTime.now().difference(lastBooking).inDays > 90) {
          atRisk++;
        }
      }

      setState(() {
        _customers = docs;
        _totalCustomers = docs.length;
        _avgLtv = docs.isEmpty ? 0 : totalLtv / docs.length;
        _highValue = high;
        _atRisk = atRisk;
        _loading = false;
      });
    });
  }

  String _healthScore(Map<String, dynamic> c) {
    final ltv = (c['lifetimeSpend'] as num?)?.toDouble() ?? 0;
    final bookings = (c['completedBookings'] as num?)?.toInt() ?? 0;
    final lastBooking = (c['lastBookingAt'] as Timestamp?)?.toDate();
    final daysSince = lastBooking != null
        ? DateTime.now().difference(lastBooking).inDays
        : 999;
    if (daysSince > 90) return 'churned';
    if (ltv > 1000 && bookings > 5) return 'high';
    if (ltv > 300 || bookings > 2) return 'medium';
    return 'low';
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _customers;
    if (_segment != 'all') {
      list = list.where((c) => _healthScore(c) == _segment).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where((c) =>
              (c['displayName'] ?? '').toString().toLowerCase().contains(q) ||
              (c['email'] ?? '').toString().toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SkeletonLoader();

    final filtered = _filtered;

    return Column(
      children: [
        // KPIs
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _kpi('Customers', '$_totalCustomers', AdminColors.accent2),
              _kpi('Avg LTV',
                  '\$${NumberFormat.compact().format(_avgLtv)}',
                  AdminColors.accent),
              _kpi('High Value', '$_highValue', AdminColors.accent3),
              _kpi('At Risk', '$_atRisk', AdminColors.warning),
            ],
          ),
        ),

        // Segment filter + search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final s in ['all', 'high', 'medium', 'low', 'churned'])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(s[0].toUpperCase() + s.substring(1),
                        style: const TextStyle(fontSize: 12)),
                    selected: _segment == s,
                    selectedColor: AdminColors.accent.withValues(alpha: 0.15),
                    onSelected: (_) => setState(() => _segment = s),
                  ),
                ),
              const Spacer(),
              SizedBox(
                width: 220,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search…',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text('No customers found',
                      style: TextStyle(color: AdminColors.muted)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final c = filtered[i];
                    final name = c['displayName'] ?? 'Unknown';
                    final email = c['email'] ?? '';
                    final ltv =
                        (c['lifetimeSpend'] as num?)?.toDouble() ?? 0;
                    final bookings =
                        (c['completedBookings'] as num?)?.toInt() ?? 0;
                    final score = _healthScore(c);
                    final lastBooking =
                        (c['lastBookingAt'] as Timestamp?)?.toDate();

                    Color scoreColor;
                    switch (score) {
                      case 'high':
                        scoreColor = AdminColors.accent;
                        break;
                      case 'medium':
                        scoreColor = AdminColors.accent2;
                        break;
                      case 'low':
                        scoreColor = AdminColors.muted;
                        break;
                      default:
                        scoreColor = AdminColors.error;
                    }

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AdminColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AdminColors.line),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                scoreColor.withValues(alpha: 0.15),
                            child: Text(name.toString().substring(0, 1),
                                style: TextStyle(
                                    color: scoreColor,
                                    fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name.toString(),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AdminColors.ink)),
                                Text(email.toString(),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AdminColors.muted)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('\$${ltv.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AdminColors.ink)),
                              Text('$bookings jobs',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AdminColors.muted)),
                            ],
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: scoreColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              score,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: scoreColor),
                            ),
                          ),
                          if (lastBooking != null) ...[
                            const SizedBox(width: 10),
                            Text(
                              DateFormat.MMMd().format(lastBooking),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AdminColors.muted),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _kpi(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AdminColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AdminColors.muted)),
          ],
        ),
      ),
    );
  }
}
