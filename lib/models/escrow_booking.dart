import 'package:cloud_firestore/cloud_firestore.dart';

/// Status values for an escrow booking lifecycle.
enum EscrowStatus {
  /// AI price offered, waiting for customer decision.
  offered,

  /// Customer accepted the AI price and paid — funds held in escrow.
  funded,

  /// Customer marked job complete.
  customerConfirmed,

  /// Contractor marked job complete.
  contractorConfirmed,

  /// Both parties confirmed → funds released to contractor.
  released,

  /// Customer declined the AI price — wants contractor estimates instead.
  declined,

  /// Booking was cancelled or disputed.
  cancelled,
}

extension EscrowStatusX on EscrowStatus {
  String get value => name;

  static EscrowStatus fromString(String s) {
    return EscrowStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => EscrowStatus.offered,
    );
  }
}

/// Represents an AI-priced instant booking with escrow.
class EscrowBooking {
  final String id;
  final String jobId;
  final String customerId;
  final String? contractorId;
  final String service;
  final String zip;
  final double aiPrice;
  final double platformFee; // 5% of aiPrice
  final double contractorPayout; // 95% of aiPrice
  final EscrowStatus status;
  final Map<String, dynamic> jobDetails;
  final DateTime createdAt;
  final DateTime? fundedAt;
  final DateTime? customerConfirmedAt;
  final DateTime? contractorConfirmedAt;
  final DateTime? releasedAt;
  final String? stripePaymentIntentId;
  final Map<String, double> priceBreakdown; // low, recommended, premium

  // ── Price Lock ──
  final DateTime? priceLockExpiry;

  // ── Savings ──
  final double? estimatedMarketPrice; // what contractors typically charge
  final double? savingsAmount; // estimatedMarketPrice - aiPrice
  final double? savingsPercent; // savings as percentage

  // ── Instant Booking Discount ──
  final double? discountPercent; // discount applied for instant booking
  final double? originalAiPrice; // price before discount

  // ── Post-Job Rating ──
  final int? priceFairnessRating; // 1-5 stars from customer
  final String? ratingComment;
  final DateTime? ratedAt;

  // ── Premium Lead ──
  final int premiumLeadCost; // credits charged to contractor (default 3)

  const EscrowBooking({
    required this.id,
    required this.jobId,
    required this.customerId,
    this.contractorId,
    required this.service,
    required this.zip,
    required this.aiPrice,
    required this.platformFee,
    required this.contractorPayout,
    required this.status,
    required this.jobDetails,
    required this.createdAt,
    this.fundedAt,
    this.customerConfirmedAt,
    this.contractorConfirmedAt,
    this.releasedAt,
    this.stripePaymentIntentId,
    this.priceBreakdown = const {},
    this.priceLockExpiry,
    this.estimatedMarketPrice,
    this.savingsAmount,
    this.savingsPercent,
    this.discountPercent,
    this.originalAiPrice,
    this.priceFairnessRating,
    this.ratingComment,
    this.ratedAt,
    this.premiumLeadCost = 3,
  });

  factory EscrowBooking.fromDoc(DocumentSnapshot doc) {
    final d = doc.data()! as Map<String, dynamic>;
    return EscrowBooking(
      id: doc.id,
      jobId: d['jobId'] as String? ?? '',
      customerId: d['customerId'] as String? ?? '',
      contractorId: d['contractorId'] as String?,
      service: d['service'] as String? ?? '',
      zip: d['zip'] as String? ?? '',
      aiPrice: (d['aiPrice'] as num?)?.toDouble() ?? 0,
      platformFee: (d['platformFee'] as num?)?.toDouble() ?? 0,
      contractorPayout: (d['contractorPayout'] as num?)?.toDouble() ?? 0,
      status: EscrowStatusX.fromString(d['status'] as String? ?? 'offered'),
      jobDetails: (d['jobDetails'] as Map<String, dynamic>?) ?? {},
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fundedAt: (d['fundedAt'] as Timestamp?)?.toDate(),
      customerConfirmedAt: (d['customerConfirmedAt'] as Timestamp?)?.toDate(),
      contractorConfirmedAt: (d['contractorConfirmedAt'] as Timestamp?)
          ?.toDate(),
      releasedAt: (d['releasedAt'] as Timestamp?)?.toDate(),
      stripePaymentIntentId: d['stripePaymentIntentId'] as String?,
      priceBreakdown: _parseBreakdown(d['priceBreakdown']),
      priceLockExpiry: (d['priceLockExpiry'] as Timestamp?)?.toDate(),
      estimatedMarketPrice: (d['estimatedMarketPrice'] as num?)?.toDouble(),
      savingsAmount: (d['savingsAmount'] as num?)?.toDouble(),
      savingsPercent: (d['savingsPercent'] as num?)?.toDouble(),
      discountPercent: (d['discountPercent'] as num?)?.toDouble(),
      originalAiPrice: (d['originalAiPrice'] as num?)?.toDouble(),
      priceFairnessRating: (d['priceFairnessRating'] as num?)?.toInt(),
      ratingComment: d['ratingComment'] as String?,
      ratedAt: (d['ratedAt'] as Timestamp?)?.toDate(),
      premiumLeadCost: (d['premiumLeadCost'] as num?)?.toInt() ?? 3,
    );
  }

  static Map<String, double> _parseBreakdown(dynamic raw) {
    if (raw is! Map) return {};
    return raw.map(
      (key, value) =>
          MapEntry(key.toString(), (value as num?)?.toDouble() ?? 0),
    );
  }

  Map<String, dynamic> toMap() => {
    'jobId': jobId,
    'customerId': customerId,
    'contractorId': contractorId,
    'service': service,
    'zip': zip,
    'aiPrice': aiPrice,
    'platformFee': platformFee,
    'contractorPayout': contractorPayout,
    'status': status.value,
    'jobDetails': jobDetails,
    'createdAt': Timestamp.fromDate(createdAt),
    'priceBreakdown': priceBreakdown,
    if (fundedAt != null) 'fundedAt': Timestamp.fromDate(fundedAt!),
    if (customerConfirmedAt != null)
      'customerConfirmedAt': Timestamp.fromDate(customerConfirmedAt!),
    if (contractorConfirmedAt != null)
      'contractorConfirmedAt': Timestamp.fromDate(contractorConfirmedAt!),
    if (releasedAt != null) 'releasedAt': Timestamp.fromDate(releasedAt!),
    if (stripePaymentIntentId != null)
      'stripePaymentIntentId': stripePaymentIntentId,
    if (priceLockExpiry != null)
      'priceLockExpiry': Timestamp.fromDate(priceLockExpiry!),
    if (estimatedMarketPrice != null)
      'estimatedMarketPrice': estimatedMarketPrice,
    if (savingsAmount != null) 'savingsAmount': savingsAmount,
    if (savingsPercent != null) 'savingsPercent': savingsPercent,
    if (discountPercent != null) 'discountPercent': discountPercent,
    if (originalAiPrice != null) 'originalAiPrice': originalAiPrice,
    if (priceFairnessRating != null)
      'priceFairnessRating': priceFairnessRating,
    if (ratingComment != null) 'ratingComment': ratingComment,
    if (ratedAt != null) 'ratedAt': Timestamp.fromDate(ratedAt!),
    'premiumLeadCost': premiumLeadCost,
  };

  /// Whether the price lock has expired.
  bool get isPriceLockExpired {
    if (priceLockExpiry == null) return false;
    return DateTime.now().isAfter(priceLockExpiry!);
  }

  /// Whether both parties have confirmed completion.
  bool get bothConfirmed =>
      customerConfirmedAt != null && contractorConfirmedAt != null;

  /// Whether this booking has been rated.
  bool get hasRating => priceFairnessRating != null;

  /// Human-readable status label.
  String get statusLabel {
    switch (status) {
      case EscrowStatus.offered:
        return 'Price Offered';
      case EscrowStatus.funded:
        return 'Payment Held in Escrow';
      case EscrowStatus.customerConfirmed:
        return 'Customer Confirmed';
      case EscrowStatus.contractorConfirmed:
        return 'Contractor Confirmed';
      case EscrowStatus.released:
        return 'Funds Released';
      case EscrowStatus.declined:
        return 'Declined';
      case EscrowStatus.cancelled:
        return 'Cancelled';
    }
  }
}
