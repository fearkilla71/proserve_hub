import 'dart:typed_data';

import 'package:go_router/go_router.dart';

import '../models/invoice_models.dart';

import '../main.dart' show RootGate;
import '../screens/recommended_contractors_page.dart';
import '../screens/job_detail_page.dart';
import '../screens/favorite_contractors_screen.dart';
import '../screens/referral_screen.dart';
import '../screens/instant_book_screen.dart';
import '../screens/booking_calendar_screen.dart';
import '../screens/browse_contractors_screen.dart';
import '../screens/service_select_page.dart';
import '../screens/conversations_list_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/payment_history_screen.dart';
import '../screens/render_tool_screen.dart';
import '../screens/customer_profile_screen.dart';
import '../screens/customer_analytics_screen.dart';
import '../screens/contractor_subscription_screen.dart';
import '../screens/contractor_portal_page.dart';
import '../screens/customer_portal_page.dart';
import '../screens/boost_listing_screen.dart';
import '../screens/contractor_profile_screen.dart';
import '../screens/contractor_subcontract_board_screen.dart';
import '../screens/verification_screen.dart';
import '../screens/contractor_analytics_screen.dart';
import '../screens/availability_calendar_screen.dart';
import '../screens/service_area_screen.dart';
import '../screens/business_profile_screen.dart';
import '../screens/contractor_login_page.dart';
import '../screens/customer_login_page.dart';
import '../screens/contractor_signup_page.dart';
import '../screens/customer_signup_page.dart';
import '../screens/job_feed_page.dart';
import '../screens/invoice_maker_screen.dart';
import '../screens/pricing_calculator_screen.dart';
import '../screens/submit_review_screen.dart';
import '../screens/dispute_screen.dart';
import '../screens/job_status_screen.dart';
import '../screens/invoice_screen.dart';
import '../screens/quotes_screen.dart';
import '../screens/bids_list_screen.dart';
import '../screens/project_milestones_screen.dart';
import '../screens/project_timeline_screen.dart';
import '../screens/progress_photos_screen.dart';
import '../screens/expenses/expenses_list_page.dart';
import '../screens/expenses/add_expense_page.dart';
import '../screens/add_tip_screen.dart';
import '../screens/cancellation_screen.dart';
import '../screens/portfolio_screen.dart';
import '../screens/reviews_list_screen.dart';
import '../screens/qanda_screen.dart';
import '../screens/cost_estimator_screen.dart';
import '../screens/nearby_contractors_page.dart';
import '../screens/call_scheduling_screen.dart';
import '../screens/customer_ai_estimator_wizard_page.dart';
import '../screens/job_request_page.dart';
import '../screens/verify_contact_info_page.dart';
import '../screens/invoice_preview_screen.dart';
import '../screens/community_feed_screen.dart';
import '../screens/notification_center_screen.dart';
import '../screens/saved_estimates_screen.dart';
import '../screens/painting_request_flow_page.dart';
import '../screens/exterior_painting_request_flow_page.dart';
import '../screens/drywall_repair_request_flow_page.dart';
import '../screens/pressure_washing_request_flow_page.dart';
import '../screens/cabinet_request_flow_page.dart';
import '../screens/landing_page.dart';
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

  // ── Conversations & Chat ──
  static const conversations = '/conversations';
  static const chat = '/chat/:conversationId';

  // ── Payments & Invoicing ──
  static const paymentHistory = '/payment-history';
  static const invoiceMaker = '/invoice-maker';
  static const invoice = '/invoice/:jobId';
  static const addTip = '/add-tip/:jobId';

  // ── Tools ──
  static const renderTool = '/render-tool';
  static const pricingCalculator = '/pricing-calculator';
  static const costEstimator = '/cost-estimator/:serviceType';
  static const aiEstimator = '/ai-estimator';

  // ── Customer Screens ──
  static const customerPortal = '/customer-portal';
  static const customerProfile = '/customer-profile';
  static const customerAnalytics = '/customer-analytics';
  static const customerLogin = '/customer-login';
  static const customerSignup = '/customer-signup';

  // ── Contractor Screens ──
  static const contractorPortal = '/contractor-portal';
  static const contractorSubscription = '/contractor-subscription';
  static const contractorProfileSettings = '/contractor-profile-settings';
  static const contractorAnalytics = '/contractor-analytics';
  static const contractorLogin = '/contractor-login';
  static const contractorSignup = '/contractor-signup';
  static const boostListing = '/boost-listing';
  static const verification = '/verification';
  static const availabilityCalendar = '/availability-calendar';
  static const serviceArea = '/service-area';
  static const businessProfile = '/business-profile';
  static const subcontractBoard = '/subcontract-board';
  static const contractorPostJob = '/contractor-post-job';
  static const contractorJobDetail = '/contractor-job-detail/:jobId';

  // ── Job Screens ──
  static const jobFeed = '/job-feed';
  static const jobStatus = '/job-status/:jobId';
  static const quotes = '/quotes/:jobId';
  static const submitQuote = '/submit-quote/:jobId';
  static const bids = '/bids/:jobId';
  static const milestones = '/milestones/:jobId';
  static const timeline = '/timeline/:jobId';
  static const progressPhotos = '/progress-photos/:jobId';
  static const expenses = '/expenses/:jobId';
  static const addExpense = '/add-expense/:jobId';
  static const cancellation = '/cancellation/:jobId';
  static const dispute = '/dispute/:jobId';
  static const disputeDetail = '/dispute-detail/:disputeId';
  static const submitReview = '/submit-review/:jobId/:contractorId';

  // ── Portfolio & Reviews ──
  static const portfolio = '/portfolio/:contractorId';
  static const reviews = '/reviews/:contractorId';
  static const qanda = '/qanda/:contractorId';

  // ── Misc ──
  static const nearbyContractors = '/nearby-contractors/:jobZip';
  static const callSchedule = '/call-schedule';
  static const jobRequest = '/job-request/:serviceName';
  static const verifyContact = '/verify-contact';
  static const invoicePreview = '/invoice-preview';
  static const communityFeed = '/community-feed';
  static const notificationCenter = '/notifications';
  static const savedEstimates = '/saved-estimates';
  static const landing = '/landing';

  // ── Service Request Flows ──
  static const flowPainting = '/flow/painting';
  static const flowExteriorPainting = '/flow/exterior-painting';
  static const flowDrywallRepair = '/flow/drywall-repair';
  static const flowPressureWashing = '/flow/pressure-washing';
  static const flowCabinets = '/flow/cabinets';
}

/// Creates and returns the application's [GoRouter].
GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      // ── Root ──
      GoRoute(
        path: '/',
        builder: (context, state) => const OfflineBanner(child: RootGate()),
      ),

      // ── Existing routes ──
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
          final extra = state.extra as Map<String, dynamic>?;
          return JobDetailPage(
            jobId: id,
            jobData: extra?['jobData'] as Map<String, dynamic>?,
          );
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

      // ── Conversations & Chat ──
      GoRoute(
        path: '/conversations',
        builder: (context, state) => const ConversationsListScreen(),
      ),
      GoRoute(
        path: '/chat/:conversationId',
        builder: (context, state) {
          final conversationId = state.pathParameters['conversationId']!;
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ChatScreen(
            conversationId: conversationId,
            otherUserId: extra['otherUserId'] as String? ?? '',
            otherUserName: extra['otherUserName'] as String? ?? '',
            jobId: extra['jobId'] as String?,
          );
        },
      ),

      // ── Payments & Invoicing ──
      GoRoute(
        path: '/payment-history',
        builder: (context, state) => const PaymentHistoryScreen(),
      ),
      GoRoute(
        path: '/invoice-maker',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final draft = extra?['initialDraft'] as InvoiceDraft?;
          return InvoiceMakerScreen(initialDraft: draft);
        },
      ),
      GoRoute(
        path: '/invoice/:jobId',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return InvoiceScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: '/add-tip/:jobId',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return AddTipScreen(
            jobId: jobId,
            contractorId: extra['contractorId'] as String? ?? '',
            jobAmount: (extra['jobAmount'] as num?)?.toDouble() ?? 0,
          );
        },
      ),
      GoRoute(
        path: '/invoice-preview',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return InvoicePreviewScreen(
            draft: extra['draft'] as InvoiceDraft,
            issuedDate: extra['issuedDate'] as DateTime,
            total: extra['total'] as double,
            buildPdf: extra['buildPdf'] as Future<Uint8List> Function(),
          );
        },
      ),

      // ── Tools ──
      GoRoute(
        path: '/render-tool',
        builder: (context, state) => const RenderToolScreen(),
      ),
      GoRoute(
        path: '/pricing-calculator',
        builder: (context, state) => const PricingCalculatorScreen(),
      ),
      GoRoute(
        path: '/cost-estimator/:serviceType',
        builder: (context, state) {
          final serviceType = state.pathParameters['serviceType']!;
          return CostEstimatorScreen(serviceType: serviceType);
        },
      ),
      GoRoute(
        path: '/ai-estimator',
        builder: (context, state) {
          final service = state.uri.queryParameters['service'] ?? 'painting';
          return CustomerAiEstimatorWizardPage(initialService: service);
        },
      ),

      // ── Customer Screens ──
      GoRoute(
        path: '/customer-portal',
        builder: (context, state) => const CustomerPortalPage(),
      ),
      GoRoute(
        path: '/customer-profile',
        builder: (context, state) => const CustomerProfileScreen(),
      ),
      GoRoute(
        path: '/customer-analytics',
        builder: (context, state) => const CustomerAnalyticsScreen(),
      ),
      GoRoute(
        path: '/customer-login',
        builder: (context, state) => const CustomerLoginPage(),
      ),
      GoRoute(
        path: '/customer-signup',
        builder: (context, state) => const CustomerSignupPage(),
      ),

      // ── Contractor Screens ──
      GoRoute(
        path: '/contractor-portal',
        builder: (context, state) => const ContractorPortalPage(),
      ),
      GoRoute(
        path: '/contractor-subscription',
        builder: (context, state) => const ContractorSubscriptionScreen(),
      ),
      GoRoute(
        path: '/contractor-profile-settings',
        builder: (context, state) => const ContractorProfileScreen(),
      ),
      GoRoute(
        path: '/contractor-analytics',
        builder: (context, state) => const ContractorAnalyticsScreen(),
      ),
      GoRoute(
        path: '/contractor-login',
        builder: (context, state) => const ContractorLoginPage(),
      ),
      GoRoute(
        path: '/contractor-signup',
        builder: (context, state) => const ContractorSignupPage(),
      ),
      GoRoute(
        path: '/boost-listing',
        builder: (context, state) => const BoostListingScreen(),
      ),
      GoRoute(
        path: '/verification',
        builder: (context, state) => const VerificationScreen(),
      ),
      GoRoute(
        path: '/availability-calendar',
        builder: (context, state) => const AvailabilityCalendarScreen(),
      ),
      GoRoute(
        path: '/service-area',
        builder: (context, state) => const ServiceAreaScreen(),
      ),
      GoRoute(
        path: '/business-profile',
        builder: (context, state) => const BusinessProfileScreen(),
      ),
      GoRoute(
        path: '/subcontract-board',
        builder: (context, state) => const ContractorSubcontractBoardScreen(),
      ),
      GoRoute(
        path: '/contractor-post-job',
        builder: (context, state) => const ContractorPostJobScreen(),
      ),
      GoRoute(
        path: '/contractor-job-detail/:jobId',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return ContractorJobDetailScreen(jobId: jobId);
        },
      ),

      // ── Job Screens ──
      GoRoute(
        path: '/job-feed',
        builder: (context, state) => const JobFeedPage(),
      ),
      GoRoute(
        path: '/job-status/:jobId',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return JobStatusScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: '/quotes/:jobId',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return QuotesScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: '/submit-quote/:jobId',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return SubmitQuoteScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: '/bids/:jobId',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return BidsListScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: '/milestones/:jobId',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          final extra = state.extra as Map<String, dynamic>?;
          return ProjectMilestonesScreen(
            jobId: jobId,
            isContractor: extra?['isContractor'] as bool? ?? false,
          );
        },
      ),
      GoRoute(
        path: '/timeline/:jobId',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return ProjectTimelineScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: '/progress-photos/:jobId',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          final extra = state.extra as Map<String, dynamic>?;
          return ProgressPhotosScreen(
            jobId: jobId,
            canUpload: extra?['canUpload'] as bool? ?? false,
          );
        },
      ),
      GoRoute(
        path: '/expenses/:jobId',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ExpensesListPage(
            jobId: jobId,
            canAdd: extra['canAdd'] as bool? ?? false,
            createdByRole: extra['createdByRole'] as String? ?? 'customer',
          );
        },
      ),
      GoRoute(
        path: '/add-expense/:jobId',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return AddExpensePage(
            jobId: jobId,
            createdByRole: extra['createdByRole'] as String? ?? 'customer',
          );
        },
      ),
      GoRoute(
        path: '/cancellation/:jobId',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CancellationScreen(
            jobId: jobId,
            collection: extra['collection'] as String? ?? 'job_requests',
            scheduledDate: extra['scheduledDate'] as DateTime,
            jobPrice: (extra['jobPrice'] as num?)?.toDouble() ?? 0,
            jobTitle: extra['jobTitle'] as String? ?? '',
          );
        },
      ),
      GoRoute(
        path: '/dispute/:jobId',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return DisputeScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: '/dispute-detail/:disputeId',
        builder: (context, state) {
          final disputeId = state.pathParameters['disputeId']!;
          return DisputeDetailScreen(disputeId: disputeId);
        },
      ),
      GoRoute(
        path: '/submit-review/:jobId/:contractorId',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          final contractorId = state.pathParameters['contractorId']!;
          return SubmitReviewScreen(jobId: jobId, contractorId: contractorId);
        },
      ),

      // ── Portfolio & Reviews ──
      GoRoute(
        path: '/portfolio/:contractorId',
        builder: (context, state) {
          final contractorId = state.pathParameters['contractorId']!;
          final extra = state.extra as Map<String, dynamic>?;
          return PortfolioScreen(
            contractorId: contractorId,
            isEditable: extra?['isEditable'] as bool? ?? false,
          );
        },
      ),
      GoRoute(
        path: '/reviews/:contractorId',
        builder: (context, state) {
          final contractorId = state.pathParameters['contractorId']!;
          return ReviewsListScreen(contractorId: contractorId);
        },
      ),
      GoRoute(
        path: '/qanda/:contractorId',
        builder: (context, state) {
          final contractorId = state.pathParameters['contractorId']!;
          final extra = state.extra as Map<String, dynamic>?;
          return QandAScreen(
            contractorId: contractorId,
            isContractor: extra?['isContractor'] as bool? ?? false,
          );
        },
      ),

      // ── Misc ──
      GoRoute(
        path: '/nearby-contractors/:jobZip',
        builder: (context, state) {
          final jobZip = state.pathParameters['jobZip']!;
          return NearbyContractorsPage(jobZip: jobZip);
        },
      ),
      GoRoute(
        path: '/call-schedule',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CallSchedulingScreen(
            otherUserId: extra['otherUserId'] as String? ?? '',
            otherUserName: extra['otherUserName'] as String? ?? '',
            conversationId: extra['conversationId'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/job-request/:serviceName',
        builder: (context, state) {
          final serviceName = state.pathParameters['serviceName']!;
          final extra = state.extra as Map<String, dynamic>?;
          return JobRequestPage(
            serviceName: serviceName,
            initialZip: extra?['initialZip'] as String?,
            initialQuantity: extra?['initialQuantity'] as String?,
            initialPrice: extra?['initialPrice'] as String?,
            initialDescription: extra?['initialDescription'] as String?,
            initialUrgent: extra?['initialUrgent'] as bool?,
          );
        },
      ),
      GoRoute(
        path: '/verify-contact',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return VerifyContactInfoPage(
            showPitchAfterVerify:
                extra?['showPitchAfterVerify'] as bool? ?? false,
          );
        },
      ),
      GoRoute(
        path: '/community-feed',
        builder: (context, state) => const CommunityFeedScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationCenterScreen(),
      ),
      GoRoute(
        path: '/saved-estimates',
        builder: (context, state) => const SavedEstimatesScreen(),
      ),
      GoRoute(
        path: '/landing',
        builder: (context, state) => const LandingPage(),
      ),

      // ── Service Request Flows ──
      GoRoute(
        path: '/flow/painting',
        builder: (context, state) {
          final scope = state.uri.queryParameters['scope'];
          return PaintingRequestFlowPage(initialPaintingScope: scope);
        },
      ),
      GoRoute(
        path: '/flow/exterior-painting',
        builder: (context, state) => const ExteriorPaintingRequestFlowPage(),
      ),
      GoRoute(
        path: '/flow/drywall-repair',
        builder: (context, state) => const DrywallRepairRequestFlowPage(),
      ),
      GoRoute(
        path: '/flow/pressure-washing',
        builder: (context, state) => const PressureWashingRequestFlowPage(),
      ),
      GoRoute(
        path: '/flow/cabinets',
        builder: (context, state) => const CabinetRequestFlowPage(),
      ),
    ],
  );
}
