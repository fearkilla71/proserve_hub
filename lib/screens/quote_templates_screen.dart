import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/quote_template_service.dart';

/// Screen for creating, editing, and applying quote/estimate templates.
class QuoteTemplatesScreen extends StatefulWidget {
  const QuoteTemplatesScreen({super.key});

  @override
  State<QuoteTemplatesScreen> createState() => _QuoteTemplatesScreenState();
}

class _QuoteTemplatesScreenState extends State<QuoteTemplatesScreen> {
  String? _serviceFilter;
  final _svc = QuoteTemplateService.instance;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quote Templates'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter by service',
            onSelected: (v) =>
                setState(() => _serviceFilter = v == 'all' ? null : v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'all', child: Text('All services')),
              ...QuoteTemplateService.serviceTypes.entries.map(
                (e) => PopupMenuItem(value: e.key, child: Text(e.value)),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _svc.watchTemplates(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          var docs = snap.data?.docs ?? [];
          if (_serviceFilter != null) {
            docs = docs
                .where((d) => d.data()['serviceType'] == _serviceFilter)
                .toList();
          }
          if (docs.isEmpty) return _emptyState(scheme);

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data();
              return _TemplateCard(
                id: doc.id,
                data: data,
                onEdit: () =>
                    _showTemplateSheet(context, id: doc.id, data: data),
                onDuplicate: () => _svc.duplicateTemplate(doc.id),
                onDelete: () => _confirmDelete(doc.id, data['name']),
                onUseTemplate: () =>
                    _showUseTemplateSheet(context, doc.id, data),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTemplateSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('New Template'),
      ),
    );
  }

  Widget _emptyState(ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.description_outlined,
            size: 72,
            color: scheme.primary.withValues(alpha: .4),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Quote Templates',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Create reusable templates for quick\nquote generation by service type.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  void _showTemplateSheet(
    BuildContext context, {
    String? id,
    Map<String, dynamic>? data,
  }) {
    final nameCtrl = TextEditingController(text: data?['name'] ?? '');
    final laborCtrl = TextEditingController(
      text: data?['laborRate'] != null
          ? (data!['laborRate'] as num).toStringAsFixed(2)
          : '',
    );
    final markupCtrl = TextEditingController(
      text: data?['markupPercent'] != null
          ? (data!['markupPercent'] as num).toStringAsFixed(0)
          : '0',
    );
    final notesCtrl = TextEditingController(text: data?['notes'] ?? '');
    final termsCtrl = TextEditingController(
      text: data?['termsAndConditions'] ?? '',
    );
    final validityCtrl = TextEditingController(
      text: '${data?['validityDays'] ?? 30}',
    );
    String serviceType = data?['serviceType'] as String? ?? 'painting';

    // Line items
    final lineItems = <Map<String, dynamic>>[];
    if (data?['lineItems'] != null) {
      for (final item in data!['lineItems'] as List) {
        lineItems.add(Map<String, dynamic>.from(item as Map));
      }
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      id == null ? 'New Template' : 'Edit Template',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _field(ctx, nameCtrl, 'Template name', Icons.badge),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: serviceType,
                      decoration: const InputDecoration(
                        labelText: 'Service type',
                        prefixIcon: Icon(Icons.work),
                        border: OutlineInputBorder(),
                      ),
                      items: QuoteTemplateService.serviceTypes.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setSheetState(() => serviceType = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            ctx,
                            laborCtrl,
                            'Labor rate/hr',
                            Icons.attach_money,
                            type: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field(
                            ctx,
                            markupCtrl,
                            'Markup %',
                            Icons.percent,
                            type: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _field(
                      ctx,
                      validityCtrl,
                      'Valid days',
                      Icons.timer,
                      type: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    // ── Line items section ──
                    Row(
                      children: [
                        const Text(
                          'Line Items',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add'),
                          onPressed: () {
                            setSheetState(() {
                              lineItems.add({
                                'description': '',
                                'quantity': 1,
                                'unitPrice': 0.0,
                              });
                            });
                          },
                        ),
                      ],
                    ),
                    ...lineItems.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      final descCtrl = TextEditingController(
                        text: item['description'] ?? '',
                      );
                      final qtyCtrl = TextEditingController(
                        text: '${item['quantity'] ?? 1}',
                      );
                      final priceCtrl = TextEditingController(
                        text:
                            (item['unitPrice'] as num?)?.toStringAsFixed(2) ??
                            '0.00',
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: descCtrl,
                                decoration: const InputDecoration(
                                  hintText: 'Description',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (v) =>
                                    lineItems[idx]['description'] = v,
                              ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 48,
                              child: TextField(
                                controller: qtyCtrl,
                                decoration: const InputDecoration(
                                  hintText: 'Qty',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (v) => lineItems[idx]['quantity'] =
                                    int.tryParse(v) ?? 1,
                              ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 72,
                              child: TextField(
                                controller: priceCtrl,
                                decoration: const InputDecoration(
                                  hintText: 'Price',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                onChanged: (v) => lineItems[idx]['unitPrice'] =
                                    double.tryParse(v) ?? 0,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                setSheetState(() => lineItems.removeAt(idx));
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    _field(ctx, notesCtrl, 'Notes', Icons.note, maxLines: 2),
                    const SizedBox(height: 12),
                    _field(
                      ctx,
                      termsCtrl,
                      'Terms & Conditions',
                      Icons.gavel,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          if (nameCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Name is required')),
                            );
                            return;
                          }
                          Navigator.pop(ctx);
                          HapticFeedback.mediumImpact();
                          try {
                            if (id == null) {
                              await _svc.createTemplate(
                                name: nameCtrl.text.trim(),
                                serviceType: serviceType,
                                lineItems: lineItems,
                                laborRate: double.tryParse(
                                  laborCtrl.text.trim(),
                                ),
                                markupPercent:
                                    double.tryParse(markupCtrl.text.trim()) ??
                                    0,
                                notes: notesCtrl.text.trim().isEmpty
                                    ? null
                                    : notesCtrl.text.trim(),
                                termsAndConditions:
                                    termsCtrl.text.trim().isEmpty
                                    ? null
                                    : termsCtrl.text.trim(),
                                validityDays:
                                    int.tryParse(validityCtrl.text.trim()) ??
                                    30,
                              );
                            } else {
                              await _svc.updateTemplate(id, {
                                'name': nameCtrl.text.trim(),
                                'serviceType': serviceType,
                                'lineItems': lineItems,
                                'laborRate': double.tryParse(
                                  laborCtrl.text.trim(),
                                ),
                                'markupPercent':
                                    double.tryParse(markupCtrl.text.trim()) ??
                                    0,
                                'notes': notesCtrl.text.trim().isEmpty
                                    ? null
                                    : notesCtrl.text.trim(),
                                'termsAndConditions':
                                    termsCtrl.text.trim().isEmpty
                                    ? null
                                    : termsCtrl.text.trim(),
                                'validityDays':
                                    int.tryParse(validityCtrl.text.trim()) ??
                                    30,
                              });
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.save),
                        label: Text(id == null ? 'Create' : 'Save'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showUseTemplateSheet(
    BuildContext context,
    String templateId,
    Map<String, dynamic> data,
  ) {
    final clientCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Generate Quote',
                style: Theme.of(
                  ctx,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Using template: ${data['name']}',
                style: TextStyle(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              _field(ctx, clientCtrl, 'Client name', Icons.person),
              const SizedBox(height: 12),
              _field(ctx, addressCtrl, 'Job address', Icons.location_on),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    if (clientCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Client name required')),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    HapticFeedback.mediumImpact();
                    final quoteData = _svc.generateQuoteData(
                      {...data, 'id': templateId},
                      clientName: clientCtrl.text.trim(),
                      jobAddress: addressCtrl.text.trim(),
                    );
                    await _svc.incrementUsage(templateId);
                    if (context.mounted) {
                      _showQuotePreview(context, quoteData);
                    }
                  },
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Generate'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showQuotePreview(BuildContext context, Map<String, dynamic> quote) {
    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quote Preview'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Client: ${quote['clientName']}'),
              Text('Address: ${quote['jobAddress']}'),
              Text(
                'Service: ${QuoteTemplateService.serviceTypes[quote['serviceType']] ?? quote['serviceType']}',
              ),
              const Divider(),
              ...(quote['lineItems'] as List).map((item) {
                final desc = item['description'] ?? '';
                final qty = item['quantity'] ?? 1;
                final price = item['unitPrice'] ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(child: Text('$desc (x$qty)')),
                      Text(
                        '\$${((qty as num) * (price as num)).toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                );
              }),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Subtotal',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text('\$${(quote['subtotal'] as num).toStringAsFixed(2)}'),
                ],
              ),
              if ((quote['markupPercent'] as num) > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Markup (${(quote['markupPercent'] as num).toStringAsFixed(0)}%)',
                    ),
                    Text(
                      '\$${((quote['total'] as num) - (quote['subtotal'] as num)).toStringAsFixed(2)}',
                    ),
                  ],
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  Text(
                    '\$${(quote['total'] as num).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
              if (quote['validUntil'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Valid until: ${DateFormat.yMMMd().format(DateTime.parse(quote['validUntil']))}',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Clipboard.setData(ClipboardData(text: _quoteToText(quote)));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Quote copied to clipboard')),
              );
            },
            child: const Text('Copy Text'),
          ),
        ],
      ),
    );
  }

  String _quoteToText(Map<String, dynamic> quote) {
    final buf = StringBuffer();
    buf.writeln('QUOTE / ESTIMATE');
    buf.writeln('Client: ${quote['clientName']}');
    buf.writeln('Address: ${quote['jobAddress']}');
    buf.writeln('Service: ${quote['serviceType']}');
    buf.writeln();
    for (final item in quote['lineItems'] as List) {
      buf.writeln(
        '${item['description']} x${item['quantity']} = \$${((item['quantity'] as num) * (item['unitPrice'] as num)).toStringAsFixed(2)}',
      );
    }
    buf.writeln();
    buf.writeln('Total: \$${(quote['total'] as num).toStringAsFixed(2)}');
    if (quote['notes'] != null) {
      buf.writeln('\nNotes: ${quote['notes']}');
    }
    if (quote['termsAndConditions'] != null) {
      buf.writeln('\nTerms: ${quote['termsAndConditions']}');
    }
    return buf.toString();
  }

  void _confirmDelete(String id, String? name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text('Remove "${name ?? 'this template'}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _svc.deleteTemplate(id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _field(
    BuildContext ctx,
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? type,
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      keyboardType: type,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onUseTemplate;

  const _TemplateCard({
    required this.id,
    required this.data,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    required this.onUseTemplate,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = data['name'] as String? ?? 'Untitled';
    final serviceType = data['serviceType'] as String? ?? 'general';
    final serviceLabel =
        QuoteTemplateService.serviceTypes[serviceType] ?? serviceType;
    final items = data['lineItems'] as List? ?? [];
    final usageCount = data['usageCount'] as int? ?? 0;
    final markup = (data['markupPercent'] as num?)?.toDouble() ?? 0;

    double subtotal = 0;
    for (final item in items) {
      subtotal +=
          ((item['quantity'] as num? ?? 1) * (item['unitPrice'] as num? ?? 0))
              .toDouble();
    }
    final total = subtotal * (1 + markup / 100);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '$serviceLabel • ${items.length} items',
                        style: TextStyle(
                          fontSize: 12,
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
                      '\$${total.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                    ),
                    if (usageCount > 0)
                      Text(
                        'Used $usageCount×',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: onUseTemplate,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Use'),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Duplicate',
                  onPressed: onDuplicate,
                  icon: const Icon(Icons.copy, size: 20),
                ),
                IconButton(
                  tooltip: 'Edit',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: scheme.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
