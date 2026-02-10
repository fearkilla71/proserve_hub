import 'package:flutter_test/flutter_test.dart';
import 'package:proserve_hub/models/invoice_item.dart';

void main() {
  group('InvoiceItem', () {
    group('constructor & total', () {
      test('total is quantity × unitPrice', () {
        const item = InvoiceItem(
          description: 'Paint job',
          quantity: 3,
          unitPrice: 50.0,
        );
        expect(item.total, 150.0);
      });

      test('total with zero quantity', () {
        const item = InvoiceItem(
          description: 'Free item',
          quantity: 0,
          unitPrice: 100.0,
        );
        expect(item.total, 0.0);
      });

      test('total with fractional quantity', () {
        const item = InvoiceItem(
          description: 'Hours',
          quantity: 2.5,
          unitPrice: 40.0,
        );
        expect(item.total, 100.0);
      });
    });

    group('toMap', () {
      test('serialises all fields', () {
        const item = InvoiceItem(
          description: 'Drywall repair',
          quantity: 2,
          unitPrice: 75.0,
        );
        final map = item.toMap();
        expect(map['description'], 'Drywall repair');
        expect(map['quantity'], 2.0);
        expect(map['unitPrice'], 75.0);
        expect(map.length, 3);
      });
    });

    group('fromMap', () {
      test('round-trip through toMap', () {
        const original = InvoiceItem(
          description: 'Plumbing',
          quantity: 1,
          unitPrice: 200.0,
        );
        final restored = InvoiceItem.fromMap(original.toMap());
        expect(restored.description, original.description);
        expect(restored.quantity, original.quantity);
        expect(restored.unitPrice, original.unitPrice);
        expect(restored.total, original.total);
      });

      test('handles missing description', () {
        final item = InvoiceItem.fromMap({'quantity': 2, 'unitPrice': 10});
        expect(item.description, 'Item');
      });

      test('handles missing quantity', () {
        final item = InvoiceItem.fromMap({
          'description': 'Widget',
          'unitPrice': 10,
        });
        expect(item.quantity, 1.0);
      });

      test('handles missing unitPrice', () {
        final item = InvoiceItem.fromMap({
          'description': 'Widget',
          'quantity': 5,
        });
        expect(item.unitPrice, 0.0);
      });

      test('handles empty map', () {
        final item = InvoiceItem.fromMap({});
        expect(item.description, 'Item');
        expect(item.quantity, 1.0);
        expect(item.unitPrice, 0.0);
      });

      test('trims whitespace from description', () {
        final item = InvoiceItem.fromMap({
          'description': '  Electric work  ',
          'quantity': 1,
          'unitPrice': 50,
        });
        expect(item.description, 'Electric work');
      });

      test('casts int quantity to double', () {
        final item = InvoiceItem.fromMap({
          'description': 'Test',
          'quantity': 3, // int, not double
          'unitPrice': 10,
        });
        expect(item.quantity, 3.0);
      });
    });
  });
}
