import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'progress_photos_screen.dart';

class JobStatusScreen extends StatefulWidget {
  final String jobId;

  const JobStatusScreen({super.key, required this.jobId});

  @override
  State<JobStatusScreen> createState() => _JobStatusScreenState();
}

class _JobStatusScreenState extends State<JobStatusScreen> {
  bool _isUpdating = false;

  Future<void> _updateStatus(String newStatus) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isUpdating = true);

    try {
      final jobRef = FirebaseFirestore.instance
          .collection('job_requests')
          .doc(widget.jobId);

      await jobRef.update({
        'status': newStatus,
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': newStatus,
            'timestamp': FieldValue.serverTimestamp(),
            'updatedBy': user.uid,
          },
        ]),
        if (newStatus == 'in_progress')
          'startedAt': FieldValue.serverTimestamp(),
        if (newStatus == 'completion_requested')
          'completionRequested': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to ${_getStatusLabel(newStatus)}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating status: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _approveCompletion() async {
    setState(() => _isUpdating = true);

    try {
      await FirebaseFirestore.instance
          .collection('job_requests')
          .doc(widget.jobId)
          .update({
            'status': 'completion_approved',
            'completionApproved': FieldValue.serverTimestamp(),
            'statusHistory': FieldValue.arrayUnion([
              {
                'status': 'completion_approved',
                'timestamp': FieldValue.serverTimestamp(),
                'updatedBy': FirebaseAuth.instance.currentUser!.uid,
                'approved': true,
              },
            ]),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job marked as completed! 🎉')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving completion: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Accepted';
      case 'in_progress':
        return 'In Progress';
      case 'completion_requested':
        return 'Completion Requested';
      case 'completion_approved':
        return 'Completion Approved';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'in_progress':
        return Colors.purple;
      case 'completion_requested':
        return Colors.deepOrange;
      case 'completion_approved':
        return Colors.teal;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule;
      case 'accepted':
        return Icons.check_circle_outline;
      case 'in_progress':
        return Icons.work;
      case 'completion_requested':
        return Icons.hourglass_top;
      case 'completion_approved':
        return Icons.verified;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Job Status')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('job_requests')
            .doc(widget.jobId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final job = snapshot.data!.data() as Map<String, dynamic>?;
          if (job == null) {
            return const Center(child: Text('Job not found'));
          }

          final currentStatus = job['status'] ?? 'pending';
          final isRequester =
              FirebaseAuth.instance.currentUser?.uid == job['requesterUid'];
          final isContractor =
              FirebaseAuth.instance.currentUser?.uid == job['claimedBy'];
          final statusHistory =
              (job['statusHistory'] as List<dynamic>?)
                  ?.cast<Map<String, dynamic>>() ??
              [];
          final completionRequested = job['completionRequested'] != null;
          final completionApproved = job['completionApproved'] != null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current Status Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          _getStatusIcon(currentStatus),
                          size: 64,
                          color: _getStatusColor(currentStatus),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _getStatusLabel(currentStatus),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (completionRequested && !completionApproved) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Awaiting customer approval',
                            style: TextStyle(
                              fontSize: 14,
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

                const SizedBox(height: 24),

                // Progress Photos Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Progress Photos'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ProgressPhotosScreen(jobId: widget.jobId),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // Action Buttons
                if (isContractor && !_isUpdating) ...[
                  if (currentStatus == 'accepted')
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start Work'),
                        onPressed: () => _updateStatus('in_progress'),
                      ),
                    ),
                  if (currentStatus == 'in_progress')
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text('Request Completion'),
                        onPressed: () => _updateStatus('completion_requested'),
                      ),
                    ),
                ],

                if (isRequester &&
                    completionRequested &&
                    !completionApproved &&
                    !_isUpdating)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Approve Completion'),
                      onPressed: () => _showApprovalDialog(),
                    ),
                  ),

                if (_isUpdating)
                  const Center(child: CircularProgressIndicator()),

                const SizedBox(height: 32),

                // Timeline
                const Text(
                  'Timeline',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                if (statusHistory.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No status updates yet',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  ...statusHistory.reversed.map((entry) {
                    final status = entry['status'] as String;
                    final timestamp = entry['timestamp'] as Timestamp?;
                    final approved = entry['approved'] == true;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    status,
                                  ).withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _getStatusIcon(status),
                                  color: _getStatusColor(status),
                                  size: 20,
                                ),
                              ),
                              if (entry != statusHistory.first)
                                Container(
                                  width: 2,
                                  height: 40,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      _getStatusLabel(status),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (approved) ...[
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.verified,
                                        size: 16,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    ],
                                  ],
                                ),
                                if (timestamp != null)
                                  Text(
                                    DateFormat(
                                      'MMM d, y • h:mm a',
                                    ).format(timestamp.toDate()),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showApprovalDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Completion'),
        content: const Text(
          'Are you satisfied with the work? This will mark the job as completed and may trigger payment release.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _approveCompletion();
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }
}
