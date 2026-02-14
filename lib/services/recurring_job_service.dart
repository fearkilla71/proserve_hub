import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for managing recurring job schedules.
///
/// Firestore structure:
///   contractors/{contractorId}/recurring_jobs/{recurringId}
///     - serviceType: String
///     - clientName: String
///     - clientId: String?
///     - address: String
///     - frequency: String ('weekly' | 'biweekly' | 'monthly' | 'quarterly' | 'annually')
///     - price: double?
///     - notes: String?
///     - nextDueDate: Timestamp
///     - lastCompletedDate: Timestamp?
///     - active: bool
///     - createdAt: Timestamp
class RecurringJobService {
  RecurringJobService._();
  static final instance = RecurringJobService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _ref(String contractorId) => _db
      .collection('contractors')
      .doc(contractorId)
      .collection('recurring_jobs');

  /// Create a recurring job schedule.
  Future<String> createRecurringJob({
    required String serviceType,
    required String clientName,
    String? clientId,
    required String address,
    required String frequency,
    double? price,
    String? notes,
    required DateTime firstDueDate,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    final doc = _ref(uid).doc();
    await doc.set({
      'serviceType': serviceType,
      'clientName': clientName,
      'clientId': clientId,
      'address': address,
      'frequency': frequency,
      'price': price,
      'notes': notes,
      'nextDueDate': Timestamp.fromDate(firstDueDate),
      'lastCompletedDate': null,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Mark a recurring job as completed and advance to next due date.
  Future<void> markCompleted(String recurringId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    final docRef = _ref(uid).doc(recurringId);
    final snap = await docRef.get();
    if (!snap.exists) return;

    final data = snap.data()!;
    final frequency = data['frequency'] as String? ?? 'monthly';
    final currentDue = (data['nextDueDate'] as Timestamp).toDate();
    final nextDue = _calculateNextDue(currentDue, frequency);

    await docRef.update({
      'lastCompletedDate': FieldValue.serverTimestamp(),
      'nextDueDate': Timestamp.fromDate(nextDue),
    });
  }

  /// Toggle active status.
  Future<void> toggleActive(String recurringId, bool active) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');
    await _ref(uid).doc(recurringId).update({'active': active});
  }

  /// Delete a recurring job.
  Future<void> deleteRecurringJob(String recurringId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');
    await _ref(uid).doc(recurringId).delete();
  }

  /// Update a recurring job.
  Future<void> updateRecurringJob(
    String recurringId,
    Map<String, dynamic> data,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _ref(uid).doc(recurringId).update(data);
  }

  /// Stream all recurring jobs.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchRecurringJobs() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _ref(uid).orderBy('nextDueDate').snapshots();
  }

  /// Get jobs that are due soon (next 7 days).
  Future<List<Map<String, dynamic>>> getDueSoon() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    final weekFromNow = DateTime.now().add(const Duration(days: 7));
    final snap = await _ref(uid)
        .where('active', isEqualTo: true)
        .where(
          'nextDueDate',
          isLessThanOrEqualTo: Timestamp.fromDate(weekFromNow),
        )
        .orderBy('nextDueDate')
        .get();

    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  /// Create an actual job_request from a recurring job.
  Future<String> createJobFromRecurring(String recurringId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    final docSnap = await _ref(uid).doc(recurringId).get();
    if (!docSnap.exists) throw Exception('Recurring job not found');
    final data = docSnap.data()!;

    final jobRef = _db.collection('job_requests').doc();
    await jobRef.set({
      'contractorId': uid,
      'customerId': data['clientId'],
      'customerName': data['clientName'],
      'serviceType': data['serviceType'],
      'address': data['address'],
      'price': data['price'],
      'notes': data['notes'],
      'status': 'scheduled',
      'isRecurring': true,
      'recurringJobId': recurringId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await markCompleted(recurringId);
    return jobRef.id;
  }

  DateTime _calculateNextDue(DateTime current, String frequency) {
    switch (frequency) {
      case 'weekly':
        return current.add(const Duration(days: 7));
      case 'biweekly':
        return current.add(const Duration(days: 14));
      case 'monthly':
        return DateTime(current.year, current.month + 1, current.day);
      case 'quarterly':
        return DateTime(current.year, current.month + 3, current.day);
      case 'annually':
        return DateTime(current.year + 1, current.month, current.day);
      default:
        return DateTime(current.year, current.month + 1, current.day);
    }
  }

  static const frequencies = {
    'weekly': 'Weekly',
    'biweekly': 'Every 2 Weeks',
    'monthly': 'Monthly',
    'quarterly': 'Quarterly',
    'annually': 'Annually',
  };
}
