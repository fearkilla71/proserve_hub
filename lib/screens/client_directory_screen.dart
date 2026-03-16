import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/client_model.dart';
import '../services/client_directory_service.dart';
import '../utils/app_error_handler.dart';

/// Full-screen Client Directory — contractors can add, edit, search,
/// and delete saved clients.
class ClientDirectoryScreen extends StatefulWidget {
  /// If true, tapping a client returns it via Navigator.pop instead of editing.
  final bool pickMode;

  const ClientDirectoryScreen({super.key, this.pickMode = false});

  @override
  State<ClientDirectoryScreen> createState() => _ClientDirectoryScreenState();
}

class _ClientDirectoryScreenState extends State<ClientDirectoryScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in to view clients.')),
      );
    }

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pickMode ? 'Select Client' : 'Client Directory'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search clients…',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: scheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add),
        label: const Text('Add Client'),
        onPressed: () => _showClientEditor(context),
      ),
      body: StreamBuilder<List<SavedClient>>(
        stream: ClientDirectoryService.clientsStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data ?? [];
          final q = _search.trim().toLowerCase();
          final filtered = q.isEmpty
              ? all
              : all
                    .where(
                      (c) =>
                          c.name.toLowerCase().contains(q) ||
                          c.email.toLowerCase().contains(q) ||
                          c.phone.contains(q),
                    )
                    .toList();

          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline, size: 64, color: scheme.outline),
                  const SizedBox(height: 12),
                  Text(
                    all.isEmpty ? 'No clients yet' : 'No matches',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    all.isEmpty
                        ? 'Tap + to add your first client'
                        : 'Try a different search',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final client = filtered[i];
              return _ClientTile(
                client: client,
                onTap: () {
                  if (widget.pickMode) {
                    Navigator.pop(context, client);
                  } else {
                    _showClientEditor(context, existing: client);
                  }
                },
                onDelete: widget.pickMode
                    ? null
                    : () => _confirmDelete(context, client),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showClientEditor(
    BuildContext context, {
    SavedClient? existing,
  }) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final email = TextEditingController(text: existing?.email ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final address = TextEditingController(text: existing?.address ?? '');
    final notes = TextEditingController(text: existing?.notes ?? '');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      existing == null ? 'New Client' : 'Edit Client',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Client name *',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: address,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notes,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    prefixIcon: Icon(Icons.notes),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.save),
                    label: Text(existing == null ? 'Save Client' : 'Update'),
                    onPressed: () {
                      if (name.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Name is required')),
                        );
                        return;
                      }
                      Navigator.pop(ctx, true);
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );

    if (saved != true) return;

    try {
      if (existing != null) {
        await ClientDirectoryService.update(
          existing.id,
          name: name.text,
          email: email.text,
          phone: phone.text,
          address: address.text,
          notes: notes.text,
        );
      } else {
        await ClientDirectoryService.add(
          name: name.text,
          email: email.text,
          phone: phone.text,
          address: address.text,
          notes: notes.text,
        );
      }
    } catch (e, st) {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      AppError.show(context, e, st, action: 'save client');
    }
  }

  Future<void> _confirmDelete(BuildContext context, SavedClient client) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Client?'),
        content: Text('Remove "${client.name}" from your directory?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    try {
      await ClientDirectoryService.delete(client.id);
    } catch (e, st) {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      AppError.show(context, e, st, action: 'delete client');
    }
  }
}

class _ClientTile extends StatelessWidget {
  final SavedClient client;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _ClientTile({required this.client, required this.onTap, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Text(
            client.name.isNotEmpty ? client.name[0].toUpperCase() : '?',
            style: TextStyle(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          client.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          [
            if (client.email.isNotEmpty) client.email,
            if (client.phone.isNotEmpty) client.phone,
          ].join(' • '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: onDelete != null
            ? IconButton(
                icon: Icon(Icons.delete_outline, color: scheme.error),
                onPressed: onDelete,
              )
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
