import 'package:flutter_test/flutter_test.dart';
import 'package:proserve_hub/models/escrow_booking.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('EscrowStatus', () {
    test('fromString returns correct enum', () {
      expect(EscrowStatusX.fromString('funded'), EscrowStatus.funded);
      expect(EscrowStatusX.fromString('released'), EscrowStatus.released);
      expect(
        EscrowStatusX.fromString('payoutFailed'),
        EscrowStatus.payoutFailed,
      );
    });

    test('fromString defaults to offered for unknown', () {
      expect(EscrowStatusX.fromString('garbage'), EscrowStatus.offered);
      expect(EscrowStatusX.fromString(''), EscrowStatus.offered);
    });

    test('value returns enum name', () {
      expect(EscrowStatus.funded.value, 'funded');
      expect(EscrowStatus.cancelled.value, 'cancelled');
    });
  });

  group('EscrowBooking', () {
    final now = DateTime(2026, 3, 18, 12, 0, 0);

    test('toMap preserves core fields', () {
      final booking = EscrowBooking(
        id: 'esc1',
        jobId: 'j1',
        customerId: 'c1',
        contractorId: 'con1',
        service: 'Interior Painting',
        zip: '77093',
        aiPrice: 1200,
        platformFee: 60,
        contractorPayout: 1140,
        status: EscrowStatus.funded,
        jobDetails: {'rooms': 3},
        createdAt: now,
        fundedAt: now,
        premiumLeadCost: 5,
      );

      final map = booking.toMap();

      expect(map['jobId'], 'j1');
      expect(map['customerId'], 'c1');
      expect(map['contractorId'], 'con1');
      expect(map['service'], 'Interior Painting');
      expect(map['zip'], '77093');
      expect(map['aiPrice'], 1200);
      expect(map['platformFee'], 60);
      expect(map['contractorPayout'], 1140);
      expect(map['status'], 'funded');
      expect(map['premiumLeadCost'], 5);
      expect(map['fundedAt'], isA<Timestamp>());
    });

    test('toMap omits null optional fields', () {
      final booking = EscrowBooking(
        id: 'esc2',
        jobId: 'j2',
        customerId: 'c2',
        service: 'Exterior Painting',
        zip: '77093',
        aiPrice: 2000,
        platformFee: 100,
        contractorPayout: 1900,
        status: EscrowStatus.offered,
        jobDetails: {},
        createdAt: now,
      );

      final map = booking.toMap();

      expect(map.containsKey('fundedAt'), isFalse);
      expect(map.containsKey('customerConfirmedAt'), isFalse);
      expect(map.containsKey('contractorConfirmedAt'), isFalse);
      expect(map.containsKey('releasedAt'), isFalse);
      expect(map.containsKey('stripePaymentIntentId'), isFalse);
      expect(map.containsKey('estimatedMarketPrice'), isFalse);
    });

    test('computed getters work correctly', () {
      final booking = EscrowBooking(
        id: 'esc3',
        jobId: 'j3',
        customerId: 'c3',
        service: 'Painting',
        zip: '77093',
        aiPrice: 500,
        platformFee: 25,
        contractorPayout: 475,
        status: EscrowStatus.released,
        jobDetails: {},
        createdAt: now,
        customerConfirmedAt: now,
        contractorConfirmedAt: now,
        priceFairnessRating: 4,
        priceLockExpiry: DateTime(2020, 1, 1), // expired
      );

      expect(booking.bothConfirmed, isTrue);
      expect(booking.hasRating, isTrue);
      expect(booking.isPriceLockExpired, isTrue);
    });

    test('statusLabel returns human-readable string', () {
      final booking = EscrowBooking(
        id: 'x',
        jobId: 'j',
        customerId: 'c',
        service: 's',
        zip: '0',
        aiPrice: 0,
        platformFee: 0,
        contractorPayout: 0,
        status: EscrowStatus.payoutPending,
        jobDetails: {},
        createdAt: now,
      );

      expect(booking.statusLabel, 'Payout Processing');
    });
  });
}
