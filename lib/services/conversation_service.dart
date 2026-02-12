import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/marketplace_models.dart';

class ConversationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Cached user display name to avoid re-fetching on every message send.
  static String? _cachedUserName;
  static String? _cachedUid;

  static Future<String> _getUserName(User user) async {
    if (_cachedUid == user.uid && _cachedUserName != null) {
      return _cachedUserName!;
    }
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    _cachedUserName =
        userDoc.data()?['name'] as String? ?? user.email ?? 'Unknown';
    _cachedUid = user.uid;
    return _cachedUserName!;
  }

  /// Gets or creates a conversation between two users.
  /// Uses a transaction to prevent duplicate conversations.
  /// Returns the conversation ID.
  static Future<String> getOrCreateConversation({
    required String otherUserId,
    required String otherUserName,
    String? jobId,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('User must be authenticated');
    }

    // Get current user name
    final currentUserName = await _getUserName(currentUser);

    // Use a transaction to prevent duplicate conversations
    final participantIds = [currentUser.uid, otherUserId]..sort();

    final conversationId = await _firestore.runTransaction<String>((tx) async {
      final existing = await _firestore
          .collection('conversations')
          .where('participantIds', isEqualTo: participantIds)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        return existing.docs.first.id;
      }

      // Create new conversation.
      // IMPORTANT: firestore.rules restricts conversation creation to ONLY these
      // keys. Do not add extra fields here unless rules are updated.
      final docRef = _firestore.collection('conversations').doc();
      tx.set(docRef, {
        'participantIds': participantIds,
        'participantNames': {
          currentUser.uid: currentUserName,
          otherUserId: otherUserName,
        },
        'jobId': jobId,
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': {currentUser.uid: 0, otherUserId: 0},
      });

      return docRef.id;
    });

    return conversationId;
  }

  /// Sends a message in a conversation
  static Future<void> sendMessage({
    required String conversationId,
    required String text,
    String? imageUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated');
    }

    final userName = await _getUserName(user);

    // Get conversation to find other user
    final conversationDoc = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .get();

    final conversation = Conversation.fromFirestore(conversationDoc);
    final otherUserId = conversation.participantIds.firstWhere(
      (id) => id != user.uid,
    );

    final message = Message(
      id: '',
      conversationId: conversationId,
      senderId: user.uid,
      senderName: userName,
      text: text,
      imageUrl: imageUrl,
      timestamp: DateTime.now(),
      isRead: false,
      readBy: {user.uid: true},
    );

    // Add message to subcollection
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .add(message.toMap());

    // Update conversation metadata.
    // firestore.rules only allows updating: lastMessage, lastMessageTime,
    // unreadCount, lastRead, typing.
    await _firestore.collection('conversations').doc(conversationId).update({
      'lastMessage': text.isNotEmpty ? text : 'Photo',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCount.$otherUserId': FieldValue.increment(1),
    });
  }

  /// Marks all messages in a conversation as read for the current user
  static Future<void> markAsRead(String conversationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _firestore.collection('conversations').doc(conversationId).update({
      'unreadCount.${user.uid}': 0,
    });
  }
}
