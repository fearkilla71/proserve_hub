/// A single line item on an invoice.
class InvoiceItem {
  final String description;
  final double quantity;
  final double unitPrice;

  const InvoiceItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
  });

  double get total => quantity * unitPrice;

  Map<String, dynamic> toMap() => {
    'description': description,
    'quantity': quantity,
    'unitPrice': unitPrice,
  };

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      description: (map['description'] as String?)?.trim() ?? 'Item',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1,
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0,
    );
  }
}
