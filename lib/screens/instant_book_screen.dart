import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/instant_book_service.dart';
import '../theme/proserve_theme.dart';

/// Screen for customers to instantly book a contractor's fixed-price package.
class InstantBookScreen extends StatefulWidget {
  const InstantBookScreen({
    super.key,
    required this.contractorId,
    required this.contractorName,
  });

  final String contractorId;
  final String contractorName;

  @override
  State<InstantBookScreen> createState() => _InstantBookScreenState();
}

class _InstantBookScreenState extends State<InstantBookScreen> {
  ServicePackage? _selectedPackage;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String _selectedTime = '09:00 AM';
  final _notesController = TextEditingController();
  bool _submitting = false;

  final List<String> _timeSlots = [
    '08:00 AM',
    '09:00 AM',
    '10:00 AM',
    '11:00 AM',
    '12:00 PM',
    '01:00 PM',
    '02:00 PM',
    '03:00 PM',
    '04:00 PM',
    '05:00 PM',
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _submit() async {
    if (_selectedPackage == null) return;

    setState(() => _submitting = true);
    try {
      final jobId = await InstantBookService.instance.bookPackage(
        package: _selectedPackage!,
        preferredDate: DateFormat('yyyy-MM-dd').format(_selectedDate),
        preferredTime: _selectedTime,
        notes: _notesController.text.trim(),
      );

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Booking Confirmed!'),
          content: Text(
            'Your booking with ${widget.contractorName} has been confirmed.\n\n'
            'Job ID: $jobId\n'
            'Date: ${DateFormat.yMMMd().format(_selectedDate)}\n'
            'Time: $_selectedTime',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // close dialog
                Navigator.pop(context); // back to profile
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Booking failed: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('Book ${widget.contractorName}')),
      body: StreamBuilder<List<ServicePackage>>(
        stream: InstantBookService.instance.watchPackages(widget.contractorId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final packages = snapshot.data ?? [];

          if (packages.isEmpty) {
            return const Center(
              child: Text('This contractor has no instant-book packages yet.'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select a Package',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),

                // Package cards
                ...packages.map((pkg) {
                  final selected = _selectedPackage?.id == pkg.id;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: selected
                          ? BorderSide(color: scheme.primary, width: 2)
                          : BorderSide.none,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _selectedPackage = pkg),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pkg.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    pkg.description,
                                    style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '~${pkg.estimatedMinutes} min',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '\$${pkg.price.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: scheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 24),

                // Date picker
                Text(
                  'Preferred Date',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(DateFormat.yMMMd().format(_selectedDate)),
                ),

                const SizedBox(height: 24),

                // Time picker
                Text(
                  'Preferred Time',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _timeSlots.map((slot) {
                    final selected = _selectedTime == slot;
                    return ChoiceChip(
                      label: Text(slot),
                      selected: selected,
                      onSelected: (_) => setState(() => _selectedTime = slot),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                // Notes
                Text(
                  'Notes (optional)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Any details the contractor should know...',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 32),

                // Submit
                SizedBox(
                  width: double.infinity,
                  child: ProServeCTAButton(
                    onPressed: _selectedPackage == null || _submitting
                        ? null
                        : _submit,
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _selectedPackage != null
                                ? 'Book Now — \$${_selectedPackage!.price.toStringAsFixed(2)}'
                                : 'Select a Package',
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
