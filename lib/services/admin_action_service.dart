import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminActionService {
  AdminActionService._();

  static final instance = AdminActionService._();

  Future<void> logAction({
    required DocumentReference<Map<String, dynamic>> parentRef,
    required String action,
    required String note,
    String? targetId,
    Map<String, Object?> previous = const {},
    Map<String, Object?> next = const {},
    Map<String, Object?> parentUpdate = const {},
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final batch = FirebaseFirestore.instance.batch();
    final actionRef = parentRef.collection('admin_actions').doc();

    batch.set(actionRef, {
      'action': action,
      'note': note,
      if (targetId != null && targetId.trim().isNotEmpty)
        'targetId': targetId.trim(),
      if (previous.isNotEmpty) 'previous': previous,
      if (next.isNotEmpty) 'next': next,
      'adminUid': user?.uid ?? 'unknown_admin',
      'adminName': user?.displayName ?? user?.email ?? 'Admin',
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(parentRef, {
      ...parentUpdate,
      'lastAdminAction': action,
      'lastAdminActionNote': note,
      'lastAdminActionAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }
}
