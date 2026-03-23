import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/proserve_theme.dart';
import '../widgets/skeleton_loader.dart';

/// Saved Project Boards — customers save future projects with photos, notes,
/// and pinned contractors for later booking.
class SavedProjectBoardsScreen extends StatefulWidget {
  final String? highlightBoardId;
  const SavedProjectBoardsScreen({super.key, this.highlightBoardId});

  @override
  State<SavedProjectBoardsScreen> createState() =>
      _SavedProjectBoardsScreenState();
}

class _SavedProjectBoardsScreenState extends State<SavedProjectBoardsScreen> {
  String _search = '';
  String _serviceFilter = 'all';

  static const _serviceOptions = {
    'all': 'All',
    'interior_painting': 'Interior',
    'exterior_painting': 'Exterior',
    'drywall_repair': 'Drywall',
    'pressure_washing': 'Pressure Wash',
    'cabinets': 'Cabinets',
    'roofing': 'Roofing',
    'flooring': 'Flooring',
    'plumbing': 'Plumbing',
    'electrical': 'Electrical',
  };

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Saved Projects')),
        body: const Center(child: Text('Please sign in to view projects.')),
      );
    }

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Projects'),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(90),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search projects…',
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
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: _serviceOptions.entries.map((e) {
                    final active = _serviceFilter == e.key;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        label: Text(e.value),
                        selected: active,
                        onSelected: (_) =>
                            setState(() => _serviceFilter = e.key),
                        showCheckmark: false,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateBoard(context, uid),
        icon: const Icon(Icons.add),
        label: const Text('New Project'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('project_boards')
            .orderBy('updatedAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 3,
              itemBuilder: (_, _) => _BoardCardSkeleton(),
            );
          }

          if (snap.hasError) {
            return Center(
              child: Text(
                'Could not load projects.',
                style: TextStyle(color: ProServeColors.muted),
              ),
            );
          }

          final allBoards = snap.data?.docs ?? [];

          if (allBoards.isEmpty) return _buildEmptyState(context, uid);

          // Client-side search + service filter.
          final boards = allBoards.where((doc) {
            final data = doc.data();
            if (_serviceFilter != 'all') {
              final svc =
                  (data['service'] ?? '').toString().toLowerCase();
              if (svc != _serviceFilter) return false;
            }
            if (_search.isNotEmpty) {
              final searchable = [
                data['name'] ?? '',
                data['service'] ?? '',
                data['notes'] ?? '',
              ].join(' ').toLowerCase();
              if (!searchable.contains(_search)) return false;
            }
            return true;
          }).toList();

          if (boards.isEmpty) {
            return Center(
              child: Text(
                'No matching projects.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: boards.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final data = boards[i].data();
              return _BoardCard(
                boardId: boards[i].id,
                userId: uid,
                data: data,
                highlight: boards[i].id == widget.highlightBoardId,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String uid) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.dashboard_customize_outlined,
              size: 64,
              color: ProServeColors.accent2,
            ),
            const SizedBox(height: 16),
            Text(
              'No projects yet',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Save future project ideas with photos, notes, and your favorite contractors.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _showCreateBoard(context, uid),
              icon: const Icon(Icons.add),
              label: const Text('Create First Project'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateBoard(BuildContext context, String uid) {
    final nameCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String? selectedService;

    const services = {
      'interior_painting': 'Interior Painting',
      'exterior_painting': 'Exterior Painting',
      'drywall_repair': 'Drywall Repair',
      'pressure_washing': 'Pressure Washing',
      'cabinets': 'Cabinet Painting',
      'roofing': 'Roofing',
      'flooring': 'Flooring',
      'plumbing': 'Plumbing',
      'electrical': 'Electrical',
    };

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
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
                    'New Project Board',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Project Name',
                      hintText: 'e.g. Kitchen Remodel 2025',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: services.entries.map((e) {
                      final sel = selectedService == e.key;
                      return ChoiceChip(
                        label: Text(e.value),
                        selected: sel,
                        onSelected: (_) =>
                            setLocal(() => selectedService = e.key),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      hintText: 'Budget, timeline, inspiration...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) return;
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .collection('project_boards')
                            .add({
                              'name': name,
                              'service': selectedService ?? '',
                              'notes': notesCtrl.text.trim(),
                              'photos': <String>[],
                              'savedContractors': <String>[],
                              'createdAt': FieldValue.serverTimestamp(),
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Create Board'),
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

class _BoardCard extends StatelessWidget {
  final String boardId;
  final String userId;
  final Map<String, dynamic> data;
  final bool highlight;

  const _BoardCard({
    required this.boardId,
    required this.userId,
    required this.data,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? 'Untitled Project';
    final service = data['service'] as String? ?? '';
    final notes = data['notes'] as String? ?? '';
    final photos = (data['photos'] as List<dynamic>?)?.cast<String>() ?? [];
    final savedPros =
        (data['savedContractors'] as List<dynamic>?)?.cast<String>() ?? [];

    return Container(
      decoration: BoxDecoration(
        color: ProServeColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight ? ProServeColors.accent2 : ProServeColors.line,
          width: highlight ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo strip
          if (photos.isNotEmpty)
            SizedBox(
              height: 100,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: photos.length,
                  itemBuilder: (ctx, i) {
                    return Image.network(
                      photos[i],
                      width: 120,
                      height: 100,
                      fit: BoxFit.cover,
                      semanticLabel: 'Project photo ${i + 1}',
                      errorBuilder: (_, _, _) => Container(
                        width: 120,
                        height: 100,
                        color: ProServeColors.card,
                        child: Icon(
                          Icons.broken_image,
                          color: ProServeColors.muted,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'delete') {
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(userId)
                              .collection('project_boards')
                              .doc(boardId)
                              .delete();
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ],
                    ),
                  ],
                ),
                if (service.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: ProServeColors.accent2.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      service.replaceAll('_', ' '),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: ProServeColors.accent2,
                      ),
                    ),
                  ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    notes,
                    style: TextStyle(color: ProServeColors.muted, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    _MiniStat(
                      icon: Icons.photo_library,
                      label: '${photos.length} photos',
                    ),
                    const SizedBox(width: 12),
                    _MiniStat(
                      icon: Icons.person,
                      label: '${savedPros.length} pros',
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => _addPhoto(context),
                      icon: Icon(
                        Icons.add_a_photo,
                        size: 20,
                        color: ProServeColors.accent2,
                      ),
                      tooltip: 'Add photo',
                    ),
                    FilledButton.tonal(
                      onPressed: () {
                        context.push(
                          '/smart-request',
                          extra: {'serviceType': service, 'serviceName': name},
                        );
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 34),
                      ),
                      child: const Text(
                        'Start Request',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
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
  }

  Future<void> _addPhoto(BuildContext context) async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (photo == null) return;

    final bytes = await photo.readAsBytes();
    final compressed = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 1920,
      minHeight: 1920,
      quality: 85,
    );

    final path =
        'project_board_photos/$userId/$boardId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance.ref(path);
    await ref.putData(Uint8List.fromList(compressed));
    final url = await ref.getDownloadURL();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('project_boards')
        .doc(boardId)
        .update({
          'photos': FieldValue.arrayUnion([url]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniStat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: ProServeColors.muted),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: ProServeColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _BoardCardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonLoader(
              width: 180,
              height: 18,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 12),
            SkeletonLoader(
              width: 120,
              height: 14,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 12),
            SkeletonLoader(
              width: double.infinity,
              height: 100,
              borderRadius: BorderRadius.circular(12),
            ),
          ],
        ),
      ),
    );
  }
}
