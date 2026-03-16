import 'package:cloud_firestore/cloud_firestore.dart';

/// A saved client in the contractor's CRM / client directory.
class SavedClient {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SavedClient({
    required this.id,
    required this.name,
    this.email = '',
    this.phone = '',
    this.address = '',
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  factory SavedClient.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return SavedClient(
      id: doc.id,
      name: (d['name'] as String?)?.trim() ?? '',
      email: (d['email'] as String?)?.trim() ?? '',
      phone: (d['phone'] as String?)?.trim() ?? '',
      address: (d['address'] as String?)?.trim() ?? '',
      notes: (d['notes'] as String?)?.trim() ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'phone': phone,
    'address': address,
    'notes': notes,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  SavedClient copyWith({
    String? name,
    String? email,
    String? phone,
    String? address,
    String? notes,
  }) {
    return SavedClient(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Display label for pickers.
  String get displayLabel {
    final parts = <String>[name];
    if (email.isNotEmpty) parts.add(email);
    if (phone.isNotEmpty) parts.add(phone);
    return parts.join(' • ');
  }
}
