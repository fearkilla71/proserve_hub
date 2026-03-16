import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/client_model.dart';

/// Manages the contractor's saved client directory in Firestore.
///
/// Path: `contractors/{uid}/clients/{clientId}`
class ClientDirectoryService {
  static final _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _col() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');
    return _firestore.collection('contractors').doc(uid).collection('clients');
  }

  /// Real-time stream of all saved clients, ordered by name.
  static Stream<List<SavedClient>> clientsStream() {
    return _col()
        .orderBy('name')
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => SavedClient.fromFirestore(d)).toList(),
        );
  }

  /// Fetch all clients once (non-streaming).
  static Future<List<SavedClient>> fetchAll() async {
    final snap = await _col().orderBy('name').get();
    return snap.docs.map((d) => SavedClient.fromFirestore(d)).toList();
  }

  /// Search clients by name (prefix match, case-insensitive via local filter).
  static Future<List<SavedClient>> search(String query) async {
    final all = await fetchAll();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.email.toLowerCase().contains(q) ||
              c.phone.contains(q),
        )
        .toList();
  }

  /// Add a new client. Returns the created document ID.
  static Future<String> add({
    required String name,
    String email = '',
    String phone = '',
    String address = '',
    String notes = '',
  }) async {
    final now = DateTime.now();
    final doc = await _col().add({
      'name': name.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'address': address.trim(),
      'notes': notes.trim(),
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });
    return doc.id;
  }

  /// Update an existing client.
  static Future<void> update(
    String clientId, {
    String? name,
    String? email,
    String? phone,
    String? address,
    String? notes,
  }) async {
    final data = <String, dynamic>{
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
    if (name != null) data['name'] = name.trim();
    if (email != null) data['email'] = email.trim();
    if (phone != null) data['phone'] = phone.trim();
    if (address != null) data['address'] = address.trim();
    if (notes != null) data['notes'] = notes.trim();
    await _col().doc(clientId).update(data);
  }

  /// Delete a client.
  static Future<void> delete(String clientId) async {
    await _col().doc(clientId).delete();
  }

  /// Auto-save a client from invoice data if not already saved.
  /// Uses email or name+phone to de-duplicate.
  static Future<void> saveFromInvoiceIfNew({
    required String name,
    String email = '',
    String phone = '',
    String address = '',
  }) async {
    if (name.trim().isEmpty) return;

    final all = await fetchAll();

    // De-duplicate by email first
    if (email.trim().isNotEmpty) {
      final emailLower = email.trim().toLowerCase();
      if (all.any((c) => c.email.toLowerCase() == emailLower)) return;
    }

    // Then by exact name + phone
    final nameMatch = all.where(
      (c) => c.name.toLowerCase() == name.trim().toLowerCase(),
    );
    if (nameMatch.isNotEmpty) {
      if (phone.trim().isEmpty) return; // name matches, close enough
      if (nameMatch.any((c) => c.phone == phone.trim())) return;
    }

    await add(name: name, email: email, phone: phone, address: address);
  }
}
