import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../theme/admin_theme.dart';

class WaitlistAdminTab extends StatelessWidget {
  const WaitlistAdminTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('waitlist')
          .orderBy('createdAt', descending: true)
          .limit(200)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        final byZip = <String, int>{};
        var customers = 0;
        var contractors = 0;
        for (final doc in docs) {
          final data = doc.data();
          final role = (data['role'] ?? '').toString();
          if (role == 'contractor') {
            contractors += 1;
          } else if (role == 'customer') {
            customers += 1;
          }
          final zip = (data['zip'] ?? 'unknown').toString();
          byZip[zip] = (byZip[zip] ?? 0) + 1;
        }

        final topZips = byZip.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Launch Waitlist',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Track users outside the Houston launch market and decide which ZIPs or roles to open next.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AdminColors.muted),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricCard(
                    label: 'Total',
                    value: '${docs.length}',
                    icon: Icons.groups_outlined,
                  ),
                  _MetricCard(
                    label: 'Customers',
                    value: '$customers',
                    icon: Icons.person_outline,
                  ),
                  _MetricCard(
                    label: 'Contractors',
                    value: '$contractors',
                    icon: Icons.handyman_outlined,
                  ),
                  _MetricCard(
                    label: 'Top ZIP',
                    value: topZips.isEmpty ? '-' : topZips.first.key,
                    icon: Icons.location_on_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _Panel(
                title: 'Top ZIP demand',
                child: topZips.isEmpty
                    ? const _EmptyState()
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: topZips.take(20).map((entry) {
                          return Chip(
                            avatar: const Icon(Icons.pin_drop, size: 16),
                            label: Text('${entry.key} · ${entry.value}'),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 20),
              _Panel(
                title: 'Recent waitlist accounts',
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : docs.isEmpty
                    ? const _EmptyState()
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Role')),
                            DataColumn(label: Text('ZIP')),
                            DataColumn(label: Text('Name')),
                            DataColumn(label: Text('Email')),
                            DataColumn(label: Text('Service')),
                            DataColumn(label: Text('Source')),
                          ],
                          rows: docs.map((doc) {
                            final data = doc.data();
                            final services = data['services'] is List
                                ? (data['services'] as List)
                                      .map((item) => item.toString())
                                      .take(2)
                                      .join(', ')
                                : '';
                            return DataRow(
                              cells: [
                                DataCell(Text((data['role'] ?? '').toString())),
                                DataCell(Text((data['zip'] ?? '').toString())),
                                DataCell(Text((data['name'] ?? '').toString())),
                                DataCell(
                                  Text((data['email'] ?? '').toString()),
                                ),
                                DataCell(
                                  Text(
                                    (data['service'] ?? '').toString().isEmpty
                                        ? services
                                        : (data['service'] ?? '').toString(),
                                  ),
                                ),
                                DataCell(
                                  Text((data['source'] ?? '').toString()),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.line),
      ),
      child: Row(
        children: [
          Icon(icon, color: AdminColors.accent),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: AdminColors.muted),
              ),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AdminColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Text(
      'No waitlist entries yet.',
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: AdminColors.muted),
    );
  }
}
