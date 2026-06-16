import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// The application title
  ///
  /// In en, this message translates to:
  /// **'ProServe Hub'**
  String get appTitle;

  /// Title of the service selection page
  ///
  /// In en, this message translates to:
  /// **'Select a Service'**
  String get selectService;

  /// Title of the browse contractors screen
  ///
  /// In en, this message translates to:
  /// **'Browse Contractors'**
  String get browseContractors;

  /// Title of the favorites screen
  ///
  /// In en, this message translates to:
  /// **'Saved Contractors'**
  String get savedContractors;

  /// Instant booking button label
  ///
  /// In en, this message translates to:
  /// **'Instant Book'**
  String get instantBook;

  /// Button to view a contractor's calendar
  ///
  /// In en, this message translates to:
  /// **'View Availability'**
  String get viewAvailability;

  /// Button to request a job
  ///
  /// In en, this message translates to:
  /// **'Request Job'**
  String get requestJob;

  /// Button to cancel a job
  ///
  /// In en, this message translates to:
  /// **'Cancel Job'**
  String get cancelJob;

  /// Referral screen title
  ///
  /// In en, this message translates to:
  /// **'Referral & Promo'**
  String get referralPromo;

  /// Booking confirmation alert
  ///
  /// In en, this message translates to:
  /// **'Booking Confirmed'**
  String get bookingConfirmed;

  /// Placeholder in error log
  ///
  /// In en, this message translates to:
  /// **'No errors logged yet.'**
  String get noErrors;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get quickActions;

  /// Quick action tile label
  ///
  /// In en, this message translates to:
  /// **'Start request'**
  String get startRequest;

  /// Quick action tile label
  ///
  /// In en, this message translates to:
  /// **'Browse pros'**
  String get browsePros;

  /// Quick action tile label
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// Quick action tile label
  ///
  /// In en, this message translates to:
  /// **'Project tracker'**
  String get projectTracker;

  /// Quick action tile label
  ///
  /// In en, this message translates to:
  /// **'Saved pros'**
  String get savedPros;

  /// Quick action tile label
  ///
  /// In en, this message translates to:
  /// **'Referral'**
  String get referral;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}'**
  String welcome(String name);

  /// Notification screen title
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Language selector label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Sign out button
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// Sign in button
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// Profile screen title
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// Home tab label
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// Search tab label
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// Project tab label
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get project;

  /// Community tab label
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get community;

  /// Tools tab label
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get tools;

  /// Jobs tab label
  ///
  /// In en, this message translates to:
  /// **'Jobs'**
  String get jobs;

  /// Plan tab label
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get plan;

  /// Render tool screen title
  ///
  /// In en, this message translates to:
  /// **'Render Tool'**
  String get renderTool;

  /// Before/after compare button
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get compare;

  /// Exit compare mode button
  ///
  /// In en, this message translates to:
  /// **'Exit compare'**
  String get exitCompare;

  /// Before label in comparison
  ///
  /// In en, this message translates to:
  /// **'BEFORE'**
  String get before;

  /// After label in comparison
  ///
  /// In en, this message translates to:
  /// **'AFTER'**
  String get after;

  /// Saved estimates screen title
  ///
  /// In en, this message translates to:
  /// **'My Estimates'**
  String get myEstimates;

  /// Empty state for estimates
  ///
  /// In en, this message translates to:
  /// **'No estimates yet'**
  String get noEstimatesYet;

  /// AI estimate button
  ///
  /// In en, this message translates to:
  /// **'Get AI Estimate'**
  String get getAiEstimate;

  /// Convert estimate to job button
  ///
  /// In en, this message translates to:
  /// **'Post as Job Request'**
  String get postAsJobRequest;

  /// Delete estimate button
  ///
  /// In en, this message translates to:
  /// **'Delete Estimate'**
  String get deleteEstimate;

  /// Expenses screen title
  ///
  /// In en, this message translates to:
  /// **'Receipts & Expenses'**
  String get receiptsExpenses;

  /// CSV export button
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get exportCsv;

  /// PDF export button
  ///
  /// In en, this message translates to:
  /// **'Export PDF'**
  String get exportPdf;

  /// Empty state for expenses
  ///
  /// In en, this message translates to:
  /// **'No receipts yet.'**
  String get noReceiptsYet;

  /// Calendar screen title
  ///
  /// In en, this message translates to:
  /// **'Availability Calendar'**
  String get availabilityCalendar;

  /// Set full day available
  ///
  /// In en, this message translates to:
  /// **'All Day Available'**
  String get allDayAvailable;

  /// Set full day unavailable
  ///
  /// In en, this message translates to:
  /// **'All Day Unavailable'**
  String get allDayUnavailable;

  /// AI estimator screen title
  ///
  /// In en, this message translates to:
  /// **'AI Estimator'**
  String get aiEstimator;

  /// New request button on estimate result
  ///
  /// In en, this message translates to:
  /// **'Start a New Request'**
  String get startNewRequest;

  /// Notification activity tab
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activity;

  /// Empty notifications
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotificationsYet;

  /// Notification prefs header
  ///
  /// In en, this message translates to:
  /// **'Choose which notifications you want to receive.'**
  String get chooseNotifications;

  /// Referral dashboard title
  ///
  /// In en, this message translates to:
  /// **'Referral Dashboard'**
  String get referralDashboard;

  /// Referral stat label
  ///
  /// In en, this message translates to:
  /// **'Total Referrals'**
  String get totalReferrals;

  /// Referral stat label
  ///
  /// In en, this message translates to:
  /// **'Credits Earned'**
  String get creditsEarned;

  /// Referral code header
  ///
  /// In en, this message translates to:
  /// **'Your Referral Code'**
  String get yourReferralCode;

  /// No description provided for @interiorPainting.
  ///
  /// In en, this message translates to:
  /// **'Interior Painting'**
  String get interiorPainting;

  /// No description provided for @cabinetPainting.
  ///
  /// In en, this message translates to:
  /// **'Cabinet Painting'**
  String get cabinetPainting;

  /// No description provided for @drywallRepair.
  ///
  /// In en, this message translates to:
  /// **'Drywall Repair'**
  String get drywallRepair;

  /// No description provided for @pressureWashing.
  ///
  /// In en, this message translates to:
  /// **'Pressure Washing'**
  String get pressureWashing;

  /// No description provided for @exteriorPainting.
  ///
  /// In en, this message translates to:
  /// **'Exterior Painting'**
  String get exteriorPainting;

  /// Price guarantee badge title
  ///
  /// In en, this message translates to:
  /// **'AI Price Match Guarantee'**
  String get aiPriceMatchGuarantee;

  /// Compact price guarantee badge label
  ///
  /// In en, this message translates to:
  /// **'AI Price Match'**
  String get aiPriceMatch;

  /// No description provided for @priceGuaranteeThreshold.
  ///
  /// In en, this message translates to:
  /// **'If your final cost exceeds our AI estimate by more than {threshold}, we\'ll credit the difference.'**
  String priceGuaranteeThreshold(String threshold);

  /// Cost breakdown chart title
  ///
  /// In en, this message translates to:
  /// **'Cost Breakdown'**
  String get costBreakdown;

  /// Labor cost label
  ///
  /// In en, this message translates to:
  /// **'Labor'**
  String get labor;

  /// Materials cost label
  ///
  /// In en, this message translates to:
  /// **'Materials'**
  String get materials;

  /// Platform fee label
  ///
  /// In en, this message translates to:
  /// **'Platform Fee'**
  String get platformFee;

  /// Escrow portion label
  ///
  /// In en, this message translates to:
  /// **'Escrow Protection'**
  String get escrowProtection;

  /// Section title for maintenance reminders
  ///
  /// In en, this message translates to:
  /// **'Maintenance Reminders'**
  String get maintenanceReminders;

  /// Badge text on due reminders
  ///
  /// In en, this message translates to:
  /// **'Maintenance Due'**
  String get maintenanceDue;

  /// Book action button
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get book;

  /// Seasonal deals section title
  ///
  /// In en, this message translates to:
  /// **'Deals & Offers'**
  String get seasonalDeals;

  /// No description provided for @hoursLeft.
  ///
  /// In en, this message translates to:
  /// **'{hours}h left'**
  String hoursLeft(int hours);

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'{percent}% OFF'**
  String off(int percent);

  /// Social proof section title
  ///
  /// In en, this message translates to:
  /// **'In Your Neighborhood'**
  String get neighborhoodActivity;

  /// No description provided for @homesNearYou.
  ///
  /// In en, this message translates to:
  /// **'{count} homes near you this month'**
  String homesNearYou(int count);

  /// Saved project boards screen title
  ///
  /// In en, this message translates to:
  /// **'Saved Projects'**
  String get savedProjects;

  /// Empty state for project boards
  ///
  /// In en, this message translates to:
  /// **'No projects yet'**
  String get noProjectsYet;

  /// Create project board button
  ///
  /// In en, this message translates to:
  /// **'Create Board'**
  String get createBoard;

  /// Board name field label
  ///
  /// In en, this message translates to:
  /// **'Board name'**
  String get boardName;

  /// Notes field label
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// Zero interest badge text
  ///
  /// In en, this message translates to:
  /// **'0% INTEREST'**
  String get zeroInterest;

  /// 3-month payment plan label
  ///
  /// In en, this message translates to:
  /// **'Pay in 3'**
  String get payInThree;

  /// 6-month payment plan label
  ///
  /// In en, this message translates to:
  /// **'Pay in 6'**
  String get payInSix;

  /// No description provided for @perMonth.
  ///
  /// In en, this message translates to:
  /// **'{amount}/mo'**
  String perMonth(String amount);

  /// Financing CTA
  ///
  /// In en, this message translates to:
  /// **'Choose a payment plan'**
  String get choosePaymentPlan;

  /// Financing card header
  ///
  /// In en, this message translates to:
  /// **'Financing Available'**
  String get financingAvailable;

  /// Multi-quote invite card title
  ///
  /// In en, this message translates to:
  /// **'Top Matched Pros'**
  String get topMatchedPros;

  /// No description provided for @prosInvited.
  ///
  /// In en, this message translates to:
  /// **'{count} pros invited — quotes arriving soon'**
  String prosInvited(int count);

  /// Countdown label
  ///
  /// In en, this message translates to:
  /// **'Time remaining'**
  String get timeRemaining;

  /// Verified tier badge
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verifiedPro;

  /// Trusted Pro tier badge
  ///
  /// In en, this message translates to:
  /// **'Trusted Pro'**
  String get trustedPro;

  /// Elite Pro tier badge
  ///
  /// In en, this message translates to:
  /// **'Elite Pro'**
  String get elitePro;

  /// Add photo button in timeline
  ///
  /// In en, this message translates to:
  /// **'Add Photo'**
  String get addPhoto;

  /// Request photo button in timeline
  ///
  /// In en, this message translates to:
  /// **'Request Photo'**
  String get requestPhoto;

  /// Snackbar message after photo request
  ///
  /// In en, this message translates to:
  /// **'Photo requested!'**
  String get photoRequested;

  /// Language option that follows the device locale
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystemDefault;

  /// Language picker title
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// Customer profile screen app bar title
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// Fallback customer display name
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customer;

  /// Profile action to set a password
  ///
  /// In en, this message translates to:
  /// **'Set password'**
  String get setPassword;

  /// Profile notification settings section title
  ///
  /// In en, this message translates to:
  /// **'Notification settings'**
  String get notificationSettings;

  /// Profile notification settings explanation
  ///
  /// In en, this message translates to:
  /// **'Get alerts when pros send you cost estimates or messages.'**
  String get notificationSettingsDescription;

  /// Button to request push notifications
  ///
  /// In en, this message translates to:
  /// **'Allow Push Notifications'**
  String get allowPushNotifications;

  /// Busy button label
  ///
  /// In en, this message translates to:
  /// **'Working…'**
  String get working;

  /// Profile support action
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get contactSupport;

  /// Help document title
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// Privacy policy document title
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// California privacy notice title
  ///
  /// In en, this message translates to:
  /// **'CA Notice at Collection'**
  String get caNoticeAtCollection;

  /// Terms of use document title
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get termsOfUse;

  /// Technical support document title
  ///
  /// In en, this message translates to:
  /// **'Report a technical problem'**
  String get reportTechnicalProblem;

  /// Privacy opt-out document title
  ///
  /// In en, this message translates to:
  /// **'Do not sell or share my info'**
  String get doNotSellOrShareMyInfo;

  /// Account deactivation document title
  ///
  /// In en, this message translates to:
  /// **'Deactivate account'**
  String get deactivateAccount;

  /// Account data deletion document title
  ///
  /// In en, this message translates to:
  /// **'Delete my account data'**
  String get deleteAccountData;

  /// Error when password reset email cannot be sent
  ///
  /// In en, this message translates to:
  /// **'No email found for this account.'**
  String get noEmailFound;

  /// No description provided for @passwordResetEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent to {email}'**
  String passwordResetEmailSent(String email);

  /// No description provided for @failedToSendEmail.
  ///
  /// In en, this message translates to:
  /// **'Failed to send email: {error}'**
  String failedToSendEmail(String error);

  /// Snackbar after notifications are enabled
  ///
  /// In en, this message translates to:
  /// **'Notifications enabled.'**
  String get notificationsEnabled;

  /// Snackbar when notification permission is denied
  ///
  /// In en, this message translates to:
  /// **'Notifications permission not granted.'**
  String get notificationsPermissionNotGranted;

  /// No description provided for @failedToEnableNotifications.
  ///
  /// In en, this message translates to:
  /// **'Failed to enable notifications: {error}'**
  String failedToEnableNotifications(String error);

  /// Snackbar after sign out
  ///
  /// In en, this message translates to:
  /// **'Signed out.'**
  String get signedOut;

  /// No description provided for @signOutFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign out failed: {error}'**
  String signOutFailed(String error);

  /// Version placeholder while app version is loading
  ///
  /// In en, this message translates to:
  /// **'Version …'**
  String get versionLoading;

  /// Subscription screen title
  ///
  /// In en, this message translates to:
  /// **'Subscription Plans'**
  String get subscriptionPlansTitle;

  /// Current subscription plan label
  ///
  /// In en, this message translates to:
  /// **'Current Plan'**
  String get subscriptionCurrentPlan;

  /// Subscription entitlement refresh status
  ///
  /// In en, this message translates to:
  /// **'Updating status…'**
  String get subscriptionUpdatingStatus;

  /// Basic subscription tier name
  ///
  /// In en, this message translates to:
  /// **'Basic'**
  String get subscriptionTierBasic;

  /// Pro subscription tier name
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get subscriptionTierPro;

  /// Enterprise subscription tier name
  ///
  /// In en, this message translates to:
  /// **'Enterprise'**
  String get subscriptionTierEnterprise;

  /// Free subscription price
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get subscriptionPriceFree;

  /// Recommended subscription badge
  ///
  /// In en, this message translates to:
  /// **'POPULAR'**
  String get subscriptionPopular;

  /// Current subscription badge
  ///
  /// In en, this message translates to:
  /// **'CURRENT'**
  String get subscriptionCurrent;

  /// No description provided for @subscriptionFeatureJobFeedAccess.
  ///
  /// In en, this message translates to:
  /// **'Job feed access'**
  String get subscriptionFeatureJobFeedAccess;

  /// No description provided for @subscriptionFeatureAcceptCustomerBids.
  ///
  /// In en, this message translates to:
  /// **'Accept customer bids'**
  String get subscriptionFeatureAcceptCustomerBids;

  /// No description provided for @subscriptionFeatureCommunityFeed.
  ///
  /// In en, this message translates to:
  /// **'Community feed'**
  String get subscriptionFeatureCommunityFeed;

  /// No description provided for @subscriptionFeatureEverythingBasic.
  ///
  /// In en, this message translates to:
  /// **'Everything in Basic'**
  String get subscriptionFeatureEverythingBasic;

  /// No description provided for @subscriptionFeaturePricingCalculator.
  ///
  /// In en, this message translates to:
  /// **'Pricing Calculator'**
  String get subscriptionFeaturePricingCalculator;

  /// No description provided for @subscriptionFeatureCostEstimator.
  ///
  /// In en, this message translates to:
  /// **'Cost Estimator'**
  String get subscriptionFeatureCostEstimator;

  /// No description provided for @subscriptionFeatureAiInvoiceMaker.
  ///
  /// In en, this message translates to:
  /// **'AI Invoice Maker'**
  String get subscriptionFeatureAiInvoiceMaker;

  /// No description provided for @subscriptionFeatureRenderTool.
  ///
  /// In en, this message translates to:
  /// **'Render Tool'**
  String get subscriptionFeatureRenderTool;

  /// No description provided for @subscriptionFeatureEverythingPro.
  ///
  /// In en, this message translates to:
  /// **'Everything in Pro'**
  String get subscriptionFeatureEverythingPro;

  /// No description provided for @subscriptionFeatureProfitLossDashboard.
  ///
  /// In en, this message translates to:
  /// **'Profit & Loss Dashboard'**
  String get subscriptionFeatureProfitLossDashboard;

  /// No description provided for @subscriptionFeaturePriorityJobFeed.
  ///
  /// In en, this message translates to:
  /// **'Priority job feed (30 min early)'**
  String get subscriptionFeaturePriorityJobFeed;

  /// No description provided for @subscriptionFeatureUnlimitedAi.
  ///
  /// In en, this message translates to:
  /// **'Unlimited AI estimates & renders'**
  String get subscriptionFeatureUnlimitedAi;

  /// No description provided for @subscriptionFeatureInvoicePaymentCollection.
  ///
  /// In en, this message translates to:
  /// **'Invoice payment collection'**
  String get subscriptionFeatureInvoicePaymentCollection;

  /// No description provided for @subscriptionFeatureSubcontractorBoard.
  ///
  /// In en, this message translates to:
  /// **'Subcontractor board'**
  String get subscriptionFeatureSubcontractorBoard;

  /// No description provided for @subscriptionFeatureCrewRoster.
  ///
  /// In en, this message translates to:
  /// **'Crew roster & scheduling'**
  String get subscriptionFeatureCrewRoster;

  /// No description provided for @subscriptionManagedSettings.
  ///
  /// In en, this message translates to:
  /// **'Auto-renewing monthly subscription. Cancel anytime in your {settingsName} settings.'**
  String subscriptionManagedSettings(String settingsName);

  /// No description provided for @subscriptionOpeningCheckout.
  ///
  /// In en, this message translates to:
  /// **'Opening checkout...'**
  String get subscriptionOpeningCheckout;

  /// No description provided for @subscriptionUpgradeWithCard.
  ///
  /// In en, this message translates to:
  /// **'Upgrade with Card'**
  String get subscriptionUpgradeWithCard;

  /// No description provided for @subscriptionOpeningStore.
  ///
  /// In en, this message translates to:
  /// **'Opening store...'**
  String get subscriptionOpeningStore;

  /// No description provided for @subscriptionSubscribeWithStorePrice.
  ///
  /// In en, this message translates to:
  /// **'Subscribe with {storeName} ({price})'**
  String subscriptionSubscribeWithStorePrice(String storeName, String price);

  /// No description provided for @subscriptionSubscribeWithStore.
  ///
  /// In en, this message translates to:
  /// **'Subscribe with {storeName}'**
  String subscriptionSubscribeWithStore(String storeName);

  /// No description provided for @subscriptionStoreUnavailableShort.
  ///
  /// In en, this message translates to:
  /// **'{storeName} subscription unavailable'**
  String subscriptionStoreUnavailableShort(String storeName);

  /// No description provided for @subscriptionIosManagementCopy.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions are purchased with Apple In-App Purchase and managed in Apple ID Settings.'**
  String get subscriptionIosManagementCopy;

  /// No description provided for @subscriptionAndroidManagementCopy.
  ///
  /// In en, this message translates to:
  /// **'Tip: Google Play is best for mobile subscriptions. Stripe is a flexible fallback and works outside the app store flow.'**
  String get subscriptionAndroidManagementCopy;

  /// No description provided for @subscriptionInformation.
  ///
  /// In en, this message translates to:
  /// **'Subscription information'**
  String get subscriptionInformation;

  /// No description provided for @subscriptionAutoRenewInfo.
  ///
  /// In en, this message translates to:
  /// **'Pro and Enterprise plans are monthly auto-renewable subscriptions. Payment is charged to your {accountName} at confirmation of purchase and renews automatically unless canceled at least 24 hours before the end of the current period.'**
  String subscriptionAutoRenewInfo(String accountName);

  /// No description provided for @subscriptionRestorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchases'**
  String get subscriptionRestorePurchases;

  /// No description provided for @subscriptionRestoreComplete.
  ///
  /// In en, this message translates to:
  /// **'Restore complete. Checking subscription status.'**
  String get subscriptionRestoreComplete;

  /// No description provided for @subscriptionRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed: {error}'**
  String subscriptionRestoreFailed(String error);

  /// No description provided for @subscriptionPurchasePending.
  ///
  /// In en, this message translates to:
  /// **'Purchase is pending confirmation.'**
  String get subscriptionPurchasePending;

  /// No description provided for @subscriptionPurchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'Purchase failed.'**
  String get subscriptionPurchaseFailed;

  /// No description provided for @subscriptionPurchaseCanceled.
  ///
  /// In en, this message translates to:
  /// **'Purchase canceled.'**
  String get subscriptionPurchaseCanceled;

  /// No description provided for @subscriptionEnterpriseActivated.
  ///
  /// In en, this message translates to:
  /// **'Enterprise subscription activated.'**
  String get subscriptionEnterpriseActivated;

  /// No description provided for @subscriptionProActivated.
  ///
  /// In en, this message translates to:
  /// **'Pro subscription activated.'**
  String get subscriptionProActivated;

  /// No description provided for @subscriptionVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Subscription verification failed: {error}'**
  String subscriptionVerificationFailed(String error);

  /// No description provided for @subscriptionCheckoutBrowserReturn.
  ///
  /// In en, this message translates to:
  /// **'Complete checkout in the browser, then return to the app. We will update your status automatically.'**
  String get subscriptionCheckoutBrowserReturn;

  /// No description provided for @subscriptionStoreTierUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Store subscription for {tierName} is not available yet.'**
  String subscriptionStoreTierUnavailable(String tierName);

  /// No description provided for @subscriptionStoreUnavailable.
  ///
  /// In en, this message translates to:
  /// **'{storeName} subscriptions are unavailable right now. Please try again from a signed-in store account.'**
  String subscriptionStoreUnavailable(String storeName);

  /// No description provided for @subscriptionProductLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load subscription products: {error}'**
  String subscriptionProductLoadFailed(String error);

  /// No description provided for @subscriptionMissingProducts.
  ///
  /// In en, this message translates to:
  /// **'Missing subscription products in App Store Connect: {productIds}.'**
  String subscriptionMissingProducts(String productIds);

  /// No description provided for @subscriptionNoProductsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No subscription products are available for this Apple sandbox account yet.'**
  String get subscriptionNoProductsAvailable;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @subscribe.
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get subscribe;

  /// No description provided for @manageSubscription.
  ///
  /// In en, this message translates to:
  /// **'Manage subscription'**
  String get manageSubscription;

  /// No description provided for @toolsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get toolsTitle;

  /// No description provided for @toolsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Win work, estimate faster, manage jobs, and get paid'**
  String get toolsSubtitle;

  /// No description provided for @toolsTodayTitle.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get toolsTodayTitle;

  /// No description provided for @toolsTodaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your contractor operating system at a glance.'**
  String get toolsTodaySubtitle;

  /// No description provided for @toolsPayoutsReady.
  ///
  /// In en, this message translates to:
  /// **'Payouts ready'**
  String get toolsPayoutsReady;

  /// No description provided for @toolsPayoutsNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Connect payouts'**
  String get toolsPayoutsNotConnected;

  /// No description provided for @toolsLeadCredits.
  ///
  /// In en, this message translates to:
  /// **'{count} lead credits'**
  String toolsLeadCredits(int count);

  /// No description provided for @toolsProActive.
  ///
  /// In en, this message translates to:
  /// **'Pro active'**
  String get toolsProActive;

  /// No description provided for @toolsProLocked.
  ///
  /// In en, this message translates to:
  /// **'Pro locked'**
  String get toolsProLocked;

  /// No description provided for @toolsEnterpriseActive.
  ///
  /// In en, this message translates to:
  /// **'Enterprise active'**
  String get toolsEnterpriseActive;

  /// No description provided for @toolsEnterpriseLocked.
  ///
  /// In en, this message translates to:
  /// **'Enterprise locked'**
  String get toolsEnterpriseLocked;

  /// No description provided for @toolsReviewSetup.
  ///
  /// In en, this message translates to:
  /// **'Review setup'**
  String get toolsReviewSetup;

  /// No description provided for @contractorProTitle.
  ///
  /// In en, this message translates to:
  /// **'Contractor Pro'**
  String get contractorProTitle;

  /// No description provided for @contractorProPrice.
  ///
  /// In en, this message translates to:
  /// **'\$11.99 / month'**
  String get contractorProPrice;

  /// No description provided for @contractorProUnlocks.
  ///
  /// In en, this message translates to:
  /// **'Unlock invoices, pricing, estimates, renders, and stronger daily tools.'**
  String get contractorProUnlocks;

  /// No description provided for @accessPro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get accessPro;

  /// No description provided for @accessEnterprise.
  ///
  /// In en, this message translates to:
  /// **'Enterprise'**
  String get accessEnterprise;

  /// No description provided for @lockedPro.
  ///
  /// In en, this message translates to:
  /// **'Pro locked'**
  String get lockedPro;

  /// No description provided for @lockedEnterprise.
  ///
  /// In en, this message translates to:
  /// **'Enterprise locked'**
  String get lockedEnterprise;

  /// No description provided for @toolsSectionWinWork.
  ///
  /// In en, this message translates to:
  /// **'Win Work'**
  String get toolsSectionWinWork;

  /// No description provided for @toolsSectionEstimateQuote.
  ///
  /// In en, this message translates to:
  /// **'Estimate & Quote'**
  String get toolsSectionEstimateQuote;

  /// No description provided for @toolsSectionGetPaid.
  ///
  /// In en, this message translates to:
  /// **'Get Paid'**
  String get toolsSectionGetPaid;

  /// No description provided for @toolsSectionManageJobs.
  ///
  /// In en, this message translates to:
  /// **'Manage Jobs'**
  String get toolsSectionManageJobs;

  /// No description provided for @toolsSectionGrowOperations.
  ///
  /// In en, this message translates to:
  /// **'Grow Operations'**
  String get toolsSectionGrowOperations;

  /// No description provided for @toolAiInvoiceMakerTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Invoice Maker'**
  String get toolAiInvoiceMakerTitle;

  /// No description provided for @toolAiInvoiceMakerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a client or job, build line items, terms, deposits, and payment links.'**
  String get toolAiInvoiceMakerSubtitle;

  /// No description provided for @toolInvoicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get toolInvoicesTitle;

  /// No description provided for @toolInvoicesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Filter drafts, sent, paid, and overdue invoices; resend reminders.'**
  String get toolInvoicesSubtitle;

  /// No description provided for @toolPricingCalculatorTitle.
  ///
  /// In en, this message translates to:
  /// **'Pricing Calculator'**
  String get toolPricingCalculatorTitle;

  /// No description provided for @toolPricingCalculatorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use labor, material, margin, and market assumptions to price jobs.'**
  String get toolPricingCalculatorSubtitle;

  /// No description provided for @toolCostEstimatorTitle.
  ///
  /// In en, this message translates to:
  /// **'Cost Estimator'**
  String get toolCostEstimatorTitle;

  /// No description provided for @toolCostEstimatorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create detailed cost estimates with editable assumptions and revisions.'**
  String get toolCostEstimatorSubtitle;

  /// No description provided for @toolRenderToolTitle.
  ///
  /// In en, this message translates to:
  /// **'Render Tool'**
  String get toolRenderToolTitle;

  /// No description provided for @toolRenderToolSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Preview colors, rooms, and surfaces before sending a proposal.'**
  String get toolRenderToolSubtitle;

  /// No description provided for @toolRenderGalleryTitle.
  ///
  /// In en, this message translates to:
  /// **'Render Gallery'**
  String get toolRenderGalleryTitle;

  /// No description provided for @toolRenderGallerySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Organize renders by client, job, room, and share-ready packs.'**
  String get toolRenderGallerySubtitle;

  /// No description provided for @toolSavedEstimatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved Estimates'**
  String get toolSavedEstimatesTitle;

  /// No description provided for @toolSavedEstimatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Duplicate, revise, compare, share, and convert estimates.'**
  String get toolSavedEstimatesSubtitle;

  /// No description provided for @toolSmartSchedulingTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart Scheduling AI'**
  String get toolSmartSchedulingTitle;

  /// No description provided for @toolSmartSchedulingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Balance crews, priorities, travel, and weather risk across the week.'**
  String get toolSmartSchedulingSubtitle;

  /// No description provided for @toolQualityInspectorTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Quality Inspector'**
  String get toolQualityInspectorTitle;

  /// No description provided for @toolQualityInspectorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review job photos with checklists, defects, severity, and reports.'**
  String get toolQualityInspectorSubtitle;

  /// No description provided for @toolMultiLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Multi-Location Dashboard'**
  String get toolMultiLocationTitle;

  /// No description provided for @toolMultiLocationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track revenue, active jobs, crews, unpaid invoices, and lead conversion.'**
  String get toolMultiLocationSubtitle;

  /// No description provided for @toolSubMarketplaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Sub Marketplace'**
  String get toolSubMarketplaceTitle;

  /// No description provided for @toolSubMarketplaceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Post overflow work, compare bids, verify subs, and hand off jobs.'**
  String get toolSubMarketplaceSubtitle;

  /// No description provided for @toolBidAnalyzerTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Bid Analyzer'**
  String get toolBidAnalyzerTitle;

  /// No description provided for @toolBidAnalyzerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Extract line items, score margin risk, and generate counter-bids.'**
  String get toolBidAnalyzerSubtitle;

  /// No description provided for @toolSelectServiceType.
  ///
  /// In en, this message translates to:
  /// **'Select Service Type'**
  String get toolSelectServiceType;

  /// No description provided for @toolActionUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get toolActionUnlock;

  /// No description provided for @toolActionAnalyzeBid.
  ///
  /// In en, this message translates to:
  /// **'Analyze bid'**
  String get toolActionAnalyzeBid;

  /// No description provided for @toolActionPostJob.
  ///
  /// In en, this message translates to:
  /// **'Post job'**
  String get toolActionPostJob;

  /// No description provided for @toolActionPriceJob.
  ///
  /// In en, this message translates to:
  /// **'Price job'**
  String get toolActionPriceJob;

  /// No description provided for @toolActionEstimateCost.
  ///
  /// In en, this message translates to:
  /// **'Estimate cost'**
  String get toolActionEstimateCost;

  /// No description provided for @toolActionReviewEstimates.
  ///
  /// In en, this message translates to:
  /// **'Review estimates'**
  String get toolActionReviewEstimates;

  /// No description provided for @toolActionCreateInvoice.
  ///
  /// In en, this message translates to:
  /// **'Create invoice'**
  String get toolActionCreateInvoice;

  /// No description provided for @toolActionTrackInvoices.
  ///
  /// In en, this message translates to:
  /// **'Track invoices'**
  String get toolActionTrackInvoices;

  /// No description provided for @toolActionBuildSchedule.
  ///
  /// In en, this message translates to:
  /// **'Build schedule'**
  String get toolActionBuildSchedule;

  /// No description provided for @toolActionInspectPhotos.
  ///
  /// In en, this message translates to:
  /// **'Inspect photos'**
  String get toolActionInspectPhotos;

  /// No description provided for @toolActionCreateRender.
  ///
  /// In en, this message translates to:
  /// **'Create render'**
  String get toolActionCreateRender;

  /// No description provided for @toolActionOpenGallery.
  ///
  /// In en, this message translates to:
  /// **'Open gallery'**
  String get toolActionOpenGallery;

  /// No description provided for @toolActionReviewLocations.
  ///
  /// In en, this message translates to:
  /// **'Review locations'**
  String get toolActionReviewLocations;

  /// No description provided for @toolMetricRiskScore.
  ///
  /// In en, this message translates to:
  /// **'Risk score'**
  String get toolMetricRiskScore;

  /// No description provided for @toolMetricVerifiedSubs.
  ///
  /// In en, this message translates to:
  /// **'Verified subs'**
  String get toolMetricVerifiedSubs;

  /// No description provided for @toolMetricMarginReady.
  ///
  /// In en, this message translates to:
  /// **'Margin ready'**
  String get toolMetricMarginReady;

  /// No description provided for @toolMetricRevisionHistory.
  ///
  /// In en, this message translates to:
  /// **'Revision history'**
  String get toolMetricRevisionHistory;

  /// No description provided for @toolMetricQuoteReady.
  ///
  /// In en, this message translates to:
  /// **'Quote ready'**
  String get toolMetricQuoteReady;

  /// No description provided for @toolMetricPaymentLink.
  ///
  /// In en, this message translates to:
  /// **'Payment link'**
  String get toolMetricPaymentLink;

  /// No description provided for @toolMetricOverdueBadges.
  ///
  /// In en, this message translates to:
  /// **'Overdue badges'**
  String get toolMetricOverdueBadges;

  /// No description provided for @toolMetricConflictWarnings.
  ///
  /// In en, this message translates to:
  /// **'Conflict warnings'**
  String get toolMetricConflictWarnings;

  /// No description provided for @toolMetricReportPdf.
  ///
  /// In en, this message translates to:
  /// **'Report PDF'**
  String get toolMetricReportPdf;

  /// No description provided for @toolMetricClientShare.
  ///
  /// In en, this message translates to:
  /// **'Client share'**
  String get toolMetricClientShare;

  /// No description provided for @toolMetricFolders.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get toolMetricFolders;

  /// No description provided for @toolMetricOwnerSummary.
  ///
  /// In en, this message translates to:
  /// **'Owner summary'**
  String get toolMetricOwnerSummary;

  /// No description provided for @boostListingTitle.
  ///
  /// In en, this message translates to:
  /// **'Boost Listing'**
  String get boostListingTitle;

  /// No description provided for @boostListingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Appear first in search results'**
  String get boostListingSubtitle;

  /// Retry button label
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
