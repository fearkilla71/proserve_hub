import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// A fixed-price service package offered by a contractor.
class ServicePackage {
  final String id;
  final String contractorId;
  final String title;
  final String description;
  final double price;
  final int estimatedMinutes;
  final String serviceType;
  final bool active;

  const ServicePackage({
    required this.id,
    required this.contractorId,
    required this.title,
    required this.description,
    required this.price,
    required this.estimatedMinutes,
    required this.serviceType,
    this.active = true,
  });

  factory ServicePackage.fromDoc(DocumentSnapshot doc) {
    final d = doc.data()! as Map<String, dynamic>;
    return ServicePackage(
      id: doc.id,
      contractorId: d['contractorId'] as String? ?? '',
      title: d['title'] as String? ?? '',
      description: d['description'] as String? ?? '',
      price: (d['price'] as num?)?.toDouble() ?? 0,
      estimatedMinutes: (d['estimatedMinutes'] as num?)?.toInt() ?? 60,
      serviceType: d['serviceType'] as String? ?? '',
      active: d['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'contractorId': contractorId,
    'title': title,
    'description': description,
    'price': price,
    'estimatedMinutes': estimatedMinutes,
    'serviceType': serviceType,
    'active': active,
  };
}

/// Manages instant-book packages and bookings.
class InstantBookService {
  InstantBookService._();
  static final InstantBookService instance = InstantBookService._();

  final _firestore = FirebaseFirestore.instance;

  /// Fetch active packages for a contractor.
  Stream<List<ServicePackage>> watchPackages(String contractorId) {
    return _firestore
        .collection('service_packages')
        .where('contractorId', isEqualTo: contractorId)
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map(ServicePackage.fromDoc).toList());
  }

  /// Create a new package (contractor-facing).
  Future<void> createPackage(ServicePackage pkg) async {
    await _firestore.collection('service_packages').add(pkg.toMap());
  }

  /// Book a package instantly — creates a job request with status 'booked'.
  Future<String> bookPackage({
    required ServicePackage package,
    required String preferredDate,
    required String preferredTime,
    String? notes,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    final ref = await _firestore.collection('job_requests').add({
      'customerId': uid,
      'contractorId': package.contractorId,
      'serviceType': package.serviceType,
      'packageId': package.id,
      'packageTitle': package.title,
      'price': package.price,
      'estimatedMinutes': package.estimatedMinutes,
      'preferredDate': preferredDate,
      'preferredTime': preferredTime,
      'notes': notes ?? '',
      'status': 'booked',
      'instantBook': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }
}
