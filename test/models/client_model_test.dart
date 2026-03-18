import 'package:flutter_test/flutter_test.dart';
import 'package:proserve_hub/models/client_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('SavedClient', () {
    final now = DateTime(2026, 3, 18, 12, 0, 0);

    test('toJson round-trip preserves all fields', () {
      final client = SavedClient(
        id: 'c1',
        name: 'Jane Doe',
        email: 'jane@example.com',
        phone: '555-1234',
        address: '123 Main St',
        notes: 'VIP customer',
        createdAt: now,
        updatedAt: now,
      );

      final json = client.toJson();

      expect(json['name'], 'Jane Doe');
      expect(json['email'], 'jane@example.com');
      expect(json['phone'], '555-1234');
      expect(json['address'], '123 Main St');
      expect(json['notes'], 'VIP customer');
      expect(json['createdAt'], isA<Timestamp>());
      expect(json['updatedAt'], isA<Timestamp>());
    });

    test('copyWith overrides specific fields', () {
      final client = SavedClient(
        id: 'c1',
        name: 'Jane',
        createdAt: now,
        updatedAt: now,
      );

      final updated = client.copyWith(name: 'Jane Doe', phone: '555-0000');

      expect(updated.name, 'Jane Doe');
      expect(updated.phone, '555-0000');
      expect(updated.id, 'c1');
      expect(updated.email, '');
    });

    test('displayLabel formats correctly', () {
      final client = SavedClient(
        id: 'c1',
        name: 'Bob',
        email: 'bob@x.com',
        phone: '555',
        createdAt: now,
        updatedAt: now,
      );
      expect(client.displayLabel, 'Bob • bob@x.com • 555');
    });

    test('displayLabel with only name', () {
      final client = SavedClient(
        id: 'c1',
        name: 'Bob',
        createdAt: now,
        updatedAt: now,
      );
      expect(client.displayLabel, 'Bob');
    });
  });
}
