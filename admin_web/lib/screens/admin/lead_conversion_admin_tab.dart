import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Lead Conversion Analytics — Track lead purchase → job booking → completion funnel
class LeadConversionAdminTab extends StatefulWidget {
  const LeadConversionAdminTab({super.key});

  @override
  State<LeadConversionAdminTab> createState() => _LeadConversionAdminTabState();
}

class _LeadConversionAdminTabState extends State<LeadConversionAdminTab> {
  String _period = '30d'; // 7d | 30d | 90d

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        // ── Header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Row(
            children: [
              Icon(Icons.trending_up, color: cs.primary, size: 28),
              const SizedBox(width: 12),
              Text(
                'Lead Conversion Analytics',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: '7d', label: Text('7 Days')),
                  ButtonSegment(value: '30d', label: Text('30 Days')),
                  ButtonSegment(value: '90d', label: Text('90 Days')),
                ],
                selected: {_period},
                onSelectionChanged: (v) => setState(() => _period = v.first),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Funnel KPIs ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _FunnelKpis(period: _period),
        ),
        const SizedBox(height: 20),

        // ── Top Converters ─
        Expanded(child: _TopConverters(period: _period)),
      ],
    );
  }
}

DateTime _cutoffDate(String period) {
  final days = switch (period) {
    '7d' => 7,
    '30d' => 30,
    '90d' => 90,
    _ => 30,
  };
  return DateTime.now().subtract(Duration(days: days));
}

class _FunnelKpis extends StatelessWidget {
  final String period;
  const _FunnelKpis({required this.period});

  @override
  Widget build(BuildContext context) {
    final cutoff = Timestamp.fromDate(_cutoffDate(period));

    return Row(
      children: [
        // Leads Purchased
        Expanded(
          child: _KpiCard(
            icon: Icons.shopping_cart_outlined,
            label: 'Leads Purchased',
            color: Colors.blue,
            stream: FirebaseFirestore.instance
                .collection('lead_credit_transactions')
                .orderBy('createdAt', descending: true)
                .limit(500)
                .snapshots(),
            cutoff: cutoff,
            cutoffField: 'createdAt',
          ),
        ),
        const SizedBox(width: 16),
        // Jobs Booked
        Expanded(
          child: _KpiCard(
            icon: Icons.handshake_outlined,
            label: 'Jobs Booked',
            color: Colors.green,
            stream: FirebaseFirestore.instance
                .collection('escrow_bookings')
                .orderBy('createdAt', descending: true)
                .limit(200)
                .snapshots(),
            cutoff: cutoff,
            cutoffField: 'createdAt',
          ),
        ),
        const SizedBox(width: 16),
        // Jobs Completed
        Expanded(
          child: _KpiCard(
            icon: Icons.check_circle_outlined,
            label: 'Jobs Completed',
            color: Colors.deepPurple,
            stream: FirebaseFirestore.instance
                .collection('escrow_bookings')
                .where('status', isEqualTo: 'completed')
                .limit(500)
                .snapshots(),
            cutoff: cutoff,
            cutoffField: 'completedAt',
          ),
        ),
        const SizedBox(width: 16),
        // Revenue from Leads
        Expanded(child: _RevenueCard(period: period)),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Stream<QuerySnapshot> stream;
  final Timestamp? cutoff;
  final String? cutoffField;

  const _KpiCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.stream,
    this.cutoff,
    this.cutoffField,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Card(
            child: Center(child: Icon(Icons.error_outline, color: cs.error)),
          );
        }
        var allDocs = snap.data?.docs ?? [];
        // Client-side date filtering to avoid composite indexes
        if (cutoff != null && cutoffField != null) {
          allDocs = allDocs.where((d) {
            final ts = d[cutoffField!] as Timestamp?;
            return ts != null && ts.compareTo(cutoff!) > 0;
          }).toList();
        }
        final count = allDocs.length;
        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(icon, color: color, size: 32),
                const SizedBox(height: 8),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RevenueCard extends StatelessWidget {
  final String period;
  const _RevenueCard({required this.period});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('lead_credit_transactions')
          .orderBy('createdAt', descending: true)
          .limit(500)
          .snapshots(),
      builder: (context, snap) {
        final cs = Theme.of(context).colorScheme;
        if (snap.hasError) {
          return Card(
            child: Center(child: Icon(Icons.error_outline, color: cs.error)),
          );
        }
        double total = 0;
        final cutoffTs = Timestamp.fromDate(_cutoffDate(period));
        for (final doc in snap.data?.docs ?? []) {
          final ts = doc.data()['createdAt'] as Timestamp?;
          if (ts != null && ts.compareTo(cutoffTs) > 0) {
            total += (doc.data()['amount'] as num?)?.toDouble() ?? 0;
          }
        }
        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Icon(Icons.attach_money, color: Colors.green, size: 32),
                const SizedBox(height: 8),
                Text(
                  '\$${total.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Lead Revenue',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TopConverters extends StatelessWidget {
  final String period;
  const _TopConverters({required this.period});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cutoff = Timestamp.fromDate(_cutoffDate(period));
    final fmt = DateFormat('MMM d  h:mm a');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Recent Lead Transactions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: cs.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('lead_credit_transactions')
                .orderBy('createdAt', descending: true)
                .limit(100)
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Text('Error', style: TextStyle(color: cs.error)),
                );
              }
              // Client-side period filtering
              final docs = (snap.data?.docs ?? []).where((d) {
                final ts = d.data()['createdAt'] as Timestamp?;
                return ts != null && ts.compareTo(cutoff) > 0;
              }).toList();
              if (docs.isEmpty) {
                return Center(
                  child: Text(
                    'No lead transactions in this period',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final d = docs[i].data();
                  final type = d['type'] as String? ?? '';
                  final credits = d['credits'] as int? ?? 0;
                  final amount = (d['amount'] as num?)?.toDouble() ?? 0;
                  final userName = d['userName'] as String? ?? 'Unknown';
                  final ts = d['createdAt'] as Timestamp?;

                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.blue.withValues(alpha: 0.15),
                      child: const Icon(
                        Icons.person_outline,
                        size: 16,
                        color: Colors.blue,
                      ),
                    ),
                    title: Text(
                      userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      '$type · $credits credits · \$${amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    trailing: Text(
                      ts != null ? fmt.format(ts.toDate()) : '',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
