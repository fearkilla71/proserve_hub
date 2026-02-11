import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralised, observable application state.
///
/// Caches the current [User], resolved role, and basic profile data so that
/// screens do not need to independently query Firestore for the same info.
///
/// Usage:
/// ```dart
/// // Access from any descendant:
/// final appState = AppState.of(context);
/// final uid = appState.uid;
/// final role = appState.role;   // 'customer' | 'contractor' | null
/// ```
class AppState extends ChangeNotifier {
  AppState({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance {
    _authSub = _auth!.authStateChanges().listen(_onAuthChanged);
    _loadLocale();
  }

  /// Test-only constructor that skips Firebase entirely.
  ///
  /// Use this to verify getters, notifier behaviour, and widget wiring
  /// without needing a real or mocked Firebase backend.
  AppState.test() : _auth = null, _firestore = null {
    _loading = false;
  }

  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;

  // ── Public accessors ──────────────────────────────────────────────────────

  User? get user => _user;
  String? get uid => _user?.uid;
  String? get role => _role;
  Map<String, dynamic> get profile => _profile;
  bool get isContractor => _role == 'contractor';
  bool get isCustomer => _role == 'customer';
  bool get isSignedIn => _user != null;
  bool get isLoading => _loading;
  bool get phoneVerified => _phoneVerified;
  bool get emailVerified => _user?.emailVerified ?? false;
  Locale? get locale => _locale;

  // ── Private state ─────────────────────────────────────────────────────────

  User? _user;
  String? _role;
  Map<String, dynamic> _profile = const {};
  bool _loading = true;
  bool _phoneVerified = false;
  Locale? _locale;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot>? _profileSub;

  // ── Auth listener ─────────────────────────────────────────────────────────

  void _onAuthChanged(User? user) {
    _user = user;

    // Cancel previous Firestore listener.
    _profileSub?.cancel();
    _profileSub = null;

    if (user == null) {
      _role = null;
      _profile = const {};
      _phoneVerified = false;
      _loading = false;
      notifyListeners();
      return;
    }

    _loading = true;
    notifyListeners();

    // Listen to the user doc for live role / profile updates.
    _profileSub = _firestore!
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen(
          (snap) {
            final data = snap.data() ?? <String, dynamic>{};
            _profile = data;
            _role = (data['role'] as String?)?.trim().toLowerCase();
            _phoneVerified =
                (data['phoneVerified'] as bool?) == true ||
                data['phoneVerifiedAt'] != null;
            _loading = false;
            notifyListeners();
          },
          onError: (_) {
            _loading = false;
            notifyListeners();
          },
        );
  }

  // ── Locale management ──────────────────────────────────────────────────────

  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString('locale');
      if (code != null && code.isNotEmpty) {
        _locale = Locale(code);
        notifyListeners();
      }
    } catch (_) {
      // Ignore — use system default.
    }
  }

  /// Set the app locale. Pass `null` to use the system default.
  Future<void> setLocale(Locale? locale) async {
    _locale = locale;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (locale == null) {
        await prefs.remove('locale');
      } else {
        await prefs.setString('locale', locale.languageCode);
      }
    } catch (_) {}
  }

  // ── Convenience mutators ──────────────────────────────────────────────────

  /// Force a refresh of the cached role (e.g. after signup).
  Future<void> refreshRole() async {
    final uid = _user?.uid;
    if (uid == null) return;

    try {
      final snap = await _firestore!.collection('users').doc(uid).get();
      final data = snap.data() ?? <String, dynamic>{};
      _profile = data;
      _role = (data['role'] as String?)?.trim().toLowerCase();
      _phoneVerified =
          (data['phoneVerified'] as bool?) == true ||
          data['phoneVerifiedAt'] != null;
      notifyListeners();
    } catch (_) {
      // Best-effort.
    }
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }

  // ── InheritedNotifier access ──────────────────────────────────────────────

  /// Retrieve the nearest [AppState] from the widget tree.
  ///
  /// Rebuilds the calling widget whenever the state changes because the
  /// provider is an [InheritedNotifier].
  static AppState of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<AppStateProvider>();
    assert(provider != null, 'No AppStateProvider found in ancestors.');
    return provider!.notifier!;
  }

  /// Like [of], but does NOT register for rebuild on change.
  static AppState read(BuildContext context) {
    final provider = context.getInheritedWidgetOfExactType<AppStateProvider>();
    assert(provider != null, 'No AppStateProvider found in ancestors.');
    return provider!.notifier!;
  }
}

/// Provides [AppState] to the widget tree via [InheritedNotifier].
///
/// Place at the root of your app, above [MaterialApp]:
/// ```dart
/// AppStateProvider(
///   notifier: appState,
///   child: MaterialApp(...),
/// )
/// ```
class AppStateProvider extends InheritedNotifier<AppState> {
  // ignore: prefer_const_constructors_in_immutables
  AppStateProvider({
    super.key,
    required AppState super.notifier,
    required super.child,
  });
}
