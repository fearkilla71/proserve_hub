import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_service.dart';
import 'stripe_service.dart';

/// Lightweight service locator for dependency injection.
///
/// Usage:
///   // At app startup (main.dart):
///   ServiceLocator.init();
///
///   // Elsewhere:
///   final auth = ServiceLocator.instance.auth;
///   final stripe = ServiceLocator.instance.stripe;
///   final db = ServiceLocator.instance.firestore;
///
///   // In tests:
///   ServiceLocator.init(
///     firestore: FakeFirebaseFirestore(),
///     auth: FakeFirebaseAuth(),
///     authService: MockAuthService(),
///     stripeService: MockStripeService(),
///   );
class ServiceLocator {
  ServiceLocator._({
    required this.firestore,
    required this.firebaseAuth,
    required this.auth,
    required this.stripe,
  });

  /// The global singleton instance.
  static ServiceLocator? _instance;

  static ServiceLocator get instance {
    assert(
      _instance != null,
      'ServiceLocator.init() must be called before accessing instance.',
    );
    return _instance!;
  }

  /// Initialize the locator. Call once from main() before runApp().
  /// Pass overrides for testing.
  static void init({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    AuthService? authService,
    StripeService? stripeService,
  }) {
    _instance = ServiceLocator._(
      firestore: firestore ?? FirebaseFirestore.instance,
      firebaseAuth: auth ?? FirebaseAuth.instance,
      auth: authService ?? AuthService(),
      stripe: stripeService ?? StripeService(),
    );
  }

  /// Reset for tests.
  static void reset() => _instance = null;

  // ---------------------------------------------------------------------------
  // Registered services
  // ---------------------------------------------------------------------------

  final FirebaseFirestore firestore;
  final FirebaseAuth firebaseAuth;
  final AuthService auth;
  final StripeService stripe;
}
