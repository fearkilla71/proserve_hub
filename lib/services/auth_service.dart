import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../utils/zip_locations.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> _sendEmailVerificationBestEffort(User user) async {
    try {
      if (!user.emailVerified) {
        await user.sendEmailVerification();
      }
    } catch (_) {
      // Best-effort; do not block signup if email verification cannot be sent.
    }
  }

  Future<String?> resolveRoleForUid(String uid) async {
    try {
      final snap = await _db.collection('users').doc(uid).get();
      final data = snap.data();
      final role = (data?['role'] as String?)?.trim().toLowerCase();
      if (role == 'customer' || role == 'contractor') return role;
    } catch (_) {
      // Best-effort.
    }

    try {
      final contractorSnap = await _db.collection('contractors').doc(uid).get();
      if (contractorSnap.exists) {
        // Backfill so RootGate and other flows can route consistently.
        try {
          await _db.collection('users').doc(uid).set({
            'role': 'contractor',
          }, SetOptions(merge: true));
        } catch (_) {
          // Best-effort.
        }
        return 'contractor';
      }
    } catch (_) {
      // Best-effort.
    }

    return null;
  }

  String friendlyAuthMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'email-already-in-use':
        return 'That email is already in use. Try signing in instead.';
      case 'weak-password':
        return 'Password is too weak (must be at least 6 characters).';
      case 'operation-not-allowed':
        return 'Email/password sign-up is disabled in Firebase Console.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection and try again.';
      default:
        // Desktop plugins sometimes surface as unknown-error.
        final message = (e.message ?? '').trim();
        final normalized = message.toLowerCase();
        if (e.code == 'unknown-error' &&
            normalized.contains('internal error') &&
            normalized.contains('occurred')) {
          return 'Firebase Auth returned an internal error. In Firebase Console, enable Authentication → Sign-in method → Email/Password. If it is already enabled, open Google Cloud Console for this project and ensure the Identity Toolkit / Firebase Authentication API is enabled.';
        }
        if (message.isNotEmpty) return message;
        return 'Sign up failed (${e.code}).';
    }
  }

  Future<User?> signUpContractor({
    required String email,
    required String password,
    required String name,
    required String company,
    required List<String> services,
    required String zip,
    required int radius,
    required String phone,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user;
      if (user == null) return null;

      await _sendEmailVerificationBestEffort(user);

      await _db.collection('users').doc(user.uid).set({
        'role': 'contractor',
        'name': name,
        'email': email,
        'company': company,
        'services': services,
        'zip': zip,
        'radius': radius,
        'phone': phone,
        'approved': false,
        'featured': false,
        'credits': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final zipKey = zip.trim();
      final loc = zipLocations[zipKey];
      final lat = loc?['lat'];
      final lng = loc?['lng'];

      await _db.collection('contractors').doc(user.uid).set({
        'name': company.trim().isEmpty ? name : company,
        'services': services,
        'zip': zip,
        // Legacy field used by the existing Nearby Contractors page.
        'radius': radius,
        // Smart matching foundation fields.
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        'rating': 0.0,
        'completedJobs': 0,
        // Legacy field used by reviews UI.
        'reviewCount': 0,

        'available': true,
        'availabilityWindow': 'next_week',
        'avgResponseMinutes': 60,
        'verified': false,
        'stripeAccountId': '',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return user;
    } on FirebaseAuthException catch (e, st) {
      debugPrint('FirebaseAuthException during signUpContractor');
      debugPrint('code=${e.code} message=${e.message}');
      debugPrintStack(stackTrace: st);
      throw Exception(friendlyAuthMessage(e));
    } catch (e, st) {
      debugPrint('Unexpected error during signUpContractor: $e');
      debugPrintStack(stackTrace: st);
      rethrow;
    }
  }

  Future<User?> createContractorAccountShell({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user;
      if (user == null) return null;

      await _sendEmailVerificationBestEffort(user);

      await _db.collection('users').doc(user.uid).set({
        'role': 'contractor',
        'email': email,
        'approved': false,
        'featured': false,
        'credits': 0,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return user;
    } on FirebaseAuthException catch (e, st) {
      debugPrint('FirebaseAuthException during createContractorAccountShell');
      debugPrint('code=${e.code} message=${e.message}');
      debugPrintStack(stackTrace: st);
      throw Exception(friendlyAuthMessage(e));
    } catch (e, st) {
      debugPrint('Unexpected error during createContractorAccountShell: $e');
      debugPrintStack(stackTrace: st);
      rethrow;
    }
  }

  Future<void> completeContractorProfile({
    required User user,
    required String name,
    required String company,
    required List<String> services,
    required String zip,
    required int radius,
    required String phone,
  }) async {
    final uid = user.uid;

    await _db.collection('users').doc(uid).set({
      'role': 'contractor',
      'name': name,
      'company': company,
      'services': services,
      'zip': zip,
      'radius': radius,
      'phone': phone,
    }, SetOptions(merge: true));

    final zipKey = zip.trim();
    final loc = zipLocations[zipKey];
    final lat = loc?['lat'];
    final lng = loc?['lng'];

    await _db.collection('contractors').doc(uid).set({
      'name': company.trim().isEmpty ? name : company,
      'services': services,
      'zip': zip,
      // Legacy field used by the existing Nearby Contractors page.
      'radius': radius,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      'rating': 0.0,
      'completedJobs': 0,
      'reviewCount': 0,
      'available': true,
      'availabilityWindow': 'next_week',
      'avgResponseMinutes': 60,
      'verified': false,
      'stripeAccountId': '',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<User?> signUpCustomer({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user;
      if (user == null) return null;

      await _sendEmailVerificationBestEffort(user);

      await _db.collection('users').doc(user.uid).set({
        'role': 'customer',
        'name': name,
        'email': email,
        'phone': phone,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return user;
    } on FirebaseAuthException catch (e, st) {
      debugPrint('FirebaseAuthException during signUpCustomer');
      debugPrint('code=${e.code} message=${e.message}');
      debugPrintStack(stackTrace: st);
      throw Exception(friendlyAuthMessage(e));
    } catch (e, st) {
      debugPrint('Unexpected error during signUpCustomer: $e');
      debugPrintStack(stackTrace: st);
      rethrow;
    }
  }

  Future<User?> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return cred.user;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
