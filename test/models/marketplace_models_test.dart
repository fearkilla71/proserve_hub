import 'package:flutter_test/flutter_test.dart';
import 'package:proserve_hub/models/marketplace_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('Bid', () {
    final now = DateTime(2026, 3, 18, 10, 0, 0);
    final expires = DateTime(2026, 3, 25, 10, 0, 0);

    test('toMap preserves all fields', () {
      final bid = Bid(
        id: 'b1',
        jobId: 'j1',
        contractorId: 'uid1',
        contractorName: 'Bob Builder',
        customerId: 'uid2',
        amount: 2500,
        currency: 'USD',
        description: 'Full exterior paint',
        estimatedDays: 5,
        status: 'pending',
        createdAt: now,
        expiresAt: expires,
        counterOfferId: null,
      );

      final map = bid.toMap();

      expect(map['jobId'], 'j1');
      expect(map['contractorId'], 'uid1');
      expect(map['contractorName'], 'Bob Builder');
      expect(map['customerId'], 'uid2');
      expect(map['amount'], 2500);
      expect(map['currency'], 'USD');
      expect(map['description'], 'Full exterior paint');
      expect(map['estimatedDays'], 5);
      expect(map['status'], 'pending');
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['expiresAt'], isA<Timestamp>());
      expect(map['counterOfferId'], isNull);
    });

    test('default currency is USD', () {
      final bid = Bid(
        id: 'b1',
        jobId: 'j1',
        contractorId: 'uid1',
        contractorName: 'X',
        customerId: 'uid2',
        amount: 100,
        description: 'Test',
        estimatedDays: 1,
        createdAt: now,
      );
      expect(bid.currency, 'USD');
      expect(bid.status, 'pending');
    });
  });

  group('Review', () {
    final now = DateTime(2026, 3, 18, 10, 0, 0);

    test('toMap preserves required fields', () {
      final review = Review(
        id: 'r1',
        jobId: 'j1',
        contractorId: 'uid1',
        customerId: 'uid2',
        customerName: 'Alice',
        rating: 4.5,
        comment: 'Great work!',
        photoUrls: ['https://example.com/photo.jpg'],
        createdAt: now,
        verified: true,
      );

      final map = review.toMap();
      expect(map['rating'], 4.5);
      expect(map['comment'], 'Great work!');
      expect(map['photoUrls'], hasLength(1));
      expect(map['verified'], isTrue);
    });

    test('toMap includes optional ratings when present', () {
      final review = Review(
        id: 'r1',
        jobId: 'j1',
        contractorId: 'uid1',
        customerId: 'uid2',
        customerName: 'Alice',
        rating: 5,
        qualityRating: 5,
        timelinessRating: 4.5,
        communicationRating: 5,
        comment: 'Perfect',
        photoUrls: [],
        createdAt: now,
      );

      final map = review.toMap();
      expect(map['qualityRating'], 5);
      expect(map['timelinessRating'], 4.5);
      expect(map['communicationRating'], 5);
    });

    test('toMap omits optional ratings when null', () {
      final review = Review(
        id: 'r1',
        jobId: 'j1',
        contractorId: 'uid1',
        customerId: 'uid2',
        customerName: 'Alice',
        rating: 4,
        comment: 'Good',
        photoUrls: [],
        createdAt: now,
      );

      final map = review.toMap();
      expect(map.containsKey('qualityRating'), isFalse);
      expect(map.containsKey('timelinessRating'), isFalse);
      expect(map.containsKey('communicationRating'), isFalse);
    });
  });

  group('Conversation', () {
    final now = DateTime(2026, 3, 18, 10, 0, 0);

    test('toMap round-trip preserves data', () {
      final convo = Conversation(
        id: 'conv1',
        participantIds: ['uid1', 'uid2'],
        participantNames: {'uid1': 'Alice', 'uid2': 'Bob'},
        jobId: 'j1',
        lastMessage: 'Hello!',
        lastMessageTime: now,
        createdAt: now,
        unreadCount: {'uid1': 0, 'uid2': 1},
      );

      final map = convo.toMap();
      expect(map['participantIds'], ['uid1', 'uid2']);
      expect(map['participantNames'], {'uid1': 'Alice', 'uid2': 'Bob'});
      expect(map['jobId'], 'j1');
      expect(map['lastMessage'], 'Hello!');
      expect(map['unreadCount'], {'uid1': 0, 'uid2': 1});
    });
  });

  group('Message', () {
    final now = DateTime(2026, 3, 18, 10, 0, 0);

    test('toMap includes audio fields when present', () {
      final msg = Message(
        id: 'm1',
        conversationId: 'conv1',
        senderId: 'uid1',
        senderName: 'Alice',
        text: '',
        audioUrl: 'https://example.com/voice.m4a',
        audioDurationMs: 5200,
        timestamp: now,
        isRead: false,
        readBy: {},
      );

      final map = msg.toMap();
      expect(map['audioUrl'], 'https://example.com/voice.m4a');
      expect(map['audioDurationMs'], 5200);
      expect(map['senderId'], 'uid1');
    });

    test('toMap includes file fields when present', () {
      final msg = Message(
        id: 'm1',
        conversationId: 'conv1',
        senderId: 'uid1',
        senderName: 'Alice',
        text: 'Check this out',
        fileUrl: 'https://example.com/doc.pdf',
        fileName: 'doc.pdf',
        timestamp: now,
        isRead: true,
        readBy: {'uid1': true},
      );

      final map = msg.toMap();
      expect(map['fileUrl'], 'https://example.com/doc.pdf');
      expect(map['fileName'], 'doc.pdf');
      expect(map['isRead'], isTrue);
    });
  });
}
