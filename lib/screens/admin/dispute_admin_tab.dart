import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DisputeAdminTab extends StatefulWidget {
  const DisputeAdminTab({super.key});

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
              return status == 'open' || status == 'under_review';
            }
            return status == _statusFilter;
          }).toList();
        }

        disputes.sort((a, b) {
          final ad = (a.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
          final bd = (b.data() as Map<String, dynamic>?) ?? <String, dynamic>{};

          final at = ad['createdAt'];
          final bt = bd['createdAt'];
          final aMillis = at is Timestamp ? at.millisecondsSinceEpoch : 0;
          final bMillis = bt is Timestamp ? bt.millisecondsSinceEpoch : 0;
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
                  color: status == 'open' ? Colors.orange : Colors.blue,
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
                        const SizedBox(height: 16),
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
                                  foregroundColor: Colors.red,
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
