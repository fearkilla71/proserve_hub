import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/recurring_job_service.dart';

/// Screen for managing recurring job schedules.
class RecurringJobsScreen extends StatefulWidget {
  const RecurringJobsScreen({super.key});

  @override
  State<RecurringJobsScreen> createState() => _RecurringJobsScreenState();
}

class _RecurringJobsScreenState extends State<RecurringJobsScreen> {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Jobs'),
        actions: [
          IconButton(
            tooltip: 'Add recurring job',
            onPressed: () => _showAddEditSheet(context),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: RecurringJobService.instance.watchRecurringJobs(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return _emptyState(scheme);
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data();
              return _RecurringJobCard(
                id: doc.id,
                data: data,
                onEdit: () =>
                    _showAddEditSheet(context, id: doc.id, data: data),
                onCreateJob: () => _createJob(doc.id),
                onToggle: (active) =>
                    RecurringJobService.instance.toggleActive(doc.id, active),
                onDelete: () => _confirmDelete(doc.id, data['clientName']),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditSheet(context),
        icon: const Icon(Icons.repeat),
        label: const Text('Add Recurring'),
      ),
    );
  }

  Widget _emptyState(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.repeat,
              size: 72,
              color: scheme.primary.withValues(alpha: .4),
            ),
            const SizedBox(height: 16),
            Text(
              'No Recurring Jobs',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Set up quarterly pressure washing, annual\nrepaints, and other recurring work.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEditSheet(
    BuildContext context, {
    String? id,
    Map<String, dynamic>? data,
  }) {
    final serviceCtrl = TextEditingController(text: data?['serviceType'] ?? '');
    final clientCtrl = TextEditingController(text: data?['clientName'] ?? '');
    final addressCtrl = TextEditingController(text: data?['address'] ?? '');
    final priceCtrl = TextEditingController(
      text: data?['price'] != null
          ? (data!['price'] as num).toStringAsFixed(2)
          : '',
    );
    final notesCtrl = TextEditingController(text: data?['notes'] ?? '');
    String frequency = data?['frequency'] as String? ?? 'monthly';
    DateTime nextDue = data?['nextDueDate'] != null
        ? (data!['nextDueDate'] as Timestamp).toDate()
        : DateTime.now().add(const Duration(days: 30));

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      id == null ? 'Add Recurring Job' : 'Edit Recurring Job',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _field(ctx, serviceCtrl, 'Service type', Icons.work),
                    const SizedBox(height: 12),
                    _field(ctx, clientCtrl, 'Client name', Icons.person),
                    const SizedBox(height: 12),
                    _field(ctx, addressCtrl, 'Address', Icons.location_on),
                    const SizedBox(height: 12),
                    _field(
                      ctx,
                      priceCtrl,
                      'Price (\$)',
                      Icons.attach_money,
                      type: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: frequency,
                      decoration: const InputDecoration(
                        labelText: 'Frequency',
                        prefixIcon: Icon(Icons.repeat),
                        border: OutlineInputBorder(),
                      ),
                      items: RecurringJobService.frequencies.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setSheetState(() => frequency = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: Text(
                        'Next due: ${DateFormat.yMMMd().format(nextDue)}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: nextDue,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 730),
                          ),
                        );
                        if (picked != null) {
                          setSheetState(() => nextDue = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _field(ctx, notesCtrl, 'Notes', Icons.note, maxLines: 2),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          if (serviceCtrl.text.trim().isEmpty ||
                              clientCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Service type and client are required',
                                ),
                              ),
                            );
                            return;
                          }
                          Navigator.pop(ctx);
                          HapticFeedback.mediumImpact();
                          try {
                            if (id == null) {
                              await RecurringJobService.instance
                                  .createRecurringJob(
                                    serviceType: serviceCtrl.text.trim(),
                                    clientName: clientCtrl.text.trim(),
                                    address: addressCtrl.text.trim(),
                                    frequency: frequency,
                                    price: double.tryParse(
                                      priceCtrl.text.trim(),
                                    ),
                                    notes: notesCtrl.text.trim().isEmpty
                                        ? null
                                        : notesCtrl.text.trim(),
                                    firstDueDate: nextDue,
                                  );
                            } else {
                              await RecurringJobService.instance
                                  .updateRecurringJob(id, {
                                    'serviceType': serviceCtrl.text.trim(),
                                    'clientName': clientCtrl.text.trim(),
                                    'address': addressCtrl.text.trim(),
                                    'frequency': frequency,
                                    'price': double.tryParse(
                                      priceCtrl.text.trim(),
                                    ),
                                    'notes': notesCtrl.text.trim().isEmpty
                                        ? null
                                        : notesCtrl.text.trim(),
                                    'nextDueDate': Timestamp.fromDate(nextDue),
                                  });
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.save),
                        label: Text(id == null ? 'Create' : 'Save'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _createJob(String recurringId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      HapticFeedback.mediumImpact();
      await RecurringJobService.instance.createJobFromRecurring(recurringId);
      messenger.showSnackBar(
        const SnackBar(content: Text('Job created and next due date advanced')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _confirmDelete(String id, String? clientName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Recurring Job'),
        content: Text(
          'Remove recurring job for ${clientName ?? 'this client'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              RecurringJobService.instance.deleteRecurringJob(id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _field(
    BuildContext ctx,
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? type,
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      keyboardType: type,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.words,
    );
  }
}

class _RecurringJobCard extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onCreateJob;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  const _RecurringJobCard({
    required this.id,
    required this.data,
    required this.onEdit,
    required this.onCreateJob,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final service = data['serviceType'] ?? 'Job';
    final client = data['clientName'] ?? 'Unknown';
    final frequency = data['frequency'] as String? ?? 'monthly';
    final active = data['active'] as bool? ?? true;
    final nextDue = (data['nextDueDate'] as Timestamp?)?.toDate();
    final price = (data['price'] as num?)?.toDouble();
    final isDue = nextDue != null && nextDue.isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: !active ? scheme.surfaceContainerHighest : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.repeat,
                  color: active ? scheme.primary : Colors.grey,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: active ? null : Colors.grey,
                        ),
                      ),
                      Text(
                        '$client • ${RecurringJobService.frequencies[frequency] ?? frequency}',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (price != null)
                  Text(
                    '\$${price.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDue
                        ? Colors.red.withValues(alpha: .1)
                        : Colors.green.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    nextDue != null
                        ? 'Next: ${DateFormat.yMMMd().format(nextDue)}'
                              '${isDue ? ' (OVERDUE)' : ''}'
                        : 'No date set',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDue ? Colors.red : Colors.green,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (active && isDue)
                  FilledButton.tonalIcon(
                    onPressed: onCreateJob,
                    icon: const Icon(Icons.add_task, size: 18),
                    label: const Text('Create Job'),
                  ),
                if (active && !isDue)
                  TextButton.icon(
                    onPressed: onCreateJob,
                    icon: const Icon(Icons.add_task, size: 18),
                    label: const Text('Create Now'),
                  ),
                const Spacer(),
                IconButton(
                  tooltip: active ? 'Pause' : 'Resume',
                  onPressed: () => onToggle(!active),
                  icon: Icon(active ? Icons.pause : Icons.play_arrow, size: 20),
                ),
                IconButton(
                  tooltip: 'Edit',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: scheme.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
