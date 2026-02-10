import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'firebase_options.dart';
import 'package:proserve_hub/screens/contractor_portal_page.dart';
import 'package:proserve_hub/screens/customer_portal_page.dart';
import 'package:proserve_hub/services/deep_link_service.dart';
import 'package:proserve_hub/services/fcm_service.dart';
import 'package:proserve_hub/services/error_logger.dart';
import 'package:proserve_hub/screens/verify_contact_info_page.dart';
import 'package:proserve_hub/theme/proserve_theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'screens/landing_page.dart';
import 'router/app_router.dart';

// Global navigator key for deep linking
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

DateTime? _lastMouseTrackerAssertionLog;
int _suppressedMouseTrackerAssertions = 0;

DateTime? _lastNeverLaidOutHitTestLog;
int _suppressedNeverLaidOutHitTests = 0;

DateTime? _lastRenderBoxNotLaidOutLog;
int _suppressedRenderBoxNotLaidOut = 0;

/// Whether Firebase Crashlytics is available on the current platform.
bool _crashlyticsSupported = false;

bool _isMouseTrackerDeviceUpdateAssertion(Object error) {
  final text = error.toString();
  return error is AssertionError &&
      (text.contains('mouse_tracker.dart') ||
          text.contains('package:flutter/src/rendering/mouse_tracker.dart')) &&
      text.contains('_debugDuringDeviceUpdate');
}

bool _isNeverLaidOutHitTestAssertion(Object error) {
  final text = error.toString();
  return text.contains(
    'Cannot hit test a render box that has never been laid out.',
  );
}

bool _isRenderBoxNotLaidOutAssertion(Object error) {
  final text = error.toString();
  return text.contains('RenderBox was not laid out') ||
      (text.contains('Failed assertion') && text.contains("'hasSize'"));
}

class _AppLoadingSkeleton extends StatelessWidget {
  const _AppLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ProServeColors.bg,
      alignment: Alignment.center,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ProServeColors.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: ProServeColors.accent.withValues(alpha: 0.25),
                ),
              ),
              child: Image.asset('assets/icon/app_icon.png'),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: 42,
              height: 42,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: ProServeColors.accent,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Just a moment…',
              style: TextStyle(
                color: ProServeColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _configureFirebaseEmulatorsIfEnabled() async {
  const useEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
  if (!useEmulators) return;

  final host = (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
      ? '10.0.2.2'
      : 'localhost';

  // Must be called before first use of each service.
  FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
  FirebaseStorage.instance.useStorageEmulator(host, 9199);

  debugPrint('Using Firebase emulators at $host');
}

Future<void> _activateFirebaseAppCheck() async {
  // Note: App Check is not supported on Windows/Linux desktop.
  if (kIsWeb) {
    const siteKey = String.fromEnvironment('RECAPTCHA_V3_SITE_KEY');
    if (siteKey.trim().isNotEmpty) {
      await FirebaseAppCheck.instance.activate(
        providerWeb: ReCaptchaV3Provider(siteKey.trim()),
      );
    } else {
      debugPrint(
        'App Check (web) not activated: missing RECAPTCHA_V3_SITE_KEY dart-define.',
      );
    }
    return;
  }

  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleDeviceCheckProvider(),
    );
    return;
  }

  debugPrint('App Check not supported on this platform.');
}

void main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Don't block first frame on file I/O. ErrorLogger buffers until ready.
      unawaited(ErrorLogger.instance.init());

      // ── Firebase Crashlytics ─────────────────────────────────────
      // Supported on Android, iOS, macOS, and web. Skip on Windows/Linux
      // desktop where the native SDK is unavailable.
      _crashlyticsSupported =
          kIsWeb ||
          defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS;

      if (_crashlyticsSupported) {
        await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
          !kDebugMode,
        );
      }

      FlutterError.onError = (details) {
        final exception = details.exception;
        if (_isMouseTrackerDeviceUpdateAssertion(exception)) {
          // Known Flutter desktop debug assertion that can spam logs and cause
          // the VM service connection to drop. Suppress it and keep running.
          final now = DateTime.now();
          final last = _lastMouseTrackerAssertionLog;
          _suppressedMouseTrackerAssertions++;
          if (last == null ||
              now.difference(last) > const Duration(seconds: 5)) {
            _lastMouseTrackerAssertionLog = now;
            debugPrint(
              'Suppressed MouseTracker _debugDuringDeviceUpdate assertion '
              '($_suppressedMouseTrackerAssertions total).',
            );
            ErrorLogger.instance.logFlutterError(details);
          }
          return;
        }

        if (!kIsWeb &&
            defaultTargetPlatform == TargetPlatform.windows &&
            _isNeverLaidOutHitTestAssertion(exception)) {
          // Desktop debug-only assertion that can happen during route/Scaffold
          // transitions while pointer events (mouse move) are still arriving.
          // Suppress it to keep the app from terminating.
          final now = DateTime.now();
          final last = _lastNeverLaidOutHitTestLog;
          _suppressedNeverLaidOutHitTests++;
          if (last == null ||
              now.difference(last) > const Duration(seconds: 5)) {
            _lastNeverLaidOutHitTestLog = now;
            debugPrint(
              'Suppressed "never been laid out" hit-test assertion '
              '($_suppressedNeverLaidOutHitTests total).',
            );
            ErrorLogger.instance.logFlutterError(details);
          }
          return;
        }

        if (!kIsWeb &&
            defaultTargetPlatform == TargetPlatform.windows &&
            _isRenderBoxNotLaidOutAssertion(exception)) {
          final now = DateTime.now();
          final last = _lastRenderBoxNotLaidOutLog;
          _suppressedRenderBoxNotLaidOut++;
          if (last == null ||
              now.difference(last) > const Duration(seconds: 5)) {
            _lastRenderBoxNotLaidOutLog = now;
            debugPrint(
              'Suppressed "RenderBox was not laid out" assertion '
              '($_suppressedRenderBoxNotLaidOut total).',
            );
            ErrorLogger.instance.logFlutterError(details);
          }
          return;
        }

        FlutterError.presentError(details);
        ErrorLogger.instance.logFlutterError(details);
        if (_crashlyticsSupported) {
          FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        }
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        if (_isMouseTrackerDeviceUpdateAssertion(error)) {
          // Prevent the app from terminating due to this debug-only issue.
          _suppressedMouseTrackerAssertions++;
          return true;
        }

        if (!kIsWeb &&
            defaultTargetPlatform == TargetPlatform.windows &&
            _isNeverLaidOutHitTestAssertion(error)) {
          _suppressedNeverLaidOutHitTests++;
          return true;
        }

        if (!kIsWeb &&
            defaultTargetPlatform == TargetPlatform.windows &&
            _isRenderBoxNotLaidOutAssertion(error)) {
          _suppressedRenderBoxNotLaidOut++;
          return true;
        }
        ErrorLogger.instance.logError(
          error,
          stack,
          context: 'PlatformDispatcher',
        );
        if (_crashlyticsSupported) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        }
        // Return false to allow the error to propagate (default behavior).
        return false;
      };

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // App Check can be surprisingly expensive / flaky on emulators.
      // - Release: activate before app work starts.
      // - Debug: keep it on for mobile by default (opt-out) so callable
      //   functions protected by App Check work during device testing.
      const useEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
      const disableAppCheckInDebug = bool.fromEnvironment(
        'DISABLE_APP_CHECK_DEBUG',
      );
      final isSupportedAppCheckPlatform =
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS);
      final shouldActivateAppCheck =
          !useEmulators &&
          isSupportedAppCheckPlatform &&
          (kReleaseMode || (!disableAppCheckInDebug && kDebugMode));
      if (shouldActivateAppCheck && kReleaseMode) {
        await _activateFirebaseAppCheck();
      }

      await _configureFirebaseEmulatorsIfEnabled();

      runApp(const ProServeHubApp());

      // External deep links (URI scheme / universal links).
      DeepLinkService.initialize(navigatorKey: navigatorKey);

      // Post-frame initialization: keep startup responsive on slower emulators.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(() async {
          if (shouldActivateAppCheck && !kReleaseMode) {
            await _activateFirebaseAppCheck();
          }

          // FCM + Stripe can be quite expensive/flaky on emulators/debug.
          // Keep them opt-in in debug to avoid ANR-like stalls.
          const enableFcmInDebug = bool.fromEnvironment('ENABLE_FCM_DEBUG');
          const enableStripeInDebug = bool.fromEnvironment(
            'ENABLE_STRIPE_DEBUG',
          );

          final shouldInitFcm = kReleaseMode || enableFcmInDebug;
          if (shouldInitFcm) {
            await FcmService.initialize(
              onNotificationTap: (data) {
                DeepLinkService.handlePayload(data);
              },
            );
          } else {
            debugPrint('FCM init skipped (debug).');
          }

          final supportsStripe =
              !kIsWeb &&
              (defaultTargetPlatform == TargetPlatform.android ||
                  defaultTargetPlatform == TargetPlatform.iOS);
          final shouldInitStripe =
              supportsStripe && (kReleaseMode || enableStripeInDebug);
          if (shouldInitStripe) {
            // Mobile-only Stripe PaymentSheet support.
            const publishableKey = String.fromEnvironment(
              'STRIPE_PUBLISHABLE_KEY',
            );
            if (publishableKey.trim().isNotEmpty) {
              Stripe.publishableKey = publishableKey.trim();
              await Stripe.instance.applySettings();
            } else {
              debugPrint('Stripe init skipped: missing STRIPE_PUBLISHABLE_KEY');
            }
          } else if (supportsStripe) {
            debugPrint('Stripe init skipped (debug).');
          }
        }());
      });
    },
    (error, stack) {
      ErrorLogger.instance.logError(error, stack, context: 'runZonedGuarded');
      if (_crashlyticsSupported) {
        FirebaseCrashlytics.instance.recordError(error, stack);
      }
    },
  );
}

class ProServeHubApp extends StatelessWidget {
  const ProServeHubApp({super.key});

  static final _router = createRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _router,
      title: 'ProServe Hub',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ProServeTheme.darkTheme(),
      theme: ProServeTheme.darkTheme(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
    );
  }
}

class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  String? _cachedUid;
  Future<Widget>? _homeFuture;

  Future<Widget> _resolveHome(User user) async {
    // Require verified email + phone before allowing portal access.
    // Email verification is stored in FirebaseAuth; phone verification is stored
    // in Firestore (`users/{uid}.phoneVerified` or `phoneVerifiedAt`).
    try {
      await user.reload();
    } catch (_) {
      // Best-effort.
    }

    Map<String, dynamic> userData = const <String, dynamic>{};
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      userData = snap.data() ?? <String, dynamic>{};
    } catch (_) {
      // Best-effort.
    }

    final phoneVerified =
        (userData['phoneVerified'] as bool?) == true ||
        userData['phoneVerifiedAt'] != null;
    if (!user.emailVerified || !phoneVerified) {
      return const VerifyContactInfoPage();
    }

    try {
      final role = (userData['role'] as String?)?.trim().toLowerCase();

      if (role == 'customer') return const CustomerPortalPage();
      if (role == 'contractor') return const ContractorPortalPage();

      // Backward-compatible fallback for older contractor accounts that have a
      // `contractors/{uid}` doc but no `users/{uid}.role`.
      final contractorSnap = await FirebaseFirestore.instance
          .collection('contractors')
          .doc(user.uid)
          .get();
      if (contractorSnap.exists) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({'role': 'contractor'}, SetOptions(merge: true));
        } catch (_) {
          // Best-effort.
        }
        return const ContractorPortalPage();
      }
    } catch (_) {
      // Fall through to unknown-role UI.
    }

    return Scaffold(
      appBar: AppBar(title: const Text('ProServe Hub')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Your account is signed in, but role setup is incomplete.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
                child: const Text('Sign Out'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        final user = snap.data;
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: _AppLoadingSkeleton());
        }

        if (user == null) {
          _cachedUid = null;
          _homeFuture = null;
          return const LandingPage();
        }

        if (_cachedUid != user.uid || _homeFuture == null) {
          _cachedUid = user.uid;
          _homeFuture = _resolveHome(user);
        }

        return FutureBuilder<Widget>(
          future: _homeFuture,
          builder: (context, homeSnap) {
            if (!homeSnap.hasData) {
              return const Scaffold(body: _AppLoadingSkeleton());
            }
            return homeSnap.data!;
          },
        );
      },
    );
  }
}
