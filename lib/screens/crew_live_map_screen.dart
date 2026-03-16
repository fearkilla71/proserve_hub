import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CrewLiveMapScreen extends StatelessWidget {
  const CrewLiveMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    final crewStream = FirebaseFirestore.instance
        .collection('contractors')
        .doc(uid)
        .collection('crew')
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Live Crew Map')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: crewStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data?.docs ?? [];
          final liveCrew = docs.where((d) {
            final data = d.data();
            final onShift = (data['onShift'] as bool?) == true;
            final share = (data['locationSharingEnabled'] as bool?) == true;
            final lastLocation = data['lastLocation'] as Map<String, dynamic>?;
            final hasCoords =
                (lastLocation?['lat'] is num) && (lastLocation?['lng'] is num);
            return onShift && share && hasCoords;
          }).toList();

          if (liveCrew.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No crew members are sharing live location right now.\n\n'
                  'Crew members must enable location sharing and start shift.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final points = liveCrew.map((d) {
            final data = d.data();
            final loc = data['lastLocation'] as Map<String, dynamic>;
            final lat = (loc['lat'] as num).toDouble();
            final lng = (loc['lng'] as num).toDouble();
            return {
              'name': (data['name'] as String?)?.trim().isNotEmpty == true
                  ? (data['name'] as String).trim()
                  : 'Crew Member',
              'role': (data['role'] as String?)?.trim() ?? 'Crew Member',
              'lat': lat,
              'lng': lng,
              'updatedAt': loc['updatedAt'],
            };
          }).toList();

          final minLat = points
              .map((p) => p['lat'] as double)
              .reduce((a, b) => a < b ? a : b);
          final maxLat = points
              .map((p) => p['lat'] as double)
              .reduce((a, b) => a > b ? a : b);
          final minLng = points
              .map((p) => p['lng'] as double)
              .reduce((a, b) => a < b ? a : b);
          final maxLng = points
              .map((p) => p['lng'] as double)
              .reduce((a, b) => a > b ? a : b);

          final latSpan = (maxLat - minLat).abs() < 0.0001
              ? 0.0001
              : (maxLat - minLat).abs();
          final lngSpan = (maxLng - minLng).abs() < 0.0001
              ? 0.0001
              : (maxLng - minLng).abs();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Live view (${liveCrew.length})',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              AspectRatio(
                aspectRatio: 1.25,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final height = constraints.maxHeight;

                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                      ),
                      child: Stack(
                        children: [
                          const Positioned(
                            top: 10,
                            left: 12,
                            child: Text('Approximate crew map'),
                          ),
                          ...points.map((p) {
                            final lat = p['lat'] as double;
                            final lng = p['lng'] as double;
                            final x = ((lng - minLng) / lngSpan).clamp(
                              0.04,
                              0.96,
                            );
                            final y = ((maxLat - lat) / latSpan).clamp(
                              0.08,
                              0.96,
                            );

                            return Positioned(
                              left: x * width,
                              top: y * height,
                              child: Tooltip(
                                message: '${p['name']}\n${p['role']}',
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF00A8C6),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              ...points.map((p) {
                final ts = p['updatedAt'];
                String updated = 'Unknown';
                if (ts is Timestamp) {
                  final dt = ts.toDate();
                  updated =
                      '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                }
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.person_pin_circle_outlined),
                    title: Text('${p['name']}'),
                    subtitle: Text('${p['role']} • ${p['lat']}, ${p['lng']}'),
                    trailing: Text(updated),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
