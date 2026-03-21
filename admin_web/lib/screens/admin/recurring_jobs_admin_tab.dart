import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/admin_theme.dart';
import '../../widgets/skeleton_loader.dart';

/// ---------------------------------------------------------------------------
/// Recurring Jobs Admin — Manage recurring job configurations, track recurring
/// revenue, handle cancellations and schedule overrides.
/// ---------------------------------------------------------------------------
class RecurringJobsAdminTab extends StatefulWidget {
  final bool canWrite;
  const RecurringJobsAdminTab({super.key, this.canWrite = false});

  @override
  State<RecurringJobsAdminTab> createState() => _RecurringJobsAdminTabState();
}

class _RecurringJobsAdminTabState extends State<RecurringJobsAdminTab> {
  StreamSubscription? _sub;
  bool _loading = true;
  List<Map<String, dynamic>> _configs = [];

  String _filter = 'all'; // all | active | paused | cancelled
  String _search = '';

  // KPIs
  int _total = 0;
  int _active = 0;
  double _recurringRevenue = 0;
  int _cancelled = 0;

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
        .collection('recurring_jobs')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      final docs = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();

      int active = 0;
      int cancelled = 0;
      double revenue = 0;

      for (final r in docs) {
        final st = r['status'] ?? 'active';
        if (st == 'active') {
          active++;
          revenue += (r['pricePerOccurrence'] as num?)?.toDouble() ?? 0;
        }
        if (st == 'cancelled') cancelled++;
      }

      setState(() {
        _configs = docs;
        _total = docs.length;
        _active = active;
        _recurringRevenue = revenue;
        _cancelled = cancelled;
        _loading = false;
      });
    });
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _configs;
    if (_filter != 'all') {
      list = list.where((r) => r['status'] == _filter).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where((r) =>
              (r['service'] ?? '').toString().toLowerCase().contains(q) ||
              (r['customerName'] ?? '').toString().toLowerCase().contains(q) ||
              (r['contractorName'] ?? '').toString().toLowerCase().contains(q))
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
              _kpi('Total', '$_total', AdminColors.accent2),
              _kpi('Active', '$_active', AdminColors.accent),
              _kpi('Monthly Rev',
                  '\$${NumberFormat.compact().format(_recurringRevenue)}',
                  AdminColors.accent3),
              _kpi('Cancelled', '$_cancelled', AdminColors.error),
            ],
          ),
        ),

        // Filter bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final s in ['all', 'active', 'paused', 'cancelled'])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(s[0].toUpperCase() + s.substring(1),
                        style: const TextStyle(fontSize: 12)),
                    selected: _filter == s,
                    selectedColor:
                        AdminColors.accent.withValues(alpha: 0.15),
                    onSelected: (_) => setState(() => _filter = s),
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
                  child: Text('No recurring jobs found',
                      style: TextStyle(color: AdminColors.muted)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final r = filtered[i];
                    final service = r['service'] ?? 'Unknown';
                    final customer = r['customerName'] ?? '';
                    final contractor = r['contractorName'] ?? '';
                    final status = r['status'] ?? 'active';
                    final freq = r['frequency'] ?? 'monthly';
                    final price =
                        (r['pricePerOccurrence'] as num?)?.toDouble() ?? 0;
                    final nextRun =
                        (r['nextRunAt'] as Timestamp?)?.toDate();

                    Color statusColor;
                    switch (status) {
                      case 'active':
                        statusColor = AdminColors.accent;
                        break;
                      case 'paused':
                        statusColor = AdminColors.warning;
                        break;
                      default:
                        statusColor = AdminColors.error;
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
                          Icon(Icons.replay,
                              size: 18, color: statusColor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(service.toString(),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AdminColors.ink)),
                                Text(
                                  '${customer.toString().isNotEmpty ? '$customer → ' : ''}$contractor · $freq',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AdminColors.muted),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('\$${price.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AdminColors.ink)),
                              if (nextRun != null)
                                Text(
                                  'Next: ${DateFormat.MMMd().format(nextRun)}',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: AdminColors.muted),
                                ),
                            ],
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color:
                                  statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor),
                            ),
                          ),
                          if (widget.canWrite) ...[
                            const SizedBox(width: 8),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert,
                                  size: 18, color: AdminColors.muted),
                              onSelected: (val) async {
                                await FirebaseFirestore.instance
                                    .collection('recurring_jobs')
                                    .doc(r['id'])
                                    .update({'status': val});
                              },
                              itemBuilder: (_) => [
                                if (status == 'active')
                                  const PopupMenuItem(
                                      value: 'paused',
                                      child: Text('Pause')),
                                if (status == 'paused')
                                  const PopupMenuItem(
                                      value: 'active',
                                      child: Text('Resume')),
                                if (status != 'cancelled')
                                  const PopupMenuItem(
                                      value: 'cancelled',
                                      child: Text('Cancel')),
                              ],
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
