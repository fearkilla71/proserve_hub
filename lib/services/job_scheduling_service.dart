import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for scheduling jobs on the contractor's calendar.
///
/// Firestore structure:
///   contractors/{contractorId}/scheduled_jobs/{scheduleId}
///     - jobId: String
///     - jobTitle: String
///     - clientName: String
///     - date: Timestamp (day)
///     - startSlot: String (e.g. '09:00 AM')
///     - endSlot: String (e.g. '12:00 PM')
///     - address: String?
///     - notes: String?
///     - status: String ('scheduled' | 'in_progress' | 'completed')
///     - createdAt: Timestamp
class JobSchedulingService {
  JobSchedulingService._();
  static final instance = JobSchedulingService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _schedRef(String contractorId) =>
      _db
          .collection('contractors')
          .doc(contractorId)
          .collection('scheduled_jobs');

  /// Schedule a job to specific time slots on a date.
  Future<String> scheduleJob({
    required String jobId,
    required String jobTitle,
    required String clientName,
    required DateTime date,
    required String startSlot,
    required String endSlot,
    String? address,
    String? notes,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    // Check for conflicts.
    final conflicts = await getScheduledJobsForDate(date);
    for (final existing in conflicts) {
      if (_slotsOverlap(
        startSlot,
        endSlot,
        existing['startSlot'] as String,
        existing['endSlot'] as String,
      )) {
        throw Exception(
          'Time conflict with "${existing['jobTitle']}" '
          '(${existing['startSlot']} – ${existing['endSlot']})',
        );
      }
    }

    final docRef = _schedRef(uid).doc();
    await docRef.set({
      'jobId': jobId,
      'jobTitle': jobTitle,
      'clientName': clientName,
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'startSlot': startSlot,
      'endSlot': endSlot,
      'address': address,
      'notes': notes,
      'status': 'scheduled',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Mark slots as booked in availability.
    await _markSlotsBooked(uid, date, startSlot, endSlot, jobTitle);

    return docRef.id;
  }

  /// Get all scheduled jobs for a specific date.
  Future<List<Map<String, dynamic>>> getScheduledJobsForDate(
    DateTime date,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final snap = await _schedRef(uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .where('date', isLessThan: Timestamp.fromDate(dayEnd))
        .orderBy('date')
        .get();

    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  /// Stream upcoming scheduled jobs (next 14 days).
  Stream<QuerySnapshot<Map<String, dynamic>>> watchUpcomingJobs() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 14));

    return _schedRef(uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .orderBy('date')
        .snapshots();
  }

  /// Get active/accepted jobs that can be scheduled.
  Future<List<Map<String, dynamic>>> getSchedulableJobs() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    final snap = await _db
        .collection('job_requests')
        .where('contractorId', isEqualTo: uid)
        .where('status', whereIn: ['accepted', 'in_progress', 'scheduled'])
        .orderBy('createdAt', descending: true)
        .get();

    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  /// Update a scheduled job's status.
  Future<void> updateStatus(String scheduleId, String status) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');
    await _schedRef(uid).doc(scheduleId).update({'status': status});
  }

  /// Remove a scheduled job.
  Future<void> removeScheduledJob(String scheduleId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');
    await _schedRef(uid).doc(scheduleId).delete();
  }

  /// Check if time slots overlap.
  bool _slotsOverlap(String startA, String endA, String startB, String endB) {
    final a1 = slotToMinutes(startA);
    final a2 = slotToMinutes(endA);
    final b1 = slotToMinutes(startB);
    final b2 = slotToMinutes(endB);
    return a1 < b2 && b1 < a2;
  }

  /// Parse a slot string like "09:00 AM" to minutes since midnight.
  int slotToMinutes(String slot) {
    // Format: "09:00 AM" or "01:00 PM"
    final parts = slot.split(' ');
    final timeParts = parts[0].split(':');
    var hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    final period = parts.length > 1 ? parts[1] : 'AM';

    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;

    return hour * 60 + minute;
  }

  /// Mark time slots as booked in the availability map.
  Future<void> _markSlotsBooked(
    String contractorId,
    DateTime date,
    String startSlot,
    String endSlot,
    String jobTitle,
  ) async {
    final dateKey =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final doc = await _db.collection('contractors').doc(contractorId).get();
    if (!doc.exists) return;

    final availability =
        (doc.data()?['availability'] as Map<String, dynamic>?) ?? {};
    final slots =
        (availability[dateKey] as List<dynamic>?)
            ?.map((s) => Map<String, dynamic>.from(s as Map))
            .toList() ??
        [];

    final startMin = slotToMinutes(startSlot);
    final endMin = slotToMinutes(endSlot);

    for (var i = 0; i < slots.length; i++) {
      final slotTime = slots[i]['time'] as String? ?? '';
      final slotMin = slotToMinutes(slotTime);
      if (slotMin >= startMin && slotMin < endMin) {
        slots[i]['booked'] = true;
        slots[i]['jobTitle'] = jobTitle;
      }
    }

    availability[dateKey] = slots;
    await _db.collection('contractors').doc(contractorId).set({
      'availability': availability,
    }, SetOptions(merge: true));
  }
}
