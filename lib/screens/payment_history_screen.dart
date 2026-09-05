import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';

class PaymentHistoryScreen extends StatelessWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.paymentHistoryTitle)),
        body: Center(child: Text(l10n.paymentHistorySignIn)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.paymentHistoryTitle)),
      body: _PaymentsTab(uid: user.uid),
    );
  }
}

class _PaymentsTab extends StatelessWidget {
  final String uid;

  const _PaymentsTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _PaymentsSection(
          title: l10n.paymentHistoryAsCustomer,
          stream: FirebaseFirestore.instance
              .collection('payments')
              .where('customerId', isEqualTo: uid)
              .orderBy('createdAt', descending: true)
              .limit(50)
              .snapshots(),
          emptyText: l10n.paymentHistoryNoCustomerPayments,
        ),
        const SizedBox(height: 16),
        _PaymentsSection(
          title: l10n.paymentHistoryAsContractor,
          stream: FirebaseFirestore.instance
              .collection('payments')
              .where('contractorId', isEqualTo: uid)
              .orderBy('createdAt', descending: true)
              .limit(50)
              .snapshots(),
          emptyText: l10n.paymentHistoryNoContractorPayments,
        ),
      ],
    );
  }
}

class _PaymentsSection extends StatefulWidget {
  final String title;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final String emptyText;

  const _PaymentsSection({
    required this.title,
    required this.stream,
    required this.emptyText,
  });

  @override
  State<_PaymentsSection> createState() => _PaymentsSectionState();
}

class _PaymentsSectionState extends State<_PaymentsSection> {
  int _reloadKey = 0;

  String _formatTimestamp(dynamic ts) {
    if (ts is Timestamp) {
      return DateFormat.yMMMd().add_jm().format(ts.toDate());
    }
    return '';
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'tip':
        return Icons.thumb_up;
      default:
        return Icons.payments;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              key: ValueKey(_reloadKey),
              stream: widget.stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _PaymentStateCard(
                    icon: Icons.wifi_off_rounded,
                    title: l10n.paymentHistoryLoadFailedTitle,
                    body: l10n.paymentHistoryLoadFailedBody,
                    actionLabel: l10n.retry,
                    onAction: () => setState(() => _reloadKey++),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return _PaymentStateCard(
                    icon: Icons.receipt_long_outlined,
                    title: widget.emptyText,
                    body: l10n.paymentHistoryEmptyBody,
                  );
                }

                return Column(
                  children: docs.map((doc) {
                    final data = doc.data();
                    final type = (data['type'] ?? 'payment').toString();
                    final status = (data['status'] ?? 'unknown').toString();
                    final jobId = (data['jobId'] ?? '').toString();
                    final amountRaw = data['amount'];
                    final amount = amountRaw is num ? amountRaw.toDouble() : 0;
                    final createdAt = _formatTimestamp(data['createdAt']);

                    final subtitleParts = <String>[];
                    subtitleParts.add('Status: $status');
                    if (jobId.trim().isNotEmpty) {
                      subtitleParts.add('Job: $jobId');
                    }
                    if (createdAt.isNotEmpty) {
                      subtitleParts.add('Created: $createdAt');
                    }

                    return ListTile(
                      leading: Icon(_iconForType(type)),
                      title: Text(
                        '${type.toUpperCase()} • \$${amount.toStringAsFixed(2)}',
                      ),
                      subtitle: Text(subtitleParts.join('\n')),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentStateCard extends StatelessWidget {
  const _PaymentStateCard({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(body, style: theme.textTheme.bodySmall),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
