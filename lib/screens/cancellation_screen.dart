import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/cancellation_service.dart';

/// Screen that walks the customer through a cancellation/refund flow.
class CancellationScreen extends StatefulWidget {
  const CancellationScreen({
    super.key,
    required this.jobId,
    required this.collection,
    required this.scheduledDate,
    required this.jobPrice,
    required this.jobTitle,
  });

  /// Firestore doc ID of the job or booking.
  final String jobId;

  /// Collection name: 'job_requests' or 'bookings'.
  final String collection;

  /// When the job is scheduled for.
  final DateTime scheduledDate;

  /// Total price of the job (for refund calc).
  final double jobPrice;

  /// Display title (e.g. service name).
  final String jobTitle;

  @override
  State<CancellationScreen> createState() => _CancellationScreenState();
}

class _CancellationScreenState extends State<CancellationScreen> {
  CancelReason? _reason;
  final _notesController = TextEditingController();
  bool _submitting = false;
  CancellationResult? _preview;

  @override
  void initState() {
    super.initState();
    _preview = CancellationService.instance.computeRefund(
      scheduledDate: widget.scheduledDate,
      jobPrice: widget.jobPrice,
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason == null) return;
    setState(() => _submitting = true);

    try {
      final result = await CancellationService.instance.cancelJob(
        jobId: widget.jobId,
        collection: widget.collection,
        reason: _reason!,
        scheduledDate: widget.scheduledDate,
        jobPrice: widget.jobPrice,
        additionalNotes: _notesController.text.trim(),
      );

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Cancellation Confirmed'),
          content: Text(result.message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // dialog
                Navigator.pop(context); // back to detail
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Cancel Job')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Job summary
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.jobTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Scheduled: ${DateFormat.yMMMd().format(widget.scheduledDate)}',
                    ),
                    Text('Price: \$${widget.jobPrice.toStringAsFixed(2)}'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Refund preview
            if (_preview != null)
              Card(
                color: _preview!.refund == RefundOutcome.fullRefund
                    ? Colors.green.withValues(alpha: 0.1)
                    : _preview!.refund == RefundOutcome.partialRefund
                    ? Colors.orange.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        _preview!.refund == RefundOutcome.noRefund
                            ? Icons.cancel
                            : Icons.check_circle,
                        color: _preview!.refund == RefundOutcome.fullRefund
                            ? Colors.green
                            : _preview!.refund == RefundOutcome.partialRefund
                            ? Colors.orange
                            : Colors.red,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _preview!.refund == RefundOutcome.fullRefund
                                  ? 'Full Refund'
                                  : _preview!.refund ==
                                        RefundOutcome.partialRefund
                                  ? 'Partial Refund'
                                  : 'No Refund',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _preview!.message,
                              style: TextStyle(
                                fontSize: 13,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            if (_preview!.refundAmount > 0)
                              Text(
                                'Refund: \$${_preview!.refundAmount.toStringAsFixed(2)} credit',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: scheme.primary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Reason picker
            Text(
              'Why are you cancelling?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            RadioGroup<CancelReason>(
              groupValue: _reason,
              onChanged: (v) => setState(() => _reason = v),
              child: Column(
                children: CancelReason.values.map((r) {
                  return RadioListTile<CancelReason>(
                    title: Text(cancelReasonLabel(r)),
                    value: r,
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // Additional notes
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Additional notes (optional)',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 32),

            // Submit
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: scheme.error),
                onPressed: _reason == null || _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Confirm Cancellation'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
