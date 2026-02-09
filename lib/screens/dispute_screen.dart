import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class DisputeScreen extends StatefulWidget {
  final String jobId;

  const DisputeScreen({super.key, required this.jobId});

  @override
  State<DisputeScreen> createState() => _DisputeScreenState();
}

class _DisputeScreenState extends State<DisputeScreen> {
  final _reasonController = TextEditingController();
  final _detailsController = TextEditingController();
  String _selectedCategory = 'Quality of Work';
  bool _isSubmitting = false;

  final List<String> _evidenceChecklist = const [
    'Photos/videos of the work area',
    'Messages and agreements (in-app or text)',
    'Invoice/quote details and receipts (if any)',
    'Dates/times and what was promised vs delivered',
  ];

  final List<String> _categories = [
    'Quality of Work',
    'Payment Issue',
    'Communication',
    'Timeline/Deadline',
    'Property Damage',
    'Other',
  ];

  Future<void> _submitDispute() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_reasonController.text.trim().isEmpty ||
        _detailsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Get job data
      final jobDoc = await FirebaseFirestore.instance
          .collection('job_requests')
          .doc(widget.jobId)
          .get();

      final jobData = jobDoc.data();
      if (jobData == null) {
        throw Exception('Job not found');
      }

      final requesterUid = (jobData['requesterUid'] as String?)?.trim() ?? '';
      final claimedBy = (jobData['claimedBy'] as String?)?.trim() ?? '';

      final acceptedQuoteId =
          (jobData['acceptedQuoteId'] as String?)?.trim() ?? '';
      final acceptedBidId = (jobData['acceptedBidId'] as String?)?.trim() ?? '';
      final hasMutualAgreement =
          acceptedQuoteId.isNotEmpty || acceptedBidId.isNotEmpty;

      if (requesterUid.isEmpty || claimedBy.isEmpty) {
        throw Exception('This job is not assigned yet');
      }

      if (!hasMutualAgreement) {
        throw Exception(
          'Disputes can be filed only after an accepted quote/bid.',
        );
      }

      final isParty = user.uid == requesterUid || user.uid == claimedBy;
      if (!isParty) {
        throw Exception('Only the customer or contractor can file a dispute');
      }

      final otherPartyId = user.uid == requesterUid ? claimedBy : requesterUid;

      // One active dispute per job: dispute doc id == jobId.
      final disputeRef = FirebaseFirestore.instance
          .collection('disputes')
          .doc(widget.jobId);

      final existing = await disputeRef.get();
      if (existing.exists) {
        throw Exception('An active dispute already exists for this job');
      }

      // Create dispute
      await disputeRef.set({
        'jobId': widget.jobId,
        'requesterUid': requesterUid,
        'contractorUid': claimedBy,
        'category': _selectedCategory,
        'reason': _reasonController.text.trim(),
        'details': _detailsController.text.trim(),
        'reportedBy': user.uid,
        'reportedAgainst': otherPartyId,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
        'messages': [],
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Dispute submitted. Our team will review it shortly.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error submitting dispute: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Widget _stepRow(
    BuildContext context, {
    required int number,
    required String title,
    required String subtitle,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Text(
            number.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report a Dispute')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Disputes should only be filed for serious issues. Please try to resolve conflicts directly first.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dispute process (controlled + predictable)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _stepRow(
                      context,
                      number: 1,
                      title: 'You submit the dispute',
                      subtitle: 'Escrow is frozen while it’s reviewed.',
                    ),
                    const SizedBox(height: 10),
                    _stepRow(
                      context,
                      number: 2,
                      title: 'We review evidence from both sides',
                      subtitle: 'We may request clarification or more proof.',
                    ),
                    const SizedBox(height: 10),
                    _stepRow(
                      context,
                      number: 3,
                      title: 'Decision + resolution update',
                      subtitle:
                          'You’ll get a status update and next steps in-app.',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            Text('Category', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: _categories
                  .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCategory = value;
                  });
                }
              },
            ),

            const SizedBox(height: 24),

            Text(
              'Brief Summary',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Summarize the issue in one sentence',
              ),
              maxLength: 100,
            ),

            const SizedBox(height: 16),

            Text(
              'Detailed Description',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _detailsController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Provide as much detail as possible...',
              ),
              maxLines: 8,
              maxLength: 1000,
            ),

            const SizedBox(height: 24),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Evidence checklist',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Having these ready helps us resolve disputes faster:',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._evidenceChecklist.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Time expectations',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Initial review: typically within 1 business day\n'
                      '• Follow-up questions (if needed): 1–2 business days\n'
                      '• Resolution target: 3–5 business days\n'
                      '• You\'ll see updates in-app as the status changes',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submitDispute,
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Submit Dispute'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DisputesListScreen extends StatelessWidget {
  const DisputesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('My Disputes')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('disputes')
            .where('reportedBy', isEqualTo: user?.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final disputes = snapshot.data!.docs;

          if (disputes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 80,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No disputes filed',
                    style: TextStyle(
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: disputes.length,
            itemBuilder: (context, index) {
              final dispute = disputes[index].data() as Map<String, dynamic>;
              final disputeId = disputes[index].id;
              final status = dispute['status'] as String? ?? 'open';
              final category = dispute['category'] as String? ?? '';
              final reason = dispute['reason'] as String? ?? '';
              final createdAt = dispute['createdAt'] as Timestamp?;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  leading: Icon(
                    Icons.report_problem,
                    color: status == 'resolved'
                        ? Colors.green
                        : status == 'open'
                        ? Colors.orange
                        : Colors.blue,
                  ),
                  title: Text(category),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reason,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (createdAt != null)
                        Text(
                          DateFormat('MMM d, y').format(createdAt.toDate()),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
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
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DisputeDetailScreen(disputeId: disputeId),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class DisputeDetailScreen extends StatelessWidget {
  final String disputeId;

  const DisputeDetailScreen({super.key, required this.disputeId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dispute Details')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('disputes')
            .doc(disputeId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final dispute = snapshot.data!.data() as Map<String, dynamic>;
          final status = dispute['status'] as String? ?? 'open';
          final category = dispute['category'] as String? ?? '';
          final reason = dispute['reason'] as String? ?? '';
          final details = dispute['details'] as String? ?? '';
          final createdAt = dispute['createdAt'] as Timestamp?;
          final resolution = dispute['resolution'] as String?;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Status',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            Chip(
                              label: Text(status.toUpperCase()),
                              backgroundColor: status == 'resolved'
                                  ? Colors.green
                                  : status == 'open'
                                  ? Colors.orange
                                  : Colors.blue,
                            ),
                          ],
                        ),
                        const Divider(),
                        Text(
                          'Category',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        Text(category),
                        const SizedBox(height: 16),
                        Text(
                          'Summary',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        Text(reason),
                        const SizedBox(height: 16),
                        Text(
                          'Details',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        Text(details),
                        if (createdAt != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Filed: ${DateFormat('MMM d, y • h:mm a').format(createdAt.toDate())}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                if (resolution != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Resolution',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            resolution,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
