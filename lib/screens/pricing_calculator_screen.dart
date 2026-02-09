import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/invoice_models.dart';
import 'invoice_maker_screen.dart';

class PricingCalculatorScreen extends StatefulWidget {
  const PricingCalculatorScreen({super.key});

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

  final List<String> _services = [
    'Painting',
    'Drywall Repair',
    'Pressure Washing',
  ];

  final Map<String, double> _serviceRates = {
    'Painting': 60.0,
    'Drywall Repair': 65.0,
    'Pressure Washing': 55.0,
  };

  final Map<String, double> _complexityMultipliers = {
    'Simple': 0.8,
    'Standard': 1.0,
    'Complex': 1.3,
    'Expert': 1.6,
  };

  @override
  void initState() {
    super.initState();
    _hourlyRate = _serviceRates[_selectedService] ?? 75.0;
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

  Future<void> _saveEstimate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('contractors')
          .doc(user.uid)
          .collection('saved_estimates')
          .add({
            'service': _selectedService,
            'complexity': _complexity,
            'hours': _hours,
            'hourlyRate': _hourlyRate,
            'materialCost': _materialCost,
            'laborCost': _calculateLaborCost(),
            'totalCost': _calculateTotalCost(),
            'createdAt': FieldValue.serverTimestamp(),
          });

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

  void _createInvoiceFromEstimate() {
    final laborCost = _calculateLaborCost();
    final totalCost = _calculateTotalCost();
    final multiplier = _complexityMultipliers[_complexity] ?? 1.0;

    final items = <InvoiceLineItem>[
      InvoiceLineItem(
        description:
            'Labor (${_hours.toStringAsFixed(1)} hrs @ \$${_hourlyRate.toStringAsFixed(0)} × ${multiplier.toStringAsFixed(2)})',
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
          'Complexity: $_complexity\nEstimated total: \$${totalCost.toStringAsFixed(2)}',
      items: items,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceMakerScreen(initialDraft: draft),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final laborCost = _calculateLaborCost();
    final totalCost = _calculateTotalCost();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pricing Calculator'),
        actions: [
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
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.calculate,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Calculate project costs with industry-standard rates',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Service Selection
            Text(
              'Service Type',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedService,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.build),
              ),
              items: _services.map((service) {
                return DropdownMenuItem(value: service, child: Text(service));
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedService = value;
                    _hourlyRate = _serviceRates[value] ?? 75.0;
                  });
                }
              },
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
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
              initialValue: _hourlyRate.toStringAsFixed(0),
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
              initialValue: _materialCost.toStringAsFixed(0),
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
                      '${_hours.toStringAsFixed(1)} hrs × \$${_hourlyRate.toStringAsFixed(0)} × ${(_complexityMultipliers[_complexity]! * 100).toInt()}%',
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

            // Pricing Suggestions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pricing Suggestions',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _buildPricingSuggestion(
                      'Budget-Friendly',
                      _calculateWithMarkup(10),
                      '+10% markup',
                      Colors.green,
                    ),
                    const SizedBox(height: 8),
                    _buildPricingSuggestion(
                      'Standard Market Rate',
                      _calculateWithMarkup(20),
                      '+20% markup',
                      Colors.blue,
                    ),
                    const SizedBox(height: 8),
                    _buildPricingSuggestion(
                      'Premium Service',
                      _calculateWithMarkup(30),
                      '+30% markup',
                      Colors.orange,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

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
                          color: Theme.of(context).colorScheme.primary,
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
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _createInvoiceFromEstimate,
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: const Text('Create AI invoice'),
                      ),
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
                        Icon(
                          Icons.lightbulb_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Pricing Tips',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
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
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                color: isTotal ? Theme.of(context).colorScheme.primary : null,
              ),
            ),
          ],
        ),
        if (details != null) ...[
          const SizedBox(height: 2),
          Text(
            details,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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
