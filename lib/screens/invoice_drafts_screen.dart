import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/invoice_models.dart';

/// Browse, open, and delete past invoice drafts stored in
/// `users/{uid}/invoice_drafts`.
class InvoiceDraftsScreen extends StatefulWidget {
  const InvoiceDraftsScreen({super.key});

  @override
  State<InvoiceDraftsScreen> createState() => _InvoiceDraftsScreenState();
}

class _InvoiceDraftsScreenState extends State<InvoiceDraftsScreen> {
  String _search = '';
  String _statusFilter = 'all';
  final Set<String> _selected = {};
  bool _selectMode = false;

  static const _statusOptions = [
    'all',
    'draft',
    'sent',
    'viewed',
    'paid',
    'overdue',
  ];

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return const Color(0xFF22C55E);
      case 'sent':
        return const Color(0xFF3B82F6);
      case 'viewed':
        return const Color(0xFF8B5CF6);
      case 'overdue':
        return const Color(0xFFEF4444);
      case 'draft':
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  String _statusLabel(String status) {
    return status[0].toUpperCase() + status.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in to view invoices.')),
      );
    }

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: _selectMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _selectMode = false;
                  _selected.clear();
                }),
              )
            : null,
        title: _selectMode
            ? Text('${_selected.length} selected')
            : const Text('Invoices'),
        actions: _selectMode
            ? [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Change status',
                  onPressed: _selected.isEmpty
                      ? null
                      : () => _batchStatusSheet(context),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete selected',
                  onPressed: _selected.isEmpty
                      ? null
                      : () => _batchDelete(context),
                ),
              ]
            : null,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by client, job, or invoice #…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (v) =>
                      setState(() => _search = v.trim().toLowerCase()),
                ),
              ),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: _statusOptions.map((s) {
                    final active = _statusFilter == s;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        label: Text(s == 'all' ? 'All' : _statusLabel(s)),
                        selected: active,
                        onSelected: (_) => setState(() => _statusFilter = s),
                        selectedColor: _statusColor(s).withValues(alpha: 0.2),
                        showCheckmark: false,
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/invoice-maker'),
        icon: const Icon(Icons.add),
        label: const Text('New Invoice'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('invoice_drafts')
            .orderBy('updatedAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: scheme.outline,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No invoices yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => context.push('/invoice-maker'),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Invoice'),
                  ),
                ],
              ),
            );
          }

          // Filter docs.
          final filtered = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final status = (data['status'] ?? 'draft').toString().toLowerCase();
            if (_statusFilter != 'all' && status != _statusFilter) return false;

            if (_search.isNotEmpty) {
              final draftMap = data['draft'] as Map<String, dynamic>? ?? {};
              final searchable = [
                draftMap['clientName'] ?? '',
                draftMap['clientEmail'] ?? '',
                draftMap['jobTitle'] ?? '',
                draftMap['invoiceNumber'] ?? '',
                doc.id,
              ].join(' ').toLowerCase();
              if (!searchable.contains(_search)) return false;
            }
            return true;
          }).toList();

          if (filtered.isEmpty) {
            return Center(
              child: Text(
                'No matching invoices.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = filtered[index];
              final data = doc.data() as Map<String, dynamic>? ?? {};
              final draftMap = data['draft'] as Map<String, dynamic>? ?? {};
              final status = (data['status'] ?? 'draft')
                  .toString()
                  .toLowerCase();
              final clientName = (draftMap['clientName'] ?? '').toString();
              final jobTitle = (draftMap['jobTitle'] ?? '').toString();
              final invoiceNumber = (draftMap['invoiceNumber'] ?? doc.id)
                  .toString();
              final subtotal =
                  (draftMap['subtotal'] as num?)?.toDouble() ?? 0.0;

              String dateStr = '';
              final updatedAt = data['updatedAt'];
              if (updatedAt is Timestamp) {
                dateStr = DateFormat.yMMMd().format(updatedAt.toDate());
              } else {
                final createdAt = data['createdAt'];
                if (createdAt is Timestamp) {
                  dateStr = DateFormat.yMMMd().format(createdAt.toDate());
                }
              }

              return Dismissible(
                key: ValueKey(doc.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (_) async {
                  return await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete invoice?'),
                          content: Text(
                            'Delete $invoiceNumber? This cannot be undone.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      ) ??
                      false;
                },
                onDismissed: (_) async {
                  try {
                    await doc.reference.delete();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Deleted $invoiceNumber')),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Delete failed: $e')),
                    );
                  }
                },
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: scheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _selectMode
                        ? () => setState(() {
                            if (_selected.contains(doc.id)) {
                              _selected.remove(doc.id);
                              if (_selected.isEmpty) _selectMode = false;
                            } else {
                              _selected.add(doc.id);
                            }
                          })
                        : () => _openDraft(context, doc),
                    onLongPress: _selectMode
                        ? null
                        : () => setState(() {
                            _selectMode = true;
                            _selected.add(doc.id);
                          }),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          if (_selectMode) ...[
                            Checkbox(
                              value: _selected.contains(doc.id),
                              onChanged: (v) => setState(() {
                                if (v == true) {
                                  _selected.add(doc.id);
                                } else {
                                  _selected.remove(doc.id);
                                  if (_selected.isEmpty) _selectMode = false;
                                }
                              }),
                            ),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _statusColor(
                                          status,
                                        ).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _statusLabel(status),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: _statusColor(status),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        invoiceNumber,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                            ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  clientName.isNotEmpty
                                      ? clientName
                                      : 'No client',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                if (jobTitle.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      jobTitle,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                if (dateStr.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      dateStr,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: scheme.outline),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '\$${subtotal.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _batchDelete(BuildContext context) async {
    final count = _selected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $count invoice${count == 1 ? '' : 's'}?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final id in _selected) {
      batch.delete(
        FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('invoice_drafts')
            .doc(id),
      );
    }
    try {
      await batch.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted $count invoice${count == 1 ? '' : 's'}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
    setState(() {
      _selected.clear();
      _selectMode = false;
    });
  }

  void _batchStatusSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Set status for ${_selected.length} invoice${_selected.length == 1 ? '' : 's'}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const Divider(height: 1),
              ..._statusOptions.where((s) => s != 'all').map((s) {
                return ListTile(
                  leading: Icon(Icons.circle, color: _statusColor(s), size: 14),
                  title: Text(_statusLabel(s)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    if (uid == null) return;
                    final batch = FirebaseFirestore.instance.batch();
                    for (final id in _selected) {
                      batch.update(
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .collection('invoice_drafts')
                            .doc(id),
                        {
                          'status': s,
                          'updatedAt': FieldValue.serverTimestamp(),
                        },
                      );
                    }
                    try {
                      await batch.commit();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${_selected.length} → ${_statusLabel(s)}',
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Update failed: $e')),
                      );
                    }
                    setState(() {
                      _selected.clear();
                      _selectMode = false;
                    });
                  },
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _openDraft(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final draftMap = data['draft'] as Map<String, dynamic>? ?? {};
    final draft = InvoiceDraft.fromJson(draftMap);
    context.push('/invoice-maker', extra: {'initialDraft': draft});
  }
}
