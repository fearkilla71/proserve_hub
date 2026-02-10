import 'package:flutter_test/flutter_test.dart';
import 'package:proserve_hub/models/invoice_models.dart';

void main() {
  // ── InvoiceLineItem ───────────────────────────────────────────────────

  group('InvoiceLineItem', () {
    group('total', () {
      test('computes quantity × unitPrice', () {
        const item = InvoiceLineItem(
          description: 'Service',
          quantity: 4,
          unitPrice: 25.0,
        );
        expect(item.total, 100.0);
      });
    });

    group('fromJson', () {
      test('parses valid JSON', () {
        final item = InvoiceLineItem.fromJson({
          'description': 'Repair',
          'quantity': 2,
          'unitPrice': 50.0,
        });
        expect(item.description, 'Repair');
        expect(item.quantity, 2);
        expect(item.unitPrice, 50.0);
      });

      test('clamps negative quantity to 1', () {
        final item = InvoiceLineItem.fromJson({
          'description': 'X',
          'quantity': -5,
          'unitPrice': 10.0,
        });
        expect(item.quantity, 1);
      });

      test('clamps zero quantity to 1', () {
        final item = InvoiceLineItem.fromJson({
          'description': 'X',
          'quantity': 0,
          'unitPrice': 10.0,
        });
        expect(item.quantity, 1);
      });

      test('defaults empty description to "Service"', () {
        final item = InvoiceLineItem.fromJson({
          'description': '   ',
          'quantity': 1,
          'unitPrice': 10.0,
        });
        expect(item.description, 'Service');
      });

      test('handles null description', () {
        final item = InvoiceLineItem.fromJson({
          'quantity': 1,
          'unitPrice': 10.0,
        });
        expect(item.description, 'Service');
      });

      test('handles non-numeric unitPrice', () {
        final item = InvoiceLineItem.fromJson({
          'description': 'X',
          'quantity': 1,
          'unitPrice': 'not-a-number',
        });
        expect(item.unitPrice, 0.0);
      });

      test('handles negative unitPrice', () {
        final item = InvoiceLineItem.fromJson({
          'description': 'X',
          'quantity': 1,
          'unitPrice': -10.0,
        });
        expect(item.unitPrice, 0.0);
      });

      test('handles infinity unitPrice', () {
        final item = InvoiceLineItem.fromJson({
          'description': 'X',
          'quantity': 1,
          'unitPrice': double.infinity,
        });
        expect(item.unitPrice, 0.0);
      });
    });

    group('toJson', () {
      test('includes computed total', () {
        const item = InvoiceLineItem(
          description: 'Tile',
          quantity: 3,
          unitPrice: 20.0,
        );
        final json = item.toJson();
        expect(json['total'], 60.0);
        expect(json['description'], 'Tile');
        expect(json['quantity'], 3);
        expect(json['unitPrice'], 20.0);
      });
    });

    group('copyWith', () {
      test('copies with changed fields', () {
        const original = InvoiceLineItem(
          description: 'A',
          quantity: 1,
          unitPrice: 10.0,
        );
        final copy = original.copyWith(quantity: 5, unitPrice: 20.0);
        expect(copy.description, 'A');
        expect(copy.quantity, 5);
        expect(copy.unitPrice, 20.0);
      });

      test('copies without changes', () {
        const original = InvoiceLineItem(
          description: 'B',
          quantity: 2,
          unitPrice: 30.0,
        );
        final copy = original.copyWith();
        expect(copy.description, original.description);
        expect(copy.quantity, original.quantity);
        expect(copy.unitPrice, original.unitPrice);
      });
    });
  });

  // ── InvoiceDraft ──────────────────────────────────────────────────────

  group('InvoiceDraft', () {
    group('empty', () {
      test('generates an invoice number', () {
        final draft = InvoiceDraft.empty();
        expect(draft.invoiceNumber, startsWith('INV-'));
        expect(draft.invoiceNumber.length, greaterThan(8));
      });

      test('defaults currency to USD', () {
        expect(InvoiceDraft.empty().currency, 'USD');
      });

      test('defaults paymentTerms', () {
        expect(InvoiceDraft.empty().paymentTerms, 'Due upon receipt');
      });

      test('contains one default line item', () {
        final draft = InvoiceDraft.empty();
        expect(draft.items.length, 1);
        expect(draft.items.first.description, 'Service');
      });

      test('uses provided business info', () {
        final draft = InvoiceDraft.empty(
          businessName: 'Acme',
          businessEmail: 'a@b.com',
          businessPhone: '555-1234',
        );
        expect(draft.businessName, 'Acme');
        expect(draft.businessEmail, 'a@b.com');
        expect(draft.businessPhone, '555-1234');
      });
    });

    group('subtotal', () {
      test('sums all item totals', () {
        final draft = InvoiceDraft.empty().copyWith(
          items: const [
            InvoiceLineItem(description: 'A', quantity: 2, unitPrice: 10),
            InvoiceLineItem(description: 'B', quantity: 1, unitPrice: 50),
          ],
        );
        expect(draft.subtotal, 70.0);
      });

      test('zero for empty items list', () {
        final draft = InvoiceDraft.empty().copyWith(items: const []);
        expect(draft.subtotal, 0.0);
      });
    });

    group('fromJson / toJson round-trip', () {
      test('round-trips correctly', () {
        final original = InvoiceDraft.empty().copyWith(
          businessName: 'Test Co',
          clientName: 'Jane Doe',
          jobTitle: 'Roof repair',
          dueDate: DateTime(2025, 6, 15),
          items: const [
            InvoiceLineItem(description: 'Labor', quantity: 8, unitPrice: 25),
          ],
        );

        final json = original.toJson();
        final restored = InvoiceDraft.fromJson(json);

        expect(restored.businessName, 'Test Co');
        expect(restored.clientName, 'Jane Doe');
        expect(restored.jobTitle, 'Roof repair');
        expect(restored.dueDate?.year, 2025);
        expect(restored.dueDate?.month, 6);
        expect(restored.dueDate?.day, 15);
        expect(restored.items.length, 1);
        expect(restored.items.first.quantity, 8);
        expect(restored.subtotal, 200.0);
      });

      test('fromJson with empty map uses sensible defaults', () {
        final draft = InvoiceDraft.fromJson({});
        expect(draft.invoiceNumber, startsWith('INV-'));
        expect(draft.currency, 'USD');
        expect(draft.paymentTerms, 'Due upon receipt');
        expect(draft.items, isNotEmpty);
      });

      test('fromJson reads dueDateISO', () {
        final draft = InvoiceDraft.fromJson({
          'dueDateISO': '2025-03-10T00:00:00.000',
        });
        expect(draft.dueDate?.year, 2025);
        expect(draft.dueDate?.month, 3);
      });

      test('fromJson falls back to dueDate field', () {
        final draft = InvoiceDraft.fromJson({'dueDate': '2024-12-25'});
        expect(draft.dueDate?.month, 12);
        expect(draft.dueDate?.day, 25);
      });
    });

    group('copyWith', () {
      test('updates only specified fields', () {
        final original = InvoiceDraft.empty();
        final updated = original.copyWith(clientName: 'Bob');
        expect(updated.clientName, 'Bob');
        expect(updated.invoiceNumber, original.invoiceNumber);
      });
    });
  });
}
