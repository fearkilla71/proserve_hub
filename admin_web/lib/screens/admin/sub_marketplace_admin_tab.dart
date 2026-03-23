import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/admin_theme.dart';

/// ---------------------------------------------------------------------------
/// Sub-Contractor Marketplace Admin — Approval workflow for sub-partnerships,
/// commission tracking, active sub contracts visibility.
/// ---------------------------------------------------------------------------
class SubMarketplaceAdminTab extends StatefulWidget {
  final bool canWrite;
  const SubMarketplaceAdminTab({super.key, this.canWrite = false});

  @override
  State<SubMarketplaceAdminTab> createState() => _SubMarketplaceAdminTabState();
}

class _SubMarketplaceAdminTabState extends State<SubMarketplaceAdminTab> {
  StreamSubscription? _sub;
  bool _loading = true;
  List<Map<String, dynamic>> _partnerships = [];

  String _filter = 'all'; // all | pending | active | ended
  String _search = '';

  // KPIs
  int _total = 0;
  int _pending = 0;
  int _active = 0;
  double _totalCommissions = 0;

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
        .collection('sub_partnerships')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
          final docs = snap.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
          }).toList();

          int pending = 0;
          int active = 0;
          double commissions = 0;

          for (final p in docs) {
            final st = p['status'] ?? 'pending';
            if (st == 'pending') pending++;
            if (st == 'active') active++;
            commissions += (p['totalCommission'] as num?)?.toDouble() ?? 0;
          }

          setState(() {
            _partnerships = docs;
            _total = docs.length;
            _pending = pending;
            _active = active;
            _totalCommissions = commissions;
            _loading = false;
          });
        });
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _partnerships;
    if (_filter != 'all') {
      list = list.where((p) => p['status'] == _filter).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where(
            (p) =>
                (p['primaryName'] ?? '').toString().toLowerCase().contains(q) ||
                (p['subName'] ?? '').toString().toLowerCase().contains(q) ||
                (p['service'] ?? '').toString().toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final filtered = _filtered;

    return Column(
      children: [
        // KPIs
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _kpi('Partnerships', '$_total', AdminColors.accent2),
              _kpi('Pending', '$_pending', AdminColors.warning),
              _kpi('Active', '$_active', AdminColors.accent),
              _kpi(
                'Commissions',
                '\$${NumberFormat.compact().format(_totalCommissions)}',
                AdminColors.accent3,
              ),
            ],
          ),
        ),

        // Filter bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final s in ['all', 'pending', 'active', 'ended'])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(
                      s[0].toUpperCase() + s.substring(1),
                      style: const TextStyle(fontSize: 12),
                    ),
                    selected: _filter == s,
                    selectedColor: AdminColors.accent.withValues(alpha: 0.15),
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
                      borderRadius: BorderRadius.circular(8),
                    ),
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
                  child: Text(
                    'No partnerships found',
                    style: TextStyle(color: AdminColors.muted),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final p = filtered[i];
                    final primary = p['primaryName'] ?? 'Primary';
                    final sub = p['subName'] ?? 'Sub';
                    final service = p['service'] ?? '';
                    final status = p['status'] ?? 'pending';
                    final commission =
                        (p['commissionPercent'] as num?)?.toDouble() ?? 0;
                    final totalComm =
                        (p['totalCommission'] as num?)?.toDouble() ?? 0;
                    final ts = (p['createdAt'] as Timestamp?)?.toDate();

                    Color statusColor;
                    switch (status) {
                      case 'active':
                        statusColor = AdminColors.accent;
                        break;
                      case 'pending':
                        statusColor = AdminColors.warning;
                        break;
                      default:
                        statusColor = AdminColors.muted;
                    }

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AdminColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: status == 'pending'
                              ? AdminColors.warning.withValues(alpha: 0.3)
                              : AdminColors.line,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.handshake, size: 18, color: statusColor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$primary → $sub',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AdminColors.ink,
                                  ),
                                ),
                                Row(
                                  children: [
                                    if (service.toString().isNotEmpty)
                                      Text(
                                        '$service · ',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AdminColors.muted,
                                        ),
                                      ),
                                    Text(
                                      '${commission.toStringAsFixed(0)}% rate · \$${totalComm.toStringAsFixed(0)} earned',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AdminColors.muted,
                                      ),
                                    ),
                                    if (ts != null)
                                      Text(
                                        ' · ${DateFormat.MMMd().format(ts)}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AdminColors.muted,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ),
                          if (widget.canWrite && status == 'pending') ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(
                                Icons.check,
                                size: 18,
                                color: AdminColors.accent,
                              ),
                              tooltip: 'Approve',
                              onPressed: () async {
                                await FirebaseFirestore.instance
                                    .collection('sub_partnerships')
                                    .doc(p['id'])
                                    .update({'status': 'active'});
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                size: 18,
                                color: AdminColors.error,
                              ),
                              tooltip: 'Reject',
                              onPressed: () async {
                                await FirebaseFirestore.instance
                                    .collection('sub_partnerships')
                                    .doc(p['id'])
                                    .update({'status': 'ended'});
                              },
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
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AdminColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
