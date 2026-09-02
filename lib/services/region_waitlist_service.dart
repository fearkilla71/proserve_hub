import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../constants/launch_regions.dart';

class RegionWaitlistService {
  RegionWaitlistService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = firestore ?? FirebaseFirestore.instance,
      _functions = FirebaseFunctions.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  Future<void> saveAccountRegion({
    required String role,
    required String zip,
    String? name,
    String? email,
    String? phone,
    String? service,
    List<String>? services,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final normalizedZip = normalizeZip(zip);
    final supported = isSupportedLaunchZip(normalizedZip);
    final launchRegion = launchRegionForZip(normalizedZip);
    final marketStatus = marketStatusForZip(normalizedZip);
    final callable = _functions.httpsCallable('completeUserProfile');
    await callable.call(<String, dynamic>{
      'role': role,
      if (normalizedZip.isNotEmpty) 'zip': normalizedZip,
      if (normalizedZip.isEmpty) 'marketStatus': kMarketStatusWaitlist,
      if (email?.trim().isNotEmpty == true) 'email': email!.trim(),
      if (name?.trim().isNotEmpty == true) 'name': name!.trim(),
      if (phone?.trim().isNotEmpty == true) 'phone': phone!.trim(),
      if (services != null) 'services': services,
    });

    if (role == 'contractor') {
      await _db.collection('contractors').doc(user.uid).set({
        'zip': normalizedZip,
        'launchRegion': launchRegion,
        'marketStatus': marketStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        if (!supported) 'waitlistJoinedAt': FieldValue.serverTimestamp(),
      });
    }

    if (!supported && normalizedZip.length == 5) {
      await _db.collection('waitlist').add({
        'uid': user.uid,
        'name': (name?.trim().isNotEmpty == true
            ? name!.trim()
            : user.displayName ?? 'ProServe user'),
        'email': (email?.trim().isNotEmpty == true
            ? email!.trim()
            : user.email ?? ''),
        'phone': phone?.trim() ?? '',
        'role': role,
        'zip': normalizedZip,
        'service': service?.trim() ?? '',
        'services': services ?? const <String>[],
        'launchRegion': launchRegion,
        'marketStatus': marketStatus,
        'source': 'app_region_gate',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
