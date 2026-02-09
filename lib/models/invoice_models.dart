import 'dart:math';

typedef JsonMap = Map<String, dynamic>;

class InvoiceLineItem {
  final String description;
  final int quantity;
  final double unitPrice;

  const InvoiceLineItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
  });

  double get total => quantity * unitPrice;

  InvoiceLineItem copyWith({
    String? description,
    int? quantity,
    double? unitPrice,
  }) {
    return InvoiceLineItem(
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }

  static InvoiceLineItem fromJson(JsonMap json) {
    final description = (json['description'] ?? '').toString().trim();
    final qtyRaw = json['quantity'];
    final priceRaw = json['unitPrice'];

    final quantity = qtyRaw is num ? qtyRaw.toInt() : 1;
    final unitPrice = priceRaw is num ? priceRaw.toDouble() : 0.0;

    return InvoiceLineItem(
      description: description.isEmpty ? 'Service' : description,
      quantity: quantity <= 0 ? 1 : quantity,
      unitPrice: unitPrice.isFinite && unitPrice >= 0 ? unitPrice : 0.0,
    );
  }

  JsonMap toJson() {
    return {
      'description': description,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'total': total,
    };
  }
}

class InvoiceDraft {
  final String invoiceNumber;
  final String businessName;
  final String businessEmail;
  final String businessPhone;
  final String clientName;
  final String clientEmail;
  final String clientPhone;
  final String clientAddress;
  final String jobTitle;
  final String jobDescription;
  final String notes;
  final String paymentTerms;
  final DateTime? dueDate;
  final String currency;
  final List<InvoiceLineItem> items;

  const InvoiceDraft({
    required this.invoiceNumber,
    required this.businessName,
    required this.businessEmail,
    required this.businessPhone,
    required this.clientName,
    required this.clientEmail,
    required this.clientPhone,
    required this.clientAddress,
    required this.jobTitle,
    required this.jobDescription,
    required this.notes,
    required this.paymentTerms,
    required this.dueDate,
    required this.currency,
    required this.items,
  });

  double get subtotal => items.fold<double>(0, (s, it) => s + it.total);

  InvoiceDraft copyWith({
    String? invoiceNumber,
    String? businessName,
    String? businessEmail,
    String? businessPhone,
    String? clientName,
    String? clientEmail,
    String? clientPhone,
    String? clientAddress,
    String? jobTitle,
    String? jobDescription,
    String? notes,
    String? paymentTerms,
    DateTime? dueDate,
    String? currency,
    List<InvoiceLineItem>? items,
  }) {
    return InvoiceDraft(
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      businessName: businessName ?? this.businessName,
      businessEmail: businessEmail ?? this.businessEmail,
      businessPhone: businessPhone ?? this.businessPhone,
      clientName: clientName ?? this.clientName,
      clientEmail: clientEmail ?? this.clientEmail,
      clientPhone: clientPhone ?? this.clientPhone,
      clientAddress: clientAddress ?? this.clientAddress,
      jobTitle: jobTitle ?? this.jobTitle,
      jobDescription: jobDescription ?? this.jobDescription,
      notes: notes ?? this.notes,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      dueDate: dueDate ?? this.dueDate,
      currency: currency ?? this.currency,
      items: items ?? this.items,
    );
  }

  static InvoiceDraft empty({
    String businessName = '',
    String businessEmail = '',
    String businessPhone = '',
  }) {
    final r = Random();
    final invoiceNumber =
        'INV-${DateTime.now().year}-${100000 + r.nextInt(899999)}';

    return InvoiceDraft(
      invoiceNumber: invoiceNumber,
      businessName: businessName,
      businessEmail: businessEmail,
      businessPhone: businessPhone,
      clientName: '',
      clientEmail: '',
      clientPhone: '',
      clientAddress: '',
      jobTitle: '',
      jobDescription: '',
      notes: '',
      paymentTerms: 'Due upon receipt',
      dueDate: null,
      currency: 'USD',
      items: const [
        InvoiceLineItem(description: 'Service', quantity: 1, unitPrice: 0.0),
      ],
    );
  }

  static InvoiceDraft fromJson(JsonMap json) {
    final invoiceNumber = (json['invoiceNumber'] ?? '').toString().trim();
    final businessName = (json['businessName'] ?? '').toString().trim();
    final businessEmail = (json['businessEmail'] ?? '').toString().trim();
    final businessPhone = (json['businessPhone'] ?? '').toString().trim();
    final clientName = (json['clientName'] ?? '').toString().trim();
    final clientEmail = (json['clientEmail'] ?? '').toString().trim();
    final clientPhone = (json['clientPhone'] ?? '').toString().trim();
    final clientAddress = (json['clientAddress'] ?? '').toString().trim();
    final jobTitle = (json['jobTitle'] ?? '').toString().trim();
    final jobDescription = (json['jobDescription'] ?? '').toString().trim();
    final notes = (json['notes'] ?? '').toString().trim();
    final paymentTerms = (json['paymentTerms'] ?? '').toString().trim();
    final currency = (json['currency'] ?? 'USD').toString().trim();

    DateTime? dueDate;
    final dueDateRaw = (json['dueDateISO'] ?? json['dueDate'] ?? '').toString();
    if (dueDateRaw.trim().isNotEmpty) {
      dueDate = DateTime.tryParse(dueDateRaw.trim());
    }

    final itemsRaw = json['items'];
    final items = <InvoiceLineItem>[];
    if (itemsRaw is List) {
      for (final it in itemsRaw) {
        if (it is Map) {
          items.add(
            InvoiceLineItem.fromJson(
              it.map((k, v) => MapEntry(k.toString(), v)),
            ),
          );
        }
      }
    }

    return InvoiceDraft(
      invoiceNumber: invoiceNumber.isEmpty
          ? InvoiceDraft.empty().invoiceNumber
          : invoiceNumber,
      businessName: businessName,
      businessEmail: businessEmail,
      businessPhone: businessPhone,
      clientName: clientName,
      clientEmail: clientEmail,
      clientPhone: clientPhone,
      clientAddress: clientAddress,
      jobTitle: jobTitle,
      jobDescription: jobDescription,
      notes: notes,
      paymentTerms: paymentTerms.isEmpty ? 'Due upon receipt' : paymentTerms,
      dueDate: dueDate,
      currency: currency.isEmpty ? 'USD' : currency,
      items: items.isEmpty
          ? const [
              InvoiceLineItem(
                description: 'Service',
                quantity: 1,
                unitPrice: 0.0,
              ),
            ]
          : items,
    );
  }

  JsonMap toJson() {
    return {
      'invoiceNumber': invoiceNumber,
      'businessName': businessName,
      'businessEmail': businessEmail,
      'businessPhone': businessPhone,
      'clientName': clientName,
      'clientEmail': clientEmail,
      'clientPhone': clientPhone,
      'clientAddress': clientAddress,
      'jobTitle': jobTitle,
      'jobDescription': jobDescription,
      'notes': notes,
      'paymentTerms': paymentTerms,
      'dueDateISO': dueDate?.toIso8601String(),
      'currency': currency,
      'items': items.map((x) => x.toJson()).toList(),
      'subtotal': subtotal,
    };
  }
}
