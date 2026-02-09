import 'package:cloud_firestore/cloud_firestore.dart';

class JobExpense {
  final String id;
  final String jobId;

  final String createdByUid;
  final String createdByRole;

  final DateTime createdAt;
  final String? vendor;
  final DateTime? receiptDate;
  final double? total;
  final double? tax;
  final String currency;
  final String? notes;

  final String? imageUrl;
  final String? ocrText;

  const JobExpense({
    required this.id,
    required this.jobId,
    required this.createdByUid,
    required this.createdByRole,
    required this.createdAt,
    required this.currency,
    this.vendor,
    this.receiptDate,
    this.total,
    this.tax,
    this.notes,
    this.imageUrl,
    this.ocrText,
  });

  factory JobExpense.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};

    DateTime? toDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    double? toDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return null;
    }

    return JobExpense(
      id: doc.id,
      jobId: (data['jobId'] as String?)?.trim() ?? '',
      createdByUid: (data['createdByUid'] as String?)?.trim() ?? '',
      createdByRole: (data['createdByRole'] as String?)?.trim() ?? '',
      createdAt: toDate(data['createdAt']) ?? DateTime.now(),
      currency: (data['currency'] as String?)?.trim().toUpperCase() ?? 'USD',
      vendor: (data['vendor'] as String?)?.trim(),
      receiptDate: toDate(data['receiptDate']),
      total: toDouble(data['total']),
      tax: toDouble(data['tax']),
      notes: (data['notes'] as String?)?.trim(),
      imageUrl: (data['imageUrl'] as String?)?.trim(),
      ocrText: (data['ocrText'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'jobId': jobId,
      'createdByUid': createdByUid,
      'createdByRole': createdByRole,
      'createdAt': Timestamp.fromDate(createdAt),
      'vendor': vendor,
      'receiptDate': receiptDate == null
          ? null
          : Timestamp.fromDate(receiptDate!),
      'total': total,
      'tax': tax,
      'currency': currency,
      'notes': notes,
      'imageUrl': imageUrl,
      'ocrText': ocrText,
    };
  }
}
