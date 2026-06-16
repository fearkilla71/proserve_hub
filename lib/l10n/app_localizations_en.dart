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

  @override
  String get languageSystemDefault => 'System default';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get you => 'You';

  @override
  String get customer => 'Customer';

  @override
  String get setPassword => 'Set password';

  @override
  String get notificationSettings => 'Notification settings';

  @override
  String get notificationSettingsDescription =>
      'Get alerts when pros send you cost estimates or messages.';

  @override
  String get allowPushNotifications => 'Allow Push Notifications';

  @override
  String get working => 'Working…';

  @override
  String get contactSupport => 'Contact Support';

  @override
  String get help => 'Help';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get caNoticeAtCollection => 'CA Notice at Collection';

  @override
  String get termsOfUse => 'Terms of Use';

  @override
  String get reportTechnicalProblem => 'Report a technical problem';

  @override
  String get doNotSellOrShareMyInfo => 'Do not sell or share my info';

  @override
  String get deactivateAccount => 'Deactivate account';

  @override
  String get deleteAccountData => 'Delete my account data';

  @override
  String get noEmailFound => 'No email found for this account.';

  @override
  String passwordResetEmailSent(String email) {
    return 'Password reset email sent to $email';
  }

  @override
  String failedToSendEmail(String error) {
    return 'Failed to send email: $error';
  }

  @override
  String get notificationsEnabled => 'Notifications enabled.';

  @override
  String get notificationsPermissionNotGranted =>
      'Notifications permission not granted.';

  @override
  String failedToEnableNotifications(String error) {
    return 'Failed to enable notifications: $error';
  }

  @override
  String get signedOut => 'Signed out.';

  @override
  String signOutFailed(String error) {
    return 'Sign out failed: $error';
  }

  @override
  String get versionLoading => 'Version …';

  @override
  String get subscriptionPlansTitle => 'Subscription Plans';

  @override
  String get subscriptionCurrentPlan => 'Current Plan';

  @override
  String get subscriptionUpdatingStatus => 'Updating status…';

  @override
  String get subscriptionTierBasic => 'Basic';

  @override
  String get subscriptionTierPro => 'Pro';

  @override
  String get subscriptionTierEnterprise => 'Enterprise';

  @override
  String get subscriptionPriceFree => 'Free';

  @override
  String get subscriptionPopular => 'POPULAR';

  @override
  String get subscriptionCurrent => 'CURRENT';

  @override
  String get subscriptionFeatureJobFeedAccess => 'Job feed access';

  @override
  String get subscriptionFeatureAcceptCustomerBids => 'Accept customer bids';

  @override
  String get subscriptionFeatureCommunityFeed => 'Community feed';

  @override
  String get subscriptionFeatureEverythingBasic => 'Everything in Basic';

  @override
  String get subscriptionFeaturePricingCalculator => 'Pricing Calculator';

  @override
  String get subscriptionFeatureCostEstimator => 'Cost Estimator';

  @override
  String get subscriptionFeatureAiInvoiceMaker => 'AI Invoice Maker';

  @override
  String get subscriptionFeatureRenderTool => 'Render Tool';

  @override
  String get subscriptionFeatureEverythingPro => 'Everything in Pro';

  @override
  String get subscriptionFeatureProfitLossDashboard =>
      'Profit & Loss Dashboard';

  @override
  String get subscriptionFeaturePriorityJobFeed =>
      'Priority job feed (30 min early)';

  @override
  String get subscriptionFeatureUnlimitedAi =>
      'Unlimited AI estimates & renders';

  @override
  String get subscriptionFeatureInvoicePaymentCollection =>
      'Invoice payment collection';

  @override
  String get subscriptionFeatureSubcontractorBoard => 'Subcontractor board';

  @override
  String get subscriptionFeatureCrewRoster => 'Crew roster & scheduling';

  @override
  String subscriptionManagedSettings(String settingsName) {
    return 'Auto-renewing monthly subscription. Cancel anytime in your $settingsName settings.';
  }

  @override
  String get subscriptionOpeningCheckout => 'Opening checkout...';

  @override
  String get subscriptionUpgradeWithCard => 'Upgrade with Card';

  @override
  String get subscriptionOpeningStore => 'Opening store...';

  @override
  String subscriptionSubscribeWithStorePrice(String storeName, String price) {
    return 'Subscribe with $storeName ($price)';
  }

  @override
  String subscriptionSubscribeWithStore(String storeName) {
    return 'Subscribe with $storeName';
  }

  @override
  String subscriptionStoreUnavailableShort(String storeName) {
    return '$storeName subscription unavailable';
  }

  @override
  String get subscriptionIosManagementCopy =>
      'Subscriptions are purchased with Apple In-App Purchase and managed in Apple ID Settings.';

  @override
  String get subscriptionAndroidManagementCopy =>
      'Tip: Google Play is best for mobile subscriptions. Stripe is a flexible fallback and works outside the app store flow.';

  @override
  String get subscriptionInformation => 'Subscription information';

  @override
  String subscriptionAutoRenewInfo(String accountName) {
    return 'Pro and Enterprise plans are monthly auto-renewable subscriptions. Payment is charged to your $accountName at confirmation of purchase and renews automatically unless canceled at least 24 hours before the end of the current period.';
  }

  @override
  String get subscriptionRestorePurchases => 'Restore Purchases';

  @override
  String get subscriptionRestoreComplete =>
      'Restore complete. Checking subscription status.';

  @override
  String subscriptionRestoreFailed(String error) {
    return 'Restore failed: $error';
  }

  @override
  String get subscriptionPurchasePending => 'Purchase is pending confirmation.';

  @override
  String get subscriptionPurchaseFailed => 'Purchase failed.';

  @override
  String get subscriptionPurchaseCanceled => 'Purchase canceled.';

  @override
  String get subscriptionEnterpriseActivated =>
      'Enterprise subscription activated.';

  @override
  String get subscriptionProActivated => 'Pro subscription activated.';

  @override
  String subscriptionVerificationFailed(String error) {
    return 'Subscription verification failed: $error';
  }

  @override
  String get subscriptionCheckoutBrowserReturn =>
      'Complete checkout in the browser, then return to the app. We will update your status automatically.';

  @override
  String subscriptionStoreTierUnavailable(String tierName) {
    return 'Store subscription for $tierName is not available yet.';
  }

  @override
  String subscriptionStoreUnavailable(String storeName) {
    return '$storeName subscriptions are unavailable right now. Please try again from a signed-in store account.';
  }

  @override
  String subscriptionProductLoadFailed(String error) {
    return 'Could not load subscription products: $error';
  }

  @override
  String subscriptionMissingProducts(String productIds) {
    return 'Missing subscription products in App Store Connect: $productIds.';
  }

  @override
  String get subscriptionNoProductsAvailable =>
      'No subscription products are available for this Apple sandbox account yet.';

  @override
  String get active => 'Active';

  @override
  String get subscribe => 'Subscribe';

  @override
  String get manageSubscription => 'Manage subscription';

  @override
  String get toolsTitle => 'Tools';

  @override
  String get toolsSubtitle =>
      'Win work, estimate faster, manage jobs, and get paid';

  @override
  String get toolsTodayTitle => 'Today';

  @override
  String get toolsTodaySubtitle =>
      'Your contractor operating system at a glance.';

  @override
  String get toolsPayoutsReady => 'Payouts ready';

  @override
  String get toolsPayoutsNotConnected => 'Connect payouts';

  @override
  String toolsLeadCredits(int count) {
    return '$count lead credits';
  }

  @override
  String get toolsProActive => 'Pro active';

  @override
  String get toolsProLocked => 'Pro locked';

  @override
  String get toolsEnterpriseActive => 'Enterprise active';

  @override
  String get toolsEnterpriseLocked => 'Enterprise locked';

  @override
  String get toolsReviewSetup => 'Review setup';

  @override
  String get contractorProTitle => 'Contractor Pro';

  @override
  String get contractorProPrice => '\$11.99 / month';

  @override
  String get contractorProUnlocks =>
      'Unlock invoices, pricing, estimates, renders, and stronger daily tools.';

  @override
  String get accessPro => 'Pro';

  @override
  String get accessEnterprise => 'Enterprise';

  @override
  String get lockedPro => 'Pro locked';

  @override
  String get lockedEnterprise => 'Enterprise locked';

  @override
  String get toolsSectionWinWork => 'Win Work';

  @override
  String get toolsSectionEstimateQuote => 'Estimate & Quote';

  @override
  String get toolsSectionGetPaid => 'Get Paid';

  @override
  String get toolsSectionManageJobs => 'Manage Jobs';

  @override
  String get toolsSectionGrowOperations => 'Grow Operations';

  @override
  String get toolAiInvoiceMakerTitle => 'AI Invoice Maker';

  @override
  String get toolAiInvoiceMakerSubtitle =>
      'Pick a client or job, build line items, terms, deposits, and payment links.';

  @override
  String get toolInvoicesTitle => 'Invoices';

  @override
  String get toolInvoicesSubtitle =>
      'Filter drafts, sent, paid, and overdue invoices; resend reminders.';

  @override
  String get toolPricingCalculatorTitle => 'Pricing Calculator';

  @override
  String get toolPricingCalculatorSubtitle =>
      'Use labor, material, margin, and market assumptions to price jobs.';

  @override
  String get toolCostEstimatorTitle => 'Cost Estimator';

  @override
  String get toolCostEstimatorSubtitle =>
      'Create detailed cost estimates with editable assumptions and revisions.';

  @override
  String get toolRenderToolTitle => 'Render Tool';

  @override
  String get toolRenderToolSubtitle =>
      'Preview colors, rooms, and surfaces before sending a proposal.';

  @override
  String get toolRenderGalleryTitle => 'Render Gallery';

  @override
  String get toolRenderGallerySubtitle =>
      'Organize renders by client, job, room, and share-ready packs.';

  @override
  String get toolSavedEstimatesTitle => 'Saved Estimates';

  @override
  String get toolSavedEstimatesSubtitle =>
      'Duplicate, revise, compare, share, and convert estimates.';

  @override
  String get toolSmartSchedulingTitle => 'Smart Scheduling AI';

  @override
  String get toolSmartSchedulingSubtitle =>
      'Balance crews, priorities, travel, and weather risk across the week.';

  @override
  String get toolQualityInspectorTitle => 'AI Quality Inspector';

  @override
  String get toolQualityInspectorSubtitle =>
      'Review job photos with checklists, defects, severity, and reports.';

  @override
  String get toolMultiLocationTitle => 'Multi-Location Dashboard';

  @override
  String get toolMultiLocationSubtitle =>
      'Track revenue, active jobs, crews, unpaid invoices, and lead conversion.';

  @override
  String get toolSubMarketplaceTitle => 'Sub Marketplace';

  @override
  String get toolSubMarketplaceSubtitle =>
      'Post overflow work, compare bids, verify subs, and hand off jobs.';

  @override
  String get toolBidAnalyzerTitle => 'AI Bid Analyzer';

  @override
  String get toolBidAnalyzerSubtitle =>
      'Extract line items, score margin risk, and generate counter-bids.';

  @override
  String get toolSelectServiceType => 'Select Service Type';

  @override
  String get toolActionUnlock => 'Unlock';

  @override
  String get toolActionAnalyzeBid => 'Analyze bid';

  @override
  String get toolActionPostJob => 'Post job';

  @override
  String get toolActionPriceJob => 'Price job';

  @override
  String get toolActionEstimateCost => 'Estimate cost';

  @override
  String get toolActionReviewEstimates => 'Review estimates';

  @override
  String get toolActionCreateInvoice => 'Create invoice';

  @override
  String get toolActionTrackInvoices => 'Track invoices';

  @override
  String get toolActionBuildSchedule => 'Build schedule';

  @override
  String get toolActionInspectPhotos => 'Inspect photos';

  @override
  String get toolActionCreateRender => 'Create render';

  @override
  String get toolActionOpenGallery => 'Open gallery';

  @override
  String get toolActionReviewLocations => 'Review locations';

  @override
  String get toolMetricRiskScore => 'Risk score';

  @override
  String get toolMetricVerifiedSubs => 'Verified subs';

  @override
  String get toolMetricMarginReady => 'Margin ready';

  @override
  String get toolMetricRevisionHistory => 'Revision history';

  @override
  String get toolMetricQuoteReady => 'Quote ready';

  @override
  String get toolMetricPaymentLink => 'Payment link';

  @override
  String get toolMetricOverdueBadges => 'Overdue badges';

  @override
  String get toolMetricConflictWarnings => 'Conflict warnings';

  @override
  String get toolMetricReportPdf => 'Report PDF';

  @override
  String get toolMetricClientShare => 'Client share';

  @override
  String get toolMetricFolders => 'Folders';

  @override
  String get toolMetricOwnerSummary => 'Owner summary';

  @override
  String get boostListingTitle => 'Boost Listing';

  @override
  String get boostListingSubtitle => 'Appear first in search results';

  @override
  String get retry => 'Retry';
}
