import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../models/invoice_models.dart';

class PricingCalculatorScreen extends StatefulWidget {
  /// If non-null, pre-fills the form with a saved estimate for editing.
  final Map<String, dynamic>? initialEstimate;

  /// Firestore document id when reopening a saved estimate.
  final String? estimateDocId;

  const PricingCalculatorScreen({
    super.key,
    this.initialEstimate,
    this.estimateDocId,
  });

  @override
  State<PricingCalculatorScreen> createState() =>
      _PricingCalculatorScreenState();
}

class _PricingCalculatorScreenState extends State<PricingCalculatorScreen> {
  String _selectedService = 'Painting';
  String _complexity = 'Standard';
  double _hours = 1.0;
  double _materialCost = 0.0;
  double _hourlyRate = 75.0;

  // Client details
  final _clientNameCtrl = TextEditingController();
  final _clientEmailCtrl = TextEditingController();

  // Custom markup percentages
  double _markupLow = 10;
  double _markupMid = 20;
  double _markupHigh = 30;

  // Controllers for rate/material so we can update them programmatically
  late TextEditingController _rateCtrl;
  late TextEditingController _materialCtrl;

  /// Built-in fallback services (always available).
  static const _builtInServices = <String>[
    'Painting',
    'Exterior Painting',
    'Cabinet Refinishing',
    'Drywall Repair',
    'Pressure Washing',
  ];

  static const _builtInRates = <String, double>{
    'Painting': 60.0,
    'Exterior Painting': 55.0,
    'Cabinet Refinishing': 70.0,
    'Drywall Repair': 65.0,
    'Pressure Washing': 55.0,
  };

  /// Dynamic services loaded from Firestore `pricing_rules`.
  List<String> _dynamicServices = [];
  final Map<String, double> _dynamicRates = {};
  bool _loadingServices = true;

  /// Merged list shown in the dropdown.
  List<String> get _allServices {
    final set = <String>{..._builtInServices, ..._dynamicServices};
    return set.toList()..sort();
  }

  final Map<String, double> _complexityMultipliers = {
    'Simple': 0.8,
    'Standard': 1.0,
    'Complex': 1.3,
    'Expert': 1.6,
  };

  @override
  void initState() {
    super.initState();
    _loadDynamicServices();

    // Pre-fill from saved estimate if provided.
    final est = widget.initialEstimate;
    if (est != null) {
      _selectedService = est['service'] as String? ?? 'Painting';
      _complexity = est['complexity'] as String? ?? 'Standard';
      _hours = (est['hours'] as num?)?.toDouble() ?? 1.0;
      _hourlyRate = (est['hourlyRate'] as num?)?.toDouble() ?? 75.0;
      _materialCost = (est['materialCost'] as num?)?.toDouble() ?? 0.0;
      _clientNameCtrl.text = est['clientName'] as String? ?? '';
      _clientEmailCtrl.text = est['clientEmail'] as String? ?? '';
      _markupLow = (est['markupLow'] as num?)?.toDouble() ?? 10;
      _markupMid = (est['markupMid'] as num?)?.toDouble() ?? 20;
      _markupHigh = (est['markupHigh'] as num?)?.toDouble() ?? 30;
    } else {
      _hourlyRate = _builtInRates[_selectedService] ?? 75.0;
    }

    _rateCtrl = TextEditingController(text: _hourlyRate.toStringAsFixed(0));
    _materialCtrl = TextEditingController(
      text: _materialCost > 0 ? _materialCost.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _clientNameCtrl.dispose();
    _clientEmailCtrl.dispose();
    _rateCtrl.dispose();
    _materialCtrl.dispose();
    super.dispose();
  }

  // ── Firestore dynamic services ──────────────────────────────────────────

  Future<void> _loadDynamicServices() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('pricing_rules')
          .get();
      final names = <String>[];
      for (final doc in snap.docs) {
        // Capitalise the document id for display.
        final name = _capitalize(doc.id);
        names.add(name);
        final rate = (doc.data()['baseRate'] as num?)?.toDouble();
        if (rate != null) _dynamicRates[name] = rate;
      }
      if (mounted) {
        setState(() {
          _dynamicServices = names;
          _loadingServices = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingServices = false);
    }
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s
        .split(RegExp(r'[_\s]+'))
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  // ── Calculations ────────────────────────────────────────────────────────

  double _rateForService(String service) {
    return _builtInRates[service] ?? _dynamicRates[service] ?? 75.0;
  }

  double _calculateLaborCost() {
    return _hours * _hourlyRate * (_complexityMultipliers[_complexity] ?? 1.0);
  }

  double _calculateTotalCost() {
    return _calculateLaborCost() + _materialCost;
  }

  double _calculateWithMarkup(double percentage) {
    return _calculateTotalCost() * (1 + percentage / 100);
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  Future<void> _saveEstimate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final payload = <String, dynamic>{
      'service': _selectedService,
      'complexity': _complexity,
      'hours': _hours,
      'hourlyRate': _hourlyRate,
      'materialCost': _materialCost,
      'laborCost': _calculateLaborCost(),
      'totalCost': _calculateTotalCost(),
      'clientName': _clientNameCtrl.text.trim(),
      'clientEmail': _clientEmailCtrl.text.trim(),
      'markupLow': _markupLow,
      'markupMid': _markupMid,
      'markupHigh': _markupHigh,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      final col = FirebaseFirestore.instance
          .collection('contractors')
          .doc(user.uid)
          .collection('saved_estimates');

      if (widget.estimateDocId != null) {
        await col.doc(widget.estimateDocId).update(payload);
      } else {
        payload['createdAt'] = FieldValue.serverTimestamp();
        await col.add(payload);
      }

      if (mounted) {
        final canCreateInvoice = _calculateTotalCost() > 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Estimate saved!'),
            action: canCreateInvoice
                ? SnackBarAction(
                    label: 'Create invoice',
                    onPressed: _createInvoiceFromEstimate,
                  )
                : null,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    }
  }

  // ── Share ────────────────────────────────────────────────────────────────

  void _shareEstimate() {
    final laborCost = _calculateLaborCost();
    final totalCost = _calculateTotalCost();
    final multiplier = _complexityMultipliers[_complexity] ?? 1.0;

    final buf = StringBuffer()
      ..writeln('── Estimate ──')
      ..writeln('Service: $_selectedService')
      ..writeln('Complexity: $_complexity (×${multiplier.toStringAsFixed(2)})')
      ..writeln()
      ..writeln(
        'Labor: ${_hours.toStringAsFixed(1)} hrs × '
        '\$${_hourlyRate.toStringAsFixed(2)} = '
        '\$${laborCost.toStringAsFixed(2)}',
      )
      ..writeln('Materials: \$${_materialCost.toStringAsFixed(2)}')
      ..writeln('Base Total: \$${totalCost.toStringAsFixed(2)}')
      ..writeln()
      ..writeln('── Pricing Options ──')
      ..writeln(
        'Budget (+${_markupLow.toStringAsFixed(0)}%): '
        '\$${_calculateWithMarkup(_markupLow).toStringAsFixed(2)}',
      )
      ..writeln(
        'Standard (+${_markupMid.toStringAsFixed(0)}%): '
        '\$${_calculateWithMarkup(_markupMid).toStringAsFixed(2)}',
      )
      ..writeln(
        'Premium (+${_markupHigh.toStringAsFixed(0)}%): '
        '\$${_calculateWithMarkup(_markupHigh).toStringAsFixed(2)}',
      );

    final client = _clientNameCtrl.text.trim();
    if (client.isNotEmpty) {
      buf
        ..writeln()
        ..writeln('Client: $client');
      final email = _clientEmailCtrl.text.trim();
      if (email.isNotEmpty) buf.writeln('Email: $email');
    }

    Share.share(buf.toString(), subject: '$_selectedService Estimate');
  }

  // ── Invoice ─────────────────────────────────────────────────────────────

  void _createInvoiceFromEstimate() {
    final laborCost = _calculateLaborCost();
    final totalCost = _calculateTotalCost();
    final multiplier = _complexityMultipliers[_complexity] ?? 1.0;

    final items = <InvoiceLineItem>[
      InvoiceLineItem(
        description:
            'Labor (${_hours.toStringAsFixed(1)} hrs @ '
            '\$${_hourlyRate.toStringAsFixed(0)} × '
            '${multiplier.toStringAsFixed(2)})',
        quantity: 1,
        unitPrice: laborCost,
      ),
    ];

    if (_materialCost > 0) {
      items.add(
        InvoiceLineItem(
          description: 'Materials',
          quantity: 1,
          unitPrice: _materialCost,
        ),
      );
    }

    final draft = InvoiceDraft.empty().copyWith(
      jobTitle: '$_selectedService estimate',
      jobDescription:
          'Complexity: $_complexity\n'
          'Estimated total: \$${totalCost.toStringAsFixed(2)}',
      clientName: _clientNameCtrl.text.trim(),
      clientEmail: _clientEmailCtrl.text.trim(),
      items: items,
    );

    context.push('/invoice-maker', extra: {'initialDraft': draft});
  }

  // ── Markup editor ───────────────────────────────────────────────────────

  Future<void> _editMarkups() async {
    double low = _markupLow;
    double mid = _markupMid;
    double high = _markupHigh;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Widget slider(String label, double val, ValueChanged<double> cb) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$label: ${val.toStringAsFixed(0)}%'),
                  Slider(
                    value: val,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: '${val.toStringAsFixed(0)}%',
                    onChanged: (v) => setLocal(() => cb(v)),
                  ),
                ],
              );
            }

            return AlertDialog(
              title: const Text('Customize Markups'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  slider('Budget-Friendly', low, (v) => low = v),
                  slider('Standard Rate', mid, (v) => mid = v),
                  slider('Premium', high, (v) => high = v),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true) {
      setState(() {
        _markupLow = low;
        _markupMid = mid;
        _markupHigh = high;
      });
    }
  }

  // ── Custom service ──────────────────────────────────────────────────────

  Future<void> _addCustomService() async {
    final nameCtrl = TextEditingController();
    final rateCtrl = TextEditingController(text: '50');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Custom Service'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Service Name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: rateCtrl,
              decoration: const InputDecoration(
                labelText: 'Hourly Rate (\$)',
                border: OutlineInputBorder(),
                prefixText: '\$ ',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true) {
      final name = nameCtrl.text.trim();
      final rate = double.tryParse(rateCtrl.text.trim()) ?? 50.0;
      if (name.isEmpty) return;
      setState(() {
        if (!_dynamicServices.contains(name)) _dynamicServices.add(name);
        _dynamicRates[name] = rate;
        _selectedService = name;
        _hourlyRate = rate;
        _rateCtrl.text = rate.toStringAsFixed(0);
      });
    }
    nameCtrl.dispose();
    rateCtrl.dispose();
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final laborCost = _calculateLaborCost();
    final totalCost = _calculateTotalCost();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pricing Calculator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => context.push('/saved-estimates'),
            tooltip: 'Saved Estimates',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: totalCost > 0 ? _shareEstimate : null,
            tooltip: 'Share Estimate',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveEstimate,
            tooltip: 'Save Estimate',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Card
            Card(
              color: scheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.calculate, color: scheme.onPrimaryContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Calculate project costs with industry-standard rates',
                        style: TextStyle(color: scheme.onPrimaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Client Details ──
            Text(
              'Client Details (optional)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _clientNameCtrl,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Client Name',
                      prefixIcon: Icon(Icons.person_outline),
                      isDense: true,
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _clientEmailCtrl,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Client Email',
                      prefixIcon: Icon(Icons.email_outlined),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Service Selection ──
            Text(
              'Service Type',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _loadingServices
                      ? const LinearProgressIndicator()
                      : DropdownButtonFormField<String>(
                          initialValue: _allServices.contains(_selectedService)
                              ? _selectedService
                              : _allServices.first,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.build),
                          ),
                          items: _allServices.map((s) {
                            final fromFirestore =
                                _dynamicRates.containsKey(s) &&
                                !_builtInServices.contains(s);
                            return DropdownMenuItem(
                              value: s,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(child: Text(s)),
                                  if (fromFirestore) ...[
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.cloud_outlined,
                                      size: 14,
                                      color: scheme.primary,
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedService = value;
                                _hourlyRate = _rateForService(value);
                                _rateCtrl.text = _hourlyRate.toStringAsFixed(0);
                              });
                            }
                          },
                        ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.add),
                  tooltip: 'Add custom service',
                  onPressed: _addCustomService,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Complexity Level
            Text(
              'Project Complexity',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Simple', label: Text('Simple')),
                ButtonSegment(value: 'Standard', label: Text('Standard')),
                ButtonSegment(value: 'Complex', label: Text('Complex')),
                ButtonSegment(value: 'Expert', label: Text('Expert')),
              ],
              selected: {_complexity},
              onSelectionChanged: (Set<String> selection) {
                setState(() {
                  _complexity = selection.first;
                });
              },
            ),
            const SizedBox(height: 4),
            Text(
              'Multiplier: ${(_complexityMultipliers[_complexity]! * 100).toInt()}%',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),

            const SizedBox(height: 24),

            // Hours Estimate
            Text(
              'Estimated Hours: ${_hours.toStringAsFixed(1)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Slider(
              value: _hours,
              min: 0.5,
              max: 40.0,
              divisions: 79,
              label: '${_hours.toStringAsFixed(1)} hrs',
              onChanged: (value) {
                setState(() {
                  _hours = value;
                });
              },
            ),

            const SizedBox(height: 24),

            // Hourly Rate
            Text('Hourly Rate', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _rateCtrl,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixText: '\$ ',
                suffixText: '/ hour',
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  _hourlyRate = double.tryParse(value) ?? 75.0;
                });
              },
            ),

            const SizedBox(height: 24),

            // Material Cost
            Text(
              'Material Cost',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _materialCtrl,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixText: '\$ ',
                hintText: '0',
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  _materialCost = double.tryParse(value) ?? 0.0;
                });
              },
            ),

            const SizedBox(height: 32),

            // Cost Breakdown
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cost Breakdown',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Divider(height: 24),
                    _buildCostRow(
                      'Labor Cost',
                      laborCost,
                      '${_hours.toStringAsFixed(1)} hrs × '
                          '\$${_hourlyRate.toStringAsFixed(0)} × '
                          '${(_complexityMultipliers[_complexity]! * 100).toInt()}%',
                    ),
                    const SizedBox(height: 12),
                    _buildCostRow('Material Cost', _materialCost, null),
                    const Divider(height: 24),
                    _buildCostRow('Base Total', totalCost, null, isTotal: true),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Pricing Suggestions (custom markups)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Pricing Suggestions',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.tune, size: 20),
                          tooltip: 'Customize markups',
                          onPressed: _editMarkups,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildPricingSuggestion(
                      'Budget-Friendly',
                      _calculateWithMarkup(_markupLow),
                      '+${_markupLow.toStringAsFixed(0)}% markup',
                      Colors.green,
                    ),
                    const SizedBox(height: 8),
                    _buildPricingSuggestion(
                      'Standard Market Rate',
                      _calculateWithMarkup(_markupMid),
                      '+${_markupMid.toStringAsFixed(0)}% markup',
                      Colors.blue,
                    ),
                    const SizedBox(height: 8),
                    _buildPricingSuggestion(
                      'Premium Service',
                      _calculateWithMarkup(_markupHigh),
                      '+${_markupHigh.toStringAsFixed(0)}% markup',
                      Colors.orange,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Create Invoice + Share row
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_outlined,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Turn this into an invoice',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Prefill an invoice from this estimate, then let AI polish the line items and terms.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _createInvoiceFromEstimate,
                            icon: const Icon(Icons.receipt_long_outlined),
                            label: const Text('Create AI Invoice'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: totalCost > 0 ? _shareEstimate : null,
                            icon: const Icon(Icons.share),
                            label: const Text('Share Estimate'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Tips Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: scheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Pricing Tips',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• Consider travel time and fuel costs\n'
                      '• Factor in tool wear and depreciation\n'
                      '• Include insurance and licensing fees\n'
                      '• Add buffer for unexpected complications\n'
                      '• Research local market rates',
                      style: TextStyle(
                        fontSize: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostRow(
    String label,
    double amount,
    String? details, {
    bool isTotal = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: isTotal ? 18 : 16,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            Text(
              '\$${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: isTotal ? 18 : 16,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                color: isTotal ? scheme.primary : null,
              ),
            ),
          ],
        ),
        if (details != null) ...[
          const SizedBox(height: 2),
          Text(
            details,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }

  Widget _buildPricingSuggestion(
    String label,
    double amount,
    String markup,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
              Text(
                markup,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
