import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../utils/bottom_sheet_helper.dart';
import '../utils/optimistic_ui.dart';

class SubmitBidScreen extends StatefulWidget {
  final String jobId;

  const SubmitBidScreen({super.key, required this.jobId});

  @override
  State<SubmitBidScreen> createState() => _SubmitBidScreenState();
}

class _SubmitBidScreenState extends State<SubmitBidScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _daysController = TextEditingController(text: '7');

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  Future<void> _submitBid() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text);
    final estimatedDays = int.tryParse(_daysController.text);
    if (amount == null ||
        amount <= 0 ||
        estimatedDays == null ||
        estimatedDays <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount and timeline.'),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirmed = await BottomSheetHelper.showConfirmation(
      context: context,
      title: 'Submit Bid',
      message:
          'Submit your bid for \$${amount.toStringAsFixed(2)} with an estimated timeline of $estimatedDays day(s)?',
      confirmText: 'Submit Bid',
    );

    if (!confirmed || !mounted) return;

    try {
      final navigator = Navigator.of(context);
      await OptimisticUI.executeWithOptimism(
        context: context,
        loadingMessage: 'Submitting bid...',
        successMessage: 'Bid submitted successfully!',
        action: () async {
          // Get job and user info
          final jobDoc = await FirebaseFirestore.instance
              .collection('job_requests')
              .doc(widget.jobId)
              .get();

          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          if (!jobDoc.exists) {
            throw Exception('Job not found');
          }

          final jobData = jobDoc.data()!;
          final userData = userDoc.data() ?? {};

          final jobStatusSnapshot = {
            'status': jobData['status'],
            'escrowStatus': jobData['escrowStatus'],
            'service': jobData['service'],
            'location': jobData['location'],
            'createdAt': jobData['createdAt'],
          };

          // Create bid
          await FirebaseFirestore.instance.collection('bids').add({
            'jobId': widget.jobId,
            'contractorId': user.uid,
            'contractorName': userData['name'] ?? user.email ?? 'Unknown',
            'customerId': jobData['requesterUid'],
            'jobStatusSnapshot': jobStatusSnapshot,
            'amount': amount,
            'currency': 'USD',
            'description': _descriptionController.text.trim(),
            'estimatedDays': estimatedDays,
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
            'expiresAt': Timestamp.fromDate(
              DateTime.now().add(const Duration(days: 7)),
            ),
          });
        },
        onSuccess: () {
          if (context.mounted) navigator.pop();
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error submitting bid: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submit Bid')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Quote Details',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Bid Amount',
                  prefixText: '\$',
                  hintText: '0.00',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _daysController,
                decoration: const InputDecoration(
                  labelText: 'Estimated Completion Days',
                  suffixText: 'days',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter estimated days';
                  }
                  final days = int.tryParse(value);
                  if (days == null || days <= 0) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Describe your approach, experience, materials...',
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please provide a description';
                  }
                  if (value.trim().length < 20) {
                    return 'Please provide more details (at least 20 characters)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Tips for a Great Bid',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Be specific about what\'s included\n'
                        '• Mention your relevant experience\n'
                        '• Explain your approach\n'
                        '• List materials you\'ll use\n'
                        '• Be realistic with timing',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitBid,
                child: const Text('Submit Bid'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
