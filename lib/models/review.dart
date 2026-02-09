import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String contractorId;
  final String? jobId;
  final int rating;
  final String comment;

  Review({
    required this.contractorId,
    required this.rating,
    required this.comment,
    this.jobId,
  });

  Map<String, dynamic> toMap() {
    return {
      'contractorId': contractorId,
      if (jobId != null) 'jobId': jobId,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    };
  }
}
