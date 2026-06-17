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
  String get email => 'Email';

  @override
  String get phone => 'Phone';

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
  String get boostListingTitle => 'Boost Listing';

  @override
  String get boostListingSubtitle => 'Appear first in search results';

  @override
  String get retry => 'Retry';
}
