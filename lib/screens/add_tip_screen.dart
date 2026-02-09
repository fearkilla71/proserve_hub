import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddTipScreen extends StatefulWidget {
  final String jobId;
  final String contractorId;
  final double jobAmount;

  const AddTipScreen({
    super.key,
    required this.jobId,
    required this.contractorId,
    required this.jobAmount,
  });

  @override
  State<AddTipScreen> createState() => _AddTipScreenState();
}

class _AddTipScreenState extends State<AddTipScreen> {
  double? _selectedTipPercentage;
  double? _customTipAmount;
  final TextEditingController _customController = TextEditingController();
  bool _isSubmitting = false;

  final List<double> _tipPercentages = [5, 10, 15, 20];

  double get _calculatedTip {
    if (_customTipAmount != null && _customTipAmount! > 0) {
      return _customTipAmount!;
    }
    if (_selectedTipPercentage != null) {
      return widget.jobAmount * (_selectedTipPercentage! / 100);
    }
    return 0;
  }

  double get _totalAmount => widget.jobAmount + _calculatedTip;

  Future<void> _submitTip() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_calculatedTip <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or enter a tip amount')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance
          .collection('job_requests')
          .doc(widget.jobId)
          .update({
            'tipAmount': _calculatedTip,
            'tipAddedAt': FieldValue.serverTimestamp(),
            'tipAddedBy': user.uid,
          });

      // Create tip payment record
      await FirebaseFirestore.instance.collection('payments').add({
        'type': 'tip',
        'jobId': widget.jobId,
        'contractorId': widget.contractorId,
        'customerId': user.uid,
        'amount': _calculatedTip,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Tip of \$${_calculatedTip.toStringAsFixed(2)} added!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding tip: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add a Tip')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Great work deserves recognition!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Add a tip to show your appreciation',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),

            // Job Amount
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Job Amount:', style: TextStyle(fontSize: 16)),
                    Text(
                      '\$${widget.jobAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Preset Tip Percentages
            Text(
              'Select a tip percentage:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _tipPercentages.map((percentage) {
                final isSelected =
                    _selectedTipPercentage == percentage &&
                    _customTipAmount == null;
                final tipAmount = widget.jobAmount * (percentage / 100);

                return ChoiceChip(
                  label: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$percentage%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimary
                              : null,
                        ),
                      ),
                      Text(
                        '\$${tipAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedTipPercentage = selected ? percentage : null;
                      _customTipAmount = null;
                      _customController.clear();
                    });
                  },
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Custom Tip Amount
            Text(
              'Or enter a custom amount:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _customController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Custom Tip Amount',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
                hintText: '0.00',
              ),
              onChanged: (value) {
                setState(() {
                  _customTipAmount = double.tryParse(value);
                  if (_customTipAmount != null && _customTipAmount! > 0) {
                    _selectedTipPercentage = null;
                  }
                });
              },
            ),

            const SizedBox(height: 32),

            // Total Summary
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Job Amount',
                          style: TextStyle(fontSize: 16),
                        ),
                        Text(
                          '\$${widget.jobAmount.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tip', style: TextStyle(fontSize: 16)),
                        Text(
                          '\$${_calculatedTip.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '\$${_totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting || _calculatedTip <= 0
                    ? null
                    : _submitTip,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Add Tip'),
              ),
            ),

            const SizedBox(height: 16),

            // Skip Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isSubmitting
                    ? null
                    : () => Navigator.pop(context, false),
                child: const Text('Skip for Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
