import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

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

/// Hardcoded fallback when Firestore is unreachable.
const List<Map<String, dynamic>> _fallbackServices = [
  {
    'name': 'Interior Painting',
    'icon': 'format_paint',
    'type': 'interior_painting',
  },
  {
    'name': 'Exterior Painting',
    'icon': 'home_work_outlined',
    'type': 'exterior_painting',
  },
  {'name': 'Drywall Repair', 'icon': 'build', 'type': 'drywall_repair'},
  {'name': 'Pressure Washing', 'icon': 'water', 'type': 'pressure_washing'},
  {'name': 'Cabinets', 'icon': 'kitchen', 'type': 'cabinets'},
  {'name': 'HVAC', 'icon': 'hvac', 'type': 'hvac'},
  {'name': 'Pool Installation', 'icon': 'pool', 'type': 'pool_installation'},
  {'name': 'Garage Door', 'icon': 'garage', 'type': 'garage_door'},
  {
    'name': 'Window Replacement',
    'icon': 'window',
    'type': 'window_replacement',
  },
  {'name': 'Solar Panels', 'icon': 'solar', 'type': 'solar_panels'},
  {'name': 'Pest Control', 'icon': 'pest', 'type': 'pest_control'},
  {'name': 'Tree Service', 'icon': 'tree', 'type': 'tree_service'},
  {'name': 'Roofing', 'icon': 'roofing', 'type': 'roofing'},
  {'name': 'Plumbing', 'icon': 'plumbing', 'type': 'plumbing'},
  {'name': 'Electrical', 'icon': 'electrical_services', 'type': 'electrical'},
  {'name': 'Flooring', 'icon': 'layers', 'type': 'flooring'},
  {'name': 'Landscaping', 'icon': 'grass', 'type': 'landscaping'},
  {'name': 'Fencing', 'icon': 'fence', 'type': 'fencing'},
  {'name': 'Bathroom Remodel', 'icon': 'bathtub', 'type': 'bathroom_remodel'},
  {'name': 'Kitchen Remodel', 'icon': 'countertops', 'type': 'kitchen_remodel'},
  {'name': 'Deck & Patio', 'icon': 'deck', 'type': 'deck_patio'},
  {
    'name': 'Concrete & Masonry',
    'icon': 'foundation',
    'type': 'concrete_masonry',
  },
  {'name': 'Demolition', 'icon': 'construction', 'type': 'demolition'},
  {'name': 'General Handyman', 'icon': 'handyman', 'type': 'general_handyman'},
];

class ServiceSelectPage extends StatelessWidget {
  const ServiceSelectPage({super.key});

  /// Services that have AI chat estimates enabled.
  static const _aiChatServices = {
    'interior_painting': 'Interior Painting',
    'exterior_painting': 'Exterior Painting',
    'drywall_repair': 'Drywall Repair',
    'pressure_washing': 'Pressure Washing',
    'cabinets': 'Cabinet Painting',
    'painting': 'Painting',
    'hvac': 'HVAC',
    'pool_installation': 'Pool Installation',
    'garage_door': 'Garage Door',
    'window_replacement': 'Window Replacement',
    'solar_panels': 'Solar Panels',
    'pest_control': 'Pest Control',
    'tree_service': 'Tree Service',
    'roofing': 'Roofing',
    'plumbing': 'Plumbing',
    'electrical': 'Electrical',
    'flooring': 'Flooring',
    'landscaping': 'Landscaping',
    'fencing': 'Fencing',
    'bathroom_remodel': 'Bathroom Remodel',
    'kitchen_remodel': 'Kitchen Remodel',
    'deck_patio': 'Deck & Patio',
    'concrete_masonry': 'Concrete & Masonry',
    'demolition': 'Demolition',
    'general_handyman': 'General Handyman',
  };

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
