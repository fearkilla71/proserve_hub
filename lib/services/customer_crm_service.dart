import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Customer CRM service for contractors.
///
/// Firestore structure:
///   contractors/{contractorId}/clients/{clientId}
///     - name: String
///     - email: String?
///     - phone: String?
///     - address: String?
///     - notes: String?
///     - tags: `List<String>`
///     - totalSpent: double
///     - jobCount: int
///     - lastJobDate: Timestamp?
///     - followUpDate: Timestamp?
///     - followUpNote: String?
///     - createdAt: Timestamp
class CustomerCrmService {
  CustomerCrmService._();
  static final instance = CustomerCrmService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _clientsRef(String contractorId) =>
      _db.collection('contractors').doc(contractorId).collection('clients');

  /// Add a client from a completed job.
  Future<String> addClient({
    required String name,
    String? email,
    String? phone,
    String? address,
    String? notes,
    List<String> tags = const [],
    String? homeownerId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    // Check for duplicate by homeownerId.
    if (homeownerId != null) {
      final existing = await _clientsRef(
        uid,
      ).where('homeownerId', isEqualTo: homeownerId).limit(1).get();
      if (existing.docs.isNotEmpty) {
        return existing.docs.first.id; // Already exists.
      }
    }

    final docRef = _clientsRef(uid).doc();
    await docRef.set({
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'notes': notes,
      'tags': tags,
      'homeownerId': homeownerId,
      'totalSpent': 0.0,
      'jobCount': 0,
      'lastJobDate': null,
      'followUpDate': null,
      'followUpNote': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Update client info.
  Future<void> updateClient(String clientId, Map<String, dynamic> data) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _clientsRef(uid).doc(clientId).update(data);
  }

  /// Delete a client.
  Future<void> deleteClient(String clientId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');
    await _clientsRef(uid).doc(clientId).delete();
  }

  /// Set a follow-up reminder.
  Future<void> setFollowUp(String clientId, DateTime date, String note) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');
    await _clientsRef(uid).doc(clientId).update({
      'followUpDate': Timestamp.fromDate(date),
      'followUpNote': note,
    });
  }

  /// Clear a follow-up reminder.
  Future<void> clearFollowUp(String clientId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');
    await _clientsRef(
      uid,
    ).doc(clientId).update({'followUpDate': null, 'followUpNote': null});
  }

  /// Record that a job was completed for this client.
  Future<void> recordJob(String clientId, double amount) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');
    await _clientsRef(uid).doc(clientId).update({
      'totalSpent': FieldValue.increment(amount),
      'jobCount': FieldValue.increment(1),
      'lastJobDate': FieldValue.serverTimestamp(),
    });
  }

  /// Stream all clients, ordered by name.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchClients() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _clientsRef(uid).orderBy('name').snapshots();
  }

  /// Get clients with upcoming follow-ups.
  Future<List<Map<String, dynamic>>> getUpcomingFollowUps() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    final now = DateTime.now();
    final weekFromNow = now.add(const Duration(days: 7));

    final snap = await _clientsRef(uid)
        .where(
          'followUpDate',
          isLessThanOrEqualTo: Timestamp.fromDate(weekFromNow),
        )
        .orderBy('followUpDate')
        .get();

    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  /// Get job history for a specific client from job_requests.
  Future<List<Map<String, dynamic>>> getClientJobHistory(
    String homeownerId,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    final snap = await _db
        .collection('job_requests')
        .where('contractorId', isEqualTo: uid)
        .where('customerId', isEqualTo: homeownerId)
        .orderBy('createdAt', descending: true)
        .get();

    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  /// Import clients from past completed jobs.
  Future<int> importFromJobs() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 0;

    final snap = await _db
        .collection('job_requests')
        .where('contractorId', isEqualTo: uid)
        .where('status', isEqualTo: 'completed')
        .get();

    int imported = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      final custId = data['customerId'] as String?;
      final custName = data['customerName'] as String?;
      if (custId == null || custName == null) continue;

      // Check if already imported.
      final existing = await _clientsRef(
        uid,
      ).where('homeownerId', isEqualTo: custId).limit(1).get();
      if (existing.docs.isNotEmpty) continue;

      await addClient(
        name: custName,
        phone: data['customerPhone'] as String?,
        address: data['address'] as String?,
        homeownerId: custId,
        tags: [data['serviceType'] as String? ?? 'general'],
      );
      imported++;
    }
    return imported;
  }
}
