import 'package:flutter/material.dart';

import 'painting_request_flow_page.dart';
import 'exterior_painting_request_flow_page.dart';
import 'cabinet_request_flow_page.dart';
import 'pressure_washing_request_flow_page.dart';
import 'drywall_repair_request_flow_page.dart';

class ServiceSelectPage extends StatelessWidget {
  const ServiceSelectPage({super.key});

  final List<Map<String, dynamic>> services = const [
    {'name': 'Interior Painting', 'icon': Icons.format_paint},
    {'name': 'Exterior Painting', 'icon': Icons.home_work_outlined},
    {'name': 'Drywall Repair', 'icon': Icons.build},
    {'name': 'Pressure Washing', 'icon': Icons.water},
    {'name': 'Cabinets', 'icon': Icons.kitchen},
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Select a Service')),
      body: Padding(
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
            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                final selectedServiceName = service['name'] as String;

                switch (selectedServiceName) {
                  case 'Interior Painting':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PaintingRequestFlowPage(
                          initialPaintingScope: 'interior',
                        ),
                      ),
                    );
                    return;
                  case 'Exterior Painting':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ExteriorPaintingRequestFlowPage(),
                      ),
                    );
                    return;
                  case 'Painting':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PaintingRequestFlowPage(),
                      ),
                    );
                    return;
                  case 'Drywall Repair':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DrywallRepairRequestFlowPage(),
                      ),
                    );
                    return;
                  case 'Pressure Washing':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PressureWashingRequestFlowPage(),
                      ),
                    );
                    return;
                  case 'Cabinets':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CabinetRequestFlowPage(),
                      ),
                    );
                    return;
                  default:
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$selectedServiceName selected')),
                    );
                }
              },
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(service['icon'], size: 48, color: scheme.primary),
                    const SizedBox(height: 12),
                    Text(
                      service['name'],
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
      ),
    );
  }
}
