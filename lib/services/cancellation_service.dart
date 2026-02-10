import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Possible cancellation reasons.
enum CancelReason {
  scheduleConflict,
  foundAnotherPro,
  tooExpensive,
  noLongerNeeded,
  other,
}

String cancelReasonLabel(CancelReason r) {
  switch (r) {
    case CancelReason.scheduleConflict:
      return 'Schedule conflict';
    case CancelReason.foundAnotherPro:
      return 'Found another contractor';
    case CancelReason.tooExpensive:
      return 'Too expensive';
    case CancelReason.noLongerNeeded:
      return 'No longer needed';
    case CancelReason.other:
      return 'Other';
  }
}

/// Refund eligibility rules.
enum RefundOutcome { fullRefund, partialRefund, noRefund }

class CancellationResult {
  final RefundOutcome refund;
  final double refundAmount;
  final String message;

  const CancellationResult({
    required this.refund,
    required this.refundAmount,
    required this.message,
  });
}

/// Service for handling job/booking cancellations with refund logic.
class CancellationService {
  CancellationService._();
  static final CancellationService instance = CancellationService._();

  final _firestore = FirebaseFirestore.instance;

  /// Computes the refund based on how far out the cancellation is.
  ///   - >48 h before scheduled date → full refund
  ///   - 24–48 h → 50 % refund
  ///   - <24 h → no refund
  CancellationResult computeRefund({
    required DateTime scheduledDate,
    required double jobPrice,
  }) {
    final now = DateTime.now();
    final diff = scheduledDate.difference(now);

    if (diff.inHours >= 48) {
      return CancellationResult(
        refund: RefundOutcome.fullRefund,
        refundAmount: jobPrice,
        message: 'Full refund — cancelled more than 48 hours in advance.',
      );
    } else if (diff.inHours >= 24) {
      final partial = (jobPrice * 0.5);
      return CancellationResult(
        refund: RefundOutcome.partialRefund,
        refundAmount: double.parse(partial.toStringAsFixed(2)),
        message: '50% refund — cancelled between 24 and 48 hours before.',
      );
    } else {
      return CancellationResult(
        refund: RefundOutcome.noRefund,
        refundAmount: 0,
        message: 'No refund — cancelled less than 24 hours before.',
      );
    }
  }

  /// Cancel a job request. Updates Firestore and returns the cancellation result.
  Future<CancellationResult> cancelJob({
    required String jobId,
    required String collection, // 'job_requests' or 'bookings'
    required CancelReason reason,
    required DateTime scheduledDate,
    required double jobPrice,
    String? additionalNotes,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    final result = computeRefund(
      scheduledDate: scheduledDate,
      jobPrice: jobPrice,
    );

    await _firestore.collection(collection).doc(jobId).update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
      'cancelledBy': uid,
      'cancelReason': reason.name,
      'cancelNotes': additionalNotes ?? '',
      'refundOutcome': result.refund.name,
      'refundAmount': result.refundAmount,
    });

    // If there's a refund, credit the customer's promo balance as a placeholder.
    // In production this would integrate with Stripe refunds.
    if (result.refundAmount > 0) {
      await _firestore.collection('users').doc(uid).set({
        'promoCredits': FieldValue.increment(result.refundAmount),
      }, SetOptions(merge: true));
    }

    return result;
  }
}
