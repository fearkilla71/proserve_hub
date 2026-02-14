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
];

class ServiceSelectPage extends StatelessWidget {
  const ServiceSelectPage({super.key});

  /// Services that have AI chat estimates enabled.
  static const _aiChatServices = {
    'interior_painting': 'Interior Painting',
    'exterior_painting': 'Exterior Painting',
    'drywall_repair': 'Drywall Repair',
    'pressure_washing': 'Pressure Washing',
    'cabinets': 'Cabinet Refinishing',
    'painting': 'Painting',
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

    // Fallback for services not yet supported
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Service "$type" is coming soon!')));
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
