import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Render Gallery — browse, search, and share persisted AI renders.
///
/// Reads from `users/{uid}/render_history` ordered by `createdAt` desc.
/// Supports:
/// - Room/label grouping
/// - Full-screen preview with share/export
/// - Delete with confirmation
/// - Label editing (room name)
class RenderGalleryScreen extends StatefulWidget {
  const RenderGalleryScreen({super.key});

  @override
  State<RenderGalleryScreen> createState() => _RenderGalleryScreenState();
}

class _RenderGalleryScreenState extends State<RenderGalleryScreen> {
  String _searchQuery = '';
  String _filterLabel = 'All';

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _col {
    final uid = _uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('render_history');
  }

  @override
  Widget build(BuildContext context) {
    final col = _col;
    if (col == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Render Gallery')),
        body: const Center(child: Text('Sign in to view saved renders.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Render Gallery'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                hintText: 'Search renders…',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) =>
                  setState(() => _searchQuery = v.trim().toLowerCase()),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'newRender',
        onPressed: () => context.push('/render-tool'),
        child: const Icon(Icons.add_a_photo),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: col.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 56,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No saved renders yet.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => context.push('/render-tool'),
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('Create a render'),
                  ),
                ],
              ),
            );
          }

          // Collect unique labels for the filter chips.
          final allLabels = <String>{'All'};
          for (final d in docs) {
            final label = (d.data()['roomLabel'] as String?) ?? 'Render';
            allLabels.add(label);
          }

          // Filter docs.
          final filtered = docs.where((d) {
            final data = d.data();
            final label = ((data['roomLabel'] as String?) ?? 'Render')
                .toLowerCase();
            final prompt = ((data['prompt'] as String?) ?? '').toLowerCase();
            final matchesSearch =
                _searchQuery.isEmpty ||
                label.contains(_searchQuery) ||
                prompt.contains(_searchQuery);
            final matchesFilter =
                _filterLabel == 'All' ||
                (data['roomLabel'] as String?) == _filterLabel;
            return matchesSearch && matchesFilter;
          }).toList();

          return Column(
            children: [
              // Label filter chips
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  itemCount: allLabels.length,
                  separatorBuilder: (c, i) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final label = allLabels.elementAt(i);
                    final selected = label == _filterLabel;
                    return FilterChip(
                      label: Text(label),
                      selected: selected,
                      onSelected: (_) => setState(() => _filterLabel = label),
                    );
                  },
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No matching renders.'))
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 0.85,
                            ),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final doc = filtered[i];
                          final data = doc.data();
                          return _RenderCard(
                            docId: doc.id,
                            imageUrl: data['imageUrl'] as String? ?? '',
                            roomLabel:
                                (data['roomLabel'] as String?) ?? 'Render',
                            prompt: data['prompt'] as String?,
                            wallColor: data['wallColor'] as String?,
                            createdAt: data['createdAt'] as Timestamp?,
                            storagePath: data['storagePath'] as String?,
                            col: col,
                            onLabelChanged: () => setState(() {}),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RenderCard extends StatelessWidget {
  final String docId;
  final String imageUrl;
  final String roomLabel;
  final String? prompt;
  final String? wallColor;
  final Timestamp? createdAt;
  final String? storagePath;
  final CollectionReference<Map<String, dynamic>> col;
  final VoidCallback onLabelChanged;

  const _RenderCard({
    required this.docId,
    required this.imageUrl,
    required this.roomLabel,
    required this.prompt,
    required this.wallColor,
    required this.createdAt,
    required this.storagePath,
    required this.col,
    required this.onLabelChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ts = createdAt?.toDate();
    final dateStr = ts != null ? '${ts.month}/${ts.day}/${ts.year}' : '';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openFullScreen(context),
        onLongPress: () => _showOptionsSheet(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) =>
                          const Center(child: Icon(Icons.broken_image)),
                    )
                  : const Center(child: Icon(Icons.image_not_supported)),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    roomLabel,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (dateStr.isNotEmpty)
                    Text(
                      dateStr,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFullScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullScreenRenderPage(
          imageUrl: imageUrl,
          roomLabel: roomLabel,
          prompt: prompt,
          wallColor: wallColor,
        ),
      ),
    );
  }

  Future<void> _showOptionsSheet(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit label'),
                onTap: () => Navigator.pop(ctx, 'edit'),
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share'),
                onTap: () => Navigator.pop(ctx, 'share'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case 'edit':
        await _editLabel(context);
      case 'share':
        await _shareRender(context);
      case 'delete':
        await _confirmDelete(context);
    }
  }

  Future<void> _editLabel(BuildContext context) async {
    final ctrl = TextEditingController(text: roomLabel);
    final newLabel = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Room / Label'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'e.g. Living Room, Kitchen',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    ctrl.dispose();
    if (newLabel == null || newLabel.isEmpty || !context.mounted) return;
    await col.doc(docId).update({'roomLabel': newLabel});
    onLabelChanged();
  }

  Future<void> _shareRender(BuildContext context) async {
    if (kIsWeb || imageUrl.isEmpty) return;
    try {
      final ref = FirebaseStorage.instance.refFromURL(imageUrl);
      final data = await ref.getData();
      if (data == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/render_$docId.jpg');
      await file.writeAsBytes(data, flush: true);
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'ProServe Render — $roomLabel');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Share failed: $e')));
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete render?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      // Delete storage file.
      if (storagePath != null && storagePath!.isNotEmpty) {
        await FirebaseStorage.instance.ref(storagePath!).delete();
      }
      await col.doc(docId).delete();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }
}

class _FullScreenRenderPage extends StatelessWidget {
  final String imageUrl;
  final String roomLabel;
  final String? prompt;
  final String? wallColor;

  const _FullScreenRenderPage({
    required this.imageUrl,
    required this.roomLabel,
    this.prompt,
    this.wallColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(roomLabel),
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: imageUrl.isNotEmpty
                    ? Image.network(imageUrl, fit: BoxFit.contain)
                    : const Icon(
                        Icons.image_not_supported,
                        color: Colors.white54,
                        size: 64,
                      ),
              ),
            ),
          ),
          if (prompt != null && prompt!.isNotEmpty)
            Container(
              width: double.infinity,
              color: const Color(0xDD000000),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Prompt',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    prompt!,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
