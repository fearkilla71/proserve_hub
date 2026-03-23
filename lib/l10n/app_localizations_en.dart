// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ProServe Hub';

  @override
  String get selectService => 'Select a Service';

  @override
  String get browseContractors => 'Browse Contractors';

  @override
  String get savedContractors => 'Saved Contractors';

  @override
  String get instantBook => 'Instant Book';

  @override
  String get viewAvailability => 'View Availability';

  @override
  String get requestJob => 'Request Job';

  @override
  String get cancelJob => 'Cancel Job';

  @override
  String get referralPromo => 'Referral & Promo';

  @override
  String get bookingConfirmed => 'Booking Confirmed';

  @override
  String get noErrors => 'No errors logged yet.';

  @override
  String get quickActions => 'Quick actions';

  @override
  String get startRequest => 'Start request';

  @override
  String get browsePros => 'Browse pros';

  @override
  String get messages => 'Messages';

  @override
  String get projectTracker => 'Project tracker';

  @override
  String get savedPros => 'Saved pros';

  @override
  String get referral => 'Referral';

  @override
  String welcome(String name) {
    return 'Welcome, $name';
  }

  @override
  String get notifications => 'Notifications';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get signOut => 'Sign Out';

  @override
  String get signIn => 'Sign In';

  @override
  String get profile => 'Profile';

  @override
  String get home => 'Home';

  @override
  String get search => 'Search';

  @override
  String get project => 'Project';

  @override
  String get community => 'Community';

  @override
  String get tools => 'Tools';

  @override
  String get jobs => 'Jobs';

  @override
  String get plan => 'Plan';

  @override
  String get renderTool => 'Render Tool';

  @override
  String get compare => 'Compare';

  @override
  String get exitCompare => 'Exit compare';

  @override
  String get before => 'BEFORE';

  @override
  String get after => 'AFTER';

  @override
  String get myEstimates => 'My Estimates';

  @override
  String get noEstimatesYet => 'No estimates yet';

  @override
  String get getAiEstimate => 'Get AI Estimate';

  @override
  String get postAsJobRequest => 'Post as Job Request';

  @override
  String get deleteEstimate => 'Delete Estimate';

  @override
  String get receiptsExpenses => 'Receipts & Expenses';

  @override
  String get exportCsv => 'Export CSV';

  @override
  String get exportPdf => 'Export PDF';

  @override
  String get noReceiptsYet => 'No receipts yet.';

  @override
  String get availabilityCalendar => 'Availability Calendar';

  @override
  String get allDayAvailable => 'All Day Available';

  @override
  String get allDayUnavailable => 'All Day Unavailable';

  @override
  String get aiEstimator => 'AI Estimator';

  @override
  String get startNewRequest => 'Start a New Request';

  @override
  String get activity => 'Activity';

  @override
  String get noNotificationsYet => 'No notifications yet';

  @override
  String get chooseNotifications =>
      'Choose which notifications you want to receive.';

  @override
  String get referralDashboard => 'Referral Dashboard';

  @override
  String get totalReferrals => 'Total Referrals';

  @override
  String get creditsEarned => 'Credits Earned';

  @override
  String get yourReferralCode => 'Your Referral Code';

  @override
  String get interiorPainting => 'Interior Painting';

  @override
  String get cabinetPainting => 'Cabinet Painting';

  @override
  String get drywallRepair => 'Drywall Repair';

  @override
  String get pressureWashing => 'Pressure Washing';

  @override
  String get exteriorPainting => 'Exterior Painting';

  @override
  String get aiPriceMatchGuarantee => 'AI Price Match Guarantee';

  @override
  String get aiPriceMatch => 'AI Price Match';

  @override
  String priceGuaranteeThreshold(String threshold) {
    return 'If your final cost exceeds our AI estimate by more than $threshold, we\'ll credit the difference.';
  }

  @override
  String get costBreakdown => 'Cost Breakdown';

  @override
  String get labor => 'Labor';

  @override
  String get materials => 'Materials';

  @override
  String get platformFee => 'Platform Fee';

  @override
  String get escrowProtection => 'Escrow Protection';

  @override
  String get maintenanceReminders => 'Maintenance Reminders';

  @override
  String get maintenanceDue => 'Maintenance Due';

  @override
  String get book => 'Book';

  @override
  String get seasonalDeals => 'Deals & Offers';

  @override
  String hoursLeft(int hours) {
    return '${hours}h left';
  }

  @override
  String off(int percent) {
    return '$percent% OFF';
  }

  @override
  String get neighborhoodActivity => 'In Your Neighborhood';

  @override
  String homesNearYou(int count) {
    return '$count homes near you this month';
  }

  @override
  String get savedProjects => 'Saved Projects';

  @override
  String get noProjectsYet => 'No projects yet';

  @override
  String get createBoard => 'Create Board';

  @override
  String get boardName => 'Board name';

  @override
  String get notes => 'Notes';

  @override
  String get zeroInterest => '0% INTEREST';

  @override
  String get payInThree => 'Pay in 3';

  @override
  String get payInSix => 'Pay in 6';

  @override
  String perMonth(String amount) {
    return '$amount/mo';
  }

  @override
  String get choosePaymentPlan => 'Choose a payment plan';

  @override
  String get financingAvailable => 'Financing Available';

  @override
  String get topMatchedPros => 'Top Matched Pros';

  @override
  String prosInvited(int count) {
    return '$count pros invited — quotes arriving soon';
  }

  @override
  String get timeRemaining => 'Time remaining';

  @override
  String get verifiedPro => 'Verified';

  @override
  String get trustedPro => 'Trusted Pro';

  @override
  String get elitePro => 'Elite Pro';

  @override
  String get addPhoto => 'Add Photo';

  @override
  String get requestPhoto => 'Request Photo';

  @override
  String get photoRequested => 'Photo requested!';
}
