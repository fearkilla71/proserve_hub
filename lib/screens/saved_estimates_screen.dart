import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

/// Contractor-side saved estimates list — reads from
/// `contractors/{uid}/saved_estimates` written by the Pricing Calculator.
class SavedEstimatesScreen extends StatefulWidget {
  const SavedEstimatesScreen({super.key});

  @override
  State<SavedEstimatesScreen> createState() => _SavedEstimatesScreenState();
}

class _SavedEstimatesScreenState extends State<SavedEstimatesScreen> {
  String _search = '';

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
      appBar: AppBar(
        title: const Text('Saved Estimates'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by service or client…',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: scheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) =>
                  setState(() => _search = v.trim().toLowerCase()),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'newEstimate',
        onPressed: () => context.push('/pricing-calculator'),
        tooltip: 'New Estimate',
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('contractors')
            .doc(uid)
            .collection('saved_estimates')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allDocs = snapshot.data?.docs ?? [];

          // Client-side search filter.
          final docs = _search.isEmpty
              ? allDocs
              : allDocs.where((d) {
                  final data = d.data();
                  final service = (data['service'] as String? ?? '')
                      .toLowerCase();
                  final client = (data['clientName'] as String? ?? '')
                      .toLowerCase();
                  return service.contains(_search) || client.contains(_search);
                }).toList();

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
                    _search.isEmpty
                        ? 'No estimates yet'
                        : 'No matching estimates',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (_search.isEmpty) ...[
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () => context.push('/pricing-calculator'),
                      icon: const Icon(Icons.calculate),
                      label: const Text('Create Estimate'),
                    ),
                  ],
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
              final docId = docs[i].id;
              final service = data['service'] as String? ?? 'Unknown';
              final totalCost = (data['totalCost'] as num?)?.toDouble() ?? 0.0;
              final clientName = data['clientName'] as String? ?? '';
              final complexity = data['complexity'] as String? ?? '';
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
              final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
              final displayDate = updatedAt ?? createdAt;
              final dateStr = displayDate != null
                  ? DateFormat.MMMd().add_jm().format(displayDate)
                  : '';

              return Dismissible(
                key: ValueKey(docId),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: scheme.error,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.delete, color: scheme.onError),
                ),
                confirmDismiss: (_) => _confirmDelete(context),
                onDismissed: (_) => _deleteEstimate(uid, docId),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _showEstimateDetail(
                      context,
                      data: data,
                      docId: docId,
                      uid: uid,
                    ),
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
                                  service,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  [
                                    if (clientName.isNotEmpty) clientName,
                                    if (complexity.isNotEmpty) complexity,
                                  ].join(' • '),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$${totalCost.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: scheme.primary,
                                    ),
                              ),
                              if (dateStr.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  dateStr,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
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

  // ── Helpers ──────────────────────────────────────────────────────────────

  IconData _iconForService(String service) {
    final s = service.toLowerCase();
    if (s.contains('paint') && s.contains('exterior')) return Icons.house;
    if (s.contains('paint')) return Icons.format_paint;
    if (s.contains('cabinet')) return Icons.kitchen;
    if (s.contains('drywall')) return Icons.handyman;
    if (s.contains('pressure') || s.contains('wash')) return Icons.water;
    return Icons.calculate;
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Estimate?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteEstimate(String uid, String docId) {
    FirebaseFirestore.instance
        .collection('contractors')
        .doc(uid)
        .collection('saved_estimates')
        .doc(docId)
        .delete();
  }

  /// Bottom sheet with estimate details, re-open, share, and delete actions.
  void _showEstimateDetail(
    BuildContext context, {
    required Map<String, dynamic> data,
    required String docId,
    required String uid,
  }) {
    final service = data['service'] as String? ?? 'Unknown';
    final complexity = data['complexity'] as String? ?? '';
    final hours = (data['hours'] as num?)?.toDouble() ?? 0;
    final hourlyRate = (data['hourlyRate'] as num?)?.toDouble() ?? 0;
    final materialCost = (data['materialCost'] as num?)?.toDouble() ?? 0;
    final laborCost = (data['laborCost'] as num?)?.toDouble() ?? 0;
    final totalCost = (data['totalCost'] as num?)?.toDouble() ?? 0;
    final clientName = data['clientName'] as String? ?? '';
    final clientEmail = data['clientEmail'] as String? ?? '';
    final markupLow = (data['markupLow'] as num?)?.toDouble() ?? 10;
    final markupMid = (data['markupMid'] as num?)?.toDouble() ?? 20;
    final markupHigh = (data['markupHigh'] as num?)?.toDouble() ?? 30;

    final scheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        service,
                        style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        complexity,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                if (clientName.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    [
                      clientName,
                      if (clientEmail.isNotEmpty) clientEmail,
                    ].join(' • '),
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],

                const Divider(height: 24),

                // Cost details
                _detailRow(ctx, 'Hours', '${hours.toStringAsFixed(1)} hrs'),
                _detailRow(
                  ctx,
                  'Hourly Rate',
                  '\$${hourlyRate.toStringAsFixed(2)}',
                ),
                _detailRow(
                  ctx,
                  'Labor Cost',
                  '\$${laborCost.toStringAsFixed(2)}',
                ),
                _detailRow(
                  ctx,
                  'Materials',
                  '\$${materialCost.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '\$${totalCost.toStringAsFixed(2)}',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),
                // Markup prices
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _priceCol(
                      ctx,
                      '+${markupLow.toStringAsFixed(0)}%',
                      totalCost * (1 + markupLow / 100),
                    ),
                    _priceCol(
                      ctx,
                      '+${markupMid.toStringAsFixed(0)}%',
                      totalCost * (1 + markupMid / 100),
                    ),
                    _priceCol(
                      ctx,
                      '+${markupHigh.toStringAsFixed(0)}%',
                      totalCost * (1 + markupHigh / 100),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Actions
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.push(
                        '/pricing-calculator',
                        extra: {
                          'initialEstimate': data,
                          'estimateDocId': docId,
                        },
                      );
                    },
                    label: const Text('Reopen & Edit'),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.share),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _shareEstimate(data);
                        },
                        label: const Text('Share'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: Icon(Icons.delete_outline, color: scheme.error),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _deleteEstimate(uid, docId);
                        },
                        label: Text(
                          'Delete',
                          style: TextStyle(color: scheme.error),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _priceCol(BuildContext context, String label, double value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '\$${value.toStringAsFixed(2)}',
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

  void _shareEstimate(Map<String, dynamic> data) {
    final service = data['service'] as String? ?? 'Unknown';
    final complexity = data['complexity'] as String? ?? '';
    final hours = (data['hours'] as num?)?.toDouble() ?? 0;
    final hourlyRate = (data['hourlyRate'] as num?)?.toDouble() ?? 0;
    final materialCost = (data['materialCost'] as num?)?.toDouble() ?? 0;
    final laborCost = (data['laborCost'] as num?)?.toDouble() ?? 0;
    final totalCost = (data['totalCost'] as num?)?.toDouble() ?? 0;
    final clientName = data['clientName'] as String? ?? '';
    final markupLow = (data['markupLow'] as num?)?.toDouble() ?? 10;
    final markupMid = (data['markupMid'] as num?)?.toDouble() ?? 20;
    final markupHigh = (data['markupHigh'] as num?)?.toDouble() ?? 30;

    final buf = StringBuffer()
      ..writeln('── Estimate ──')
      ..writeln('Service: $service')
      ..writeln('Complexity: $complexity')
      ..writeln()
      ..writeln(
        'Labor: ${hours.toStringAsFixed(1)} hrs × '
        '\$${hourlyRate.toStringAsFixed(2)} = '
        '\$${laborCost.toStringAsFixed(2)}',
      )
      ..writeln('Materials: \$${materialCost.toStringAsFixed(2)}')
      ..writeln('Base Total: \$${totalCost.toStringAsFixed(2)}')
      ..writeln()
      ..writeln('── Pricing Options ──')
      ..writeln(
        'Budget (+${markupLow.toStringAsFixed(0)}%): '
        '\$${(totalCost * (1 + markupLow / 100)).toStringAsFixed(2)}',
      )
      ..writeln(
        'Standard (+${markupMid.toStringAsFixed(0)}%): '
        '\$${(totalCost * (1 + markupMid / 100)).toStringAsFixed(2)}',
      )
      ..writeln(
        'Premium (+${markupHigh.toStringAsFixed(0)}%): '
        '\$${(totalCost * (1 + markupHigh / 100)).toStringAsFixed(2)}',
      );

    if (clientName.isNotEmpty) {
      buf
        ..writeln()
        ..writeln('Client: $clientName');
    }

    Share.share(buf.toString(), subject: '$service Estimate');
  }
}
