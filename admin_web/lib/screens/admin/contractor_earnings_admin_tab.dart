import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Per-Contractor Earnings — Break down revenue, payouts, and avg job size per contractor
class ContractorEarningsAdminTab extends StatefulWidget {
  const ContractorEarningsAdminTab({super.key});

  @override
  State<ContractorEarningsAdminTab> createState() =>
      _ContractorEarningsAdminTabState();
}

class _ContractorEarningsAdminTabState
    extends State<ContractorEarningsAdminTab> {
  final _currFmt = NumberFormat.currency(symbol: '\$');
  final _searchCtrl = TextEditingController();
  String _sortBy = 'totalEarnings'; // totalEarnings | jobCount | avgPayout
  bool _sortAsc = false;

  List<_ContractorRow> _rows = [];
  bool _loading = true;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _loadData() {
    _sub = FirebaseFirestore.instance
        .collection('escrow_bookings')
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .listen((snap) {
          final map = <String, _ContractorRow>{};
          for (final doc in snap.docs) {
            final d = doc.data();
            final cid = d['contractorId'] as String? ?? '';
            if (cid.isEmpty) continue;
            final amount = (d['amount'] as num?)?.toDouble() ?? 0;
            final name = d['contractorName'] as String? ?? 'Unknown';
            final existing = map[cid];
            if (existing != null) {
              existing.totalEarnings += amount;
              existing.jobCount += 1;
              final ts = d['completedAt'] as Timestamp?;
              if (ts != null &&
                  (existing.lastPayout == null ||
                      ts.toDate().isAfter(existing.lastPayout!))) {
                existing.lastPayout = ts.toDate();
              }
            } else {
              final ts = d['completedAt'] as Timestamp?;
              map[cid] = _ContractorRow(
                contractorId: cid,
                name: name,
                totalEarnings: amount,
                jobCount: 1,
                lastPayout: ts?.toDate(),
              );
            }
          }
          if (mounted) {
            setState(() {
              _rows = map.values.toList();
              _loading = false;
            });
          }
        });
  }

  List<_ContractorRow> get _sortedFiltered {
    var list = List<_ContractorRow>.from(_rows);
    final q = _searchCtrl.text.toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((r) => r.name.toLowerCase().contains(q)).toList();
    }
    list.sort((a, b) {
      int cmp;
      switch (_sortBy) {
        case 'totalEarnings':
          cmp = a.totalEarnings.compareTo(b.totalEarnings);
          break;
        case 'jobCount':
          cmp = a.jobCount.compareTo(b.jobCount);
          break;
        case 'avgPayout':
          cmp = a.avgPayout.compareTo(b.avgPayout);
          break;
        default:
          cmp = 0;
      }
      return _sortAsc ? cmp : -cmp;
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rows = _sortedFiltered;

    // Summary
    double totalRevenue = 0;
    int totalJobs = 0;
    for (final r in _rows) {
      totalRevenue += r.totalEarnings;
      totalJobs += r.jobCount;
    }

    return Column(
      children: [
        // ── Header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Row(
            children: [
              Icon(Icons.account_balance_wallet, color: Colors.green, size: 28),
              const SizedBox(width: 12),
              Text(
                'Contractor Earnings',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              _summaryChip(
                '${_rows.length} contractors',
                Icons.people,
                Colors.blue,
              ),
              const SizedBox(width: 12),
              _summaryChip('$totalJobs jobs', Icons.work, Colors.teal),
              const SizedBox(width: 12),
              _summaryChip(
                _currFmt.format(totalRevenue),
                Icons.attach_money,
                Colors.green,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Search + sort ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search contractor…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 16),
              const Text('Sort by: ', style: TextStyle(fontSize: 13)),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'totalEarnings',
                    label: Text('Earnings'),
                  ),
                  ButtonSegment(value: 'jobCount', label: Text('Jobs')),
                  ButtonSegment(value: 'avgPayout', label: Text('Avg Payout')),
                ],
                selected: {_sortBy},
                onSelectionChanged: (v) => setState(() => _sortBy = v.first),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  _sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 18,
                ),
                tooltip: _sortAsc ? 'Ascending' : 'Descending',
                onPressed: () => setState(() => _sortAsc = !_sortAsc),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Table ──
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : rows.isEmpty
              ? Center(
                  child: Text(
                    'No matching contractors',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                )
              : _buildTable(rows, cs),
        ),
      ],
    );
  }

  Widget _buildTable(List<_ContractorRow> rows, ColorScheme cs) {
    final dateFmt = DateFormat('MMM d, yyyy');
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: DataTable(
        columnSpacing: 32,
        columns: const [
          DataColumn(label: Text('Contractor')),
          DataColumn(label: Text('Jobs'), numeric: true),
          DataColumn(label: Text('Total Earned'), numeric: true),
          DataColumn(label: Text('Avg/Job'), numeric: true),
          DataColumn(label: Text('Last Payout')),
        ],
        rows: rows.map((r) {
          return DataRow(
            cells: [
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: cs.primary.withValues(alpha: 0.1),
                      child: Text(
                        r.name.isNotEmpty ? r.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      r.name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              DataCell(Text('${r.jobCount}')),
              DataCell(
                Text(
                  _currFmt.format(r.totalEarnings),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataCell(Text(_currFmt.format(r.avgPayout))),
              DataCell(
                Text(
                  r.lastPayout != null ? dateFmt.format(r.lastPayout!) : '—',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _summaryChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContractorRow {
  final String contractorId;
  final String name;
  double totalEarnings;
  int jobCount;
  DateTime? lastPayout;

  _ContractorRow({
    required this.contractorId,
    required this.name,
    required this.totalEarnings,
    required this.jobCount,
    this.lastPayout,
  });

  double get avgPayout => jobCount > 0 ? totalEarnings / jobCount : 0;
}
