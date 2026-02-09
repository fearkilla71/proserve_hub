import 'package:flutter/material.dart';

import '../services/location_matcher.dart';

class NearbyContractorsPage extends StatelessWidget {
  final String jobZip;

  const NearbyContractorsPage({super.key, required this.jobZip});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nearby Contractors')),
      body: FutureBuilder(
        future: findMatchingContractors(jobZip),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final contractors = snapshot.data!;

          if (contractors.isEmpty) {
            return const Center(child: Text('No contractors nearby'));
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: contractors.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return Card(
                child: ListTile(
                  title: Text((data['name'] ?? 'Contractor').toString()),
                  subtitle: Text(
                    'Radius: ${data['radius']} miles • ZIP ${data['zip']}',
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
