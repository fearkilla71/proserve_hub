import 'package:flutter_test/flutter_test.dart';
import 'package:proserve_hub/models/invoice_item.dart';

void main() {
  group('InvoiceItem', () {
    test('toMap → fromMap round-trip preserves data', () {
      const item = InvoiceItem(
        description: 'Painting — living room',
        quantity: 3,
        unitPrice: 45.50,
      );

      final map = item.toMap();
      final restored = InvoiceItem.fromMap(map);

      expect(restored.description, item.description);
      expect(restored.quantity, item.quantity);
      expect(restored.unitPrice, item.unitPrice);
      expect(restored.total, item.total);
    });

    test('total computes correctly', () {
      const item = InvoiceItem(
        description: 'Drywall',
        quantity: 2,
        unitPrice: 100,
      );
      expect(item.total, 200.0);
    });

    test('fromMap handles missing fields', () {
      final item = InvoiceItem.fromMap({});
      expect(item.description, 'Item');
      expect(item.quantity, 1);
      expect(item.unitPrice, 0);
    });

    test('fromMap trims description', () {
      final item = InvoiceItem.fromMap({
        'description': '  Wall prep  ',
        'quantity': 1,
        'unitPrice': 20,
      });
      expect(item.description, 'Wall prep');
    });
  });
}
