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
    'createdAt': FieldValue.serverTimestamp(),
    'priceBreakdown': priceBreakdown,
  };

  /// Whether both parties have confirmed completion.
  bool get bothConfirmed =>
      customerConfirmedAt != null && contractorConfirmedAt != null;

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
