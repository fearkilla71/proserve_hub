import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

class PaymentOperationsTab extends StatefulWidget {
  const PaymentOperationsTab({super.key});

  @override
  State<PaymentOperationsTab> createState() => _PaymentOperationsTabState();
}

class _PaymentOperationsTabState extends State<PaymentOperationsTab> {
  String _filter = 'attention';
  final _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('escrow_bookings')
          .snapshots(),
      builder: (context, escrowSnap) {
        if (escrowSnap.hasError) {
          return _ErrorState(message: escrowSnap.error.toString());
        }
        if (!escrowSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('payments').snapshots(),
          builder: (context, paymentSnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'contractor')
                  .snapshots(),
              builder: (context, contractorSnap) {
                final escrows = escrowSnap.data!.docs;
                final payments = paymentSnap.data?.docs ?? const [];
                final contractors = contractorSnap.data?.docs ?? const [];

                final escrowItems =
                    escrows.map((doc) => _EscrowOpsItem.fromDoc(doc)).toList()
                      ..sort((a, b) => b.sortTime.compareTo(a.sortTime));
                final paymentItems =
                    payments.map((doc) => _PaymentOpsItem.fromDoc(doc)).toList()
                      ..sort((a, b) => b.sortTime.compareTo(a.sortTime));
                final payoutItems =
                    contractors
                        .map((doc) => _PayoutOpsItem.fromDoc(doc))
                        .where((item) => !item.payoutReady)
                        .toList()
                      ..sort((a, b) => a.displayName.compareTo(b.displayName));

                final stuckEscrows = escrowItems
                    .where((item) => item.needsAttention)
                    .toList();
                final failedPayments = paymentItems
                    .where((item) => item.needsAttention)
                    .toList();

                final showEscrows = _filter == 'all'
                    ? escrowItems
                    : stuckEscrows;
                final showPayments = _filter == 'all'
                    ? paymentItems
                    : failedPayments;

                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    _SummaryGrid(
                      stuckEscrows: stuckEscrows.length,
                      failedPayments: failedPayments.length,
                      payoutIssues: payoutItems.length,
                      escrowTotal: escrowItems.length,
                    ),
                    const SizedBox(height: 12),
                    _FilterCard(
                      filter: _filter,
                      onChanged: (value) => setState(() => _filter = value),
                    ),
                    const SizedBox(height: 12),
                    _SectionTitle(
                      title: l10n.paymentOpsEscrowOperations,
                      subtitle: l10n.paymentOpsEscrowOperationsSubtitle,
                    ),
                    if (showEscrows.isEmpty)
                      _EmptyState(
                        title: l10n.paymentOpsNoEscrowIssues,
                        subtitle: l10n.paymentOpsNoEscrowIssuesSubtitle,
                      )
                    else
                      ...showEscrows.map(_escrowCard),
                    const SizedBox(height: 12),
                    _SectionTitle(
                      title: l10n.paymentOpsPaymentRecords,
                      subtitle: l10n.paymentOpsPaymentRecordsSubtitle,
                    ),
                    if (showPayments.isEmpty)
                      _EmptyState(
                        title: l10n.paymentOpsNoPaymentIssues,
                        subtitle: l10n.paymentOpsNoPaymentIssuesSubtitle,
                      )
                    else
                      ...showPayments.map(_paymentCard),
                    const SizedBox(height: 12),
                    _SectionTitle(
                      title: l10n.paymentOpsPayoutSetup,
                      subtitle: l10n.paymentOpsPayoutSetupSubtitle,
                    ),
                    if (payoutItems.isEmpty)
                      _EmptyState(
                        title: l10n.paymentOpsPayoutsReady,
                        subtitle: l10n.paymentOpsPayoutsReadySubtitle,
                      )
                    else
                      ...payoutItems.map(_payoutCard),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _escrowCard(_EscrowOpsItem item) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.service,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _RiskChip(
                  label: item.needsAttention ? l10n.needsAttention : l10n.ok,
                  color: item.needsAttention ? scheme.error : scheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(l10n.escrowIdLabel(item.id)),
            if (item.jobId.isNotEmpty) Text(l10n.jobLabel(item.jobId)),
            Text(l10n.statusPayoutLabel(item.status, item.payoutStatus)),
            Text(
              l10n.amountContractorPayoutLabel(
                _currency.format(item.aiPrice),
                _currency.format(item.contractorPayout),
              ),
            ),
            if (item.payoutError.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(item.payoutError, style: TextStyle(color: scheme.error)),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => context.push('/escrow-status/${item.id}'),
                  icon: const Icon(Icons.shield_outlined),
                  label: Text(l10n.openEscrow),
                ),
                if (item.jobId.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => context.push('/job-command/${item.jobId}'),
                    icon: const Icon(Icons.work_outline),
                    label: Text(l10n.openJob),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _markEscrowReviewed(item.id),
                  icon: const Icon(Icons.done_all),
                  label: Text(l10n.markReviewed),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentCard(_PaymentOpsItem item) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            item.needsAttention
                ? Icons.warning_amber_outlined
                : Icons.receipt_long_outlined,
          ),
        ),
        title: Text(item.title),
        subtitle: Text(
          [
            l10n.idLabel(item.id),
            if (item.type.isNotEmpty) l10n.typeLabel(item.type),
            if (item.uid.isNotEmpty) l10n.userLabel(item.uid),
            if (item.status.isNotEmpty) l10n.statusLabel(item.status),
            if (item.amount > 0)
              l10n.amountLabel(_currency.format(item.amount)),
          ].join('\n'),
        ),
        trailing: _RiskChip(
          label: item.needsAttention ? l10n.check : l10n.ok,
          color: item.needsAttention ? scheme.error : scheme.primary,
        ),
      ),
    );
  }

  Widget _payoutCard(_PayoutOpsItem item) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.payments_outlined)),
        title: Text(item.displayName),
        subtitle: Text(
          [
            l10n.userLabel(item.uid),
            l10n.stripeAccountLabel(
              item.stripeAccountId.isEmpty
                  ? l10n.missing
                  : item.stripeAccountId,
            ),
            l10n.detailsSubmittedLabel(
              item.detailsSubmitted ? l10n.yes : l10n.no,
            ),
            l10n.payoutsEnabledLabel(item.payoutsEnabled ? l10n.yes : l10n.no),
          ].join('\n'),
        ),
        trailing: _RiskChip(
          label: l10n.paymentOpsPayoutSetup,
          color: Colors.orange,
        ),
      ),
    );
  }

  Future<void> _markEscrowReviewed(String escrowId) async {
    try {
      await FirebaseFirestore.instance
          .collection('escrow_bookings')
          .doc(escrowId)
          .update({'adminReviewedAt': FieldValue.serverTimestamp()});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.escrowMarkedReviewed),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.couldNotMarkReviewed('$e'))));
    }
  }
}

class _EscrowOpsItem {
  const _EscrowOpsItem({
    required this.id,
    required this.jobId,
    required this.service,
    required this.status,
    required this.payoutStatus,
    required this.payoutError,
    required this.aiPrice,
    required this.contractorPayout,
    required this.createdAt,
    required this.adminReviewedAt,
  });

  factory _EscrowOpsItem.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return _EscrowOpsItem(
      id: doc.id,
      jobId: (data['jobId'] ?? '').toString(),
      service: (data['service'] ?? 'Escrow booking').toString(),
      status: (data['status'] ?? '').toString(),
      payoutStatus: (data['payoutStatus'] ?? '').toString(),
      payoutError: (data['payoutError'] ?? '').toString(),
      aiPrice: (data['aiPrice'] as num?)?.toDouble() ?? 0,
      contractorPayout: (data['contractorPayout'] as num?)?.toDouble() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      adminReviewedAt: (data['adminReviewedAt'] as Timestamp?)?.toDate(),
    );
  }

  final String id;
  final String jobId;
  final String service;
  final String status;
  final String payoutStatus;
  final String payoutError;
  final double aiPrice;
  final double contractorPayout;
  final DateTime? createdAt;
  final DateTime? adminReviewedAt;

  int get sortTime => (createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
      .millisecondsSinceEpoch;

  bool get needsAttention {
    final s = status.toLowerCase();
    final p = payoutStatus.toLowerCase();
    final reviewedAfterCreated =
        adminReviewedAt != null &&
        createdAt != null &&
        adminReviewedAt!.isAfter(createdAt!);

    if (reviewedAfterCreated && !p.contains('failed')) return false;
    return s.contains('failed') ||
        s.contains('dispute') ||
        s == 'payoutfailed' ||
        s == 'payout_failed' ||
        p.contains('failed') ||
        p.contains('manual') ||
        p == 'transferring' ||
        p == 'pending' ||
        s == 'payoutpending' ||
        s == 'payout_pending';
  }

  String get riskLabel => needsAttention ? 'Needs attention' : 'OK';
}

class _PaymentOpsItem {
  const _PaymentOpsItem({
    required this.id,
    required this.title,
    required this.type,
    required this.status,
    required this.uid,
    required this.amount,
    required this.createdAt,
  });

  factory _PaymentOpsItem.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final amountCents =
        (data['amountCents'] as num?)?.toDouble() ??
        (data['amount_cents'] as num?)?.toDouble();
    final amount = amountCents != null
        ? amountCents / 100
        : (data['amount'] as num?)?.toDouble() ?? 0;
    final status =
        (data['status'] ??
                data['payment_status'] ??
                data['paymentStatus'] ??
                data['refundStatus'] ??
                '')
            .toString();
    return _PaymentOpsItem(
      id: doc.id,
      title: (data['description'] ?? data['productName'] ?? 'Payment record')
          .toString(),
      type: (data['type'] ?? data['source'] ?? data['sessionType'] ?? '')
          .toString(),
      status: status,
      uid: (data['uid'] ?? data['userId'] ?? data['contractorId'] ?? '')
          .toString(),
      amount: amount,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ??
          (data['created'] as Timestamp?)?.toDate(),
    );
  }

  final String id;
  final String title;
  final String type;
  final String status;
  final String uid;
  final double amount;
  final DateTime? createdAt;

  int get sortTime => (createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
      .millisecondsSinceEpoch;

  bool get needsAttention {
    final s = status.toLowerCase();
    return s.contains('fail') ||
        s.contains('refund') ||
        s.contains('void') ||
        s.contains('dispute') ||
        s == 'requires_payment_method' ||
        s == 'requires_action' ||
        s == 'unpaid';
  }
}

class _PayoutOpsItem {
  const _PayoutOpsItem({
    required this.uid,
    required this.displayName,
    required this.stripeAccountId,
    required this.detailsSubmitted,
    required this.payoutsEnabled,
  });

  factory _PayoutOpsItem.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final name =
        (data['businessName'] ??
                data['displayName'] ??
                data['name'] ??
                'Contractor')
            .toString();
    return _PayoutOpsItem(
      uid: doc.id,
      displayName: name,
      stripeAccountId: (data['stripeAccountId'] ?? '').toString(),
      detailsSubmitted: data['stripeDetailsSubmitted'] == true,
      payoutsEnabled: data['stripePayoutsEnabled'] == true,
    );
  }

  final String uid;
  final String displayName;
  final String stripeAccountId;
  final bool detailsSubmitted;
  final bool payoutsEnabled;

  bool get payoutReady =>
      stripeAccountId.isNotEmpty && detailsSubmitted && payoutsEnabled;
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.stuckEscrows,
    required this.failedPayments,
    required this.payoutIssues,
    required this.escrowTotal,
  });

  final int stuckEscrows;
  final int failedPayments;
  final int payoutIssues;
  final int escrowTotal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.9,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        _MetricCard(label: l10n.escrows, value: escrowTotal.toString()),
        _MetricCard(label: l10n.escrowAlerts, value: stuckEscrows.toString()),
        _MetricCard(
          label: l10n.paymentAlerts,
          value: failedPayments.toString(),
        ),
        _MetricCard(
          label: l10n.paymentOpsPayoutSetup,
          value: payoutIssues.toString(),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _FilterCard extends StatelessWidget {
  const _FilterCard({required this.filter, required this.onChanged});

  final String filter;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: Text(l10n.needsAttention),
              selected: filter == 'attention',
              onSelected: (_) => onChanged('attention'),
            ),
            ChoiceChip(
              label: Text(l10n.allRecords),
              selected: filter == 'all',
              onSelected: (_) => onChanged('all'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          Text(subtitle),
        ],
      ),
    );
  }
}

class _RiskChip extends StatelessWidget {
  const _RiskChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withValues(alpha: 0.12),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w800),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListTile(
          leading: const Icon(Icons.check_circle_outline),
          title: Text(title),
          subtitle: Text(subtitle),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(l10n.errorLoadingPaymentOperations(message)),
      ),
    );
  }
}
