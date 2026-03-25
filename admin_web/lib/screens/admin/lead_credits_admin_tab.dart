import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/admin_theme.dart';

/// ---------------------------------------------------------------------------
/// Lead Credits Marketplace Admin — Credit transaction history, pricing
/// management, pack purchase tracking, credit economy health.
/// ---------------------------------------------------------------------------
class LeadCreditsAdminTab extends StatefulWidget {
  final bool canWrite;
  const LeadCreditsAdminTab({super.key, this.canWrite = false});

  @override
  State<LeadCreditsAdminTab> createState() => _LeadCreditsAdminTabState();
}

class _LeadCreditsAdminTabState extends State<LeadCreditsAdminTab> {
  StreamSubscription? _txnSub;
  StreamSubscription? _packSub;
  bool _loading = true;
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _packs = [];

  String _filter = 'all'; // all | purchase | spend | refund
  String _search = '';

  // KPIs
  int _totalTxns = 0;
  double _totalRevenue = 0;
  int _creditsInCirculation = 0;
  int _activePacks = 0;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void dispose() {
    _txnSub?.cancel();
    _packSub?.cancel();
    super.dispose();
  }

  void _listen() {
    _txnSub = FirebaseFirestore.instance
        .collection('lead_credit_transactions')
        .orderBy('createdAt', descending: true)
        .limit(500)
        .snapshots()
        .listen(
          (snap) {
            final docs = snap.docs.map((d) {
              final data = d.data();
              data['id'] = d.id;
              return data;
            }).toList();

            double revenue = 0;
            int circ = 0;
            for (final t in docs) {
              final type = t['type'] ?? '';
              final amount = (t['credits'] as num?)?.toInt() ?? 0;
              if (type == 'purchase') {
                revenue += (t['pricePaid'] as num?)?.toDouble() ?? 0;
                circ += amount;
              } else if (type == 'spend') {
                circ -= amount;
              }
            }

            setState(() {
              _transactions = docs;
              _totalTxns = docs.length;
              _totalRevenue = revenue;
              _creditsInCirculation = circ;
              _loading = false;
            });
          },
          onError: (e) {
            debugPrint('lead_credit_transactions listen error: $e');
            if (mounted) setState(() => _loading = false);
          },
        );

    _packSub = FirebaseFirestore.instance
        .collection('lead_credit_packs')
        .snapshots()
        .listen(
          (snap) {
            setState(() {
              _packs = snap.docs.map((d) {
                final data = d.data();
                data['id'] = d.id;
                return data;
              }).toList();
              _activePacks = _packs.where((p) => p['active'] == true).length;
            });
          },
          onError: (e) {
            debugPrint('lead_credit_packs listen error: $e');
          },
        );
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _transactions;
    if (_filter != 'all') {
      list = list.where((t) => t['type'] == _filter).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where(
            (t) =>
                (t['userId'] ?? '').toString().toLowerCase().contains(q) ||
                (t['userName'] ?? '').toString().toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // KPIs
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _kpi('Transactions', '$_totalTxns', AdminColors.accent2),
                _kpi(
                  'Revenue',
                  '\$${NumberFormat.compact().format(_totalRevenue)}',
                  AdminColors.accent,
                ),
                _kpi(
                  'In Circulation',
                  NumberFormat.compact().format(_creditsInCirculation),
                  AdminColors.accent3,
                ),
                _kpi('Packs', '$_activePacks', AdminColors.warning),
              ],
            ),
          ),

          const TabBar(
            tabs: [
              Tab(text: 'Transactions'),
              Tab(text: 'Credit Packs'),
            ],
          ),

          Expanded(
            child: TabBarView(
              children: [_buildTransactionsTab(), _buildPacksTab()],
            ),
          ),
        ],
      ),
    );
  }

  // ── Transactions tab ──

  Widget _buildTransactionsTab() {
    final filtered = _filtered;

    return Column(
      children: [
        // Filter bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              for (final s in ['all', 'purchase', 'spend', 'refund'])
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
                width: 200,
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

        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No transactions found',
                    style: TextStyle(color: AdminColors.muted),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final t = filtered[i];
                    final type = t['type'] ?? 'purchase';
                    final credits = (t['credits'] as num?)?.toInt() ?? 0;
                    final price = (t['pricePaid'] as num?)?.toDouble();
                    final userName = t['userName'] ?? '';
                    final ts = (t['createdAt'] as Timestamp?)?.toDate();

                    final isSpend = type == 'spend';
                    final color = isSpend
                        ? AdminColors.error
                        : AdminColors.accent;

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AdminColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AdminColors.line),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSpend
                                ? Icons.remove_circle_outline
                                : Icons.add_circle_outline,
                            size: 18,
                            color: color,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName.toString().isNotEmpty
                                      ? userName.toString()
                                      : type,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AdminColors.ink,
                                  ),
                                ),
                                if (ts != null)
                                  Text(
                                    DateFormat.yMMMd().add_jm().format(ts),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AdminColors.muted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '${isSpend ? '-' : '+'}$credits',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: color,
                            ),
                          ),
                          if (price != null) ...[
                            const SizedBox(width: 10),
                            Text(
                              '\$${price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AdminColors.muted,
                              ),
                            ),
                          ],
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              type,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── Packs tab ──

  Widget _buildPacksTab() {
    return Column(
      children: [
        if (widget.canWrite)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => _showPackDialog(context, null),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Pack'),
              ),
            ),
          ),
        Expanded(
          child: _packs.isEmpty
              ? Center(
                  child: Text(
                    'No credit packs configured',
                    style: TextStyle(color: AdminColors.muted),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _packs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final p = _packs[i];
                    final name = p['name'] ?? 'Pack';
                    final credits = (p['credits'] as num?)?.toInt() ?? 0;
                    final price = (p['price'] as num?)?.toDouble() ?? 0;
                    final active = p['active'] == true;
                    final sold = (p['totalSold'] as num?)?.toInt() ?? 0;

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AdminColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AdminColors.line),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.token,
                            size: 18,
                            color: active
                                ? AdminColors.accent
                                : AdminColors.muted,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name.toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AdminColors.ink,
                                  ),
                                ),
                                Text(
                                  '$credits credits · \$${price.toStringAsFixed(2)} · $sold sold',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AdminColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.canWrite) ...[
                            Switch(
                              value: active,
                              onChanged: (val) async {
                                await FirebaseFirestore.instance
                                    .collection('lead_credit_packs')
                                    .doc(p['id'])
                                    .update({'active': val});
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                size: 18,
                                color: AdminColors.accent2,
                              ),
                              onPressed: () => _showPackDialog(context, p),
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

  void _showPackDialog(BuildContext context, Map<String, dynamic>? pack) {
    final nameCtrl = TextEditingController(
      text: pack?['name'] as String? ?? '',
    );
    final creditsCtrl = TextEditingController(
      text: (pack?['credits'] ?? 10).toString(),
    );
    final priceCtrl = TextEditingController(
      text: (pack?['price'] ?? 9.99).toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(pack == null ? 'New Credit Pack' : 'Edit Pack'),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Pack Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: creditsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Credits',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Price (\$)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final data = {
                'name': nameCtrl.text.trim(),
                'credits': int.tryParse(creditsCtrl.text.trim()) ?? 10,
                'price': double.tryParse(priceCtrl.text.trim()) ?? 9.99,
                'updatedAt': FieldValue.serverTimestamp(),
              };
              if (pack != null) {
                await FirebaseFirestore.instance
                    .collection('lead_credit_packs')
                    .doc(pack['id'])
                    .update(data);
              } else {
                data['createdAt'] = FieldValue.serverTimestamp();
                data['active'] = true;
                data['totalSold'] = 0;
                await FirebaseFirestore.instance
                    .collection('lead_credit_packs')
                    .add(data);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(pack == null ? 'Create' : 'Save'),
          ),
        ],
      ),
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
