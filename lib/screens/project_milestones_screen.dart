import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ProjectMilestonesScreen extends StatefulWidget {
  final String jobId;
  final bool isContractor;

  const ProjectMilestonesScreen({
    super.key,
    required this.jobId,
    this.isContractor = false,
  });

  @override
  State<ProjectMilestonesScreen> createState() =>
      _ProjectMilestonesScreenState();
}

class _ProjectMilestonesScreenState extends State<ProjectMilestonesScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _paymentController = TextEditingController();
  bool _isAdding = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _paymentController.dispose();
    super.dispose();
  }

  Future<void> _addMilestone() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a milestone title')),
      );
      return;
    }

    setState(() => _isAdding = true);

    try {
      final payment = double.tryParse(_paymentController.text.trim()) ?? 0.0;

      await FirebaseFirestore.instance
          .collection('job_requests')
          .doc(widget.jobId)
          .collection('milestones')
          .add({
            'title': _titleController.text.trim(),
            'description': _descriptionController.text.trim(),
            'paymentAmount': payment,
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
            'createdBy': FirebaseAuth.instance.currentUser?.uid,
          });

      _titleController.clear();
      _descriptionController.clear();
      _paymentController.clear();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Milestone added!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
      }
    }
  }

  Future<void> _updateMilestoneStatus(
    String milestoneId,
    String newStatus,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('job_requests')
          .doc(widget.jobId)
          .collection('milestones')
          .doc(milestoneId)
          .update({
            'status': newStatus,
            'updatedAt': FieldValue.serverTimestamp(),
            if (newStatus == 'completed')
              'completedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Milestone marked as $newStatus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteMilestone(String milestoneId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Milestone'),
        content: const Text('Are you sure you want to delete this milestone?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('job_requests')
          .doc(widget.jobId)
          .collection('milestones')
          .doc(milestoneId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Milestone deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Project Milestones')),
      body: Column(
        children: [
          // Add Milestone Form (Contractor Only)
          if (widget.isContractor)
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Milestone',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Milestone Title',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., Foundation Complete',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _paymentController,
                      decoration: const InputDecoration(
                        labelText: 'Payment Amount (Optional)',
                        border: OutlineInputBorder(),
                        prefixText: '\$ ',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isAdding ? null : _addMilestone,
                        icon: _isAdding
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.add),
                        label: const Text('Add Milestone'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Milestones List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('job_requests')
                  .doc(widget.jobId)
                  .collection('milestones')
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading milestones'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final milestones = snapshot.data!.docs;

                if (milestones.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.task_alt,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No milestones yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (widget.isContractor) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Add milestones to track project progress',
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
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: milestones.length,
                  itemBuilder: (context, index) {
                    final doc = milestones[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final title = data['title']?.toString() ?? 'Untitled';
                    final description = data['description']?.toString() ?? '';
                    final status = data['status']?.toString() ?? 'pending';
                    final paymentAmount = data['paymentAmount'] ?? 0.0;
                    final createdAt = data['createdAt'] as Timestamp?;

                    return _buildMilestoneCard(
                      doc.id,
                      title,
                      description,
                      status,
                      paymentAmount.toDouble(),
                      createdAt,
                      index + 1,
                      milestones.length,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneCard(
    String milestoneId,
    String title,
    String description,
    String status,
    double paymentAmount,
    Timestamp? createdAt,
    int milestoneNumber,
    int totalMilestones,
  ) {
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'in_progress':
        statusColor = Colors.orange;
        statusIcon = Icons.radio_button_checked;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.radio_button_unchecked;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            leading: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(statusIcon, color: statusColor),
                const SizedBox(height: 4),
                Text(
                  '$milestoneNumber/$totalMilestones',
                  style: const TextStyle(fontSize: 10),
                ),
              ],
            ),
            title: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                decoration: status == 'completed'
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(description),
                ],
                if (paymentAmount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Payment: \$${paymentAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                if (createdAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Created: ${DateFormat.yMMMd().format(createdAt.toDate())}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
            trailing: Chip(
              label: Text(
                status.replaceAll('_', ' ').toUpperCase(),
                style: const TextStyle(fontSize: 10),
              ),
              backgroundColor: statusColor.withValues(alpha: 0.2),
              labelStyle: TextStyle(color: statusColor),
            ),
          ),
          if (widget.isContractor && status != 'completed')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  if (status == 'pending')
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _updateMilestoneStatus(milestoneId, 'in_progress'),
                        icon: const Icon(Icons.play_arrow, size: 16),
                        label: const Text('Start'),
                      ),
                    ),
                  if (status == 'in_progress') ...[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () =>
                            _updateMilestoneStatus(milestoneId, 'completed'),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Complete'),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _deleteMilestone(milestoneId),
                    icon: const Icon(Icons.delete, size: 20),
                    color: Colors.red,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
