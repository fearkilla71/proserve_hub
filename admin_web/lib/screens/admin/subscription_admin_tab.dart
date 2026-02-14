import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../widgets/skeleton_loader.dart';

/// ---------------------------------------------------------------------------
/// Subscriptions Admin Tab — Real-time subscription tracking
/// ---------------------------------------------------------------------------
class SubscriptionAdminTab extends StatefulWidget {
  final bool canWrite;
  const SubscriptionAdminTab({super.key, this.canWrite = false});

  @override
  State<SubscriptionAdminTab> createState() => _SubscriptionAdminTabState();
}

class _SubscriptionAdminTabState extends State<SubscriptionAdminTab> {
  StreamSubscription? _sub;
  bool _loading = true;
  List<Map<String, dynamic>> _users = [];
  String _tierFilter = 'all'; // all, basic, pro, enterprise
  String _search = '';

  // KPIs
  int _totalContractors = 0;
  int _basicCount = 0;
  int _proCount = 0;
  int _enterpriseCount = 0;
  double _mrr = 0;
  double _arr = 0;
  double _conversionRate = 0;

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
        .where('role', isEqualTo: 'contractor')
        .snapshots()
        .listen((snap) {
          final docs = snap.docs.map((d) {
            final data = d.data();
            data['uid'] = d.id;
            return data;
          }).toList();

          // Calculate KPIs
          int basic = 0, pro = 0, enterprise = 0;
          for (final u in docs) {
            final tier = _effectiveTier(u);
            if (tier == 'enterprise') {
              enterprise++;
            } else if (tier == 'pro') {
              pro++;
            } else {
              basic++;
            }
          }

          final total = docs.length;
          final paid = pro + enterprise;
          // PRO = $11.99/mo, Enterprise = $49.99/mo
          final mrr = (pro * 11.99) + (enterprise * 49.99);

          setState(() {
            _users = docs;
            _totalContractors = total;
            _basicCount = basic;
            _proCount = pro;
            _enterpriseCount = enterprise;
            _mrr = mrr;
            _arr = mrr * 12;
            _conversionRate = total > 0 ? (paid / total) * 100 : 0;
            _loading = false;
          });
        });
  }

  String _effectiveTier(Map<String, dynamic> data) {
    final tier = (data['subscriptionTier'] as String?)?.toLowerCase();
    if (tier == 'enterprise') return 'enterprise';
    if (tier == 'pro') return 'pro';
    if (data['pricingToolsPro'] == true ||
        data['contractorPro'] == true ||
        data['isPro'] == true) {
      return 'pro';
    }
    return 'basic';
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _users;
    if (_tierFilter != 'all') {
      list = list.where((u) => _effectiveTier(u) == _tierFilter).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((u) {
        final name = (u['displayName'] ?? '').toString().toLowerCase();
        final email = (u['email'] ?? '').toString().toLowerCase();
        final company = (u['companyName'] ?? '').toString().toLowerCase();
        return name.contains(q) || email.contains(q) || company.contains(q);
      }).toList();
    }
    return list;
  }

  Color _tierColor(String tier) {
    switch (tier) {
      case 'enterprise':
        return Colors.purpleAccent;
      case 'pro':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  IconData _tierIcon(String tier) {
    switch (tier) {
      case 'enterprise':
        return Icons.diamond;
      case 'pro':
        return Icons.star;
      default:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            ListTileSkeleton(),
            SizedBox(height: 12),
            ListTileSkeleton(),
            SizedBox(height: 12),
            ListTileSkeleton(),
          ],
        ),
      );
    }

    final filtered = _filtered;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── KPI Cards ───────────────────────────────────────────
        Text(
          'Subscription Overview',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _kpiCard(
              'Total Contractors',
              '$_totalContractors',
              Icons.people,
              Colors.blue,
            ),
            _kpiCard('Basic (Free)', '$_basicCount', Icons.person, Colors.grey),
            _kpiCard('PRO', '$_proCount', Icons.star, Colors.amber),
            _kpiCard(
              'Enterprise',
              '$_enterpriseCount',
              Icons.diamond,
              Colors.purpleAccent,
            ),
            _kpiCard(
              'MRR',
              '\$${_mrr.toStringAsFixed(2)}',
              Icons.attach_money,
              Colors.green,
            ),
            _kpiCard(
              'ARR',
              '\$${_arr.toStringAsFixed(2)}',
              Icons.trending_up,
              Colors.teal,
            ),
            _kpiCard(
              'Conversion',
              '${_conversionRate.toStringAsFixed(1)}%',
              Icons.pie_chart,
              Colors.orange,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── Tier Distribution Chart ─────────────────────────────
        Text(
          'Tier Distribution',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: Row(
            children: [
              Expanded(
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: [
                      PieChartSectionData(
                        value: _basicCount.toDouble(),
                        color: Colors.grey,
                        title: 'Basic\n$_basicCount',
                        titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        radius: 60,
                      ),
                      PieChartSectionData(
                        value: _proCount.toDouble(),
                        color: Colors.amber,
                        title: 'PRO\n$_proCount',
                        titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        radius: 60,
                      ),
                      PieChartSectionData(
                        value: _enterpriseCount.toDouble(),
                        color: Colors.purpleAccent,
                        title: 'Ent.\n$_enterpriseCount',
                        titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        radius: 60,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Revenue breakdown
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Revenue Breakdown',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 12),
                        _revenueRow(
                          'PRO ($_proCount × \$11.99)',
                          '\$${(_proCount * 11.99).toStringAsFixed(2)}/mo',
                        ),
                        const SizedBox(height: 8),
                        _revenueRow(
                          'Enterprise ($_enterpriseCount × \$49.99)',
                          '\$${(_enterpriseCount * 49.99).toStringAsFixed(2)}/mo',
                        ),
                        const Divider(height: 20),
                        _revenueRow(
                          'Total MRR',
                          '\$${_mrr.toStringAsFixed(2)}/mo',
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Filter & Search ─────────────────────────────────────
        Row(
          children: [
            Text('Subscribers', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('All')),
                ButtonSegment(value: 'basic', label: Text('Basic')),
                ButtonSegment(value: 'pro', label: Text('PRO')),
                ButtonSegment(value: 'enterprise', label: Text('Ent.')),
              ],
              selected: {_tierFilter},
              onSelectionChanged: (v) => setState(() => _tierFilter = v.first),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search by name, email, or company...',
          ),
          onChanged: (v) => setState(() => _search = v),
        ),
        const SizedBox(height: 12),

        // ── Subscriber List ─────────────────────────────────────
        Text('${filtered.length} results'),
        const SizedBox(height: 8),
        ...filtered.map((u) {
          final tier = _effectiveTier(u);
          final name = u['displayName'] ?? 'Unknown';
          final email = u['email'] ?? '';
          final company = u['companyName'] ?? '';
          final created = u['createdAt'];
          final createdStr = created is Timestamp
              ? DateFormat.yMMMd().format(created.toDate())
              : '—';
          final tierChanged = u['subscriptionTierChangedAt'];
          final tierChangedStr = tierChanged is Timestamp
              ? DateFormat.yMMMd().format(tierChanged.toDate())
              : '—';

          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _tierColor(tier).withValues(alpha: 0.2),
                child: Icon(_tierIcon(tier), color: _tierColor(tier)),
              ),
              title: Text(name),
              subtitle: Text(
                '$email${company.isNotEmpty ? ' · $company' : ''}\n'
                'Joined: $createdStr · Tier since: $tierChangedStr',
              ),
              isThreeLine: true,
              trailing: Chip(
                label: Text(
                  tier.toUpperCase(),
                  style: TextStyle(
                    color: tier == 'basic' ? Colors.white70 : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                backgroundColor: _tierColor(tier),
              ),
              onTap: widget.canWrite ? () => _showTierDialog(u) : null,
            ),
          );
        }),
      ],
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.white60),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _revenueRow(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: Colors.greenAccent,
          ),
        ),
      ],
    );
  }

  void _showTierDialog(Map<String, dynamic> user) {
    String selected = _effectiveTier(user);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Change Tier — ${user['displayName'] ?? user['uid']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final t in ['basic', 'pro', 'enterprise'])
                ListTile(
                  title: Text(t.toUpperCase()),
                  leading: Icon(
                    selected == t
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: selected == t ? Colors.blue : null,
                  ),
                  onTap: () => setDialogState(() => selected = t),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user['uid'])
                    .update({
                      'subscriptionTier': selected,
                      'subscriptionTierChangedAt': FieldValue.serverTimestamp(),
                      if (selected == 'pro' || selected == 'enterprise')
                        'pricingToolsPro': true,
                      if (selected == 'enterprise') 'contractorPro': true,
                    });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Updated ${user['displayName']} to ${selected.toUpperCase()}',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
