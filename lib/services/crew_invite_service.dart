import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class CrewInviteService {
  CrewInviteService._();
  static final instance = CrewInviteService._();

  final _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _inviteRef(String contractorId) {
    return _db
        .collection('contractors')
        .doc(contractorId)
        .collection('crew_invites');
  }

  CollectionReference<Map<String, dynamic>> _crewRef(String contractorId) {
    return _db.collection('contractors').doc(contractorId).collection('crew');
  }

  String _generateCode({int length = 8}) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(
      length,
      (_) => chars[rand.nextInt(chars.length)],
    ).join();
  }

  Future<Map<String, dynamic>> createInvite({
    String? roleTitle,
    int expiresInDays = 14,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not signed in');

    for (int attempt = 0; attempt < 4; attempt++) {
      final code = _generateCode();
      final docRef = _inviteRef(uid).doc(code);
      final existing = await docRef.get();
      if (existing.exists) continue;

      final expiresAt = DateTime.now().add(Duration(days: expiresInDays));
      await docRef.set({
        'code': code,
        'contractorId': uid,
        'status': 'pending',
        'roleTitle': (roleTitle ?? '').trim(),
        'createdBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
      });

      return {'code': code, 'contractorId': uid, 'expiresAt': expiresAt};
    }

    throw Exception('Could not generate unique invite code. Try again.');
  }

  Future<Map<String, dynamic>> redeemInviteCode(String codeRaw) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not signed in');

    final code = codeRaw.trim().toUpperCase();
    if (code.length < 6) throw Exception('Enter a valid invite code.');

    final snap = await _db
        .collectionGroup('crew_invites')
        .where('code', isEqualTo: code)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      throw Exception('Invite code not found.');
    }

    final inviteDoc = snap.docs.first;
    final invite = inviteDoc.data();
    final contractorId = (invite['contractorId'] as String?)?.trim() ?? '';
    if (contractorId.isEmpty) {
      throw Exception('Invite is invalid.');
    }

    final status =
        (invite['status'] as String?)?.trim().toLowerCase() ?? 'pending';
    if (status != 'pending') {
      throw Exception('Invite is no longer active.');
    }

    final expiresAt = invite['expiresAt'];
    if (expiresAt is Timestamp && expiresAt.toDate().isBefore(DateTime.now())) {
      throw Exception('Invite code has expired.');
    }

    final userDoc = await _db.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? <String, dynamic>{};
    final name = (userData['name'] as String?)?.trim();
    final phone = (userData['phone'] as String?)?.trim();

    String crewMemberId = '';

    await _db.runTransaction((tx) async {
      final freshInvite = await tx.get(inviteDoc.reference);
      final freshData = freshInvite.data() ?? <String, dynamic>{};
      final freshStatus =
          (freshData['status'] as String?)?.trim().toLowerCase() ?? 'pending';
      if (freshStatus != 'pending') {
        throw Exception('Invite has already been used.');
      }

      tx.set(_db.collection('users').doc(uid), {
        'role': 'crew_member',
        'crewContractorId': contractorId,
        'crewInviteCode': code,
        'crewJoinedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final existingCrew = await _crewRef(
        contractorId,
      ).where('linkedUserUid', isEqualTo: uid).limit(1).get();

      if (existingCrew.docs.isNotEmpty) {
        final doc = existingCrew.docs.first;
        crewMemberId = doc.id;
        tx.set(doc.reference, {
          'linkedUserUid': uid,
          'inviteCode': code,
          'available': true,
          'locationSharingEnabled': false,
          'onShift': false,
          'inviteAcceptedAt': FieldValue.serverTimestamp(),
          if (name != null && name.isNotEmpty) 'name': name,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
        }, SetOptions(merge: true));
      } else {
        final newDoc = _crewRef(contractorId).doc();
        crewMemberId = newDoc.id;
        tx.set(newDoc, {
          'name': (name == null || name.isEmpty) ? 'Crew Member' : name,
          'role': (freshData['roleTitle'] as String?)?.trim().isNotEmpty == true
              ? (freshData['roleTitle'] as String).trim()
              : 'Crew Member',
          'phone': phone ?? '',
          'skills': <String>[],
          'skillRatings': <String, int>{},
          'certifications': <String>[],
          'available': true,
          'yearsExperience': 0,
          'jobsCompleted': 0,
          'linkedUserUid': uid,
          'inviteCode': code,
          'locationSharingEnabled': false,
          'onShift': false,
          'addedAt': FieldValue.serverTimestamp(),
          'inviteAcceptedAt': FieldValue.serverTimestamp(),
        });
      }

      tx.update(inviteDoc.reference, {
        'status': 'accepted',
        'redeemedBy': uid,
        'redeemedAt': FieldValue.serverTimestamp(),
      });
    });

    return {
      'contractorId': contractorId,
      'crewMemberId': crewMemberId,
      'code': code,
    };
  }

  Future<Map<String, dynamic>?> getCrewLink() async {
    final uid = _uid;
    if (uid == null) return null;

    final userDoc = await _db.collection('users').doc(uid).get();
    final user = userDoc.data() ?? <String, dynamic>{};
    final contractorId = (user['crewContractorId'] as String?)?.trim() ?? '';
    if (contractorId.isEmpty) return null;

    final crewSnap = await _crewRef(
      contractorId,
    ).where('linkedUserUid', isEqualTo: uid).limit(1).get();

    if (crewSnap.docs.isEmpty) return null;

    final crewDoc = crewSnap.docs.first;
    final crew = crewDoc.data();

    return {
      'contractorId': contractorId,
      'crewMemberId': crewDoc.id,
      'crewName': (crew['name'] as String?)?.trim() ?? 'Crew Member',
      'onShift': (crew['onShift'] as bool?) == true,
      'locationSharingEnabled':
          (crew['locationSharingEnabled'] as bool?) == true,
      'role': (crew['role'] as String?)?.trim() ?? 'Crew Member',
    };
  }

  Future<void> updateCrewShift({
    required String contractorId,
    required String crewMemberId,
    bool? onShift,
    bool? locationSharingEnabled,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not signed in');

    await _crewRef(contractorId).doc(crewMemberId).set({
      if (onShift != null) 'onShift': onShift,
      if (locationSharingEnabled != null)
        'locationSharingEnabled': locationSharingEnabled,
      'linkedUserUid': uid,
      'lastPresenceAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> pushCrewLocation({
    required String contractorId,
    required String crewMemberId,
    required Position position,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not signed in');

    await _crewRef(contractorId).doc(crewMemberId).set({
      'linkedUserUid': uid,
      'lastLocation': {
        'lat': position.latitude,
        'lng': position.longitude,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'heading': position.heading,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      'lastPresenceAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchInvites(
    String contractorId,
  ) {
    return _inviteRef(
      contractorId,
    ).orderBy('createdAt', descending: true).limit(30).snapshots();
  }

  Future<void> cancelInvite(String code) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not signed in');
    final key = code.trim().toUpperCase();
    if (key.isEmpty) return;

    await _inviteRef(uid).doc(key).set({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
