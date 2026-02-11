import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class SavedEstimatesScreen extends StatelessWidget {
  const SavedEstimatesScreen({super.key});

  static const _serviceLabels = <String, String>{
    'painting': 'Interior Painting',
    'cabinet_painting': 'Cabinet Painting',
    'drywall': 'Drywall Repair',
    'pressure_washing': 'Pressure Washing',
  };

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in to view estimates.')),
      );
    }

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('My Estimates')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/ai-estimator'),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('customer_estimates')
            .where('requesterUid', isEqualTo: uid)
            .orderBy('updatedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calculate_outlined,
                    size: 64,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No estimates yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => context.push('/ai-estimator'),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Get AI Estimate'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final data = docs[i].data();
              final service = data['service'] as String? ?? '';
              final status = data['status'] as String? ?? 'draft';
              final zip = data['zip'] as String? ?? '';
              final qty = data['quantity']?.toString() ?? '';
              final aiEstimate = data['aiEstimate'] as Map<String, dynamic>?;
              final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();

              // Price range
              String priceRange = '';
              if (aiEstimate != null) {
                final prices = aiEstimate['prices'] as Map<String, dynamic>?;
                if (prices != null) {
                  final low = prices['low']?.toString() ?? '?';
                  final high = prices['premium']?.toString() ?? '?';
                  priceRange = '\$$low – \$$high';
                }
              }

              final serviceLabel = _serviceLabels[service] ?? service;
              final dateStr = updatedAt != null
                  ? DateFormat.MMMd().format(updatedAt)
                  : '';

              return Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    // If estimate has result, show details or convert to job
                    if (aiEstimate != null) {
                      _showEstimateDetail(
                        context,
                        data: data,
                        docId: docs[i].id,
                      );
                    } else {
                      // Resume draft
                      context.push('/ai-estimator');
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _iconForService(service),
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                serviceLabel,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  if (qty.isNotEmpty) qty,
                                  if (zip.isNotEmpty) 'ZIP $zip',
                                  if (priceRange.isNotEmpty) priceRange,
                                ].join(' • '),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _statusChip(context, status),
                            if (dateStr.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                dateStr,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _iconForService(String service) {
    switch (service) {
      case 'painting':
        return Icons.format_paint;
      case 'cabinet_painting':
        return Icons.kitchen;
      case 'drywall':
        return Icons.handyman;
      case 'pressure_washing':
        return Icons.water;
      default:
        return Icons.calculate;
    }
  }

  Widget _statusChip(BuildContext context, String status) {
    final scheme = Theme.of(context).colorScheme;
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'completed':
        bg = Colors.green.withValues(alpha: 0.15);
        fg = Colors.green;
        label = 'Complete';
        break;
      case 'draft':
        bg = scheme.surfaceContainerHighest;
        fg = scheme.onSurfaceVariant;
        label = 'Draft';
        break;
      default:
        bg = scheme.primaryContainer;
        fg = scheme.onPrimaryContainer;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  void _showEstimateDetail(
    BuildContext context, {
    required Map<String, dynamic> data,
    required String docId,
  }) {
    final service = data['service'] as String? ?? '';
    final aiEstimate = data['aiEstimate'] as Map<String, dynamic>?;
    final prices = aiEstimate?['prices'] as Map<String, dynamic>?;
    final serviceLabel = _serviceLabels[service] ?? service;

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  serviceLabel,
                  style: Theme.of(
                    ctx,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (prices != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _priceCol(ctx, 'Low', prices['low']),
                      _priceCol(ctx, 'Recommended', prices['recommended']),
                      _priceCol(ctx, 'Premium', prices['premium']),
                    ],
                  ),
                ],
                if (aiEstimate?['notes'] != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    aiEstimate!['notes'].toString(),
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.send),
                    onPressed: () {
                      Navigator.pop(ctx);
                      final recommended =
                          prices?['recommended']?.toString() ?? '';
                      final qty = data['quantity']?.toString() ?? '';
                      final zip = data['zip'] as String? ?? '';
                      context.push(
                        '/job-request/$serviceLabel',
                        extra: <String, dynamic>{
                          'initialZip': zip,
                          'initialQuantity': qty,
                          'initialPrice': recommended,
                          'initialDescription':
                              'AI-estimated $serviceLabel job',
                          'initialUrgent': data['urgency'] == 'rush',
                        },
                      );
                    },
                    label: const Text('Post as Job Request'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      Navigator.pop(ctx);
                      FirebaseFirestore.instance
                          .collection('customer_estimates')
                          .doc(docId)
                          .delete();
                    },
                    label: const Text('Delete Estimate'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _priceCol(BuildContext context, String label, dynamic value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '\$${value ?? '—'}',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
