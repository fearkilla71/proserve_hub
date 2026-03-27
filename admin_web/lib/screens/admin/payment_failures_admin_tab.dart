import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Payment Failures Admin Tab — Track declined cards, Stripe errors, refund issues
class PaymentFailuresAdminTab extends StatefulWidget {
  const PaymentFailuresAdminTab({super.key});

  @override
  State<PaymentFailuresAdminTab> createState() =>
      _PaymentFailuresAdminTabState();
}

class _PaymentFailuresAdminTabState extends State<PaymentFailuresAdminTab> {
  final _fmt = DateFormat('MMM d  h:mm a');
  String _filter = 'all'; // all | declined | failed | refund_failed | dispute

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
              Icon(Icons.credit_card_off, color: cs.error, size: 28),
              const SizedBox(width: 12),
              Text(
                'Payment Failures',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              // Summary counters
              _SummaryCounters(),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Filters ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              _filterChip('All', 'all', cs),
              const SizedBox(width: 8),
              _filterChip('Declined', 'declined', cs),
              const SizedBox(width: 8),
              _filterChip('Failed', 'failed', cs),
              const SizedBox(width: 8),
              _filterChip('Refund Failed', 'refund_failed', cs),
              const SizedBox(width: 8),
              _filterChip('Disputes', 'dispute', cs),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── List ──
        Expanded(child: _buildList(cs)),
      ],
    );
  }

  Widget _filterChip(String label, String value, ColorScheme cs) {
    final selected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: cs.primary.withValues(alpha: 0.2),
    );
  }

  Widget _buildList(ColorScheme cs) {
    // Single query without compound where+orderBy to avoid needing composite index
    final q = FirebaseFirestore.instance
        .collection('payment_failures')
        .orderBy('createdAt', descending: true)
        .limit(200);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Text(
              'Error loading data: ${snap.error}',
              style: TextStyle(color: cs.error),
            ),
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        var docs = snap.data?.docs ?? [];
        // Client-side filter to avoid needing composite index
        if (_filter != 'all') {
          docs = docs.where((d) => d.data()['type'] == _filter).toList();
        }
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: Colors.green[400],
                ),
                const SizedBox(height: 12),
                Text(
                  'No payment failures',
                  style: TextStyle(
                    fontSize: 18,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'All payments are processing normally',
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final d = docs[i].data();
            final type = d['type'] as String? ?? 'unknown';
            final amount = (d['amount'] as num?)?.toDouble() ?? 0;
            final currency = d['currency'] as String? ?? 'usd';
            final error = d['errorMessage'] as String? ?? 'No details';
            final stripeCode = d['stripeErrorCode'] as String? ?? '';
            final userId = d['userId'] as String? ?? '';
            final userName = d['userName'] as String? ?? 'Unknown';
            final ts = d['createdAt'] as Timestamp?;
            final dateStr = ts != null ? _fmt.format(ts.toDate()) : '—';

            final color = _typeColor(type);
            final icon = _typeIcon(type);

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color, size: 20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      type.toUpperCase().replaceAll('_', ' '),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '\$${amount.toStringAsFixed(2)} ${currency.toUpperCase()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(error, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        userName,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      if (stripeCode.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          stripeCode,
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.error,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              isThreeLine: true,
              onTap: userId.isNotEmpty
                  ? () => _showDetail(context, d, docs[i].id)
                  : null,
            );
          },
        );
      },
    );
  }

  void _showDetail(BuildContext context, Map<String, dynamic> d, String docId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Payment Failure: $docId'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: SelectableText(
              d.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'declined':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      case 'refund_failed':
        return Colors.purple;
      case 'dispute':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'declined':
        return Icons.credit_card_off;
      case 'failed':
        return Icons.error_outline;
      case 'refund_failed':
        return Icons.money_off;
      case 'dispute':
        return Icons.gavel;
      default:
        return Icons.warning_amber;
    }
  }
}

class _SummaryCounters extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('payment_failures')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const SizedBox.shrink();
        final cutoff = DateTime.now().subtract(const Duration(hours: 24));
        final count = (snap.data?.docs ?? []).where((d) {
          final ts = d['createdAt'] as Timestamp?;
          return ts != null && ts.toDate().isAfter(cutoff);
        }).length;
        final cs = Theme.of(context).colorScheme;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: count > 0
                ? cs.error.withValues(alpha: 0.15)
                : Colors.green.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                count > 0 ? Icons.warning_amber : Icons.check_circle,
                size: 16,
                color: count > 0 ? cs.error : Colors.green,
              ),
              const SizedBox(width: 6),
              Text(
                '$count failures (24h)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: count > 0 ? cs.error : Colors.green,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
