import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

import '../services/favorites_service.dart';

/// Shows the customer's saved / favorite contractors.
class FavoriteContractorsScreen extends StatefulWidget {
  const FavoriteContractorsScreen({super.key});

  @override
  State<FavoriteContractorsScreen> createState() =>
      _FavoriteContractorsScreenState();
}

class _FavoriteContractorsScreenState extends State<FavoriteContractorsScreen> {
  final _searchController = TextEditingController();
  String _search = '';
  final Map<String, Map<String, dynamic>> _contractorCache = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Batch-fetch all contractor docs for the given IDs.
  Future<Map<String, Map<String, dynamic>>> _batchLoadContractors(
    Set<String> ids,
  ) async {
    final toFetch = ids
        .where((id) => !_contractorCache.containsKey(id))
        .toSet()
        .toList();
    if (toFetch.isEmpty) return _contractorCache;
    final db = FirebaseFirestore.instance;
    for (var i = 0; i < toFetch.length; i += 10) {
      final chunk = toFetch.sublist(i, (i + 10).clamp(0, toFetch.length));
      final snap = await db
          .collection('contractors')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        _contractorCache[doc.id] = doc.data();
      }
    }
    return _contractorCache;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Saved Contractors')),
      body: StreamBuilder<Set<String>>(
        stream: FavoritesService.instance.watchFavorites(),
        builder: (context, favSnap) {
          if (favSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final favIds = favSnap.data ?? {};

          if (favIds.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 64,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No saved contractors yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the heart icon on any contractor to save them here.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return FutureBuilder<Map<String, Map<String, dynamic>>>(
            future: _batchLoadContractors(favIds),
            builder: (context, cacheSnap) {
              final cache = cacheSnap.data ?? _contractorCache;

              // Filter by search query.
              final filteredIds = favIds.where((id) {
                if (_search.isEmpty) return true;
                final data = cache[id];
                if (data == null) return false;
                final name =
                    (data['businessName'] ??
                            data['companyName'] ??
                            data['name'] ??
                            '')
                        .toString()
                        .toLowerCase();
                return name.contains(_search.toLowerCase());
              }).toList();

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search saved contractors…',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  ),
                  if (filteredIds.isEmpty && _search.isNotEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          'No results for "$_search"',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredIds.length,
                        itemBuilder: (context, index) {
                          final contractorId = filteredIds[index];
                          final data = cache[contractorId];
                          if (data == null) return const SizedBox.shrink();

                          final displayName =
                              (data['businessName'] as String?)
                                      ?.trim()
                                      .isNotEmpty ==
                                  true
                              ? data['businessName'] as String
                              : (data['companyName'] as String?)
                                        ?.trim()
                                        .isNotEmpty ==
                                    true
                              ? data['companyName'] as String
                              : (data['name'] as String?) ?? 'Unknown';
                          final location = data['location'] as String? ?? '';
                          final rating =
                              (data['averageRating'] as num?)?.toDouble() ?? 0;
                          final profileImage = data['profileImage'] as String?;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                radius: 28,
                                backgroundColor: scheme.primaryContainer,
                                backgroundImage: profileImage != null
                                    ? CachedNetworkImageProvider(profileImage)
                                    : null,
                                child: profileImage == null
                                    ? Text(
                                        displayName.isNotEmpty
                                            ? displayName[0]
                                            : '?',
                                      )
                                    : null,
                              ),
                              title: Text(
                                displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (location.isNotEmpty) Text(location),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.star,
                                        size: 16,
                                        color: Colors.amber[700],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(rating.toStringAsFixed(1)),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                tooltip: 'Remove from favorites',
                                icon: Icon(Icons.favorite, color: scheme.error),
                                onPressed: () async {
                                  await FavoritesService.instance.remove(
                                    contractorId,
                                  );
                                  _contractorCache.remove(contractorId);
                                },
                              ),
                              onTap: () {
                                context.push('/contractor/$contractorId');
                              },
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
