import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../theme/admin_theme.dart';

class DisputeAdminTab extends StatefulWidget {
  final bool canWrite;
  const DisputeAdminTab({super.key, this.canWrite = false});

  @override
  State<DisputeAdminTab> createState() => _DisputeAdminTabState();
}

class _DisputeAdminTabState extends State<DisputeAdminTab> {
  String _statusFilter = 'active';
  String _sortBy = 'newest';

  Future<void> _updateDisputeStatus(
    BuildContext context,
    String disputeId,
    String newStatus,
    String? resolution,
  ) async {
    try {
      final disputeSnap = await FirebaseFirestore.instance
          .collection('disputes')
          .doc(disputeId)
          .get();
      final disputeData = disputeSnap.data();
      final jobId = (disputeData?['jobId'] as String?)?.trim();

      final updates = <String, dynamic>{
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (resolution != null) {
        updates['resolution'] = resolution;
        updates['resolvedAt'] = FieldValue.serverTimestamp();
      }

      await FirebaseFirestore.instance
          .collection('disputes')
          .doc(disputeId)
          .update(updates);

      // Keep job document in sync for job detail discovery.
      if (jobId != null && jobId.isNotEmpty) {
        final jobUpdates = <String, dynamic>{
          'disputeStatus': newStatus,
          'disputeUpdatedAt': FieldValue.serverTimestamp(),
        };
        if (newStatus == 'resolved') {
          jobUpdates['disputeResolvedAt'] = FieldValue.serverTimestamp();
        }
        if (newStatus == 'closed') {
          jobUpdates['disputeClosedAt'] = FieldValue.serverTimestamp();
        }
        await FirebaseFirestore.instance
            .collection('job_requests')
            .doc(jobId)
            .set(jobUpdates, SetOptions(merge: true));
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dispute status updated to $newStatus')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showResolutionDialog(BuildContext context, String disputeId) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Resolve Dispute'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Resolution Details',
            border: OutlineInputBorder(),
          ),
          maxLines: 5,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _updateDisputeStatus(
                context,
                disputeId,
                'resolved',
                controller.text.trim(),
              );
            },
            child: const Text('Resolve'),
          ),
        ],
      ),
    );
  }

  /// Escalate a dispute to senior admin
  Future<void> _escalateDispute(
    BuildContext context,
    String disputeId,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('disputes')
          .doc(disputeId)
          .update({
        'status': 'escalated',
        'escalatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Write to mediation history
      await FirebaseFirestore.instance
          .collection('disputes')
          .doc(disputeId)
          .collection('mediation_history')
          .add({
        'action': 'escalated',
        'note': 'Dispute escalated by admin for senior review',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dispute escalated')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  /// Issue a refund for the dispute's escrow booking
  void _showRefundDialog(BuildContext context, String disputeId,
      Map<String, dynamic> dispute) {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Issue Refund'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Refund Amount (\$)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Refund Reason',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AdminColors.error),
            onPressed: () async {
              Navigator.pop(dialogContext);
              final amount =
                  double.tryParse(amountCtrl.text.trim()) ?? 0;
              if (amount <= 0) return;

              // Record refund
              await FirebaseFirestore.instance
                  .collection('disputes')
                  .doc(disputeId)
                  .update({
                'refundAmount': amount,
                'refundReason': reasonCtrl.text.trim(),
                'refundIssuedAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              });

              // Add to mediation history
              await FirebaseFirestore.instance
                  .collection('disputes')
                  .doc(disputeId)
                  .collection('mediation_history')
                  .add({
                'action': 'refund_issued',
                'amount': amount,
                'note': reasonCtrl.text.trim(),
                'createdAt': FieldValue.serverTimestamp(),
              });

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          'Refund of \$${amount.toStringAsFixed(2)} issued')),
                );
              }
            },
            child: const Text('Issue Refund'),
          ),
        ],
      ),
    );
  }

  /// Add a mediation note
  void _showAddNoteDialog(BuildContext context, String disputeId) {
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Mediation Note'),
        content: TextField(
          controller: noteCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Note',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              if (noteCtrl.text.trim().isEmpty) return;
              await FirebaseFirestore.instance
                  .collection('disputes')
                  .doc(disputeId)
                  .collection('mediation_history')
                  .add({
                'action': 'note',
                'note': noteCtrl.text.trim(),
                'createdAt': FieldValue.serverTimestamp(),
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('disputes').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Error loading disputes:\n\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var disputes = snapshot.data!.docs.toList();
        if (_statusFilter != 'all') {
          disputes = disputes.where((doc) {
            final data =
                (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
            final status = (data['status'] as String?)?.trim().toLowerCase();
            if (_statusFilter == 'active') {
              return status == 'open' ||
                  status == 'under_review' ||
                  status == 'escalated';
            }
            return status == _statusFilter;
          }).toList();
        }

        disputes.sort((a, b) {
          final ad = (a.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
          final bd = (b.data() as Map<String, dynamic>?) ?? <String, dynamic>{};

          final at = ad['createdAt'];
          final bt = bd['createdAt'];
          final aMillis = at is Timestamp
              ? at.millisecondsSinceEpoch
              : (at is DateTime ? at.millisecondsSinceEpoch : 0);
          final bMillis = bt is Timestamp
              ? bt.millisecondsSinceEpoch
              : (bt is DateTime ? bt.millisecondsSinceEpoch : 0);

          return _sortBy == 'oldest'
              ? aMillis.compareTo(bMillis)
              : bMillis.compareTo(aMillis);
        });

        if (disputes.isEmpty) {
          return const Center(child: Text('No active disputes'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: disputes.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filters & sorting',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Active'),
                            selected: _statusFilter == 'active',
                            onSelected: (_) {
                              setState(() => _statusFilter = 'active');
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Open'),
                            selected: _statusFilter == 'open',
                            onSelected: (_) {
                              setState(() => _statusFilter = 'open');
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Under review'),
                            selected: _statusFilter == 'under_review',
                            onSelected: (_) {
                              setState(() => _statusFilter = 'under_review');
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Escalated'),
                            selected: _statusFilter == 'escalated',
                            onSelected: (_) {
                              setState(() => _statusFilter = 'escalated');
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Resolved'),
                            selected: _statusFilter == 'resolved',
                            onSelected: (_) {
                              setState(() => _statusFilter = 'resolved');
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Closed'),
                            selected: _statusFilter == 'closed',
                            onSelected: (_) {
                              setState(() => _statusFilter = 'closed');
                            },
                          ),
                          ChoiceChip(
                            label: const Text('All'),
                            selected: _statusFilter == 'all',
                            onSelected: (_) {
                              setState(() => _statusFilter = 'all');
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _sortBy,
                        decoration: const InputDecoration(
                          labelText: 'Sort by',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'newest',
                            child: Text('Newest → Oldest'),
                          ),
                          DropdownMenuItem(
                            value: 'oldest',
                            child: Text('Oldest → Newest'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _sortBy = value);
                        },
                      ),
                    ],
                  ),
                ),
              );
            }

            final dispute = disputes[index - 1].data() as Map<String, dynamic>;
            final disputeId = disputes[index - 1].id;
            final status = dispute['status'] as String? ?? 'open';
            final category = dispute['category'] as String? ?? '';
            final reason = dispute['reason'] as String? ?? '';
            final details = dispute['details'] as String? ?? '';
            final jobId = dispute['jobId'] as String? ?? '';
            final createdAt = dispute['createdAt'] as Timestamp?;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: ExpansionTile(
                leading: Icon(
                  Icons.report_problem,
                  color: status == 'open'
                      ? AdminColors.warning
                      : AdminColors.accent2,
                ),
                title: Text(category),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reason),
                    if (createdAt != null)
                      Text(
                        DateFormat(
                          'MMM d, y • h:mm a',
                        ).format(createdAt.toDate()),
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
                trailing: Chip(
                  label: Text(
                    status.toUpperCase(),
                    style: const TextStyle(fontSize: 10),
                  ),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Details',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(details),
                        const SizedBox(height: 16),
                        Text(
                          'Job ID: $jobId',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (dispute['refundAmount'] != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.money_off,
                                  size: 16, color: AdminColors.error),
                              const SizedBox(width: 4),
                              Text(
                                'Refund issued: \$${(dispute['refundAmount'] as num).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: AdminColors.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (status == 'escalated') ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AdminColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '⚠ ESCALATED — Awaiting senior review',
                              style: TextStyle(
                                color: AdminColors.warning,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // ── Action buttons ──
                        Row(
                          children: [
                            if (status == 'open')
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _updateDisputeStatus(
                                    context,
                                    disputeId,
                                    'under_review',
                                    null,
                                  ),
                                  child: const Text('Start Review'),
                                ),
                              ),
                            if (status == 'open') const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton(
                                onPressed: () =>
                                    _showResolutionDialog(context, disputeId),
                                child: const Text('Resolve'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AdminColors.error,
                                ),
                                onPressed: () => _updateDisputeStatus(
                                  context,
                                  disputeId,
                                  'closed',
                                  'Dispute closed without resolution',
                                ),
                                child: const Text('Close'),
                              ),
                            ),
                          ],
                        ),

                        // ── Escalation + Refund row ──
                        if (widget.canWrite &&
                            status != 'resolved' &&
                            status != 'closed') ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (status != 'escalated')
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.arrow_upward,
                                        size: 16),
                                    label: const Text('Escalate'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AdminColors.warning,
                                    ),
                                    onPressed: () => _escalateDispute(
                                        context, disputeId),
                                  ),
                                ),
                              if (status != 'escalated')
                                const SizedBox(width: 8),
                              if (dispute['refundAmount'] == null)
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.money_off,
                                        size: 16),
                                    label: const Text('Issue Refund'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AdminColors.error,
                                    ),
                                    onPressed: () => _showRefundDialog(
                                        context, disputeId, dispute),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.note_add, size: 16),
                                  label: const Text('Add Note'),
                                  onPressed: () =>
                                      _showAddNoteDialog(context, disputeId),
                                ),
                              ),
                            ],
                          ),
                        ],

                        // ── Mediation History ──
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        const Text(
                          'Mediation History',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('disputes')
                              .doc(disputeId)
                              .collection('mediation_history')
                              .orderBy('createdAt', descending: true)
                              .snapshots(),
                          builder: (ctx, histSnap) {
                            if (!histSnap.hasData ||
                                histSnap.data!.docs.isEmpty) {
                              return const Text(
                                'No mediation entries yet.',
                                style: TextStyle(
                                    fontSize: 12, fontStyle: FontStyle.italic),
                              );
                            }
                            final entries = histSnap.data!.docs;
                            return Column(
                              children: entries.map((doc) {
                                final d = doc.data() as Map<String, dynamic>;
                                final action =
                                    d['action'] as String? ?? 'note';
                                final note = d['note'] as String? ?? '';
                                final ts = d['createdAt'] as Timestamp?;
                                final amount = d['amount'] as num?;

                                IconData icon;
                                Color iconColor;
                                switch (action) {
                                  case 'escalated':
                                    icon = Icons.arrow_upward;
                                    iconColor = AdminColors.warning;
                                    break;
                                  case 'refund_issued':
                                    icon = Icons.money_off;
                                    iconColor = AdminColors.error;
                                    break;
                                  default:
                                    icon = Icons.note;
                                    iconColor = AdminColors.accent2;
                                }

                                return Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(icon,
                                          size: 16, color: iconColor),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              action == 'refund_issued'
                                                  ? 'Refund \$${amount?.toStringAsFixed(2) ?? ''}'
                                                  : action
                                                      .replaceAll('_', ' ')
                                                      .toUpperCase(),
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                                color: iconColor,
                                              ),
                                            ),
                                            if (note.isNotEmpty)
                                              Text(note,
                                                  style: const TextStyle(
                                                      fontSize: 12)),
                                            if (ts != null)
                                              Text(
                                                DateFormat('MMM d, y h:mm a')
                                                    .format(ts.toDate()),
                                                style: const TextStyle(
                                                    fontSize: 10,
                                                    color:
                                                        AdminColors.muted),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
