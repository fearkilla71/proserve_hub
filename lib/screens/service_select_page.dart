import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'painting_request_flow_page.dart';
import 'exterior_painting_request_flow_page.dart';
import 'cabinet_request_flow_page.dart';
import 'pressure_washing_request_flow_page.dart';
import 'drywall_repair_request_flow_page.dart';

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
    case 'electrical_services':
      return Icons.electrical_services;
    case 'plumbing':
      return Icons.plumbing;
    case 'roofing':
      return Icons.roofing;
    case 'yard':
      return Icons.yard;
    case 'cleaning_services':
      return Icons.cleaning_services;
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

  void _navigateToFlow(BuildContext context, String type) {
    Widget? page;
    switch (type) {
      case 'interior_painting':
        page = const PaintingRequestFlowPage(initialPaintingScope: 'interior');
        break;
      case 'exterior_painting':
        page = const ExteriorPaintingRequestFlowPage();
        break;
      case 'painting':
        page = const PaintingRequestFlowPage();
        break;
      case 'drywall_repair':
        page = const DrywallRepairRequestFlowPage();
        break;
      case 'pressure_washing':
        page = const PressureWashingRequestFlowPage();
        break;
      case 'cabinets':
        page = const CabinetRequestFlowPage();
        break;
    }

    if (page != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => page!));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Service "$type" is coming soon!')),
      );
    }
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
