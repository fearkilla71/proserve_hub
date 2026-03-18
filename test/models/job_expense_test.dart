import 'package:flutter_test/flutter_test.dart';
import 'package:proserve_hub/models/job_expense.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('JobExpense', () {
    final now = DateTime(2026, 3, 18, 10, 0, 0);

    test('toMap preserves all fields', () {
      final expense = JobExpense(
        id: 'exp1',
        jobId: 'j1',
        createdByUid: 'uid1',
        createdByRole: 'contractor',
        createdAt: now,
        currency: 'USD',
        vendor: 'Home Depot',
        receiptDate: now,
        total: 125.50,
        tax: 10.32,
        notes: '5 gal primer',
        imageUrl: 'https://example.com/receipt.jpg',
        ocrText: r'PRIMER 5GAL $125.50',
      );

      final map = expense.toMap();

      expect(map['jobId'], 'j1');
      expect(map['createdByUid'], 'uid1');
      expect(map['createdByRole'], 'contractor');
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['currency'], 'USD');
      expect(map['vendor'], 'Home Depot');
      expect(map['total'], 125.50);
      expect(map['tax'], 10.32);
      expect(map['notes'], '5 gal primer');
      expect(map['imageUrl'], 'https://example.com/receipt.jpg');
      expect(map['ocrText'], 'PRIMER 5GAL \$125.50');
    });

    test('toMap handles null optional fields', () {
      final expense = JobExpense(
        id: 'exp2',
        jobId: 'j2',
        createdByUid: 'uid1',
        createdByRole: 'customer',
        createdAt: now,
        currency: 'USD',
      );

      final map = expense.toMap();

      expect(map['vendor'], isNull);
      expect(map['receiptDate'], isNull);
      expect(map['total'], isNull);
      expect(map['tax'], isNull);
      expect(map['notes'], isNull);
      expect(map['imageUrl'], isNull);
      expect(map['ocrText'], isNull);
    });
  });
}
