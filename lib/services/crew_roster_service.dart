import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for managing a contractor's crew roster.
///
/// Firestore structure:
///   contractors/`{contractorId}`/crew/`{crewMemberId}`
///     - name: String
///     - role: String (e.g. 'Lead Painter', 'Drywall Tech')
///     - phone: String?
///     - photoUrl: String?
///     - skills: `List<String>`
///     - skillRatings: `Map<String, int>` (skill → 1-5)
///     - certifications: `List<String>`
///     - available: bool
///     - yearsExperience: int
///     - jobsCompleted: int
///     - hourlyRate: double?
///     - addedAt: Timestamp
///
///   contractors/{contractorId}/labor_logs/{logId}
///     - crewMemberId: String
///     - crewMemberName: String
///     - jobId: String
///     - jobTitle: String
///     - hoursWorked: double
///     - hourlyRate: double
///     - totalCost: double
///     - date: Timestamp
///     - notes: String?
class CrewRosterService {
  CrewRosterService._();
  static final instance = CrewRosterService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _crewRef(String contractorId) =>
      _db.collection('contractors').doc(contractorId).collection('crew');

  CollectionReference<Map<String, dynamic>> _laborRef(String contractorId) =>
      _db.collection('contractors').doc(contractorId).collection('labor_logs');

  /// Add a crew member.
  Future<String> addCrewMember({
    required String name,
    required String role,
    String? phone,
    String? photoUrl,
    List<String> skills = const [],
    Map<String, int> skillRatings = const {},
    List<String> certifications = const [],
    int yearsExperience = 0,
    double? hourlyRate,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    final docRef = _crewRef(uid).doc();
    await docRef.set({
      'name': name,
      'role': role,
      'phone': phone,
      'photoUrl': photoUrl,
      'skills': skills,
      'skillRatings': skillRatings,
      'certifications': certifications,
      'available': true,
      'yearsExperience': yearsExperience,
      'jobsCompleted': 0,
      if (hourlyRate != null) 'hourlyRate': hourlyRate,
      'addedAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Update a crew member.
  Future<void> updateCrewMember(
    String memberId, {
    String? name,
    String? role,
    String? phone,
    String? photoUrl,
    List<String>? skills,
    Map<String, int>? skillRatings,
    List<String>? certifications,
    bool? available,
    int? yearsExperience,
    double? hourlyRate,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    await _crewRef(uid).doc(memberId).update({
      if (name != null) 'name': name,
      if (role != null) 'role': role,
      if (phone != null) 'phone': phone,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (skills != null) 'skills': skills,
      if (skillRatings != null) 'skillRatings': skillRatings,
      if (certifications != null) 'certifications': certifications,
      if (available != null) 'available': available,
      if (yearsExperience != null) 'yearsExperience': yearsExperience,
      if (hourlyRate != null) 'hourlyRate': hourlyRate,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Remove a crew member.
  Future<void> removeCrewMember(String memberId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');
    await _crewRef(uid).doc(memberId).delete();
  }

  /// Toggle availability.
  Future<void> toggleAvailability(String memberId, bool available) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');
    await _crewRef(uid).doc(memberId).update({'available': available});
  }

  /// Stream crew roster for a contractor.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchCrew(String contractorId) {
    return _crewRef(contractorId).orderBy('addedAt').snapshots();
  }

  /// Assign crew members to a job.
  Future<void> assignCrewToJob(
    String jobId,
    List<String> crewMemberIds,
    List<Map<String, String>> crewDetails,
  ) async {
    await _db.collection('job_requests').doc(jobId).update({
      'assignedCrew': crewMemberIds,
      'assignedCrewDetails': crewDetails,
    });
  }

  // ── Labor cost tracking ──────────────────────────────────

  /// Log labor hours for a crew member on a specific job.
  Future<String> logLabor({
    required String crewMemberId,
    required String crewMemberName,
    required String jobId,
    required String jobTitle,
    required double hoursWorked,
    required double hourlyRate,
    DateTime? date,
    String? notes,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    final totalCost = hoursWorked * hourlyRate;
    final docRef = _laborRef(uid).doc();
    await docRef.set({
      'crewMemberId': crewMemberId,
      'crewMemberName': crewMemberName,
      'jobId': jobId,
      'jobTitle': jobTitle,
      'hoursWorked': hoursWorked,
      'hourlyRate': hourlyRate,
      'totalCost': totalCost,
      'date': Timestamp.fromDate(date ?? DateTime.now()),
      'notes': notes,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update the job's total labor cost.
    final jobRef = _db.collection('job_requests').doc(jobId);
    await _db.runTransaction((tx) async {
      final jobSnap = await tx.get(jobRef);
      if (!jobSnap.exists) return;
      final current =
          (jobSnap.data()?['totalLaborCost'] as num?)?.toDouble() ?? 0;
      tx.update(jobRef, {'totalLaborCost': current + totalCost});
    });

    return docRef.id;
  }

  /// Get labor logs for a specific job.
  Future<List<Map<String, dynamic>>> getJobLaborLogs(String jobId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];
    final snap = await _laborRef(
      uid,
    ).where('jobId', isEqualTo: jobId).orderBy('date', descending: true).get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  /// Get labor logs for a specific crew member.
  Future<List<Map<String, dynamic>>> getCrewMemberLaborLogs(
    String crewMemberId,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];
    final snap = await _laborRef(uid)
        .where('crewMemberId', isEqualTo: crewMemberId)
        .orderBy('date', descending: true)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  /// Get total labor cost summary per crew member.
  Future<Map<String, double>> getCrewLaborCostSummary() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return {};
    final snap = await _laborRef(uid).get();
    final summary = <String, double>{};
    for (final doc in snap.docs) {
      final memberId = doc.data()['crewMemberId'] as String? ?? '';
      final cost = (doc.data()['totalCost'] as num?)?.toDouble() ?? 0;
      summary[memberId] = (summary[memberId] ?? 0) + cost;
    }
    return summary;
  }

  /// Get open/active jobs for this contractor (for job assignment picker).
  Future<List<Map<String, dynamic>>> getActiveJobs() async {
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

  /// Delete a labor log entry.
  Future<void> deleteLaborLog(String logId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');
    await _laborRef(uid).doc(logId).delete();
  }
}
