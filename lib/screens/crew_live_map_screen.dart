import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class CrewLiveMapScreen extends StatefulWidget {
  const CrewLiveMapScreen({super.key});

  @override
  State<CrewLiveMapScreen> createState() => _CrewLiveMapScreenState();
}

class _CrewLiveMapScreenState extends State<CrewLiveMapScreen> {
  GoogleMapController? _mapController;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _fitBounds(List<LatLng> positions) {
    if (positions.isEmpty || _mapController == null) return;
    if (positions.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(positions.first, 14),
      );
      return;
    }
    var south = positions.first.latitude;
    var north = positions.first.latitude;
    var west = positions.first.longitude;
    var east = positions.first.longitude;
    for (final p in positions) {
      if (p.latitude < south) south = p.latitude;
      if (p.latitude > north) north = p.latitude;
      if (p.longitude < west) west = p.longitude;
      if (p.longitude > east) east = p.longitude;
    }
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(south, west),
          northeast: LatLng(north, east),
        ),
        48,
      ),
    );
  }

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

          final markers = <Marker>{};
          final positions = <LatLng>[];

          for (final d in liveCrew) {
            final data = d.data();
            final loc = data['lastLocation'] as Map<String, dynamic>;
            final lat = (loc['lat'] as num).toDouble();
            final lng = (loc['lng'] as num).toDouble();
            final name = (data['name'] as String?)?.trim().isNotEmpty == true
                ? (data['name'] as String).trim()
                : 'Crew Member';
            final role = (data['role'] as String?)?.trim() ?? 'Crew Member';
            final ts = loc['updatedAt'];
            String updated = '';
            if (ts is Timestamp) {
              final dt = ts.toDate();
              updated =
                  ' • ${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
            }
            final pos = LatLng(lat, lng);
            positions.add(pos);
            markers.add(
              Marker(
                markerId: MarkerId(d.id),
                position: pos,
                infoWindow: InfoWindow(title: name, snippet: '$role$updated'),
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Text(
                      'Live view (${liveCrew.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Fit all',
                      icon: const Icon(Icons.fit_screen),
                      onPressed: () => _fitBounds(positions),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: positions.first,
                    zoom: 12,
                  ),
                  markers: markers,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: true,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    Future.delayed(
                      const Duration(milliseconds: 300),
                      () => _fitBounds(positions),
                    );
                  },
                ),
              ),
              // Crew list below the map
              SizedBox(
                height: 160,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: liveCrew.length,
                  itemBuilder: (context, i) {
                    final data = liveCrew[i].data();
                    final loc = data['lastLocation'] as Map<String, dynamic>;
                    final lat = (loc['lat'] as num).toDouble();
                    final lng = (loc['lng'] as num).toDouble();
                    final name =
                        (data['name'] as String?)?.trim().isNotEmpty == true
                        ? (data['name'] as String).trim()
                        : 'Crew Member';
                    final role =
                        (data['role'] as String?)?.trim() ?? 'Crew Member';
                    final ts = loc['updatedAt'];
                    String updated = 'Unknown';
                    if (ts is Timestamp) {
                      final dt = ts.toDate();
                      updated =
                          '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                    }
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.person_pin_circle_outlined),
                        title: Text(name),
                        subtitle: Text(
                          '$role • ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                        ),
                        trailing: Text(updated),
                        onTap: () {
                          _mapController?.animateCamera(
                            CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16),
                          );
                        },
                      ),
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
