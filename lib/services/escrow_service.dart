import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/escrow_booking.dart';
import 'ai_pricing_service.dart';
import 'stripe_service.dart';

/// Manages the escrow lifecycle: create → fund → confirm → release.
class EscrowService {
  EscrowService._();
  static final EscrowService instance = EscrowService._();

  final _db = FirebaseFirestore.instance;

  static const String _collection = 'escrow_bookings';

  // ───────────────────────────────────── CREATE ─────────────────────────

  /// Create an escrow booking when the customer sees the AI price.
  ///
  /// Status starts as [EscrowStatus.offered].
  Future<String> createOffer({
    required String jobId,
    required String service,
    required String zip,
    required double aiPrice,
    required Map<String, double> priceBreakdown,
    required Map<String, dynamic> jobDetails,
    DateTime? priceLockExpiry,
    double? estimatedMarketPrice,
    double? savingsAmount,
    double? savingsPercent,
    double? discountPercent,
    double? originalAiPrice,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    final platformFee = _roundCents(aiPrice * AiPricingService.platformFeeRate);
    final contractorPayout = _roundCents(aiPrice - platformFee);

    final ref = _db.collection(_collection).doc();
    await ref.set({
      'jobId': jobId,
      'customerId': uid,
      'contractorId': null,
      'service': service,
      'zip': zip,
      'aiPrice': aiPrice,
      'platformFee': platformFee,
      'contractorPayout': contractorPayout,
      'status': EscrowStatus.offered.value,
      'jobDetails': jobDetails,
      'priceBreakdown': priceBreakdown,
      'createdAt': FieldValue.serverTimestamp(),
      if (priceLockExpiry != null)
        'priceLockExpiry': Timestamp.fromDate(priceLockExpiry),
      if (estimatedMarketPrice != null)
        'estimatedMarketPrice': estimatedMarketPrice,
      if (savingsAmount != null) 'savingsAmount': savingsAmount,
      if (savingsPercent != null) 'savingsPercent': savingsPercent,
      if (discountPercent != null) 'discountPercent': discountPercent,
      if (originalAiPrice != null) 'originalAiPrice': originalAiPrice,
      'premiumLeadCost': 3,
    });

    return ref.id;
  }

  // ───────────────────────────────── CUSTOMER ACCEPTS ───────────────────

  /// Customer accepts the AI price and "pays" → status becomes [funded].
  ///
  /// In production this would create a Stripe PaymentIntent and capture
  /// funds into a connected escrow account. For now we record the intent.
  Future<void> acceptAndFund({
    required String escrowId,
    String? stripePaymentIntentId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    // Verify caller is the escrow customer
    final snap = await _db.collection(_collection).doc(escrowId).get();
    if (snap.data()?['customerId'] != uid) {
      throw Exception('Only the customer can fund this escrow');
    }

    // Enforce price lock expiry
    final lockTs = snap.data()?['priceLockExpiry'] as Timestamp?;
    if (lockTs != null && DateTime.now().isAfter(lockTs.toDate())) {
      throw Exception(
        'This price offer has expired. Please request a new estimate.',
      );
    }

    final ref = _db.collection(_collection).doc(escrowId);
    await ref.update({
      'status': EscrowStatus.funded.value,
      'fundedAt': FieldValue.serverTimestamp(),
      if (stripePaymentIntentId != null)
        'stripePaymentIntentId': stripePaymentIntentId,
    });

    // Also update the job_request to mark it as booked via escrow
    final jobId = snap.data()?['jobId'] as String?;
    if (jobId != null && jobId.isNotEmpty) {
      await _db.collection('job_requests').doc(jobId).update({
        'status': 'escrow_funded',
        'escrowId': escrowId,
        'escrowPrice': snap.data()?['aiPrice'],
        'instantBook': true,
      });
    }
  }

  // ───────────────────────────────── CUSTOMER DECLINES ──────────────────

  /// Customer declines the AI price — wants contractor estimates instead.
  Future<void> decline(String escrowId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    final snap = await _db.collection(_collection).doc(escrowId).get();
    if (snap.data()?['customerId'] != uid) {
      throw Exception('Only the customer can decline this escrow');
    }

    await _db.collection(_collection).doc(escrowId).update({
      'status': EscrowStatus.declined.value,
    });
  }

  // ───────────────────────────── ASSIGN CONTRACTOR ──────────────────────

  /// Assign a contractor to the escrow booking.
  ///
  /// Called when a contractor claims the job that has an escrow.
  /// Deducts premium lead credits (3x) from the contractor.
  Future<void> assignContractor({
    required String escrowId,
    required String contractorId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    // Only the contractor being assigned can claim
    if (uid != contractorId) {
      throw Exception('You can only assign yourself to an escrow');
    }

    // Use a transaction to atomically check credits and deduct
    await _db.runTransaction((tx) async {
      final escrowRef = _db.collection(_collection).doc(escrowId);
      final escrowSnap = await tx.get(escrowRef);
      final premiumCost =
          (escrowSnap.data()?['premiumLeadCost'] as num?)?.toInt() ?? 3;

      final contractorRef = _db.collection('contractors').doc(contractorId);
      final contractorSnap = await tx.get(contractorRef);
      if (contractorSnap.exists) {
        final currentCredits =
            (contractorSnap.data()?['leadCredits'] as num?)?.toInt() ?? 0;
        if (currentCredits < premiumCost) {
          throw Exception(
            'Insufficient credits. Escrow leads require $premiumCost credits.',
          );
        }
        tx.update(contractorRef, {
          'leadCredits': FieldValue.increment(-premiumCost),
          'premiumLeadsUsed': FieldValue.increment(1),
        });
      }

      tx.update(escrowRef, {'contractorId': contractorId});
    });
  }

  // ──────────────────────────── CONFIRM COMPLETION ──────────────────────

  /// Customer confirms the job is done.
  Future<void> customerConfirm(String escrowId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    // Verify caller is the customer
    final snap = await _db.collection(_collection).doc(escrowId).get();
    if (snap.data()?['customerId'] != uid) {
      throw Exception('Only the customer can confirm completion');
    }

    final ref = _db.collection(_collection).doc(escrowId);
    await ref.update({
      'customerConfirmedAt': FieldValue.serverTimestamp(),
      'status': EscrowStatus.customerConfirmed.value,
    });

    // Check if both have confirmed
    await _tryRelease(escrowId);
  }

  /// Contractor confirms the job is done.
  Future<void> contractorConfirm(String escrowId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    // Verify caller is the contractor
    final snap = await _db.collection(_collection).doc(escrowId).get();
    if (snap.data()?['contractorId'] != uid) {
      throw Exception('Only the contractor can confirm completion');
    }

    final ref = _db.collection(_collection).doc(escrowId);
    await ref.update({
      'contractorConfirmedAt': FieldValue.serverTimestamp(),
      'status': EscrowStatus.contractorConfirmed.value,
    });

    // Check if both have confirmed
    await _tryRelease(escrowId);
  }

  /// If both customer and contractor have confirmed, release funds.
  Future<void> _tryRelease(String escrowId) async {
    final ref = _db.collection(_collection).doc(escrowId);

    // Use a transaction to prevent double-release from simultaneous confirms
    final released = await _db.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null) return false;

      // Already released — nothing to do
      if (data['status'] == EscrowStatus.released.value) return false;

      final customerDone = data['customerConfirmedAt'] != null;
      final contractorDone = data['contractorConfirmedAt'] != null;

      if (customerDone && contractorDone) {
        tx.update(ref, {
          'status': EscrowStatus.released.value,
          'releasedAt': FieldValue.serverTimestamp(),
        });
        return true;
      }
      return false;
    });

    if (released) {
      // Update job_request status (outside transaction — best effort)
      final snap = await ref.get();
      final jobId = snap.data()?['jobId'] as String?;
      if (jobId != null && jobId.isNotEmpty) {
        await _db.collection('job_requests').doc(jobId).update({
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
        });
      }

      // Trigger Stripe Transfer to contractor's connected account
      try {
        await StripeService().releaseEscrowFunds(escrowId: escrowId);
      } catch (e) {
        // Log but don't block — admin can retry payout manually
        debugPrint('Escrow payout failed for $escrowId: $e');
      }
    }
  }

  // ────────────────────────────── CANCEL ─────────────────────────────────

  /// Cancel an escrow booking and issue a Stripe refund.
  /// Only allowed before funds are released to the contractor.
  Future<void> cancel(String escrowId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    final ref = _db.collection(_collection).doc(escrowId);
    final snap = await ref.get();
    final data = snap.data();
    if (data == null) return;

    // Verify caller is the customer
    if (data['customerId'] != uid) {
      throw Exception('Only the customer can cancel this escrow');
    }

    final status = EscrowStatusX.fromString(data['status'] ?? '');
    if (status == EscrowStatus.released) {
      throw Exception('Cannot cancel — funds already released.');
    }

    final hasPaid =
        data['stripePaymentIntentId'] != null &&
        (data['stripePaymentIntentId'] as String).isNotEmpty;

    if (hasPaid) {
      // Issue real Stripe refund via Cloud Function
      await StripeService().refundEscrow(escrowId: escrowId);
      // The Cloud Function handles setting status to 'cancelled',
      // saving refund details, and resetting the job_request.
    } else {
      // No payment was made — just cancel locally
      await ref.update({'status': EscrowStatus.cancelled.value});

      final jobId = data['jobId'] as String?;
      if (jobId != null && jobId.isNotEmpty) {
        await _db.collection('job_requests').doc(jobId).update({
          'status': 'open',
          'escrowId': FieldValue.delete(),
          'escrowPrice': FieldValue.delete(),
        });
      }
    }
  }

  // ────────────────────────────── WATCHERS ───────────────────────────────

  /// Watch a single escrow booking.
  Stream<EscrowBooking?> watchBooking(String escrowId) {
    return _db.collection(_collection).doc(escrowId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return EscrowBooking.fromDoc(snap);
    });
  }

  /// Watch all escrow bookings for the current user (as customer).
  Stream<List<EscrowBooking>> watchCustomerBookings() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _db
        .collection(_collection)
        .where('customerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(EscrowBooking.fromDoc).toList());
  }

  /// Watch all escrow bookings assigned to the current contractor.
  Stream<List<EscrowBooking>> watchContractorBookings() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _db
        .collection(_collection)
        .where('contractorId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(EscrowBooking.fromDoc).toList());
  }

  /// Find an escrow booking by jobId.
  Future<EscrowBooking?> findByJobId(String jobId) async {
    final snap = await _db
        .collection(_collection)
        .where('jobId', isEqualTo: jobId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return EscrowBooking.fromDoc(snap.docs.first);
  }

  double _roundCents(double value) => (value * 100).round() / 100;

  // ────────────────────────────── POST-JOB RATING ──────────────────────

  /// Submit a price fairness rating after job completion.
  Future<void> submitRating({
    required String escrowId,
    required int rating,
    String? comment,
  }) async {
    if (rating < 1 || rating > 5) {
      throw Exception('Rating must be between 1 and 5');
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    // Verify caller is customer or contractor on this escrow
    final snap = await _db.collection(_collection).doc(escrowId).get();
    final data = snap.data();
    if (data == null) throw Exception('Escrow not found');
    if (data['customerId'] != uid && data['contractorId'] != uid) {
      throw Exception('Only participants can rate this escrow');
    }

    await _db.collection(_collection).doc(escrowId).update({
      'priceFairnessRating': rating,
      if (comment != null && comment.isNotEmpty) 'ratingComment': comment,
      'ratedAt': FieldValue.serverTimestamp(),
    });
  }
}
