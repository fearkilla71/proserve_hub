import 'package:go_router/go_router.dart';

import '../main.dart' show RootGate;
import '../screens/recommended_contractors_page.dart';
import '../screens/job_detail_page.dart';
import '../screens/favorite_contractors_screen.dart';
import '../screens/referral_screen.dart';
import '../screens/instant_book_screen.dart';
import '../screens/booking_calendar_screen.dart';
import '../screens/browse_contractors_screen.dart';
import '../screens/service_select_page.dart';
import '../widgets/offline_banner.dart';

/// Centralised route path constants.
///
/// Use these instead of raw strings to avoid typos and enable easy refactoring.
abstract final class AppRoutes {
  static const root = '/';
  static const recommended = '/recommended/:jobId';
  static const contractorProfile = '/contractor/:contractorId';
  static const jobDetail = '/job/:jobId';
  static const favorites = '/favorites';
  static const referral = '/referral';
  static const instantBook = '/instant-book/:contractorId';
  static const bookingCalendar = '/calendar/:contractorId';
  static const browse = '/browse';
  static const selectService = '/select-service';
}

/// Creates and returns the application's [GoRouter].
GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const OfflineBanner(child: RootGate()),
      ),
      GoRoute(
        path: '/recommended/:jobId',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return RecommendedContractorsPage(jobId: jobId);
        },
      ),
      GoRoute(
        path: '/contractor/:contractorId',
        builder: (context, state) {
          final id = state.pathParameters['contractorId']!;
          return ContractorProfilePage(contractorId: id);
        },
      ),
      GoRoute(
        path: '/job/:jobId',
        builder: (context, state) {
          final id = state.pathParameters['jobId']!;
          return JobDetailPage(jobId: id);
        },
      ),
      GoRoute(
        path: '/favorites',
        builder: (context, state) => const FavoriteContractorsScreen(),
      ),
      GoRoute(
        path: '/referral',
        builder: (context, state) => const ReferralScreen(),
      ),
      GoRoute(
        path: '/instant-book/:contractorId',
        builder: (context, state) {
          final id = state.pathParameters['contractorId']!;
          final name = state.uri.queryParameters['name'] ?? '';
          return InstantBookScreen(contractorId: id, contractorName: name);
        },
      ),
      GoRoute(
        path: '/calendar/:contractorId',
        builder: (context, state) {
          final id = state.pathParameters['contractorId']!;
          final name = state.uri.queryParameters['name'] ?? '';
          return BookingCalendarScreen(contractorId: id, contractorName: name);
        },
      ),
      GoRoute(
        path: '/browse',
        builder: (context, state) =>
            const BrowseContractorsScreen(showBackButton: true),
      ),
      GoRoute(
        path: '/select-service',
        builder: (context, state) => const ServiceSelectPage(),
      ),
    ],
  );
}
