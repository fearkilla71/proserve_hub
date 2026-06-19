import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

import '../constants/service_types.dart';

/// Maps icon name strings stored in Firestore to [IconData].
IconData _iconFromName(String? name) {
  switch (name) {
    case 'format_paint':
      return Icons.format_paint;
    case 'home_work_outlined':
      return Icons.home_work_outlined;
    case 'build':
      return Icons.build;
    case 'water':
      return Icons.water;
    case 'kitchen':
      return Icons.kitchen;
    case 'hvac':
      return Icons.thermostat;
    case 'pool':
      return Icons.pool;
    case 'garage':
      return Icons.garage;
    case 'window':
      return Icons.window;
    case 'solar':
      return Icons.solar_power;
    case 'pest':
      return Icons.pest_control;
    case 'tree':
      return Icons.park;
    case 'roofing':
      return Icons.roofing;
    case 'plumbing':
      return Icons.plumbing;
    case 'electrical_services':
      return Icons.electrical_services;
    case 'layers':
      return Icons.layers;
    case 'grass':
      return Icons.grass;
    case 'fence':
      return Icons.fence;
    case 'bathtub':
      return Icons.bathtub;
    case 'countertops':
      return Icons.countertops;
    case 'deck':
      return Icons.deck;
    case 'foundation':
      return Icons.foundation;
    case 'construction':
      return Icons.construction;
    case 'handyman':
      return Icons.handyman;
    default:
      return Icons.home_repair_service;
  }
}

String _iconNameForService(String slug, String name) {
  final key = '${slug}_$name'.toLowerCase();
  if (key.contains('paint')) return 'format_paint';
  if (key.contains('drywall')) return 'build';
  if (key.contains('pressure') || key.contains('wash')) return 'water';
  if (key.contains('cabinet') || key.contains('kitchen')) {
    return key.contains('remodel') ? 'countertops' : 'kitchen';
  }
  if (key.contains('hvac')) return 'hvac';
  if (key.contains('pool')) return 'pool';
  if (key.contains('garage')) return 'garage';
  if (key.contains('window')) return 'window';
  if (key.contains('solar')) return 'solar';
  if (key.contains('pest')) return 'pest';
  if (key.contains('tree')) return 'tree';
  if (key.contains('roof')) return 'roofing';
  if (key.contains('plumb')) return 'plumbing';
  if (key.contains('electric')) return 'electrical_services';
  if (key.contains('floor')) return 'layers';
  if (key.contains('landscap') || key.contains('lawn')) return 'grass';
  if (key.contains('fenc')) return 'fence';
  if (key.contains('bathroom')) return 'bathtub';
  if (key.contains('deck') || key.contains('patio')) return 'deck';
  if (key.contains('concrete') || key.contains('masonry')) return 'foundation';
  if (key.contains('demolition')) return 'construction';
  if (key.contains('handyman')) return 'handyman';
  return 'handyman';
}

/// Hardcoded fallback when Firestore is unreachable.
final List<Map<String, dynamic>> _fallbackServices = kQuickServices.entries
    .map(
      (entry) => {
        'name': entry.value,
        'icon': _iconNameForService(entry.key, entry.value),
        'type': entry.key,
      },
    )
    .toList(growable: false);

class ServiceSelectPage extends StatelessWidget {
  const ServiceSelectPage({super.key});

  /// Services that have AI chat estimates enabled.
  static const _aiChatServices = kQuickServices;

  void _navigateToFlow(BuildContext context, String type) {
    // Route all supported services to the conversational AI estimator.
    if (_aiChatServices.containsKey(type)) {
      context.push(
        '/ai-estimate-chat',
        extra: {'serviceType': type, 'serviceName': _aiChatServices[type]!},
      );
      return;
    }

    final label = _labelForType(type);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$label is not available in this build yet. Choose another service or contact support.',
        ),
      ),
    );
  }

  String _labelForType(String type) {
    return _aiChatServices[type] ??
        type
            .split('_')
            .where((part) => part.trim().isNotEmpty)
            .map((part) => part[0].toUpperCase() + part.substring(1))
            .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Select a Service')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('services')
            .orderBy('order')
            .snapshots(),
        builder: (context, snapshot) {
          // Build list from Firestore or fallback.
          final List<Map<String, dynamic>> services;
          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            services = snapshot.data!.docs.map((doc) {
              final data = doc.data()! as Map<String, dynamic>;
              return <String, dynamic>{
                'name': data['name'] ?? doc.id,
                'icon': data['icon'] ?? '',
                'type': data['type'] ?? doc.id,
              };
            }).toList();
          } else {
            services = _fallbackServices;
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              itemCount: services.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                final service = services[index];
                final iconData = service['icon'] is IconData
                    ? service['icon'] as IconData
                    : _iconFromName(service['icon'] as String?);

                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () =>
                      _navigateToFlow(context, service['type'] as String),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(iconData, size: 48, color: scheme.primary),
                        const SizedBox(height: 12),
                        Text(
                          service['name'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
