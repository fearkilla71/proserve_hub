import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../utils/app_error_handler.dart';

class PaymentOperationsTab extends StatefulWidget {
  const PaymentOperationsTab({super.key});

  @override
  State<PaymentOperationsTab> createState() => _PaymentOperationsTabState();
}

class _PaymentOperationsTabState extends State<PaymentOperationsTab> {
  String _filter = 'attention';
  final _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
  final _dateTime = DateFormat('MMM d, h:mm a');

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
            _OperatorNextAction(
              icon: item.needsAttention
                  ? Icons.priority_high_outlined
                  : Icons.fact_check_outlined,
              title: item.needsAttention
                  ? 'Operator next action'
                  : 'Operator check',
              body: item.needsAttention
                  ? 'Open escrow and job, confirm Stripe payout state, then add a note or mark reviewed after the stuck payment is resolved.'
                  : 'No immediate escrow action is required. Keep the record available for audit history.',
            ),
            if (item.lastAdminNote.isNotEmpty) ...[
              const SizedBox(height: 8),
              _AdminNotePreview(
                note: item.lastAdminNote,
                timestamp: item.lastAdminActionAt,
                formatter: _dateTime,
              ),
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
                OutlinedButton.icon(
                  onPressed: () => _showAdminNoteDialog(
                    title: 'Add escrow note',
                    parentRef: FirebaseFirestore.instance
                        .collection('escrow_bookings')
                        .doc(item.id),
                    type: 'note',
                  ),
                  icon: const Icon(Icons.note_add_outlined),
                  label: const Text('Add note'),
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
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  child: Icon(
                    item.needsAttention
                        ? Icons.warning_amber_outlined
                        : Icons.receipt_long_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        [
                          l10n.idLabel(item.id),
                          if (item.type.isNotEmpty) l10n.typeLabel(item.type),
                          if (item.uid.isNotEmpty) l10n.userLabel(item.uid),
                          if (item.status.isNotEmpty)
                            l10n.statusLabel(item.status),
                          if (item.amount > 0)
                            l10n.amountLabel(_currency.format(item.amount)),
                          if (item.adminReviewedAt != null)
                            'Reviewed ${_dateTime.format(item.adminReviewedAt!)}',
                        ].join('\n'),
                      ),
                    ],
                  ),
                ),
                _RiskChip(
                  label: item.needsAttention ? l10n.check : l10n.ok,
                  color: item.needsAttention ? scheme.error : scheme.primary,
                ),
              ],
            ),
            if (item.lastAdminNote.isNotEmpty) ...[
              const SizedBox(height: 10),
              _AdminNotePreview(
                note: item.lastAdminNote,
                timestamp: item.lastAdminActionAt,
                formatter: _dateTime,
              ),
            ],
            const SizedBox(height: 10),
            _OperatorNextAction(
              icon: item.needsAttention
                  ? Icons.receipt_long_outlined
                  : Icons.check_circle_outline,
              title: item.needsAttention
                  ? 'Operator next action'
                  : 'Operator check',
              body: item.needsAttention
                  ? 'Confirm the Stripe event, subscription or invoice metadata, then record whether the payment was retried, refunded, or fulfilled.'
                  : 'Payment is not flagged. Add a note only if you manually verified it.',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _markPaymentReviewed(item.id),
                  icon: const Icon(Icons.done_all),
                  label: Text(l10n.markReviewed),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showAdminNoteDialog(
                    title: 'Add payment note',
                    parentRef: FirebaseFirestore.instance
                        .collection('payments')
                        .doc(item.id),
                    type: 'note',
                  ),
                  icon: const Icon(Icons.note_add_outlined),
                  label: const Text('Add note'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _payoutCard(_PayoutOpsItem item) {
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
                const CircleAvatar(child: Icon(Icons.payments_outlined)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.displayName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
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
                          l10n.payoutsEnabledLabel(
                            item.payoutsEnabled ? l10n.yes : l10n.no,
                          ),
                          if (item.payoutAdminContactedAt != null)
                            'Contacted ${_dateTime.format(item.payoutAdminContactedAt!)}',
                        ].join('\n'),
                      ),
                    ],
                  ),
                ),
                _RiskChip(
                  label: l10n.paymentOpsPayoutSetup,
                  color: Colors.orange,
                ),
              ],
            ),
            if (item.lastAdminNote.isNotEmpty) ...[
              const SizedBox(height: 10),
              _AdminNotePreview(
                note: item.lastAdminNote,
                timestamp: item.lastAdminActionAt,
                formatter: _dateTime,
              ),
            ],
            const SizedBox(height: 10),
            _OperatorNextAction(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Operator next action',
              body: item.stripeAccountId.isEmpty
                  ? 'Ask the contractor to start Connect onboarding before they can receive escrow or invoice payouts.'
                  : 'Ask the contractor to resume Connect onboarding until details are submitted and payouts are enabled.',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _markPayoutContacted(item.uid),
                  icon: const Icon(Icons.contact_mail_outlined),
                  label: const Text('Mark contacted'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showAdminNoteDialog(
                    title: 'Add payout note',
                    parentRef: FirebaseFirestore.instance
                        .collection('users')
                        .doc(item.uid),
                    type: 'payout_note',
                  ),
                  icon: const Icon(Icons.note_add_outlined),
                  label: const Text('Add note'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAdminNoteDialog({
    required String title,
    required DocumentReference<Map<String, dynamic>> parentRef,
    required String type,
  }) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 4,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Internal admin note',
              hintText: 'What did you check, change, or tell the user?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Save note'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (note == null || note.isEmpty) return;
    await _addAdminAction(parentRef: parentRef, type: type, note: note);
  }

  Future<void> _markEscrowReviewed(String escrowId) async {
    await _addAdminAction(
      parentRef: FirebaseFirestore.instance
          .collection('escrow_bookings')
          .doc(escrowId),
      type: 'reviewed',
      note: 'Marked reviewed from payment operations.',
      parentUpdate: {'adminReviewedAt': FieldValue.serverTimestamp()},
      successMessage: AppLocalizations.of(context)!.escrowMarkedReviewed,
    );
  }

  Future<void> _markPaymentReviewed(String paymentId) async {
    await _addAdminAction(
      parentRef: FirebaseFirestore.instance
          .collection('payments')
          .doc(paymentId),
      type: 'reviewed',
      note: 'Marked reviewed from payment operations.',
      parentUpdate: {'adminReviewedAt': FieldValue.serverTimestamp()},
      successMessage: 'Payment marked reviewed.',
    );
  }

  Future<void> _markPayoutContacted(String uid) async {
    await _addAdminAction(
      parentRef: FirebaseFirestore.instance.collection('users').doc(uid),
      type: 'payout_contacted',
      note: 'Contractor contacted about payout setup.',
      parentUpdate: {'payoutAdminContactedAt': FieldValue.serverTimestamp()},
      successMessage: 'Payout setup marked contacted.',
    );
  }

  Future<void> _addAdminAction({
    required DocumentReference<Map<String, dynamic>> parentRef,
    required String type,
    required String note,
    Map<String, Object?> parentUpdate = const {},
    String successMessage = 'Admin note saved.',
  }) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final actionRef = parentRef.collection('admin_actions').doc();
      batch.set(actionRef, {
        'type': type,
        'note': note,
        'operatorUid':
            FirebaseAuth.instance.currentUser?.uid ?? 'unknown_admin',
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(parentRef, {
        ...parentUpdate,
        'lastAdminActionAt': FieldValue.serverTimestamp(),
        'lastAdminNote': note,
      });
      await batch.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e, st) {
      if (!mounted) return;
      AppError.show(context, e, st, action: 'save admin action');
    }
  }
}

class _OperatorNextAction extends StatelessWidget {
  const _OperatorNextAction({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(body, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
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
    required this.lastAdminNote,
    required this.lastAdminActionAt,
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
      lastAdminNote: (data['lastAdminNote'] ?? '').toString(),
      lastAdminActionAt: (data['lastAdminActionAt'] as Timestamp?)?.toDate(),
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
  final String lastAdminNote;
  final DateTime? lastAdminActionAt;

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
    required this.adminReviewedAt,
    required this.lastAdminNote,
    required this.lastAdminActionAt,
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
      adminReviewedAt: (data['adminReviewedAt'] as Timestamp?)?.toDate(),
      lastAdminNote: (data['lastAdminNote'] ?? '').toString(),
      lastAdminActionAt: (data['lastAdminActionAt'] as Timestamp?)?.toDate(),
    );
  }

  final String id;
  final String title;
  final String type;
  final String status;
  final String uid;
  final double amount;
  final DateTime? createdAt;
  final DateTime? adminReviewedAt;
  final String lastAdminNote;
  final DateTime? lastAdminActionAt;

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
    required this.lastAdminNote,
    required this.lastAdminActionAt,
    required this.payoutAdminContactedAt,
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
      lastAdminNote: (data['lastAdminNote'] ?? '').toString(),
      lastAdminActionAt: (data['lastAdminActionAt'] as Timestamp?)?.toDate(),
      payoutAdminContactedAt: (data['payoutAdminContactedAt'] as Timestamp?)
          ?.toDate(),
    );
  }

  final String uid;
  final String displayName;
  final String stripeAccountId;
  final bool detailsSubmitted;
  final bool payoutsEnabled;
  final String lastAdminNote;
  final DateTime? lastAdminActionAt;
  final DateTime? payoutAdminContactedAt;

  bool get payoutReady =>
      stripeAccountId.isNotEmpty && detailsSubmitted && payoutsEnabled;
}

class _AdminNotePreview extends StatelessWidget {
  const _AdminNotePreview({
    required this.note,
    required this.timestamp,
    required this.formatter,
  });

  final String note;
  final DateTime? timestamp;
  final DateFormat formatter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            timestamp == null
                ? 'Last admin note'
                : 'Last admin note • ${formatter.format(timestamp!)}',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(note),
        ],
      ),
    );
  }
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
