import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/job_expense.dart';

class JobExpenseService {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  JobExpenseService({
    FirebaseFirestore? db,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  }) : _db = db ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _auth = auth ?? FirebaseAuth.instance;

  Stream<List<JobExpense>> streamExpensesForJob(String jobId) {
    return _db
        .collection('job_expenses')
        .where('jobId', isEqualTo: jobId)
        .snapshots()
        .map((snap) {
          final items = snap.docs.map(JobExpense.fromDoc).toList();
          items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return items;
        });
  }

  Stream<List<JobExpense>> streamExpensesForJobAndUser({
    required String jobId,
    required String userId,
  }) {
    return _db
        .collection('job_expenses')
        .where('jobId', isEqualTo: jobId)
        .where('createdByUid', isEqualTo: userId)
        .snapshots()
        .map((snap) {
          final items = snap.docs.map(JobExpense.fromDoc).toList();
          items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return items;
        });
  }

  Future<List<JobExpense>> fetchExpensesForJob(String jobId) async {
    final snap = await _db
        .collection('job_expenses')
        .where('jobId', isEqualTo: jobId)
        .get();

    final items = snap.docs.map(JobExpense.fromDoc).toList();
    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }

  Future<JobExpense> addExpense({
    required String jobId,
    required File imageFile,
    required String createdByRole,
    String? vendor,
    DateTime? receiptDate,
    double? total,
    double? tax,
    String currency = 'USD',
    String? notes,
    String? ocrText,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('You must be signed in to add an expense.');
    }

    final ref = _db.collection('job_expenses').doc();

    final storagePath = 'job_expenses/$jobId/${ref.id}.jpg';
    final uploadRef = _storage.ref().child(storagePath);

    final task = await uploadRef.putFile(
      imageFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final imageUrl = await task.ref.getDownloadURL();

    final expense = JobExpense(
      id: ref.id,
      jobId: jobId,
      createdByUid: uid,
      createdByRole: createdByRole,
      createdAt: DateTime.now(),
      currency: currency,
      vendor: vendor,
      receiptDate: receiptDate,
      total: total,
      tax: tax,
      notes: notes,
      imageUrl: imageUrl,
      ocrText: ocrText,
    );

    await ref.set(expense.toMap());
    return expense;
  }
}
