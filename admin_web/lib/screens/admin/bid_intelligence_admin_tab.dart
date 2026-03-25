import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/admin_theme.dart';

/// ---------------------------------------------------------------------------
/// Bid Intelligence Admin — Aggregated bidding analytics: acceptance rates,
/// avg bid amounts by service/region, undercut alerts, time-to-bid metrics.
/// ---------------------------------------------------------------------------
class BidIntelligenceAdminTab extends StatefulWidget {
  const BidIntelligenceAdminTab({super.key});

  @override
  State<BidIntelligenceAdminTab> createState() =>
      _BidIntelligenceAdminTabState();
}

class _BidIntelligenceAdminTabState extends State<BidIntelligenceAdminTab> {
  StreamSubscription? _sub;
  bool _loading = true;
  List<Map<String, dynamic>> _bids = [];

  String _filter = 'all'; // all | accepted | rejected | pending
  String _search = '';

  // KPIs
  int _totalBids = 0;
  double _avgAmount = 0;
  double _acceptRate = 0;
  double _avgTimeToBid = 0; // hours

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
        .collection('bids')
        .orderBy('createdAt', descending: true)
        .limit(500)
        .snapshots()
        .listen(
          (snap) {
            final docs = snap.docs.map((d) {
              final data = d.data();
              data['id'] = d.id;
              data['_path'] = d.reference.path;
              return data;
            }).toList();

            double sumAmt = 0;
            int accepted = 0;
            double sumHours = 0;
            int withTime = 0;

            for (final b in docs) {
              sumAmt += (b['amount'] as num?)?.toDouble() ?? 0;
              if (b['status'] == 'accepted') accepted++;
              final created = (b['createdAt'] as Timestamp?)?.toDate();
              final jobPosted = (b['jobPostedAt'] as Timestamp?)?.toDate();
              if (created != null && jobPosted != null) {
                sumHours += created.difference(jobPosted).inMinutes / 60.0;
                withTime++;
              }
            }

            setState(() {
              _bids = docs;
              _totalBids = docs.length;
              _avgAmount = docs.isEmpty ? 0 : sumAmt / docs.length;
              _acceptRate = docs.isEmpty ? 0 : (accepted / docs.length) * 100;
              _avgTimeToBid = withTime == 0 ? 0 : sumHours / withTime;
              _loading = false;
            });
          },
          onError: (e) {
            debugPrint('bids listen error: $e');
            if (mounted) setState(() => _loading = false);
          },
        );
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _bids;
    if (_filter != 'all') {
      list = list.where((b) => b['status'] == _filter).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where(
            (b) =>
                (b['contractorName'] ?? '').toString().toLowerCase().contains(
                  q,
                ) ||
                (b['service'] ?? '').toString().toLowerCase().contains(q) ||
                (b['id'] ?? '').toString().toLowerCase().contains(q),
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
              _kpi('Bids', '$_totalBids', AdminColors.accent2),
              _kpi(
                'Avg Amount',
                '\$${NumberFormat.compact().format(_avgAmount)}',
                AdminColors.accent,
              ),
              _kpi(
                'Accept Rate',
                '${_acceptRate.toStringAsFixed(1)}%',
                AdminColors.accent3,
              ),
              _kpi(
                'Avg Time',
                '${_avgTimeToBid.toStringAsFixed(1)}h',
                AdminColors.warning,
              ),
            ],
          ),
        ),

        // Filter bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final s in ['all', 'pending', 'accepted', 'rejected'])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(
                      s[0].toUpperCase() + s.substring(1),
                      style: const TextStyle(fontSize: 12),
                    ),
                    selected: _filter == s,
                    selectedColor: AdminColors.accent2.withValues(alpha: 0.15),
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

        // Bids list
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No bids found',
                    style: TextStyle(color: AdminColors.muted),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final b = filtered[i];
                    final contractor = b['contractorName'] ?? 'Unknown';
                    final amount = (b['amount'] as num?)?.toDouble() ?? 0;
                    final status = b['status'] ?? 'pending';
                    final service = b['service'] ?? '';
                    final ts = (b['createdAt'] as Timestamp?)?.toDate();

                    Color statusColor;
                    switch (status) {
                      case 'accepted':
                        statusColor = AdminColors.accent;
                        break;
                      case 'rejected':
                        statusColor = AdminColors.error;
                        break;
                      default:
                        statusColor = AdminColors.warning;
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
                            radius: 16,
                            backgroundColor: statusColor.withValues(
                              alpha: 0.15,
                            ),
                            child: Icon(
                              Icons.gavel,
                              size: 14,
                              color: statusColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  contractor.toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AdminColors.ink,
                                  ),
                                ),
                                if (service.toString().isNotEmpty)
                                  Text(
                                    service.toString(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AdminColors.muted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '\$${amount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AdminColors.ink,
                            ),
                          ),
                          const SizedBox(width: 10),
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
                          if (ts != null) ...[
                            const SizedBox(width: 10),
                            Text(
                              DateFormat.MMMd().format(ts),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AdminColors.muted,
                              ),
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
