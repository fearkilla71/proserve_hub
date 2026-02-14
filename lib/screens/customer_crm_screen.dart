import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/customer_crm_service.dart';

/// Customer CRM / Contact Management screen for contractors.
class CustomerCrmScreen extends StatefulWidget {
  const CustomerCrmScreen({super.key});

  @override
  State<CustomerCrmScreen> createState() => _CustomerCrmScreenState();
}

class _CustomerCrmScreenState extends State<CustomerCrmScreen> {
  String _searchQuery = '';
  bool _showFollowUps = false;
  List<Map<String, dynamic>> _followUps = [];

  @override
  void initState() {
    super.initState();
    _loadFollowUps();
  }

  Future<void> _loadFollowUps() async {
    final ups = await CustomerCrmService.instance.getUpcomingFollowUps();
    if (mounted) setState(() => _followUps = ups);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Client Manager'),
        actions: [
          IconButton(
            tooltip: 'Import from past jobs',
            icon: const Icon(Icons.download),
            onPressed: _importClients,
          ),
          IconButton(
            tooltip: _showFollowUps ? 'Show all' : 'Show follow-ups',
            icon: Icon(
              _showFollowUps ? Icons.people : Icons.notification_important,
              color: _followUps.isNotEmpty && !_showFollowUps
                  ? Colors.orange
                  : null,
            ),
            onPressed: () => setState(() => _showFollowUps = !_showFollowUps),
          ),
        ],
      ),
      body: Column(
        children: [
          // Follow-up banner
          if (_followUps.isNotEmpty && !_showFollowUps)
            Material(
              color: Colors.orange.withValues(alpha: .1),
              child: InkWell(
                onTap: () => setState(() => _showFollowUps = true),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.notification_important,
                        color: Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_followUps.length} follow-up${_followUps.length == 1 ? '' : 's'} due',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.orange,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.chevron_right,
                        color: Colors.orange,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search clients…',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: scheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            ),
          ),

          // Client list
          Expanded(
            child: _showFollowUps
                ? _buildFollowUpsList(scheme)
                : _buildClientList(scheme),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditSheet(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Client'),
      ),
    );
  }

  Widget _buildFollowUpsList(ColorScheme scheme) {
    if (_followUps.isEmpty) {
      return const Center(child: Text('No upcoming follow-ups'));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: _followUps.length,
      itemBuilder: (ctx, i) {
        final c = _followUps[i];
        final date = (c['followUpDate'] as Timestamp?)?.toDate();
        final isPast = date != null && date.isBefore(DateTime.now());

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: isPast
              ? Colors.red.withValues(alpha: .05)
              : Colors.orange.withValues(alpha: .05),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isPast
                  ? Colors.red.shade100
                  : Colors.orange.shade100,
              child: Icon(
                Icons.notification_important,
                color: isPast ? Colors.red : Colors.orange,
              ),
            ),
            title: Text(
              c['name'] ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${date != null ? DateFormat.yMMMd().format(date) : ''}'
              '${isPast ? ' (OVERDUE)' : ''}'
              '\n${c['followUpNote'] ?? ''}',
            ),
            isThreeLine: true,
            trailing: IconButton(
              icon: const Icon(Icons.check_circle_outline),
              tooltip: 'Mark done',
              onPressed: () async {
                await CustomerCrmService.instance.clearFollowUp(
                  c['id'] as String,
                );
                _loadFollowUps();
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildClientList(ColorScheme scheme) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: CustomerCrmService.instance.watchClients(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var docs = snap.data?.docs ?? [];
        if (_searchQuery.isNotEmpty) {
          docs = docs.where((d) {
            final name = (d.data()['name'] as String? ?? '').toLowerCase();
            final email = (d.data()['email'] as String? ?? '').toLowerCase();
            final phone = (d.data()['phone'] as String? ?? '').toLowerCase();
            return name.contains(_searchQuery) ||
                email.contains(_searchQuery) ||
                phone.contains(_searchQuery);
          }).toList();
        }

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 72,
                  color: scheme.primary.withValues(alpha: .4),
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'No matching clients'
                      : 'No Clients Yet',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Import from past jobs or add manually.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final doc = docs[i];
            final data = doc.data();
            return _ClientCard(
              id: doc.id,
              data: data,
              onEdit: () => _showAddEditSheet(context, id: doc.id, data: data),
              onFollowUp: () =>
                  _showFollowUpSheet(context, doc.id, data['name'] ?? ''),
              onViewHistory: () => _showJobHistory(
                context,
                data['homeownerId'] as String?,
                data['name'] ?? 'Client',
              ),
            );
          },
        );
      },
    );
  }

  void _showAddEditSheet(
    BuildContext context, {
    String? id,
    Map<String, dynamic>? data,
  }) {
    final nameCtrl = TextEditingController(text: data?['name'] ?? '');
    final emailCtrl = TextEditingController(text: data?['email'] ?? '');
    final phoneCtrl = TextEditingController(text: data?['phone'] ?? '');
    final addressCtrl = TextEditingController(text: data?['address'] ?? '');
    final notesCtrl = TextEditingController(text: data?['notes'] ?? '');
    final tagCtrl = TextEditingController();
    List<String> tags = ((data?['tags'] as List?) ?? []).cast<String>();

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
                      id == null ? 'Add Client' : 'Edit Client',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _field(ctx, nameCtrl, 'Full name', Icons.person),
                    const SizedBox(height: 12),
                    _field(
                      ctx,
                      emailCtrl,
                      'Email',
                      Icons.email,
                      type: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      ctx,
                      phoneCtrl,
                      'Phone',
                      Icons.phone,
                      type: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    _field(ctx, addressCtrl, 'Address', Icons.location_on),
                    const SizedBox(height: 12),
                    _field(ctx, notesCtrl, 'Notes', Icons.note, maxLines: 2),
                    const SizedBox(height: 12),
                    Text(
                      'Tags',
                      style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: tags
                          .map(
                            (t) => Chip(
                              label: Text(t),
                              onDeleted: () =>
                                  setSheetState(() => tags.remove(t)),
                            ),
                          )
                          .toList(),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _field(ctx, tagCtrl, 'Add tag', Icons.label),
                        ),
                        IconButton.filled(
                          onPressed: () {
                            final t = tagCtrl.text.trim();
                            if (t.isEmpty) return;
                            setSheetState(() => tags.add(t));
                            tagCtrl.clear();
                          },
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Name is required')),
                            );
                            return;
                          }
                          Navigator.pop(ctx);
                          HapticFeedback.mediumImpact();
                          try {
                            if (id == null) {
                              await CustomerCrmService.instance.addClient(
                                name: name,
                                email: emailCtrl.text.trim().isEmpty
                                    ? null
                                    : emailCtrl.text.trim(),
                                phone: phoneCtrl.text.trim().isEmpty
                                    ? null
                                    : phoneCtrl.text.trim(),
                                address: addressCtrl.text.trim().isEmpty
                                    ? null
                                    : addressCtrl.text.trim(),
                                notes: notesCtrl.text.trim().isEmpty
                                    ? null
                                    : notesCtrl.text.trim(),
                                tags: tags,
                              );
                            } else {
                              await CustomerCrmService.instance
                                  .updateClient(id, {
                                    'name': name,
                                    'email': emailCtrl.text.trim().isEmpty
                                        ? null
                                        : emailCtrl.text.trim(),
                                    'phone': phoneCtrl.text.trim().isEmpty
                                        ? null
                                        : phoneCtrl.text.trim(),
                                    'address': addressCtrl.text.trim().isEmpty
                                        ? null
                                        : addressCtrl.text.trim(),
                                    'notes': notesCtrl.text.trim().isEmpty
                                        ? null
                                        : notesCtrl.text.trim(),
                                    'tags': tags,
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
                        label: Text(id == null ? 'Add Client' : 'Save'),
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

  void _showFollowUpSheet(BuildContext context, String clientId, String name) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));
    final noteCtrl = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set Follow-Up — $name',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: Text(DateFormat.yMMMd().format(selectedDate)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setSheetState(() => selectedDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _field(
                    ctx,
                    noteCtrl,
                    'Reminder note',
                    Icons.note,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await CustomerCrmService.instance.setFollowUp(
                          clientId,
                          selectedDate,
                          noteCtrl.text.trim(),
                        );
                        _loadFollowUps();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Follow-up set for ${DateFormat.yMMMd().format(selectedDate)}',
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.alarm),
                      label: const Text('Set Reminder'),
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

  void _showJobHistory(
    BuildContext context,
    String? homeownerId,
    String name,
  ) async {
    if (homeownerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No linked homeowner account')),
      );
      return;
    }

    final jobs = await CustomerCrmService.instance.getClientJobHistory(
      homeownerId,
    );
    if (!context.mounted) return;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (ctx, scrollCtrl) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Job History — $name',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: jobs.isEmpty
                        ? const Center(child: Text('No job history'))
                        : ListView.separated(
                            controller: scrollCtrl,
                            itemCount: jobs.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final job = jobs[i];
                              final date = (job['createdAt'] as Timestamp?)
                                  ?.toDate();
                              final amount = (job['price'] as num?)?.toDouble();
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  child: Icon(
                                    _serviceIcon(
                                      job['serviceType'] as String? ?? '',
                                    ),
                                  ),
                                ),
                                title: Text(
                                  job['serviceType'] ?? 'Job',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  '${date != null ? DateFormat.yMMMd().format(date) : ''}'
                                  ' • ${job['status'] ?? ''}',
                                ),
                                trailing: amount != null
                                    ? Text(
                                        '\$${amount.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      )
                                    : null,
                              );
                            },
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

  void _importClients() async {
    final messenger = ScaffoldMessenger.of(context);
    final count = await CustomerCrmService.instance.importFromJobs();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          count > 0
              ? '$count client${count == 1 ? '' : 's'} imported from past jobs'
              : 'No new clients to import',
        ),
      ),
    );
  }

  IconData _serviceIcon(String service) {
    final s = service.toLowerCase();
    if (s.contains('paint')) return Icons.format_paint;
    if (s.contains('drywall')) return Icons.construction;
    if (s.contains('pressure') || s.contains('wash')) return Icons.water;
    if (s.contains('cabinet')) return Icons.kitchen;
    return Icons.home_repair_service;
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

// ─── Client card ─────────────────────────────────────────────────
class _ClientCard extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onFollowUp;
  final VoidCallback onViewHistory;

  const _ClientCard({
    required this.id,
    required this.data,
    required this.onEdit,
    required this.onFollowUp,
    required this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = data['name'] ?? 'Unknown';
    final phone = data['phone'] as String?;
    final email = data['email'] as String?;
    final totalSpent = (data['totalSpent'] as num?)?.toDouble() ?? 0;
    final jobCount = (data['jobCount'] as num?)?.toInt() ?? 0;
    final tags = (data['tags'] as List?)?.cast<String>() ?? [];
    final followUp = (data['followUpDate'] as Timestamp?)?.toDate();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (phone != null || email != null)
                        Text(
                          [
                            if (phone != null) phone,
                            if (email != null) email,
                          ].join(' • '),
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (followUp != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: followUp.isBefore(DateTime.now())
                          ? Colors.red.withValues(alpha: .1)
                          : Colors.orange.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.alarm,
                          size: 12,
                          color: followUp.isBefore(DateTime.now())
                              ? Colors.red
                              : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat.MMMd().format(followUp),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: followUp.isBefore(DateTime.now())
                                ? Colors.red
                                : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _stat(
                  Icons.attach_money,
                  '\$${totalSpent.toStringAsFixed(0)} total',
                ),
                const SizedBox(width: 16),
                _stat(Icons.task_alt, '$jobCount jobs'),
              ],
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: tags
                    .map(
                      (t) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer.withValues(
                            alpha: .5,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          t,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onViewHistory,
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('History'),
                ),
                TextButton.icon(
                  onPressed: onFollowUp,
                  icon: const Icon(Icons.alarm, size: 18),
                  label: const Text('Follow-up'),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Edit',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
