import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
            child: _AdminLoadErrorCard(
              title: 'Payment failures unavailable',
              body:
                  'The console could not load payment failure records. Check admin permissions, Firestore indexes, and network status before retrying.',
              onRetry: () => setState(() {}),
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
            final reviewedAt = d['adminReviewedAt'] as Timestamp?;
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
                  if (reviewedAt != null) ...[
                    const SizedBox(width: 8),
                    Chip(
                      label: const Text('Reviewed'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.green.withValues(alpha: 0.12),
                      labelStyle: const TextStyle(
                        color: Colors.green,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
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
                  Text(
                    _friendlyFailureSummary(type, stripeCode, error),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
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
    final cs = Theme.of(context).colorScheme;
    final type = d['type'] as String? ?? 'unknown';
    final amount = (d['amount'] as num?)?.toDouble() ?? 0;
    final currency = d['currency'] as String? ?? 'usd';
    final error = d['errorMessage'] as String? ?? 'No details';
    final stripeCode = d['stripeErrorCode'] as String? ?? '';
    final userName = d['userName'] as String? ?? 'Unknown user';
    final userId = d['userId'] as String? ?? '';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Payment recovery: $docId'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _DetailChip(label: type.toUpperCase().replaceAll('_', ' ')),
                    _DetailChip(
                      label:
                          '\$${amount.toStringAsFixed(2)} ${currency.toUpperCase()}',
                    ),
                    if (stripeCode.isNotEmpty) _DetailChip(label: stripeCode),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  userId.isEmpty ? userName : '$userName\n$userId',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                _OperatorRecoveryCard(
                  title: 'Operator next action',
                  body: _operatorActionFor(type, stripeCode),
                ),
                const SizedBox(height: 12),
                _OperatorRecoveryCard(
                  title: 'Customer-safe summary',
                  body: _friendlyFailureSummary(type, stripeCode, error),
                ),
                const SizedBox(height: 16),
                Text(
                  'Action history',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                _PaymentFailureHistory(docId: docId),
                const SizedBox(height: 16),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Technical record'),
                  subtitle: const Text(
                    'Use this only for Stripe/Firebase diagnostics.',
                  ),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SelectableText(
                        d.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () => _showPaymentFailureNoteDialog(context, docId),
            icon: const Icon(Icons.note_add_outlined),
            label: const Text('Add note'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await _markPaymentFailureReviewed(context, docId);
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.done_all),
            label: const Text('Mark reviewed'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _friendlyFailureSummary(
    String type,
    String stripeCode,
    String rawMessage,
  ) {
    final lower = '$type $stripeCode $rawMessage'.toLowerCase();
    if (lower.contains('insufficient_funds')) {
      return 'The customer card did not have enough funds. Ask the customer to retry with another payment method.';
    }
    if (lower.contains('authentication') || lower.contains('requires_action')) {
      return 'The payment needs customer authentication. Ask the customer to retry and complete bank or card verification.';
    }
    if (lower.contains('refund')) {
      return 'A refund needs operator review. Confirm the Stripe refund status before updating the customer or contractor.';
    }
    if (lower.contains('dispute')) {
      return 'A dispute needs operator review. Open the dispute and escrow records before taking any payment action.';
    }
    if (lower.contains('declin')) {
      return 'The payment method was declined. Ask the customer to retry with a different payment method.';
    }
    if (lower.contains('expired')) {
      return 'The checkout or payment session expired. Ask the user to start payment again from the app.';
    }
    return 'This payment needs review. Check the Stripe event, related user, and job or invoice metadata before marking it resolved.';
  }

  String _operatorActionFor(String type, String stripeCode) {
    final lower = '$type $stripeCode'.toLowerCase();
    if (lower.contains('refund')) {
      return 'Open the Stripe refund and related escrow. Record whether the refund succeeded, failed, or needs manual support follow-up.';
    }
    if (lower.contains('dispute')) {
      return 'Open the dispute queue, verify the Stripe dispute deadline, and add a note with the evidence or next customer/contractor contact.';
    }
    if (lower.contains('declined')) {
      return 'Confirm the failed checkout belongs to the correct user, then ask the user to retry with another payment method.';
    }
    return 'Verify the Stripe event, match it to the user/job/invoice, and add a recovery note before marking reviewed.';
  }

  Future<void> _showPaymentFailureNoteDialog(
    BuildContext context,
    String docId,
  ) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add payment recovery note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Internal note',
            hintText: 'What did you check or tell the user?',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save note'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (note == null || note.isEmpty) return;
    if (!context.mounted) return;
    await _logPaymentFailureAction(
      context: context,
      docId: docId,
      action: 'note',
      note: note,
    );
  }

  Future<void> _markPaymentFailureReviewed(
    BuildContext context,
    String docId,
  ) async {
    await _logPaymentFailureAction(
      context: context,
      docId: docId,
      action: 'reviewed',
      note: 'Payment failure reviewed from Admin Web.',
      parentUpdate: {'adminReviewedAt': FieldValue.serverTimestamp()},
    );
  }

  Future<void> _logPaymentFailureAction({
    required BuildContext context,
    required String docId,
    required String action,
    required String note,
    Map<String, Object?> parentUpdate = const {},
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final ref = FirebaseFirestore.instance
        .collection('payment_failures')
        .doc(docId);
    final batch = FirebaseFirestore.instance.batch();
    batch.set(ref.collection('admin_actions').doc(), {
      'action': action,
      'note': note,
      'adminUid': user?.uid ?? 'unknown_admin',
      'adminName': user?.displayName ?? user?.email ?? 'Admin',
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(ref, {
      ...parentUpdate,
      'lastAdminAction': action,
      'lastAdminActionNote': note,
      'lastAdminActionAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    try {
      await batch.commit();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Admin action saved.')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save the admin action. Check permissions and try again.',
          ),
        ),
      );
    }
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

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Chip(
      label: Text(label),
      backgroundColor: cs.primaryContainer.withValues(alpha: 0.45),
      labelStyle: TextStyle(color: cs.onPrimaryContainer),
    );
  }
}

class _OperatorRecoveryCard extends StatelessWidget {
  const _OperatorRecoveryCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(body),
        ],
      ),
    );
  }
}

class _PaymentFailureHistory extends StatelessWidget {
  const _PaymentFailureHistory({required this.docId});

  final String docId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('payment_failures')
          .doc(docId)
          .collection('admin_actions')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Text(
            'Action history unavailable.',
            style: TextStyle(color: cs.error),
          );
        }
        if (!snap.hasData) return const LinearProgressIndicator();
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Text(
            'No recovery actions recorded yet.',
            style: TextStyle(color: cs.onSurfaceVariant),
          );
        }
        return Column(
          children: docs.map((doc) {
            final data = doc.data();
            final action = (data['action'] ?? 'admin_action')
                .toString()
                .replaceAll('_', ' ');
            final note = (data['note'] ?? '').toString();
            final admin = (data['adminName'] ?? 'Admin').toString();
            final createdAt = data['createdAt'] is Timestamp
                ? (data['createdAt'] as Timestamp).toDate()
                : null;
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history, size: 18),
              title: Text(action),
              subtitle: Text(
                [
                  if (note.isNotEmpty) note,
                  [
                    admin,
                    if (createdAt != null)
                      DateFormat.MMMd().add_jm().format(createdAt),
                  ].join(' • '),
                ].join('\n'),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _AdminLoadErrorCard extends StatelessWidget {
  const _AdminLoadErrorCard({
    required this.title,
    required this.body,
    required this.onRetry,
  });

  final String title;
  final String body;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.all(24),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_outlined, color: cs.error, size: 36),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(body, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
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
