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
  String get loyalty => 'Loyalty';

  @override
  String get leaderboard => 'Leaderboard';

  @override
  String get aiSupport => 'AI Support';

  @override
  String get myRequests => 'My Requests';

  @override
  String get refresh => 'Refresh';

  @override
  String get actionCenter => 'Action Center';

  @override
  String get active => 'Active';

  @override
  String get quotes => 'quotes';

  @override
  String get protected => 'protected';

  @override
  String get verifiedPros => 'Verified pros';

  @override
  String get upfrontPricing => 'Upfront pricing';

  @override
  String get projectTracking => 'Project tracking';

  @override
  String get landingLanguageSystem => 'System';

  @override
  String get landingBadge => 'AI-powered contractor OS';

  @override
  String get landingHeadlinePrefix => 'Connect. Hire.\nGet Work ';

  @override
  String get landingHeadlineAccent => 'Done.';

  @override
  String get landingSubtitle =>
      'The all-in-one platform for homeowners and contractors to keep projects moving.';

  @override
  String get landingHomeownerTitle => 'I need a contractor';

  @override
  String get landingHomeownerBody =>
      'Post your job and connect with trusted local pros.';

  @override
  String get landingHomeownerBulletVerified => 'Verified & reviewed pros';

  @override
  String get landingHomeownerBulletQuotes => 'Upfront quotes';

  @override
  String get landingHomeownerBulletEscrow => 'Escrow-safe payments';

  @override
  String get landingHomeownerCta => 'Find a Contractor';

  @override
  String get landingHomeownerFootnote => 'As a homeowner';

  @override
  String get landingContractorTitle => 'I run a contractor business';

  @override
  String get landingContractorBody =>
      'Find quality leads, quote fast, and grow your business.';

  @override
  String get landingContractorBulletLeads => 'High-quality local leads';

  @override
  String get landingContractorBulletTools => 'AI tools to quote & invoice';

  @override
  String get landingContractorBulletPaid => 'Get paid faster';

  @override
  String get landingContractorCta => 'I\'m a Contractor';

  @override
  String get landingContractorFootnote => 'Grow my business';

  @override
  String get landingTrustVerifiedTitle => 'Verified Pros';

  @override
  String get landingTrustVerifiedBody => 'Background checked and insured';

  @override
  String get landingTrustEscrowTitle => 'Escrow-Safe Payments';

  @override
  String get landingTrustEscrowBody => 'Your payment is protected';

  @override
  String get landingTrustTrackingTitle => 'Real Project Tracking';

  @override
  String get landingTrustTrackingBody => 'Stay updated from start to finish';

  @override
  String get landingBuiltTitle => 'Built for the trades.';

  @override
  String get landingBuiltSubtitle => 'Powered by AI. Backed by trust.';

  @override
  String get snapForInstantQuote => 'Snap for Instant Quote';

  @override
  String get viewAllProjects => 'View all projects';

  @override
  String get postYourFirstJob => 'Post your first job';

  @override
  String get customerWelcomeFallback => 'there';

  @override
  String get customerHomeHeroTitle => 'BOOK A PRO IN MINUTES';

  @override
  String get customerHomeHeroSubtitle =>
      'Tell us what you need, compare quotes, and track the job here.';

  @override
  String get customerQuickStartRequestSubtitle => 'Smart 4-step flow';

  @override
  String get customerQuickBrowseProsSubtitle => 'Compare nearby contractors';

  @override
  String get customerQuickMessagesSubtitle => 'Open your inbox';

  @override
  String get customerQuickProjectTrackerSubtitle => 'View active requests';

  @override
  String get customerQuickSavedProsSubtitle => 'Your favorite contractors';

  @override
  String get customerQuickReferralSubtitle => 'Share and earn credit';

  @override
  String get customerQuickLoyaltySubtitle => 'Points and rewards';

  @override
  String get customerQuickLeaderboardSubtitle => 'Top-rated pros';

  @override
  String get customerQuickSavedProjectsSubtitle => 'Plan future work';

  @override
  String get customerQuickMyEstimatesSubtitle => 'View saved AI estimates';

  @override
  String get customerQuickAiSupportSubtitle => 'Get instant help 24/7';

  @override
  String get couldNotLoadRequests => 'Couldn\'t load your requests';

  @override
  String get stillLoadingRequests => 'Still loading your requests...';

  @override
  String get showingLegacyRequests => 'Showing legacy requests.';

  @override
  String get customerActionCenterSubtitle =>
      'Your next steps from request to paid, completed, and reviewed.';

  @override
  String get customerActionCenterNoQuotesTip =>
      'Tip: invite more pros or browse contractors if a request has no quotes yet.';

  @override
  String reviewService(String service) {
    return 'Review $service';
  }

  @override
  String get customerActionReviewSubtitle =>
      'Help future homeowners trust the right pro.';

  @override
  String get checkProtectedPayment => 'Check protected payment';

  @override
  String customerActionEscrowSubtitle(String service) {
    return 'View escrow status and release steps for $service.';
  }

  @override
  String compareQuoteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count quotes',
      one: '1 quote',
    );
    return 'Compare $_temp0';
  }

  @override
  String get customerActionCompareSubtitle =>
      'Review price, scope, warranty, and contractor proof.';

  @override
  String trackService(String service) {
    return 'Track $service';
  }

  @override
  String get customerActionTrackSubtitle =>
      'Open chat, photos, timeline, invoice, and next steps.';

  @override
  String get waitingForQuotes => 'Waiting for quotes';

  @override
  String get customerActionWaitingSubtitle =>
      'Open the job and invite or compare nearby pros.';

  @override
  String get customerActionEmptyBody =>
      'No active projects yet. Start with photos, ZIP code, and service type.';

  @override
  String get customerActionAllClearBody =>
      'No urgent actions. You can still review project details or start another request.';

  @override
  String get myTeam => 'My Team';

  @override
  String get myTeamSubtitle => 'Your hired pros and trusted contacts.';

  @override
  String get hiredPros => 'Hired Pros';

  @override
  String get hiredProsSubtitle => 'Contractors you\'ve completed jobs with.';

  @override
  String get trustedPros => 'Trusted Pros';

  @override
  String get trustedProsSubtitle =>
      'Your curated shortlist - add notes and organize by trade.';

  @override
  String get shareMyList => 'Share my list';

  @override
  String get add => 'Add';

  @override
  String get save => 'Save';

  @override
  String get updated => 'Updated.';

  @override
  String get pro => 'Pro';

  @override
  String get contractor => 'Contractor';

  @override
  String get message => 'Message';

  @override
  String get rebook => 'Rebook';

  @override
  String get addTrustedPro => 'Add Trusted Pro';

  @override
  String get editTrustedPro => 'Edit Trusted Pro';

  @override
  String get searchContractorName => 'Search contractor name';

  @override
  String get noContractorsFound => 'No contractors found.';

  @override
  String get tradeSpecialty => 'Trade / specialty';

  @override
  String get tradeSpecialtyHint => 'e.g. Painter, pressure washing tech';

  @override
  String get privateNote => 'Private note';

  @override
  String get privateNoteHint => 'e.g. Great with tile, fast response';

  @override
  String get addToTrustedList => 'Add to Trusted List';

  @override
  String addedToTrustedList(String name) {
    return '$name added to trusted list.';
  }

  @override
  String get removeQuestion => 'Remove?';

  @override
  String get removeTrustedProConfirm =>
      'Remove this contractor from your trusted list?';

  @override
  String get noRequestsYet => 'No requests yet';

  @override
  String get noRequestsYetSubtitle =>
      'Post your first service request and local pros will send you quotes.';

  @override
  String get noProsYet => 'No pros yet';

  @override
  String get noProsYetSubtitle =>
      'Once you complete a job, your contractors will appear here.';

  @override
  String get noTrustedProsYet => 'No trusted pros yet';

  @override
  String get noTrustedProsYetSubtitle =>
      'Add contractors you trust so you can find them fast, add notes, and share your list.';

  @override
  String jobsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jobs',
      one: '1 job',
    );
    return '$_temp0';
  }

  @override
  String activeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active',
      one: '1 active',
    );
    return '$_temp0';
  }

  @override
  String doneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count done',
      one: '1 done',
    );
    return '$_temp0';
  }

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
  String get browse => 'Browse';

  @override
  String get search => 'Search';

  @override
  String get project => 'Project';

  @override
  String get team => 'Team';

  @override
  String get gallery => 'Gallery';

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
  String get receiptsExpenses => 'Receipts & expenses';

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
  String get toolsPayoutsPending => 'Payouts pending';

  @override
  String get toolsConnectPayouts => 'Connect payouts';

  @override
  String get toolsReviewPayoutSetup => 'Review payout setup';

  @override
  String get toolsPayoutSetupReason =>
      'Required before you can receive escrow payouts and invoice payments.';

  @override
  String get toolsPayoutSetupOpenFailed =>
      'Could not open payout setup. Try again.';

  @override
  String get toolsPayoutSetupUnavailable =>
      'Payout setup is temporarily unavailable. Please try again or contact support.';

  @override
  String get toolsPayoutSetupRateLimited =>
      'Too many payout setup attempts. Please wait a bit and try again.';

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
  String get toolsSubscriptionActiveSubtitle =>
      'Your paid tools are active. Manage billing or keep working from the sections below.';

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
  String get toolQuoteTemplatesTitle => 'Quote Templates';

  @override
  String get toolQuoteTemplatesSubtitle =>
      'Reuse scopes, terms, warranties, exclusions, and branded quote language.';

  @override
  String get toolProfitLossTitle => 'Profit & Loss';

  @override
  String get toolProfitLossSubtitle =>
      'Track revenue, expenses, profit margin, and job profitability.';

  @override
  String get toolCrewRosterTitle => 'Crew Roster';

  @override
  String get toolCrewRosterSubtitle =>
      'Manage crew roles, availability, assignments, and labor history.';

  @override
  String get toolCrewScheduleTitle => 'Crew Schedule';

  @override
  String get toolCrewScheduleSubtitle =>
      'Assign crews to jobs and review the weekly operations board.';

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
  String get toolActionOpenTemplates => 'Open templates';

  @override
  String get toolActionReviewProfit => 'Review profit';

  @override
  String get toolActionManageCrew => 'Manage crew';

  @override
  String get toolActionAssignCrew => 'Assign crew';

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
  String get toolMetricReusableTerms => 'Reusable terms';

  @override
  String get toolMetricJobProfit => 'Job profit';

  @override
  String get toolMetricCrewRoles => 'Crew roles';

  @override
  String get toolMetricScheduleBoard => 'Schedule board';

  @override
  String get email => 'Email';

  @override
  String get phone => 'Phone';

  @override
  String get name => 'Name';

  @override
  String get zipCode => 'ZIP Code';

  @override
  String get address => 'Address';

  @override
  String get update => 'Update';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get history => 'History';

  @override
  String get description => 'Description';

  @override
  String get item => 'Item';

  @override
  String get copyToClipboard => 'Copy to Clipboard';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get clientDirectoryTitle => 'Client Directory';

  @override
  String get clientDirectorySelect => 'Select Client';

  @override
  String get clientDirectorySignInRequired => 'Sign in to view clients.';

  @override
  String get clientDirectorySearchHint => 'Search clients...';

  @override
  String get clientDirectoryAddClient => 'Add Client';

  @override
  String get clientDirectoryNoClients => 'No clients yet';

  @override
  String get clientDirectoryNoMatches => 'No matches';

  @override
  String get clientDirectoryNoClientsSubtitle =>
      'Tap + to add your first client';

  @override
  String get clientDirectoryNoMatchesSubtitle => 'Try a different search';

  @override
  String get clientDirectoryNewClient => 'New Client';

  @override
  String get clientDirectoryEditClient => 'Edit Client';

  @override
  String get clientDirectoryNameLabel => 'Client name *';

  @override
  String get clientDirectoryNotesLabel => 'Notes';

  @override
  String get clientDirectorySaveClient => 'Save Client';

  @override
  String get clientDirectoryNameRequired => 'Name is required';

  @override
  String get clientDirectoryDeleteTitle => 'Delete Client?';

  @override
  String clientDirectoryDeleteMessage(String clientName) {
    return 'Remove \"$clientName\" from your directory?';
  }

  @override
  String get bidAnalyzerAnalyzeTab => 'Analyze';

  @override
  String get bidAnalyzerPasteRequired =>
      'Paste a competitor bid or RFP text first';

  @override
  String get bidAnalyzerJobLabel => 'Job / Project Label (optional)';

  @override
  String get bidAnalyzerJobHint => 'e.g. 5000 sqft Exterior - Smith Residence';

  @override
  String get bidAnalyzerInputTitle => 'Competitor Bid / RFP Text';

  @override
  String get bidAnalyzerPasteClipboard => 'Paste from clipboard';

  @override
  String get bidAnalyzerInputSubtitle =>
      'Paste the full bid document, email, or line-item breakdown';

  @override
  String get bidAnalyzerInputHint =>
      'Paste competitor bid text here...\n\nExample:\n- Interior paint (3 BR): \$2,400\n- Trim & baseboards: \$800\n- Ceiling: \$600\n- Prep & primer: \$500';

  @override
  String bidAnalyzerCharacters(int count) {
    return '$count characters';
  }

  @override
  String get bidAnalyzerAnalyzing => 'Analyzing...';

  @override
  String get bidAnalyzerSummaryTitle => 'Analysis Summary';

  @override
  String get bidAnalyzerTheirTotal => 'Their Total';

  @override
  String get bidAnalyzerYourPrice => 'Your Price';

  @override
  String bidAnalyzerLineItems(int count) {
    return 'Line Items ($count)';
  }

  @override
  String get bidAnalyzerTheirs => 'Theirs';

  @override
  String get bidAnalyzerYours => 'Yours';

  @override
  String get bidAnalyzerCounterBidTitle => 'Suggested Counter-Bid';

  @override
  String get bidAnalyzerCounterBidLabel => 'Counter-Bid Suggestion:';

  @override
  String get bidAnalyzerNoAnalyses => 'No analyses yet';

  @override
  String get bidAnalyzerNoAnalysesSubtitle =>
      'Upload or paste a bid to extract line items, compare pricing, score risk, and save the analysis here.';

  @override
  String get bidAnalyzerStartAnalysis => 'Start analysis';

  @override
  String get bidAnalyzerFallbackTitle => 'Bid Analysis';

  @override
  String bidAnalyzerHistoryItems(String count) {
    return '$count items';
  }

  @override
  String bidAnalyzerLocalSummary(int count, String totalText) {
    return 'Local analysis extracted $count line items$totalText. Deploy the analyzeBid Cloud Function for AI-powered comparison against your pricing engine and counter-bid suggestions.';
  }

  @override
  String bidAnalyzerLocalSummaryTotal(String total) {
    return ' (total: $total)';
  }

  @override
  String get notNow => 'Not now';

  @override
  String get upgrade => 'Upgrade';

  @override
  String get signInRequired => 'Sign in required';

  @override
  String get checkConnectionTryAgain => 'Check your connection and try again.';

  @override
  String get pullToRefreshTryAgain =>
      'Pull to refresh or try again in a moment.';

  @override
  String get leadMarketEmptyFiltersTitle => 'No leads match your filters';

  @override
  String get leadMarketEmptyFiltersSubtitle =>
      'Your feed loaded, but filters, service matching, or radius are hiding available leads.';

  @override
  String get leadMarketEmptyMarketTitle =>
      'No leads available in this market right now';

  @override
  String get leadMarketEmptyMarketSubtitle =>
      'You are set up to browse leads. New customer requests will appear here when they are posted.';

  @override
  String leadMarketCreditBalance(int count) {
    return '$count lead credits available';
  }

  @override
  String leadMarketRadiusStatus(String radius, String zip) {
    return 'Showing leads within $radius miles of ZIP $zip';
  }

  @override
  String get leadMarketZipMissing =>
      'Add your ZIP or use location to improve local lead matching.';

  @override
  String get leadMarketPayoutReady => 'Payouts are connected for paid jobs.';

  @override
  String get leadMarketPayoutPending =>
      'Payout setup is started but still pending.';

  @override
  String get leadMarketPayoutBlocked =>
      'Connect payouts before accepting paid jobs.';

  @override
  String get leadMarketServiceFilterOn =>
      'Matching your selected services only.';

  @override
  String get leadMarketBuyCredits => 'Buy credits';

  @override
  String get leadMarketClearFilters => 'Clear filters';

  @override
  String get leadMarketExpandRadius => 'Expand radius';

  @override
  String get pricingWhyThisPriceTitle => 'Why this price';

  @override
  String pricingWhyThisPriceBody(
    String hours,
    String rate,
    String complexity,
    String materials,
    String markup,
  ) {
    return '$hours hours at \$$rate/hr, $complexity complexity, \$$materials materials, and a $markup% standard markup.';
  }

  @override
  String get pricingBackToJob => 'Back to Job';

  @override
  String get pricingSendQuote => 'Send quote';

  @override
  String get pricingAttachToJob => 'Attach to job';

  @override
  String get pricingCreateInvoice => 'Create invoice';

  @override
  String get pricingSaveToClient => 'Save to client';

  @override
  String get pricingAttachJobFirst =>
      'Open this calculator from a job before sending a quote.';

  @override
  String get pricingAttachedToJob => 'Estimate attached to job.';

  @override
  String get pricingSavedToClient => 'Estimate saved to client.';

  @override
  String get service => 'Service';

  @override
  String get unknown => 'Unknown';

  @override
  String get escrow => 'Escrow';

  @override
  String get approved => 'Approved';

  @override
  String get pendingAdminApproval => 'Pending Admin Approval';

  @override
  String get payoutsConnected => 'Payouts connected';

  @override
  String get payoutsPending => 'Payouts pending';

  @override
  String get payoutsSetup => 'Payouts setup';

  @override
  String get payoutsNotConnected => 'Payouts not connected';

  @override
  String get accountOverview => 'Account overview';

  @override
  String nonExclusiveCredits(int count) {
    return 'Non-exclusive credits: $count';
  }

  @override
  String exclusiveCredits(int count) {
    return 'Exclusive credits: $count';
  }

  @override
  String get editProfile => 'Edit profile';

  @override
  String get updatePublicContractorInfo => 'Update your public contractor info';

  @override
  String get getVerified => 'Get verified';

  @override
  String get improveTrustWinMoreWork => 'Improve trust and win more work';

  @override
  String get analytics => 'Analytics';

  @override
  String get availability => 'Availability';

  @override
  String get serviceArea => 'Service area';

  @override
  String get businessProfile => 'Business profile';

  @override
  String get qAndA => 'Q&A';

  @override
  String get contractorPortalWelcomeFallback => 'there';

  @override
  String get contractorHomeToday => 'Today';

  @override
  String get contractorHomeViewAll => 'View all';

  @override
  String get contractorHomeNewLeads => 'New leads';

  @override
  String contractorHomeActiveCount(int count) {
    return '$count Active';
  }

  @override
  String get contractorHomePayouts => 'Payouts';

  @override
  String get contractorHomeNextPayout => 'Next payout';

  @override
  String get contractorHomePayoutReady => 'Ready';

  @override
  String get contractorHomePayoutPending => 'Pending';

  @override
  String get contractorHomePayoutSetup => 'Setup';

  @override
  String get contractorHomePayoutUnderReview => 'Under review';

  @override
  String get contractorHomeVerifyTitle => 'Verify account';

  @override
  String get contractorHomeVerifySubtitle =>
      'Finish verification to build trust';

  @override
  String get contractorHomeAccountAllGood => 'Account status all good';

  @override
  String get contractorHomeCompleteSetup => 'Complete setup';

  @override
  String get contractorHomeToolQuote => 'Quote';

  @override
  String get contractorHomeToolEstimator => 'Estimator';

  @override
  String get contractorHomeToolScheduler => 'Scheduler';

  @override
  String get contractorHomeToolBidAnalyzer => 'Bid Analyzer';

  @override
  String get contractorHomeToolInspector => 'Inspector';

  @override
  String get contractorHomeToolsBasicSubtitle =>
      'Marketplace tools available. Upgrade for estimating and invoicing.';

  @override
  String get contractorHomeToolsProSubtitle =>
      'Estimate, invoice, render, and manage jobs faster.';

  @override
  String get contractorHomeToolsEnterpriseSubtitle =>
      'Operations tools for crews, bids, quality, and multi-location growth.';

  @override
  String get contractorHomeToolBrowseLeads => 'Browse Leads';

  @override
  String get contractorHomeToolSubmitQuote => 'Submit Quote';

  @override
  String get contractorHomeToolBuyCredits => 'Buy Credits';

  @override
  String get contractorHomeToolCommunity => 'Community';

  @override
  String get contractorHomeToolVerify => 'Verify';

  @override
  String get contractorHomeToolUpgradePro => 'Upgrade Pro';

  @override
  String get contractorHomeToolPricing => 'Pricing';

  @override
  String get contractorHomeToolSavedEstimates => 'Estimates';

  @override
  String get contractorHomeToolRender => 'Render';

  @override
  String get contractorHomeToolInvoices => 'Invoices';

  @override
  String get contractorHomeToolSmartSchedule => 'Scheduler';

  @override
  String get contractorHomeToolMultiLocation => 'Locations';

  @override
  String get contractorHomeToolSubMarket => 'Sub Market';

  @override
  String get contractorHomeToolPaymentLinks => 'Pay Links';

  @override
  String get contractorHomeToolProfitLoss => 'P&L';

  @override
  String get contractorHomeToolCrewRoster => 'Crew';

  @override
  String contractorHomeReviews(int count) {
    return '$count reviews';
  }

  @override
  String get contractorHomeNoReviews => 'No reviews';

  @override
  String contractorHomeYears(int count) {
    return '$count yrs';
  }

  @override
  String get contractorHomeExperience => 'Experience';

  @override
  String get contractorHomeTier => 'Tier';

  @override
  String get contractorPortalProRequiredTitle => 'Contractor Pro required';

  @override
  String get contractorPortalProRequiredBody =>
      'Unlock the Pricing Calculator, Cost Estimator, and Render Tool with Contractor Pro.';

  @override
  String get contractorPortalEnterpriseRequiredTitle =>
      'Enterprise plan required';

  @override
  String get contractorPortalEnterpriseBoardBody =>
      'The Subcontractor Board is available on the Enterprise plan. Upgrade to post and browse subcontract jobs.';

  @override
  String get contractorPortalEnterpriseToolsBody =>
      'Upgrade to Enterprise for multi-location operations, subcontractor marketplace workflows, bid analysis, crew scheduling, and quality reports.';

  @override
  String get contractorPortalBrowseJobs => 'Browse jobs';

  @override
  String get contractorPortalFindNewLeads => 'Find new leads';

  @override
  String get contractorPortalReplyFaster => 'Reply faster';

  @override
  String get contractorPortalPortfolio => 'Portfolio';

  @override
  String get contractorPortalShowcaseYourWork => 'Showcase your work';

  @override
  String get contractorPortalPayments => 'Payments';

  @override
  String get contractorPortalTrackEarnings => 'Track earnings';

  @override
  String get contractorPortalSubcontractJobs => 'Subcontract jobs';

  @override
  String get contractorPortalViewPostedWork => 'View posted work';

  @override
  String get contractorPortalPostJob => 'Post a job';

  @override
  String get contractorPortalShareOverflowWork => 'Share overflow work';

  @override
  String get contractorPortalCrewRoster => 'Crew roster';

  @override
  String get contractorPortalManageTeam => 'Manage your team';

  @override
  String get contractorPortalLeaderboard => 'Leaderboard';

  @override
  String get contractorPortalXpRankings => 'XP rankings';

  @override
  String get contractorPortalProfitLoss => 'Profit & Loss';

  @override
  String get contractorPortalFinancialDashboard => 'Financial dashboard';

  @override
  String get contractorPortalAiSupport => 'AI Support';

  @override
  String get contractorPortalInstantHelp => 'Get instant help 24/7';

  @override
  String get contractorPortalNoClaimedJobs => 'No claimed jobs yet';

  @override
  String get contractorPortalNoClaimedJobsSubtitle =>
      'Browse leads and purchase one to start a conversation with the customer.';

  @override
  String get contractorPortalCouldNotLoadJobs => 'Couldn\'t load jobs';

  @override
  String contractorPortalLocationLabel(String location) {
    return 'Location: $location';
  }

  @override
  String contractorPortalClaimedLabel(String date) {
    return 'Claimed: $date';
  }

  @override
  String contractorPortalCreatedLabel(String date) {
    return 'Created: $date';
  }

  @override
  String get contractorPortalJobsSubtitle =>
      'Browse and purchase customer project leads';

  @override
  String get contractorPortalMyClaimedJobs => 'My Claimed Jobs';

  @override
  String get contractorPortalPlanSubtitle =>
      'Manage your account, credits, and subscription';

  @override
  String get contractorPortalCouldNotLoadAccount =>
      'Couldn\'t load account info';

  @override
  String get contractorPortalTrackPerformance => 'Track performance and growth';

  @override
  String get keepScheduleUpToDate => 'Keep your schedule up to date';

  @override
  String get controlWhereYouGetLeads => 'Control where you get leads';

  @override
  String get showcaseBestWork => 'Showcase your best work';

  @override
  String get manageCompanyDetails => 'Manage company details';

  @override
  String get answerCustomerQuestions => 'Answer common customer questions';

  @override
  String get adminOperationsTitle => 'Admin Operations';

  @override
  String get adminOverviewTab => 'Overview';

  @override
  String get adminPaymentsTab => 'Payments';

  @override
  String get adminDisputesTab => 'Disputes';

  @override
  String get adminModerationTab => 'Moderation';

  @override
  String adminCheckFailed(String error) {
    return 'Admin check failed: $error';
  }

  @override
  String get adminAccessRequired =>
      'Admin access required. This screen is only available to approved operators.';

  @override
  String disputeStatusUpdated(String status) {
    return 'Dispute status updated to $status';
  }

  @override
  String errorWithMessage(String message) {
    return 'Error: $message';
  }

  @override
  String get resolveDispute => 'Resolve Dispute';

  @override
  String get resolutionDetails => 'Resolution Details';

  @override
  String get resolve => 'Resolve';

  @override
  String errorLoadingDisputes(String error) {
    return 'Error loading disputes:\n\n$error';
  }

  @override
  String get noActiveDisputes => 'No active disputes';

  @override
  String get filtersAndSorting => 'Filters & sorting';

  @override
  String get open => 'Open';

  @override
  String get underReview => 'Under review';

  @override
  String get resolved => 'Resolved';

  @override
  String get closed => 'Closed';

  @override
  String get all => 'All';

  @override
  String get sortBy => 'Sort by';

  @override
  String get newestToOldest => 'Newest to Oldest';

  @override
  String get oldestToNewest => 'Oldest to Newest';

  @override
  String get details => 'Details';

  @override
  String jobIdLabel(String jobId) {
    return 'Job ID: $jobId';
  }

  @override
  String get startReview => 'Start Review';

  @override
  String get close => 'Close';

  @override
  String get disputeClosedWithoutResolution =>
      'Dispute closed without resolution';

  @override
  String get paymentOpsEscrowOperations => 'Escrow Operations';

  @override
  String get paymentOpsEscrowOperationsSubtitle =>
      'Stuck, failed, refund, dispute, and payout states.';

  @override
  String get paymentOpsNoEscrowIssues => 'No escrow issues';

  @override
  String get paymentOpsNoEscrowIssuesSubtitle =>
      'Escrow records do not need admin attention.';

  @override
  String get paymentOpsPaymentRecords => 'Payment Records';

  @override
  String get paymentOpsPaymentRecordsSubtitle =>
      'Stripe, app store, lead credit, and invoice records.';

  @override
  String get paymentOpsNoPaymentIssues => 'No payment issues';

  @override
  String get paymentOpsNoPaymentIssuesSubtitle =>
      'Payment records do not need attention.';

  @override
  String get paymentOpsPayoutSetup => 'Payout setup';

  @override
  String get paymentOpsPayoutSetupSubtitle =>
      'Contractors who cannot reliably receive payouts yet.';

  @override
  String get paymentOpsPayoutsReady => 'All payout setups look ready';

  @override
  String get paymentOpsPayoutsReadySubtitle =>
      'No contractor payout blockers found.';

  @override
  String get needsAttention => 'Needs attention';

  @override
  String get ok => 'OK';

  @override
  String escrowIdLabel(String id) {
    return 'Escrow: $id';
  }

  @override
  String jobLabel(String jobId) {
    return 'Job: $jobId';
  }

  @override
  String statusPayoutLabel(String status, String payout) {
    return 'Status: $status • Payout: $payout';
  }

  @override
  String amountContractorPayoutLabel(String amount, String payout) {
    return 'Amount: $amount • Contractor payout: $payout';
  }

  @override
  String get openEscrow => 'Open escrow';

  @override
  String get openJob => 'Open job';

  @override
  String get markReviewed => 'Mark reviewed';

  @override
  String idLabel(String id) {
    return 'ID: $id';
  }

  @override
  String typeLabel(String type) {
    return 'Type: $type';
  }

  @override
  String userLabel(String userId) {
    return 'User: $userId';
  }

  @override
  String statusLabel(String status) {
    return 'Status: $status';
  }

  @override
  String amountLabel(String amount) {
    return 'Amount: $amount';
  }

  @override
  String get check => 'Check';

  @override
  String stripeAccountLabel(String account) {
    return 'Stripe account: $account';
  }

  @override
  String detailsSubmittedLabel(String value) {
    return 'Details submitted: $value';
  }

  @override
  String payoutsEnabledLabel(String value) {
    return 'Payouts enabled: $value';
  }

  @override
  String get missing => 'Missing';

  @override
  String get yes => 'yes';

  @override
  String get no => 'no';

  @override
  String get escrowMarkedReviewed => 'Escrow marked reviewed.';

  @override
  String couldNotMarkReviewed(String error) {
    return 'Could not mark reviewed: $error';
  }

  @override
  String get escrows => 'Escrows';

  @override
  String get escrowAlerts => 'Escrow alerts';

  @override
  String get paymentAlerts => 'Payment alerts';

  @override
  String get allRecords => 'All records';

  @override
  String errorLoadingPaymentOperations(String message) {
    return 'Error loading payment operations:\n\n$message';
  }

  @override
  String errorLoadingJobs(String error) {
    return 'Error loading jobs:\n\n$error';
  }

  @override
  String get noJobsFound => 'No jobs found';

  @override
  String get inProgress => 'In progress';

  @override
  String get completed => 'Completed';

  @override
  String get cancelled => 'Cancelled';

  @override
  String get allClaims => 'All claims';

  @override
  String get unclaimed => 'Unclaimed';

  @override
  String get claimed => 'Claimed';

  @override
  String get serviceAToZ => 'Service A to Z';

  @override
  String get serviceZToA => 'Service Z to A';

  @override
  String get deleteJobQuestion => 'Delete Job?';

  @override
  String get deleteJobPermanentWarning =>
      'This will permanently delete this job request. This cannot be undone.';

  @override
  String errorLoadingModerationQueue(String error) {
    return 'Error loading moderation queue: $error';
  }

  @override
  String get communityModeration => 'Community moderation';

  @override
  String get communityModerationSubtitle =>
      'Review reported posts, remove harmful content, restore false positives, or clear reviewed reports.';

  @override
  String get reported => 'Reported';

  @override
  String get removed => 'Removed';

  @override
  String get unknownAuthor => 'Unknown author';

  @override
  String postIdLabel(String postId) {
    return 'Post $postId';
  }

  @override
  String reportCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reports',
      one: '1 report',
      zero: '0 reports',
    );
    return '$_temp0';
  }

  @override
  String get noCaption => 'No caption';

  @override
  String mediaAttachmentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count media attachments',
      one: '1 media attachment',
    );
    return '$_temp0';
  }

  @override
  String get restore => 'Restore';

  @override
  String get remove => 'Remove';

  @override
  String postMarkedStatus(String status) {
    return 'Post marked $status.';
  }

  @override
  String get reportsMarkedReviewed => 'Reports marked reviewed.';

  @override
  String get leaveReviewTitle => 'Leave a Review';

  @override
  String get reviewSignInRequired => 'Please sign in to leave a review.';

  @override
  String get reviewSubmitted => 'Review submitted';

  @override
  String get reviewTrustTitle => 'Help the next homeowner choose confidently';

  @override
  String get reviewTrustSubtitle =>
      'Your review improves contractor quality, pricing trust, and safety for future jobs.';

  @override
  String get rating => 'Rating';

  @override
  String reviewRatingSemantics(int count) {
    return '$count star rating';
  }

  @override
  String reviewRatingHelper(int count) {
    return 'Selected rating: $count/5';
  }

  @override
  String get reviewCommentLabel => 'Comment';

  @override
  String get reviewCommentHint =>
      'What went well? Was the contractor on time, clear, and professional?';

  @override
  String get submitReview => 'Submit Review';

  @override
  String get bidsSignInRequired => 'Please sign in to view bids.';

  @override
  String get compareBids => 'Compare Bids';

  @override
  String get noBidsYet => 'No bids yet';

  @override
  String get noBidsYetSubtitle => 'Contractors will submit bids soon';

  @override
  String completedJobsCount(int count) {
    return '$count completed';
  }

  @override
  String etaDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return 'ETA: $_temp0';
  }

  @override
  String get reject => 'Reject';

  @override
  String get decline => 'Decline';

  @override
  String get counter => 'Counter';

  @override
  String get accept => 'Accept';

  @override
  String get price => 'Price';

  @override
  String get viewCounterOffer => 'View counter offer';

  @override
  String bidStatusUpdated(String status) {
    return 'Bid $status';
  }

  @override
  String get acceptBid => 'Accept Bid';

  @override
  String acceptBidMessage(String amount, String contractorName) {
    return 'Accept bid for $amount?\n\nThis will assign the job to $contractorName.';
  }

  @override
  String get acceptingBid => 'Accepting bid...';

  @override
  String get bidAcceptedJobAssigned => 'Bid accepted! Job assigned.';

  @override
  String get counterOffer => 'Counter Offer';

  @override
  String get amount => 'Amount';

  @override
  String get messageOptional => 'Message (optional)';

  @override
  String get send => 'Send';

  @override
  String get counterOfferDefaultDescription => 'Counter offer to original bid';

  @override
  String get counterOfferSent => 'Counter offer sent';

  @override
  String get compareQuotes => 'Compare Quotes';

  @override
  String get noQuotesYet => 'No quotes yet';

  @override
  String get noQuotesYetSubtitle =>
      'Contractors will submit quotes for your job request.';

  @override
  String get quoteAccepted => 'Quote accepted';

  @override
  String get chooseTheRightPro => 'Choose the right pro';

  @override
  String get quoteAcceptedHeaderBody =>
      'Your job is assigned. Open the Job Command Center to chat, track status, escrow, photos, invoice, and review.';

  @override
  String get compareQuotesHeaderBody =>
      'Compare price, reviews, completed jobs, notes, warranty, scope, and timeline before accepting. After you accept, the Job Command Center keeps the whole job in one place.';

  @override
  String get quotesLower => 'quotes';

  @override
  String get pendingLower => 'pending';

  @override
  String get rangeLower => 'range';

  @override
  String get escrowAfterApproval => 'Escrow after approval';

  @override
  String get openJobCommandCenter => 'Open Job Command Center';

  @override
  String get unknownContractor => 'Unknown Contractor';

  @override
  String quoteEtaValue(String value) {
    return 'ETA: $value';
  }

  @override
  String get insured => 'Insured';

  @override
  String get licensed => 'Licensed';

  @override
  String reviewCountShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reviews',
      one: '1 review',
      zero: 'No reviews',
    );
    return '$_temp0';
  }

  @override
  String get aiPrice => 'AI price';

  @override
  String get adjustedFromAi => 'Adjusted from AI';

  @override
  String revisionNumber(int number) {
    return 'Revision $number';
  }

  @override
  String expiresDate(String date) {
    return 'Expires $date';
  }

  @override
  String get scopeAttached => 'Scope attached';

  @override
  String get protectedPaymentPath => 'Protected payment path';

  @override
  String get beforeYouAccept => 'Before you accept';

  @override
  String get scopeOfWork => 'Scope of work';

  @override
  String get scopeMissing => 'Ask for scope details before approving';

  @override
  String get warranty => 'Warranty';

  @override
  String get warrantyIncluded => 'Included in this quote';

  @override
  String get warrantyNotListed => 'Not listed';

  @override
  String get exclusions => 'Exclusions';

  @override
  String get exclusionsListed => 'Listed by contractor';

  @override
  String get exclusionsNotListed => 'Not listed';

  @override
  String get deposit => 'Deposit';

  @override
  String depositRequiredAmount(String amount) {
    return '$amount required';
  }

  @override
  String get depositNotListed => 'No deposit listed';

  @override
  String get adjustment => 'Adjustment';

  @override
  String submittedDate(String date) {
    return 'Submitted $date';
  }

  @override
  String get acceptQuote => 'Accept Quote';

  @override
  String get continueJob => 'Continue Job';

  @override
  String acceptQuoteMessage(String amount, String contractorName) {
    return 'Accept this quote for $amount from $contractorName?\n\nThe contractor will be assigned and your next steps will move to the Job Command Center.';
  }

  @override
  String get acceptingQuote => 'Accepting quote...';

  @override
  String get quoteAcceptedJobAssigned => 'Quote accepted. Job assigned.';

  @override
  String get quoteDeclined => 'Quote declined';

  @override
  String get jobCommandCenterTitle => 'Job Command Center';

  @override
  String get jobDetailsTooltip => 'Job details';

  @override
  String get couldNotLoadJob => 'Could not load job';

  @override
  String get jobNotFoundTitle => 'Job not found';

  @override
  String get jobNotFoundSubtitle =>
      'This job may have been removed or is unavailable.';

  @override
  String get pending => 'Pending';

  @override
  String get accepted => 'Accepted';

  @override
  String get completionRequested => 'Completion Requested';

  @override
  String get completionApproved => 'Completion Approved';

  @override
  String get escrowFunded => 'Escrow Funded';

  @override
  String get customerView => 'Customer view';

  @override
  String get contractorView => 'Contractor view';

  @override
  String get escrowAttached => 'Escrow attached';

  @override
  String get disputeOpen => 'Dispute open';

  @override
  String get customerJourney => 'Customer journey';

  @override
  String get customerJourneySubtitle =>
      'Track the job from request to paid, completed, and reviewed.';

  @override
  String get jobStepRequest => 'Request';

  @override
  String get jobStepQuotes => 'Quotes';

  @override
  String get jobStepHire => 'Hire';

  @override
  String get jobStepEscrow => 'Escrow';

  @override
  String get jobStepWork => 'Work';

  @override
  String get jobStepReview => 'Review';

  @override
  String get nextBestAction => 'Next best action';

  @override
  String get reviewIncomingQuotes => 'Review incoming quotes';

  @override
  String get submitAQuote => 'Submit a quote';

  @override
  String get startWork => 'Start work';

  @override
  String get requestCompletion => 'Request completion';

  @override
  String get approveCompletion => 'Approve completion';

  @override
  String get checkEscrow => 'Check escrow';

  @override
  String get openJobStatus => 'Open job status';

  @override
  String get compareBidsChooseContractor =>
      'Compare bids, chat with pros, and choose the right contractor.';

  @override
  String get sendClearQuote =>
      'Send a clear quote so the customer can approve the work.';

  @override
  String get confirmWorkBeforeRelease =>
      'Confirm the work before payment release continues.';

  @override
  String get fundsVisibleFromEscrow =>
      'Funds and release state are visible from escrow status.';

  @override
  String get useStatusToAlign => 'Use status to keep both sides aligned.';

  @override
  String get commandSectionWinConfirm => 'Win & confirm work';

  @override
  String get reviewQuotes => 'Review quotes';

  @override
  String get submitQuote => 'Submit quote';

  @override
  String get reviewQuotesSubtitle => 'Compare contractor pricing and terms.';

  @override
  String get submitQuoteSubtitle =>
      'Send pricing, notes, and scope for this job.';

  @override
  String get bids => 'Bids';

  @override
  String get bidsSubtitle => 'View bids and acceptance status.';

  @override
  String get commandSectionToolsForJob => 'Tools for this job';

  @override
  String get priceThisJob => 'Price this job';

  @override
  String get priceThisJobSubtitle =>
      'Open the calculator with this job attached.';

  @override
  String get savedEstimates => 'Saved estimates';

  @override
  String get savedEstimatesJobSubtitle =>
      'View estimates connected to this job or create one.';

  @override
  String get aiInvoiceMaker => 'AI invoice maker';

  @override
  String get aiInvoiceMakerJobSubtitle =>
      'Draft an invoice with this client and job context.';

  @override
  String get createRender => 'Create render';

  @override
  String get createRenderJobSubtitle =>
      'Attach render concepts back to this job.';

  @override
  String get commandSectionCommunicateDocument => 'Communicate & document';

  @override
  String get chatWithContractor => 'Chat with contractor';

  @override
  String get chatWithClient => 'Chat with client';

  @override
  String get openJobConversation => 'Open the job conversation.';

  @override
  String get chatOpensAfterClaimed => 'Chat opens after the job is claimed.';

  @override
  String get progressPhotos => 'Progress photos';

  @override
  String get progressPhotosSubtitle => 'Upload and review job photos.';

  @override
  String get timeline => 'Timeline';

  @override
  String get timelineSubtitle => 'See updates, milestones, and activity.';

  @override
  String get milestones => 'Milestones';

  @override
  String get milestonesSubtitle => 'Track major job checkpoints.';

  @override
  String get commandSectionMoneyCompletion => 'Money & completion';

  @override
  String get status => 'Status';

  @override
  String get statusJobSubtitle =>
      'Start work, request completion, or approve it.';

  @override
  String get createInvoice => 'Create invoice';

  @override
  String get invoice => 'Invoice';

  @override
  String get createInvoiceSubtitle => 'Create or update the customer invoice.';

  @override
  String get invoiceSubtitle => 'Review invoice details for this job.';

  @override
  String get escrowSubtitle => 'View secured funds and release status.';

  @override
  String get noEscrowAttached => 'No escrow has been attached to this job yet.';

  @override
  String get receiptsExpensesSubtitle =>
      'Track materials, labor, and reimbursements.';

  @override
  String get commandSectionTrustCloseout => 'Trust & closeout';

  @override
  String get review => 'Review';

  @override
  String get reviewCompletedWork => 'Rate the completed contractor work.';

  @override
  String get reviewOpensAfterCompleted =>
      'Reviews open after the job is completed.';

  @override
  String get viewDispute => 'View dispute';

  @override
  String get reportDispute => 'Report dispute';

  @override
  String get viewDisputeSubtitle => 'Open the latest dispute details.';

  @override
  String get reportDisputeSubtitle => 'Report an issue with this job.';

  @override
  String get cancellation => 'Cancellation';

  @override
  String get cancelRefundEligibility => 'Cancel and check refund eligibility.';

  @override
  String get cancellationUnavailable =>
      'Cancellation is unavailable for this status.';

  @override
  String get escrowStatusTitle => 'Escrow Status';

  @override
  String get bookingNotFound => 'Booking not found';

  @override
  String get bookingNotFoundSubtitle =>
      'It may have been deleted or the link is invalid.';

  @override
  String get goBack => 'Go Back';

  @override
  String get confirmJobCompleteQuestion => 'Confirm Job Complete?';

  @override
  String customerConfirmReleaseMessage(String amount) {
    return 'You\'re verifying the work was completed to your satisfaction. Once the contractor also confirms, $amount will be released.';
  }

  @override
  String contractorConfirmReleaseMessage(String amount) {
    return 'You\'re verifying the job has been completed. Once the customer also confirms, your payment of $amount will be released.';
  }

  @override
  String get confirmRelease => 'Confirm & Release';

  @override
  String get notYet => 'Not Yet';

  @override
  String get confirmationRecorded => 'Confirmation recorded!';

  @override
  String get cancelBookingQuestion => 'Cancel Booking?';

  @override
  String get cancelBookingRefundWarning =>
      'Your payment will be fully refunded. This action cannot be undone.';

  @override
  String get keepBooking => 'Keep Booking';

  @override
  String get bookingCancelledRefunded => 'Booking cancelled & refunded.';

  @override
  String get cancellationFailedTryAgain =>
      'Cancellation failed. Please try again.';

  @override
  String get priceOffered => 'Price Offered';

  @override
  String get paymentHeldInEscrow => 'Payment Held in Escrow';

  @override
  String get customerConfirmed => 'Customer Confirmed';

  @override
  String get contractorConfirmed => 'Contractor Confirmed';

  @override
  String get payoutProcessing => 'Payout Processing';

  @override
  String get fundsReleased => 'Funds Released';

  @override
  String get payoutFailed => 'Payout Failed';

  @override
  String get declined => 'Declined';

  @override
  String get escrowMeaningOfferedTitle => 'Price is ready';

  @override
  String get escrowMeaningOfferedBody =>
      'The AI price has been created, but funds are not held yet.';

  @override
  String get escrowMeaningOfferedNext =>
      'Next: customer accepts and pays, or requests contractor quotes.';

  @override
  String get escrowMeaningFundedTitle => 'Money is protected';

  @override
  String get escrowMeaningFundedBody =>
      'The customer paid and funds are being held while the work is completed.';

  @override
  String get escrowMeaningFundedNext =>
      'Next: complete the job, then both sides confirm completion.';

  @override
  String get escrowMeaningCustomerConfirmedTitle =>
      'Customer confirmed completion';

  @override
  String get escrowMeaningCustomerConfirmedBody =>
      'The customer approved the completed work. The contractor still needs to confirm.';

  @override
  String get escrowMeaningCustomerConfirmedNext =>
      'Next: contractor confirms so payout can continue.';

  @override
  String get escrowMeaningContractorConfirmedTitle =>
      'Contractor confirmed completion';

  @override
  String get escrowMeaningContractorConfirmedBody =>
      'The contractor marked the work complete. The customer still needs to approve it.';

  @override
  String get escrowMeaningContractorConfirmedNext =>
      'Next: customer confirms before payment release continues.';

  @override
  String get escrowMeaningPayoutPendingTitle => 'Payout is processing';

  @override
  String escrowMeaningPayoutPendingBody(String amount) {
    return '$amount is being prepared for contractor payout.';
  }

  @override
  String get escrowMeaningPayoutPendingNext =>
      'Next: Stripe confirms the transfer automatically.';

  @override
  String get escrowMeaningReleasedTitle => 'Payment released';

  @override
  String escrowMeaningReleasedBody(String amount) {
    return '$amount was released to the contractor.';
  }

  @override
  String get escrowMeaningReleasedNext =>
      'Next: customer can rate the AI price and leave a review.';

  @override
  String get escrowMeaningPayoutFailedTitle => 'Payout needs review';

  @override
  String get escrowMeaningPayoutFailedBody =>
      'The job is complete, but the contractor payout did not finish automatically.';

  @override
  String get escrowMeaningPayoutFailedNext =>
      'Next: admin support should review and retry or resolve the payout.';

  @override
  String get escrowMeaningDeclinedTitle => 'Escrow declined';

  @override
  String get escrowMeaningDeclinedBody =>
      'The AI price was declined, so this escrow was not funded.';

  @override
  String get escrowMeaningDeclinedNext =>
      'Next: continue with contractor quotes or post a new request.';

  @override
  String get escrowMeaningCancelledTitle => 'Escrow cancelled';

  @override
  String get escrowMeaningCancelledBody =>
      'This booking was cancelled and the payment should be refunded.';

  @override
  String escrowMeaningCancelledRefundBody(String status) {
    return 'Refund status: $status';
  }

  @override
  String get escrowMeaningCancelledNext =>
      'Next: check refund status or contact support if it does not update.';

  @override
  String get paymentSummary => 'Payment Summary';

  @override
  String get totalPaid => 'Total Paid';

  @override
  String get platformFeePercent => 'Platform Fee (5%)';

  @override
  String get contractorPayout => 'Contractor Payout';

  @override
  String get payoutStatus => 'Payout Status';

  @override
  String get refundStatus => 'Refund Status';

  @override
  String get stripeTransfer => 'Stripe Transfer';

  @override
  String get stripeRefund => 'Stripe Refund';

  @override
  String get aiPriceOffered => 'AI Price Offered';

  @override
  String get paymentFunded => 'Payment Funded';

  @override
  String get awaitingPayment => 'Awaiting payment';

  @override
  String get afterBothConfirm => 'After both confirm';

  @override
  String get escrowTimeline => 'Escrow Timeline';

  @override
  String get howEscrowWorks => 'How Escrow Works';

  @override
  String get howEscrowStepOne =>
      'You pay the AI price, and funds are held securely.';

  @override
  String get howEscrowStepTwo =>
      'A contractor claims your job and completes the work.';

  @override
  String get howEscrowStepThree =>
      'Both you and the contractor confirm completion.';

  @override
  String get howEscrowStepFour =>
      'Funds are released to the contractor minus the platform fee.';

  @override
  String get confirmJobComplete => 'Confirm Job Complete';

  @override
  String get cancelling => 'Cancelling...';

  @override
  String get cancelBooking => 'Cancel Booking';

  @override
  String get contractorConfirmedPleaseRelease =>
      'The contractor has confirmed. Please confirm to release payment.';

  @override
  String get confirmReleasePayment => 'Confirm & Release Payment';

  @override
  String get waitingForContractor => 'Waiting for Contractor';

  @override
  String get waitingForContractorSubtitle =>
      'You\'ve confirmed completion. Once the contractor also confirms, funds will be released.';

  @override
  String get jobCompleteExclamation => 'Job Complete!';

  @override
  String releasedToContractor(String amount) {
    return '$amount released to contractor.';
  }

  @override
  String get rateAiPrice => 'Rate the AI Price';

  @override
  String get rateAiPriceSubtitle =>
      'Help our AI learn by rating how fair the price was.';

  @override
  String get youRatedThisPrice => 'You rated this price';

  @override
  String get backToHome => 'Back to Home';

  @override
  String payoutProcessingMessage(String amount) {
    return '$amount is being prepared for contractor payout. This usually updates automatically after Stripe confirms the transfer.';
  }

  @override
  String get payoutNeedsAdminReview => 'Payout Needs Admin Review';

  @override
  String get payoutNeedsAdminReviewMessage =>
      'The job is complete, but the contractor payout did not finish automatically. Support can review this escrow and retry or resolve the payout.';

  @override
  String get bookingCancelled => 'Booking Cancelled';

  @override
  String refundStatusValue(String status) {
    return 'Refund status: $status';
  }

  @override
  String get paymentRefunded => 'Your payment has been refunded.';

  @override
  String get writeReviewTitle => 'Write a Review';

  @override
  String get verifiedReviewTitle => 'Verified job review';

  @override
  String get verifiedReviewSubtitle =>
      'This review is tied to a completed ProServe job, so future homeowners can trust the feedback.';

  @override
  String get rateYourExperience => 'Rate your experience';

  @override
  String get quality => 'Quality';

  @override
  String get timeliness => 'Timeliness';

  @override
  String get communication => 'Communication';

  @override
  String reviewCategoryRatingSemantics(String label, int count) {
    return '$label $count of 5 stars';
  }

  @override
  String overallRatingValue(String rating) {
    return 'Overall: $rating/5';
  }

  @override
  String get shareYourExperience => 'Share your experience';

  @override
  String get reviewExperienceHint =>
      'Tell us about the contractor\'s quality, timing, communication, and professionalism.';

  @override
  String get reviewCommentRequired => 'Please write a comment';

  @override
  String get reviewCommentTooShort => 'Comment must be at least 20 characters';

  @override
  String get reviewRemoveInappropriateLanguage =>
      'Please remove inappropriate language';

  @override
  String get addPhotosOptional => 'Add photos (optional)';

  @override
  String get reviewPhotosSubtitle =>
      'Show before/after photos or highlight quality of work.';

  @override
  String reviewPhotoSemantics(int count) {
    return 'Review photo $count';
  }

  @override
  String get removePhoto => 'Remove photo';

  @override
  String addPhotosCount(int count) {
    return 'Add Photos ($count/5)';
  }

  @override
  String get submitting => 'Submitting...';

  @override
  String get reviewTips => 'Review Tips';

  @override
  String get reviewTipSpecific => '• Be specific about quality and service';

  @override
  String get reviewTipProfessionalism =>
      '• Mention professionalism and communication';

  @override
  String get reviewTipPhotos => '• Include before/after photos if applicable';

  @override
  String get reviewTipHonest => '• Be honest but constructive';

  @override
  String errorPickingPhotos(String error) {
    return 'Error picking photos: $error';
  }

  @override
  String get onlyRequestingCustomerCanReview =>
      'Only the customer who requested this job can review';

  @override
  String get reviewOnlyAfterCompleted =>
      'You can only review after the job is completed';

  @override
  String get reviewAlreadySubmittedForJob =>
      'You already submitted a review for this job';

  @override
  String get reviewSubmittedSuccessfully => 'Review submitted successfully!';

  @override
  String errorSubmittingReview(String error) {
    return 'Error submitting review: $error';
  }

  @override
  String smartRequestStepTitle(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get smartRequestResumeTitle => 'Resume saved request?';

  @override
  String get smartRequestResumeBody =>
      'We found a saved job request. Continue where you left off or start fresh.';

  @override
  String smartRequestResumeBodyWithDate(String time) {
    return 'We found a saved job request from $time. Continue where you left off or start fresh.';
  }

  @override
  String get smartRequestStartFresh => 'Start fresh';

  @override
  String get smartRequestResume => 'Resume';

  @override
  String get smartRequestDiscardTitle => 'Discard request?';

  @override
  String get smartRequestDiscardBody =>
      'Your progress is saved automatically. Leave now and resume this request later.';

  @override
  String get smartRequestStay => 'Stay';

  @override
  String get smartRequestDiscard => 'Leave';

  @override
  String get smartRequestClearDraft => 'Clear saved draft';

  @override
  String get smartRequestDraftCleared => 'Saved draft cleared';

  @override
  String get smartRequestDraftAutosave =>
      'Draft saves automatically as you build the request.';

  @override
  String smartRequestDraftSavedAt(String time) {
    return 'Draft saved at $time';
  }

  @override
  String get smartRequestPhotoRequired =>
      'Please add at least one photo of the project area.';

  @override
  String get smartRequestZipInvalid => 'Please enter a valid 5-digit ZIP code.';

  @override
  String get smartRequestServiceRequired => 'Please select a service type.';

  @override
  String get smartRequestAiUnavailable =>
      'AI analysis unavailable. You can fill in details manually.';

  @override
  String smartRequestSubmitFailed(String error) {
    return 'Failed to submit request: $error';
  }

  @override
  String get smartRequestSnapTitle => 'Snap & Describe';

  @override
  String get smartRequestSnapSubtitle =>
      'Take or upload photos and we\'ll help build the request.';

  @override
  String get smartRequestPhotoTrustTitle => 'Photos make quotes more accurate';

  @override
  String get smartRequestPhotoTrustSubtitle =>
      'Add the project area, close-up damage, and any access details so contractors can quote with fewer follow-up questions.';

  @override
  String get smartRequestProjectPhotos => 'Project Photos';

  @override
  String get smartRequestPhotoPlaceholder =>
      'Take a photo or upload from gallery';

  @override
  String get smartRequestCamera => 'Camera';

  @override
  String get smartRequestGallery => 'Gallery';

  @override
  String get smartRequestAddMorePhotos => 'Add More';

  @override
  String get smartRequestZipHint => 'Enter your ZIP code';

  @override
  String get smartRequestServiceType => 'Service Type';

  @override
  String get smartRequestAnalyzeWithAi => 'Analyze with AI';

  @override
  String get smartRequestAiAnalyzing => 'AI is analyzing your photos...';

  @override
  String get smartRequestAiAnalyzingSubtitle =>
      'Estimating size, condition, and pricing';

  @override
  String get smartRequestAiDetectedDetails => 'AI-Detected Details';

  @override
  String get smartRequestReviewAdjust => 'Review and adjust the details below.';

  @override
  String smartRequestAiConfidence(String percent) {
    return 'AI Confidence: $percent%';
  }

  @override
  String get smartRequestEstimatedSize => 'Estimated Size (sqft)';

  @override
  String get smartRequestPropertyType => 'Property Type';

  @override
  String get smartRequestHome => 'Home';

  @override
  String get smartRequestBusiness => 'Business';

  @override
  String get smartRequestSurfaceCondition => 'Surface Condition';

  @override
  String get smartRequestExcellent => 'Excellent';

  @override
  String get smartRequestFair => 'Fair';

  @override
  String get smartRequestPoor => 'Poor';

  @override
  String get smartRequestAiNotes => 'AI Notes';

  @override
  String get smartRequestContinue => 'Continue';

  @override
  String get smartRequestTimelineBudget => 'Timeline & Budget';

  @override
  String get smartRequestTimelineQuestion => 'When do you need the work done?';

  @override
  String get smartRequestTimelineStandard => 'Standard';

  @override
  String get smartRequestTimelineStandardSubtitle => 'Within 1-2 weeks';

  @override
  String get smartRequestTimelineAsap => 'ASAP';

  @override
  String get smartRequestTimelineAsapSubtitle =>
      'As soon as possible (+15% urgency premium)';

  @override
  String get smartRequestTimelineFlexible => 'Flexible';

  @override
  String get smartRequestTimelineFlexibleSubtitle =>
      'No rush. I\'m flexible on timing';

  @override
  String get smartRequestBudgetPreference => 'Budget Preference';

  @override
  String get smartRequestBudgetFriendly => 'Budget-Friendly';

  @override
  String get smartRequestBudgetFriendlySubtitle =>
      'Lower end of market pricing';

  @override
  String get smartRequestBudgetRecommended => 'Recommended';

  @override
  String get smartRequestBudgetRecommendedSubtitle =>
      'Fair market price for quality work';

  @override
  String get smartRequestBudgetPremium => 'Premium';

  @override
  String get smartRequestBudgetPremiumSubtitle =>
      'Top-tier materials and craftsmanship';

  @override
  String get smartRequestReviewSubmit => 'Review & Submit';

  @override
  String get smartRequestConfirmDetails => 'Confirm your details and submit.';

  @override
  String get smartRequestSummarySize => 'Size';

  @override
  String get smartRequestSummaryProperty => 'Property';

  @override
  String get smartRequestSummaryCondition => 'Condition';

  @override
  String get smartRequestSummaryBudget => 'Budget';

  @override
  String get smartRequestSummaryPhotos => 'Photos';

  @override
  String get smartRequestContactInformation => 'Contact Information';

  @override
  String get smartRequestAdditionalNotesOptional =>
      'Additional Notes (optional)';

  @override
  String get smartRequestSubmitRequest => 'Submit Request';

  @override
  String get boostListingTitle => 'Boost Listing';

  @override
  String get boostListingSubtitle => 'Appear first in search results';

  @override
  String get retry => 'Retry';
}
