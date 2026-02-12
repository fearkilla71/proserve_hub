import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String text;
  final String? imageUrl;
  final String? fileUrl;
  final String? fileName;
  final String? audioUrl;
  final int? audioDurationMs;
  final DateTime timestamp;
  final bool isRead;
  final Map<String, bool> readBy;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.imageUrl,
    this.fileUrl,
    this.fileName,
    this.audioUrl,
    this.audioDurationMs,
    required this.timestamp,
    required this.isRead,
    required this.readBy,
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final durationRaw = data['audioDurationMs'];
    return Message(
      id: doc.id,
      conversationId: data['conversationId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Unknown',
      text: data['text'] ?? '',
      imageUrl: data['imageUrl'],
      fileUrl: data['fileUrl'],
      fileName: data['fileName'],
      audioUrl: data['audioUrl'],
      audioDurationMs: durationRaw is num ? durationRaw.toInt() : null,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      readBy: Map<String, bool>.from(data['readBy'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'imageUrl': imageUrl,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'audioUrl': audioUrl,
      'audioDurationMs': audioDurationMs,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': isRead,
      'readBy': readBy,
    };
  }
}

class Conversation {
  final String id;
  final List<String> participantIds;
  final Map<String, String> participantNames;
  final String? jobId;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final Map<String, int> unreadCount;

  Conversation({
    required this.id,
    required this.participantIds,
    required this.participantNames,
    this.jobId,
    this.lastMessage,
    this.lastMessageTime,
    this.lastMessageAt,
    this.createdAt,
    this.expiresAt,
    required this.unreadCount,
  });

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};

    DateTime? tsToDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      return null;
    }

    final lastTime = tsToDate(data['lastMessageTime']);
    final lastAt = tsToDate(data['lastMessageAt']);
    return Conversation(
      id: doc.id,
      participantIds: List<String>.from(data['participantIds'] ?? []),
      participantNames: Map<String, String>.from(
        data['participantNames'] ?? {},
      ),
      jobId: data['jobId'],
      lastMessage: data['lastMessage'],
      lastMessageTime: lastTime ?? lastAt,
      lastMessageAt: lastAt ?? lastTime,
      createdAt: tsToDate(data['createdAt']),
      expiresAt: tsToDate(data['expiresAt']),
      unreadCount: Map<String, int>.from(data['unreadCount'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participantIds': participantIds,
      'participantNames': participantNames,
      'jobId': jobId,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime != null
          ? Timestamp.fromDate(lastMessageTime!)
          : null,
      'lastMessageAt': lastMessageAt != null
          ? Timestamp.fromDate(lastMessageAt!)
          : (lastMessageTime != null
                ? Timestamp.fromDate(lastMessageTime!)
                : null),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'unreadCount': unreadCount,
    };
  }
}

class Bid {
  final String id;
  final String jobId;
  final String contractorId;
  final String contractorName;
  final String customerId;
  final double amount;
  final String currency;
  final String description;
  final int estimatedDays;
  final String status; // pending, accepted, rejected, countered
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String? counterOfferId;

  Bid({
    required this.id,
    required this.jobId,
    required this.contractorId,
    required this.contractorName,
    required this.customerId,
    required this.amount,
    this.currency = 'USD',
    required this.description,
    required this.estimatedDays,
    this.status = 'pending',
    required this.createdAt,
    this.expiresAt,
    this.counterOfferId,
  });

  factory Bid.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return Bid(
      id: doc.id,
      jobId: data['jobId'] ?? '',
      contractorId: data['contractorId'] ?? '',
      contractorName: data['contractorName'] ?? 'Unknown',
      customerId: data['customerId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      currency: data['currency'] ?? 'USD',
      description: data['description'] ?? '',
      estimatedDays: data['estimatedDays'] ?? 0,
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      counterOfferId: data['counterOfferId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'jobId': jobId,
      'contractorId': contractorId,
      'contractorName': contractorName,
      'customerId': customerId,
      'amount': amount,
      'currency': currency,
      'description': description,
      'estimatedDays': estimatedDays,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'counterOfferId': counterOfferId,
    };
  }
}

class Review {
  final String id;
  final String jobId;
  final String contractorId;
  final String customerId;
  final String customerName;
  final double rating;
  final double? qualityRating;
  final double? timelinessRating;
  final double? communicationRating;
  final String comment;
  final List<String> photoUrls;
  final DateTime createdAt;
  final String? contractorResponse;
  final DateTime? responseDate;
  final bool verified;

  Review({
    required this.id,
    required this.jobId,
    required this.contractorId,
    required this.customerId,
    required this.customerName,
    required this.rating,
    this.qualityRating,
    this.timelinessRating,
    this.communicationRating,
    required this.comment,
    required this.photoUrls,
    required this.createdAt,
    this.contractorResponse,
    this.responseDate,
    this.verified = false,
  });

  factory Review.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};

    double? numToDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return Review(
      id: doc.id,
      jobId: data['jobId'] ?? '',
      contractorId: data['contractorId'] ?? '',
      customerId: data['customerId'] ?? '',
      customerName: data['customerName'] ?? 'Anonymous',
      rating: (data['rating'] ?? 0).toDouble(),
      qualityRating: numToDouble(data['qualityRating']),
      timelinessRating: numToDouble(data['timelinessRating']),
      communicationRating: numToDouble(data['communicationRating']),
      comment: data['comment'] ?? '',
      photoUrls: List<String>.from(data['photoUrls'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      contractorResponse: data['contractorResponse'],
      responseDate: (data['responseDate'] as Timestamp?)?.toDate(),
      verified: data['verified'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'jobId': jobId,
      'contractorId': contractorId,
      'customerId': customerId,
      'customerName': customerName,
      'rating': rating,
      if (qualityRating != null) 'qualityRating': qualityRating,
      if (timelinessRating != null) 'timelinessRating': timelinessRating,
      if (communicationRating != null)
        'communicationRating': communicationRating,
      'comment': comment,
      'photoUrls': photoUrls,
      'createdAt': Timestamp.fromDate(createdAt),
      'contractorResponse': contractorResponse,
      'responseDate': responseDate != null
          ? Timestamp.fromDate(responseDate!)
          : null,
      'verified': verified,
    };
  }
}
