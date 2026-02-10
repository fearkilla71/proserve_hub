import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/favorites_service.dart';
import 'recommended_contractors_page.dart';

/// Shows the customer's saved / favorite contractors.
class FavoriteContractorsScreen extends StatelessWidget {
  const FavoriteContractorsScreen({super.key});

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

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: favIds.length,
            itemBuilder: (context, index) {
              final contractorId = favIds.elementAt(index);

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('contractors')
                    .doc(contractorId)
                    .get(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const SizedBox(
                      height: 80,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final data = snap.data?.data() as Map<String, dynamic>?;
                  if (data == null) return const SizedBox.shrink();

                  final displayName =
                      (data['businessName'] as String?)?.trim().isNotEmpty ==
                          true
                      ? data['businessName'] as String
                      : (data['companyName'] as String?)?.trim().isNotEmpty ==
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
                            ? NetworkImage(profileImage)
                            : null,
                        child: profileImage == null
                            ? Text(
                                displayName.isNotEmpty ? displayName[0] : '?',
                              )
                            : null,
                      ),
                      title: Text(
                        displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
                          await FavoritesService.instance.remove(contractorId);
                        },
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ContractorProfilePage(
                              contractorId: contractorId,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
