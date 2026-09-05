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

  /// Customer loyalty feature label
  ///
  /// In en, this message translates to:
  /// **'Loyalty'**
  String get loyalty;

  /// Leaderboard feature label
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get leaderboard;

  /// AI support chat label
  ///
  /// In en, this message translates to:
  /// **'AI Support'**
  String get aiSupport;

  /// Customer project request list title
  ///
  /// In en, this message translates to:
  /// **'My Requests'**
  String get myRequests;

  /// Refresh button label
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// Customer portal action center title
  ///
  /// In en, this message translates to:
  /// **'Action Center'**
  String get actionCenter;

  /// Metric label for active items
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// Metric label for quote count
  ///
  /// In en, this message translates to:
  /// **'quotes'**
  String get quotes;

  /// Metric label for protected payment jobs
  ///
  /// In en, this message translates to:
  /// **'protected'**
  String get protected;

  /// Home hero trust chip
  ///
  /// In en, this message translates to:
  /// **'Verified pros'**
  String get verifiedPros;

  /// Home hero trust chip
  ///
  /// In en, this message translates to:
  /// **'Upfront pricing'**
  String get upfrontPricing;

  /// Home hero trust chip
  ///
  /// In en, this message translates to:
  /// **'Project tracking'**
  String get projectTracking;

  /// No description provided for @landingLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get landingLanguageSystem;

  /// No description provided for @landingBadge.
  ///
  /// In en, this message translates to:
  /// **'AI-powered contractor OS'**
  String get landingBadge;

  /// No description provided for @landingHeadlinePrefix.
  ///
  /// In en, this message translates to:
  /// **'Connect. Hire.\nGet Work '**
  String get landingHeadlinePrefix;

  /// No description provided for @landingHeadlineAccent.
  ///
  /// In en, this message translates to:
  /// **'Done.'**
  String get landingHeadlineAccent;

  /// No description provided for @landingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The all-in-one platform for homeowners and contractors to keep projects moving.'**
  String get landingSubtitle;

  /// No description provided for @landingHomeownerTitle.
  ///
  /// In en, this message translates to:
  /// **'I need a contractor'**
  String get landingHomeownerTitle;

  /// No description provided for @landingHomeownerBody.
  ///
  /// In en, this message translates to:
  /// **'Post your job and connect with trusted local pros.'**
  String get landingHomeownerBody;

  /// No description provided for @landingHomeownerBulletVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified & reviewed pros'**
  String get landingHomeownerBulletVerified;

  /// No description provided for @landingHomeownerBulletQuotes.
  ///
  /// In en, this message translates to:
  /// **'Upfront quotes'**
  String get landingHomeownerBulletQuotes;

  /// No description provided for @landingHomeownerBulletEscrow.
  ///
  /// In en, this message translates to:
  /// **'Escrow-safe payments'**
  String get landingHomeownerBulletEscrow;

  /// No description provided for @landingHomeownerCta.
  ///
  /// In en, this message translates to:
  /// **'Find a Contractor'**
  String get landingHomeownerCta;

  /// No description provided for @landingHomeownerFootnote.
  ///
  /// In en, this message translates to:
  /// **'As a homeowner'**
  String get landingHomeownerFootnote;

  /// No description provided for @landingContractorTitle.
  ///
  /// In en, this message translates to:
  /// **'I run a contractor business'**
  String get landingContractorTitle;

  /// No description provided for @landingContractorBody.
  ///
  /// In en, this message translates to:
  /// **'Find quality leads, quote fast, and grow your business.'**
  String get landingContractorBody;

  /// No description provided for @landingContractorBulletLeads.
  ///
  /// In en, this message translates to:
  /// **'High-quality local leads'**
  String get landingContractorBulletLeads;

  /// No description provided for @landingContractorBulletTools.
  ///
  /// In en, this message translates to:
  /// **'AI tools to quote & invoice'**
  String get landingContractorBulletTools;

  /// No description provided for @landingContractorBulletPaid.
  ///
  /// In en, this message translates to:
  /// **'Get paid faster'**
  String get landingContractorBulletPaid;

  /// No description provided for @landingContractorCta.
  ///
  /// In en, this message translates to:
  /// **'I\'m a Contractor'**
  String get landingContractorCta;

  /// No description provided for @landingContractorFootnote.
  ///
  /// In en, this message translates to:
  /// **'Grow my business'**
  String get landingContractorFootnote;

  /// No description provided for @landingTrustVerifiedTitle.
  ///
  /// In en, this message translates to:
  /// **'Verified Pros'**
  String get landingTrustVerifiedTitle;

  /// No description provided for @landingTrustVerifiedBody.
  ///
  /// In en, this message translates to:
  /// **'Background checked and insured'**
  String get landingTrustVerifiedBody;

  /// No description provided for @landingTrustEscrowTitle.
  ///
  /// In en, this message translates to:
  /// **'Escrow-Safe Payments'**
  String get landingTrustEscrowTitle;

  /// No description provided for @landingTrustEscrowBody.
  ///
  /// In en, this message translates to:
  /// **'Your payment is protected'**
  String get landingTrustEscrowBody;

  /// No description provided for @landingTrustTrackingTitle.
  ///
  /// In en, this message translates to:
  /// **'Real Project Tracking'**
  String get landingTrustTrackingTitle;

  /// No description provided for @landingTrustTrackingBody.
  ///
  /// In en, this message translates to:
  /// **'Stay updated from start to finish'**
  String get landingTrustTrackingBody;

  /// No description provided for @landingBuiltTitle.
  ///
  /// In en, this message translates to:
  /// **'Built for the trades.'**
  String get landingBuiltTitle;

  /// No description provided for @landingBuiltSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Powered by AI. Backed by trust.'**
  String get landingBuiltSubtitle;

  /// Camera quote button label
  ///
  /// In en, this message translates to:
  /// **'Snap for Instant Quote'**
  String get snapForInstantQuote;

  /// Action center button label
  ///
  /// In en, this message translates to:
  /// **'View all projects'**
  String get viewAllProjects;

  /// Empty action center CTA
  ///
  /// In en, this message translates to:
  /// **'Post your first job'**
  String get postYourFirstJob;

  /// Fallback name for customer welcome
  ///
  /// In en, this message translates to:
  /// **'there'**
  String get customerWelcomeFallback;

  /// Customer home hero headline
  ///
  /// In en, this message translates to:
  /// **'BOOK A PRO IN MINUTES'**
  String get customerHomeHeroTitle;

  /// Customer home hero subtitle
  ///
  /// In en, this message translates to:
  /// **'Tell us what you need, compare quotes, and track the job here.'**
  String get customerHomeHeroSubtitle;

  /// No description provided for @customerTodayTitle.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get customerTodayTitle;

  /// No description provided for @customerTodaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Post a project, compare trusted pros, pay safely, and track the work.'**
  String get customerTodaySubtitle;

  /// No description provided for @customerStartProject.
  ///
  /// In en, this message translates to:
  /// **'Start a project'**
  String get customerStartProject;

  /// No description provided for @customerActiveProjects.
  ///
  /// In en, this message translates to:
  /// **'Active projects'**
  String get customerActiveProjects;

  /// No description provided for @customerQuotesWaiting.
  ///
  /// In en, this message translates to:
  /// **'Quotes waiting'**
  String get customerQuotesWaiting;

  /// No description provided for @customerProtectedPayments.
  ///
  /// In en, this message translates to:
  /// **'Protected payments'**
  String get customerProtectedPayments;

  /// No description provided for @customerReviewsDue.
  ///
  /// In en, this message translates to:
  /// **'Reviews due'**
  String get customerReviewsDue;

  /// No description provided for @customerCoreFlowTitle.
  ///
  /// In en, this message translates to:
  /// **'Project shortcuts'**
  String get customerCoreFlowTitle;

  /// No description provided for @customerCoreFlowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse pros, messages, and project tracking.'**
  String get customerCoreFlowSubtitle;

  /// No description provided for @customerMoreToolsTitle.
  ///
  /// In en, this message translates to:
  /// **'More homeowner tools'**
  String get customerMoreToolsTitle;

  /// No description provided for @customerMoreToolsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Saved pros, rewards, support, reminders, and neighborhood proof.'**
  String get customerMoreToolsSubtitle;

  /// Customer quick action subtitle
  ///
  /// In en, this message translates to:
  /// **'Smart 4-step flow'**
  String get customerQuickStartRequestSubtitle;

  /// Customer quick action subtitle
  ///
  /// In en, this message translates to:
  /// **'Compare nearby contractors'**
  String get customerQuickBrowseProsSubtitle;

  /// Customer quick action subtitle
  ///
  /// In en, this message translates to:
  /// **'Open your inbox'**
  String get customerQuickMessagesSubtitle;

  /// Customer quick action subtitle
  ///
  /// In en, this message translates to:
  /// **'View active requests'**
  String get customerQuickProjectTrackerSubtitle;

  /// Customer quick action subtitle
  ///
  /// In en, this message translates to:
  /// **'Your favorite contractors'**
  String get customerQuickSavedProsSubtitle;

  /// Customer quick action subtitle
  ///
  /// In en, this message translates to:
  /// **'Share and earn credit'**
  String get customerQuickReferralSubtitle;

  /// Customer quick action subtitle
  ///
  /// In en, this message translates to:
  /// **'Points and rewards'**
  String get customerQuickLoyaltySubtitle;

  /// Customer quick action subtitle
  ///
  /// In en, this message translates to:
  /// **'Top-rated pros'**
  String get customerQuickLeaderboardSubtitle;

  /// Customer quick action subtitle
  ///
  /// In en, this message translates to:
  /// **'Plan future work'**
  String get customerQuickSavedProjectsSubtitle;

  /// Customer quick action subtitle
  ///
  /// In en, this message translates to:
  /// **'View saved AI estimates'**
  String get customerQuickMyEstimatesSubtitle;

  /// Customer quick action subtitle
  ///
  /// In en, this message translates to:
  /// **'Get instant help 24/7'**
  String get customerQuickAiSupportSubtitle;

  /// No description provided for @customerProjectsTitle.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get customerProjectsTitle;

  /// No description provided for @customerProjectsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track requests, quotes, payments, and completed work.'**
  String get customerProjectsSubtitle;

  /// No description provided for @projectNewProject.
  ///
  /// In en, this message translates to:
  /// **'New project'**
  String get projectNewProject;

  /// No description provided for @projectFilterActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get projectFilterActive;

  /// No description provided for @projectFilterQuotes.
  ///
  /// In en, this message translates to:
  /// **'Quotes'**
  String get projectFilterQuotes;

  /// No description provided for @projectFilterProtected.
  ///
  /// In en, this message translates to:
  /// **'Protected'**
  String get projectFilterProtected;

  /// No description provided for @projectFilterCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get projectFilterCompleted;

  /// No description provided for @projectFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get projectFilterAll;

  /// No description provided for @projectEmptyActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'No active projects'**
  String get projectEmptyActiveTitle;

  /// No description provided for @projectEmptyActiveBody.
  ///
  /// In en, this message translates to:
  /// **'No active projects right now. Start from Home or Browse Pros.'**
  String get projectEmptyActiveBody;

  /// No description provided for @projectEmptyQuotesTitle.
  ///
  /// In en, this message translates to:
  /// **'No quotes yet'**
  String get projectEmptyQuotesTitle;

  /// No description provided for @projectEmptyQuotesBody.
  ///
  /// In en, this message translates to:
  /// **'Quotes will appear here after contractors respond.'**
  String get projectEmptyQuotesBody;

  /// No description provided for @projectEmptyProtectedTitle.
  ///
  /// In en, this message translates to:
  /// **'No protected payments'**
  String get projectEmptyProtectedTitle;

  /// No description provided for @projectEmptyProtectedBody.
  ///
  /// In en, this message translates to:
  /// **'Escrow projects will appear here once payment is protected.'**
  String get projectEmptyProtectedBody;

  /// No description provided for @projectEmptyCompletedTitle.
  ///
  /// In en, this message translates to:
  /// **'No completed projects'**
  String get projectEmptyCompletedTitle;

  /// No description provided for @projectEmptyCompletedBody.
  ///
  /// In en, this message translates to:
  /// **'Completed work and review history will appear here.'**
  String get projectEmptyCompletedBody;

  /// No description provided for @projectOfflineCached.
  ///
  /// In en, this message translates to:
  /// **'Showing cached project data. You may be offline.'**
  String get projectOfflineCached;

  /// No description provided for @projectToolsTitle.
  ///
  /// In en, this message translates to:
  /// **'Project tools'**
  String get projectToolsTitle;

  /// No description provided for @projectToolsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Estimator, analytics, and protected payment details.'**
  String get projectToolsSubtitle;

  /// No description provided for @projectLeaveReview.
  ///
  /// In en, this message translates to:
  /// **'Leave review'**
  String get projectLeaveReview;

  /// No description provided for @projectCheckPayment.
  ///
  /// In en, this message translates to:
  /// **'Check payment'**
  String get projectCheckPayment;

  /// No description provided for @projectCompareQuotes.
  ///
  /// In en, this message translates to:
  /// **'Compare quotes'**
  String get projectCompareQuotes;

  /// No description provided for @projectViewSummary.
  ///
  /// In en, this message translates to:
  /// **'View summary'**
  String get projectViewSummary;

  /// No description provided for @projectOpenCommandCenter.
  ///
  /// In en, this message translates to:
  /// **'Open command center'**
  String get projectOpenCommandCenter;

  /// No description provided for @projectViewProject.
  ///
  /// In en, this message translates to:
  /// **'View project'**
  String get projectViewProject;

  /// No description provided for @projectLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get projectLocationLabel;

  /// No description provided for @projectContractorLabel.
  ///
  /// In en, this message translates to:
  /// **'Contractor'**
  String get projectContractorLabel;

  /// No description provided for @projectCreatedLabel.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get projectCreatedLabel;

  /// No description provided for @projectAssignedLabel.
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get projectAssignedLabel;

  /// No description provided for @projectProtectedPayment.
  ///
  /// In en, this message translates to:
  /// **'Protected payment'**
  String get projectProtectedPayment;

  /// No description provided for @projectNearbyContractors.
  ///
  /// In en, this message translates to:
  /// **'Nearby contractors'**
  String get projectNearbyContractors;

  /// Customer requests error title
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your requests'**
  String get couldNotLoadRequests;

  /// Customer requests delayed loading title
  ///
  /// In en, this message translates to:
  /// **'Still loading your requests...'**
  String get stillLoadingRequests;

  /// Customer requests fallback notice
  ///
  /// In en, this message translates to:
  /// **'Showing legacy requests.'**
  String get showingLegacyRequests;

  /// Customer action center subtitle
  ///
  /// In en, this message translates to:
  /// **'Your next step to get the project done safely.'**
  String get customerActionCenterSubtitle;

  /// Customer action center no quotes tip
  ///
  /// In en, this message translates to:
  /// **'Tip: invite more pros or browse contractors if a request has no quotes yet.'**
  String get customerActionCenterNoQuotesTip;

  /// No description provided for @reviewService.
  ///
  /// In en, this message translates to:
  /// **'Review {service}'**
  String reviewService(String service);

  /// Customer review action subtitle
  ///
  /// In en, this message translates to:
  /// **'Help future homeowners trust the right pro.'**
  String get customerActionReviewSubtitle;

  /// Customer escrow action title
  ///
  /// In en, this message translates to:
  /// **'Check protected payment'**
  String get checkProtectedPayment;

  /// No description provided for @customerActionEscrowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View escrow status and release steps for {service}.'**
  String customerActionEscrowSubtitle(String service);

  /// No description provided for @compareQuoteCount.
  ///
  /// In en, this message translates to:
  /// **'Compare {count, plural, =1{1 quote} other{{count} quotes}}'**
  String compareQuoteCount(int count);

  /// Customer compare quote action subtitle
  ///
  /// In en, this message translates to:
  /// **'Review price, scope, warranty, and contractor proof.'**
  String get customerActionCompareSubtitle;

  /// No description provided for @trackService.
  ///
  /// In en, this message translates to:
  /// **'Track {service}'**
  String trackService(String service);

  /// Customer track job action subtitle
  ///
  /// In en, this message translates to:
  /// **'Open chat, photos, timeline, invoice, and next steps.'**
  String get customerActionTrackSubtitle;

  /// Customer action title for open request
  ///
  /// In en, this message translates to:
  /// **'Waiting for quotes'**
  String get waitingForQuotes;

  /// Customer waiting action subtitle
  ///
  /// In en, this message translates to:
  /// **'Open the job and invite or compare nearby pros.'**
  String get customerActionWaitingSubtitle;

  /// Customer action center empty body
  ///
  /// In en, this message translates to:
  /// **'No active projects yet. Start once with photos, ZIP code, and service type.'**
  String get customerActionEmptyBody;

  /// No description provided for @customerActionEmptyTrust.
  ///
  /// In en, this message translates to:
  /// **'Local pros send quotes, escrow protects payment, and Job Command Center keeps chat, photos, invoices, and review in one place.'**
  String get customerActionEmptyTrust;

  /// Customer action center all clear body
  ///
  /// In en, this message translates to:
  /// **'No urgent actions. You can still review project details or start another request.'**
  String get customerActionAllClearBody;

  /// Customer team tab title
  ///
  /// In en, this message translates to:
  /// **'My Team'**
  String get myTeam;

  /// Customer team tab subtitle
  ///
  /// In en, this message translates to:
  /// **'Your hired pros and trusted contacts.'**
  String get myTeamSubtitle;

  /// Customer hired pros section title
  ///
  /// In en, this message translates to:
  /// **'Hired Pros'**
  String get hiredPros;

  /// Customer hired pros section subtitle
  ///
  /// In en, this message translates to:
  /// **'Contractors you\'ve completed jobs with.'**
  String get hiredProsSubtitle;

  /// Customer trusted pros section title
  ///
  /// In en, this message translates to:
  /// **'Trusted Pros'**
  String get trustedPros;

  /// Customer trusted pros section subtitle
  ///
  /// In en, this message translates to:
  /// **'Your curated shortlist - add notes and organize by trade.'**
  String get trustedProsSubtitle;

  /// Trusted pros share tooltip
  ///
  /// In en, this message translates to:
  /// **'Share my list'**
  String get shareMyList;

  /// Add button label
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Save button label
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Saved update snackbar
  ///
  /// In en, this message translates to:
  /// **'Updated.'**
  String get updated;

  /// Generic professional label
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get pro;

  /// Generic contractor label
  ///
  /// In en, this message translates to:
  /// **'Contractor'**
  String get contractor;

  /// Message button label
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// Rebook button label
  ///
  /// In en, this message translates to:
  /// **'Rebook'**
  String get rebook;

  /// Add trusted pro sheet title
  ///
  /// In en, this message translates to:
  /// **'Add Trusted Pro'**
  String get addTrustedPro;

  /// Edit trusted pro sheet title
  ///
  /// In en, this message translates to:
  /// **'Edit Trusted Pro'**
  String get editTrustedPro;

  /// Contractor search field label
  ///
  /// In en, this message translates to:
  /// **'Search contractor name'**
  String get searchContractorName;

  /// Contractor search empty state
  ///
  /// In en, this message translates to:
  /// **'No contractors found.'**
  String get noContractorsFound;

  /// Trusted pro trade field label
  ///
  /// In en, this message translates to:
  /// **'Trade / specialty'**
  String get tradeSpecialty;

  /// Trusted pro trade field hint
  ///
  /// In en, this message translates to:
  /// **'e.g. Painter, pressure washing tech'**
  String get tradeSpecialtyHint;

  /// Trusted pro note field label
  ///
  /// In en, this message translates to:
  /// **'Private note'**
  String get privateNote;

  /// Trusted pro note field hint
  ///
  /// In en, this message translates to:
  /// **'e.g. Great with tile, fast response'**
  String get privateNoteHint;

  /// Trusted pro add button label
  ///
  /// In en, this message translates to:
  /// **'Add to Trusted List'**
  String get addToTrustedList;

  /// No description provided for @addedToTrustedList.
  ///
  /// In en, this message translates to:
  /// **'{name} added to trusted list.'**
  String addedToTrustedList(String name);

  /// Remove confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Remove?'**
  String get removeQuestion;

  /// Remove trusted pro confirmation body
  ///
  /// In en, this message translates to:
  /// **'Remove this contractor from your trusted list?'**
  String get removeTrustedProConfirm;

  /// Customer requests empty title
  ///
  /// In en, this message translates to:
  /// **'No requests yet'**
  String get noRequestsYet;

  /// Customer requests empty subtitle
  ///
  /// In en, this message translates to:
  /// **'Post your first service request and local pros will send you quotes.'**
  String get noRequestsYetSubtitle;

  /// Hired pros empty title
  ///
  /// In en, this message translates to:
  /// **'No pros yet'**
  String get noProsYet;

  /// Hired pros empty subtitle
  ///
  /// In en, this message translates to:
  /// **'Once you complete a job, your contractors will appear here.'**
  String get noProsYetSubtitle;

  /// Trusted pros empty title
  ///
  /// In en, this message translates to:
  /// **'No trusted pros yet'**
  String get noTrustedProsYet;

  /// Trusted pros empty subtitle
  ///
  /// In en, this message translates to:
  /// **'Add contractors you trust so you can find them fast, add notes, and share your list.'**
  String get noTrustedProsYetSubtitle;

  /// No description provided for @jobsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 job} other{{count} jobs}}'**
  String jobsCount(int count);

  /// No description provided for @activeCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 active} other{{count} active}}'**
  String activeCount(int count);

  /// No description provided for @doneCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 done} other{{count} done}}'**
  String doneCount(int count);

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

  /// Browse tab label
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get browse;

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

  /// Team tab label
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get team;

  /// Gallery tab label
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

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
  /// **'Receipts & expenses'**
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

  /// No description provided for @toolsPayoutsPending.
  ///
  /// In en, this message translates to:
  /// **'Payouts pending'**
  String get toolsPayoutsPending;

  /// No description provided for @toolsConnectPayouts.
  ///
  /// In en, this message translates to:
  /// **'Connect payouts'**
  String get toolsConnectPayouts;

  /// No description provided for @toolsReviewPayoutSetup.
  ///
  /// In en, this message translates to:
  /// **'Review payout setup'**
  String get toolsReviewPayoutSetup;

  /// No description provided for @toolsPayoutSetupReason.
  ///
  /// In en, this message translates to:
  /// **'Required before you can receive escrow payouts and invoice payments.'**
  String get toolsPayoutSetupReason;

  /// No description provided for @toolsPayoutSetupOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open payout setup. Try again.'**
  String get toolsPayoutSetupOpenFailed;

  /// No description provided for @toolsPayoutSetupUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Payout setup is temporarily unavailable. Please try again or contact support.'**
  String get toolsPayoutSetupUnavailable;

  /// No description provided for @toolsPayoutSetupRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many payout setup attempts. Please wait a bit and try again.'**
  String get toolsPayoutSetupRateLimited;

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

  /// No description provided for @toolsSubscriptionActiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your paid tools are active. Manage billing or keep working from the sections below.'**
  String get toolsSubscriptionActiveSubtitle;

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

  /// No description provided for @toolQuoteTemplatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Quote Templates'**
  String get toolQuoteTemplatesTitle;

  /// No description provided for @toolQuoteTemplatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reuse scopes, terms, warranties, exclusions, and branded quote language.'**
  String get toolQuoteTemplatesSubtitle;

  /// No description provided for @toolProfitLossTitle.
  ///
  /// In en, this message translates to:
  /// **'Profit & Loss'**
  String get toolProfitLossTitle;

  /// No description provided for @toolProfitLossSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track revenue, expenses, profit margin, and job profitability.'**
  String get toolProfitLossSubtitle;

  /// No description provided for @toolCrewRosterTitle.
  ///
  /// In en, this message translates to:
  /// **'Crew Roster'**
  String get toolCrewRosterTitle;

  /// No description provided for @toolCrewRosterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage crew roles, availability, assignments, and labor history.'**
  String get toolCrewRosterSubtitle;

  /// No description provided for @toolCrewScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Crew Schedule'**
  String get toolCrewScheduleTitle;

  /// No description provided for @toolCrewScheduleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Assign crews to jobs and review the weekly operations board.'**
  String get toolCrewScheduleSubtitle;

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

  /// No description provided for @toolActionOpenTemplates.
  ///
  /// In en, this message translates to:
  /// **'Open templates'**
  String get toolActionOpenTemplates;

  /// No description provided for @toolActionReviewProfit.
  ///
  /// In en, this message translates to:
  /// **'Review profit'**
  String get toolActionReviewProfit;

  /// No description provided for @toolActionManageCrew.
  ///
  /// In en, this message translates to:
  /// **'Manage crew'**
  String get toolActionManageCrew;

  /// No description provided for @toolActionAssignCrew.
  ///
  /// In en, this message translates to:
  /// **'Assign crew'**
  String get toolActionAssignCrew;

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

  /// No description provided for @toolMetricReusableTerms.
  ///
  /// In en, this message translates to:
  /// **'Reusable terms'**
  String get toolMetricReusableTerms;

  /// No description provided for @toolMetricJobProfit.
  ///
  /// In en, this message translates to:
  /// **'Job profit'**
  String get toolMetricJobProfit;

  /// No description provided for @toolMetricCrewRoles.
  ///
  /// In en, this message translates to:
  /// **'Crew roles'**
  String get toolMetricCrewRoles;

  /// No description provided for @toolMetricScheduleBoard.
  ///
  /// In en, this message translates to:
  /// **'Schedule board'**
  String get toolMetricScheduleBoard;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @zipCode.
  ///
  /// In en, this message translates to:
  /// **'ZIP Code'**
  String get zipCode;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @item.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get item;

  /// No description provided for @copyToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy to Clipboard'**
  String get copyToClipboard;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @clientDirectoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Client Directory'**
  String get clientDirectoryTitle;

  /// No description provided for @clientDirectorySelect.
  ///
  /// In en, this message translates to:
  /// **'Select Client'**
  String get clientDirectorySelect;

  /// No description provided for @clientDirectorySignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in to view clients.'**
  String get clientDirectorySignInRequired;

  /// No description provided for @clientDirectorySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search clients...'**
  String get clientDirectorySearchHint;

  /// No description provided for @clientDirectoryAddClient.
  ///
  /// In en, this message translates to:
  /// **'Add Client'**
  String get clientDirectoryAddClient;

  /// No description provided for @clientDirectoryNoClients.
  ///
  /// In en, this message translates to:
  /// **'No clients yet'**
  String get clientDirectoryNoClients;

  /// No description provided for @clientDirectoryNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get clientDirectoryNoMatches;

  /// No description provided for @clientDirectoryNoClientsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add your first client'**
  String get clientDirectoryNoClientsSubtitle;

  /// No description provided for @clientDirectoryNoMatchesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Try a different search'**
  String get clientDirectoryNoMatchesSubtitle;

  /// No description provided for @clientDirectoryNewClient.
  ///
  /// In en, this message translates to:
  /// **'New Client'**
  String get clientDirectoryNewClient;

  /// No description provided for @clientDirectoryEditClient.
  ///
  /// In en, this message translates to:
  /// **'Edit Client'**
  String get clientDirectoryEditClient;

  /// No description provided for @clientDirectoryNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Client name *'**
  String get clientDirectoryNameLabel;

  /// No description provided for @clientDirectoryNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get clientDirectoryNotesLabel;

  /// No description provided for @clientDirectorySaveClient.
  ///
  /// In en, this message translates to:
  /// **'Save Client'**
  String get clientDirectorySaveClient;

  /// No description provided for @clientDirectoryNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get clientDirectoryNameRequired;

  /// No description provided for @clientDirectoryDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Client?'**
  String get clientDirectoryDeleteTitle;

  /// No description provided for @clientDirectoryDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{clientName}\" from your directory?'**
  String clientDirectoryDeleteMessage(String clientName);

  /// No description provided for @bidAnalyzerAnalyzeTab.
  ///
  /// In en, this message translates to:
  /// **'Analyze'**
  String get bidAnalyzerAnalyzeTab;

  /// No description provided for @bidAnalyzerPasteRequired.
  ///
  /// In en, this message translates to:
  /// **'Paste a competitor bid or RFP text first'**
  String get bidAnalyzerPasteRequired;

  /// No description provided for @bidAnalyzerJobLabel.
  ///
  /// In en, this message translates to:
  /// **'Job / Project Label (optional)'**
  String get bidAnalyzerJobLabel;

  /// No description provided for @bidAnalyzerJobHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 5000 sqft Exterior - Smith Residence'**
  String get bidAnalyzerJobHint;

  /// No description provided for @bidAnalyzerInputTitle.
  ///
  /// In en, this message translates to:
  /// **'Competitor Bid / RFP Text'**
  String get bidAnalyzerInputTitle;

  /// No description provided for @bidAnalyzerPasteClipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste from clipboard'**
  String get bidAnalyzerPasteClipboard;

  /// No description provided for @bidAnalyzerInputSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Paste the full bid document, email, or line-item breakdown'**
  String get bidAnalyzerInputSubtitle;

  /// No description provided for @bidAnalyzerInputHint.
  ///
  /// In en, this message translates to:
  /// **'Paste competitor bid text here...\n\nExample:\n- Interior paint (3 BR): \$2,400\n- Trim & baseboards: \$800\n- Ceiling: \$600\n- Prep & primer: \$500'**
  String get bidAnalyzerInputHint;

  /// No description provided for @bidAnalyzerCharacters.
  ///
  /// In en, this message translates to:
  /// **'{count} characters'**
  String bidAnalyzerCharacters(int count);

  /// No description provided for @bidAnalyzerAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing...'**
  String get bidAnalyzerAnalyzing;

  /// No description provided for @bidAnalyzerSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Analysis Summary'**
  String get bidAnalyzerSummaryTitle;

  /// No description provided for @bidAnalyzerTheirTotal.
  ///
  /// In en, this message translates to:
  /// **'Their Total'**
  String get bidAnalyzerTheirTotal;

  /// No description provided for @bidAnalyzerYourPrice.
  ///
  /// In en, this message translates to:
  /// **'Your Price'**
  String get bidAnalyzerYourPrice;

  /// No description provided for @bidAnalyzerLineItems.
  ///
  /// In en, this message translates to:
  /// **'Line Items ({count})'**
  String bidAnalyzerLineItems(int count);

  /// No description provided for @bidAnalyzerTheirs.
  ///
  /// In en, this message translates to:
  /// **'Theirs'**
  String get bidAnalyzerTheirs;

  /// No description provided for @bidAnalyzerYours.
  ///
  /// In en, this message translates to:
  /// **'Yours'**
  String get bidAnalyzerYours;

  /// No description provided for @bidAnalyzerInternalCost.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get bidAnalyzerInternalCost;

  /// No description provided for @bidAnalyzerCounterBidTitle.
  ///
  /// In en, this message translates to:
  /// **'Suggested Counter-Bid'**
  String get bidAnalyzerCounterBidTitle;

  /// No description provided for @bidAnalyzerCounterBidLabel.
  ///
  /// In en, this message translates to:
  /// **'Counter-Bid Suggestion:'**
  String get bidAnalyzerCounterBidLabel;

  /// No description provided for @bidAnalyzerNoAnalyses.
  ///
  /// In en, this message translates to:
  /// **'No analyses yet'**
  String get bidAnalyzerNoAnalyses;

  /// No description provided for @bidAnalyzerNoAnalysesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload or paste a bid to extract line items, compare pricing, score risk, and save the analysis here.'**
  String get bidAnalyzerNoAnalysesSubtitle;

  /// No description provided for @bidAnalyzerStartAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Start analysis'**
  String get bidAnalyzerStartAnalysis;

  /// No description provided for @bidAnalyzerFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Bid Analysis'**
  String get bidAnalyzerFallbackTitle;

  /// No description provided for @bidAnalyzerHistoryItems.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String bidAnalyzerHistoryItems(String count);

  /// No description provided for @bidAnalyzerLocalSummary.
  ///
  /// In en, this message translates to:
  /// **'Local analysis extracted {count} line items{totalText}. Deploy the analyzeBid Cloud Function for AI-powered comparison against your pricing engine and counter-bid suggestions.'**
  String bidAnalyzerLocalSummary(int count, String totalText);

  /// No description provided for @bidAnalyzerLocalSummaryTotal.
  ///
  /// In en, this message translates to:
  /// **' (total: {total})'**
  String bidAnalyzerLocalSummaryTotal(String total);

  /// No description provided for @bidAnalyzerUploadPdf.
  ///
  /// In en, this message translates to:
  /// **'Upload PDF'**
  String get bidAnalyzerUploadPdf;

  /// No description provided for @bidAnalyzerUploadImage.
  ///
  /// In en, this message translates to:
  /// **'Upload image'**
  String get bidAnalyzerUploadImage;

  /// No description provided for @bidAnalyzerPasteText.
  ///
  /// In en, this message translates to:
  /// **'Paste text'**
  String get bidAnalyzerPasteText;

  /// No description provided for @bidAnalyzerSelectedFile.
  ///
  /// In en, this message translates to:
  /// **'Selected: {fileName}'**
  String bidAnalyzerSelectedFile(String fileName);

  /// No description provided for @bidAnalyzerUploadFallback.
  ///
  /// In en, this message translates to:
  /// **'{fileName} is attached. If text extraction is not available on this device, paste the bid text below before analyzing.'**
  String bidAnalyzerUploadFallback(String fileName);

  /// No description provided for @bidAnalyzerRiskScore.
  ///
  /// In en, this message translates to:
  /// **'Risk: {level}'**
  String bidAnalyzerRiskScore(String level);

  /// No description provided for @bidAnalyzerRiskLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get bidAnalyzerRiskLow;

  /// No description provided for @bidAnalyzerRiskMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get bidAnalyzerRiskMedium;

  /// No description provided for @bidAnalyzerRiskHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get bidAnalyzerRiskHigh;

  /// No description provided for @bidAnalyzerUnderbidWarning.
  ///
  /// In en, this message translates to:
  /// **'Potential underbid: your suggested price may leave too little margin.'**
  String get bidAnalyzerUnderbidWarning;

  /// No description provided for @bidAnalyzerMissingScopeWarning.
  ///
  /// In en, this message translates to:
  /// **'Missing scope detail: some line items need manual price or scope review.'**
  String get bidAnalyzerMissingScopeWarning;

  /// No description provided for @bidAnalyzerMaterialLaborWarning.
  ///
  /// In en, this message translates to:
  /// **'Material and labor are not clearly separated; verify job cost before sending.'**
  String get bidAnalyzerMaterialLaborWarning;

  /// No description provided for @bidAnalyzerMargin.
  ///
  /// In en, this message translates to:
  /// **'Margin'**
  String get bidAnalyzerMargin;

  /// No description provided for @bidAnalyzerNextActions.
  ///
  /// In en, this message translates to:
  /// **'Next actions'**
  String get bidAnalyzerNextActions;

  /// No description provided for @bidAnalyzerCreateCounterQuote.
  ///
  /// In en, this message translates to:
  /// **'Create counter-quote'**
  String get bidAnalyzerCreateCounterQuote;

  /// No description provided for @bidAnalyzerSaveAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Save analysis'**
  String get bidAnalyzerSaveAnalysis;

  /// No description provided for @bidAnalyzerAttachToJob.
  ///
  /// In en, this message translates to:
  /// **'Attach to job'**
  String get bidAnalyzerAttachToJob;

  /// No description provided for @bidAnalyzerOpenQuoteTemplates.
  ///
  /// In en, this message translates to:
  /// **'Open quote templates'**
  String get bidAnalyzerOpenQuoteTemplates;

  /// No description provided for @bidAnalyzerCounterCopied.
  ///
  /// In en, this message translates to:
  /// **'Counter-quote copied. Use a quote template to send it professionally.'**
  String get bidAnalyzerCounterCopied;

  /// No description provided for @bidAnalyzerAttachToJobUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Open Bid Analyzer from a job to attach this analysis.'**
  String get bidAnalyzerAttachToJobUnavailable;

  /// No description provided for @bidAnalyzerUseCaseCompetitor.
  ///
  /// In en, this message translates to:
  /// **'Compare a competitor bid before you counter.'**
  String get bidAnalyzerUseCaseCompetitor;

  /// No description provided for @bidAnalyzerUseCaseRfp.
  ///
  /// In en, this message translates to:
  /// **'Break down an RFP or large scope into line items.'**
  String get bidAnalyzerUseCaseRfp;

  /// No description provided for @bidAnalyzerUseCaseScope.
  ///
  /// In en, this message translates to:
  /// **'Find missing labor, material, or warranty details before sending.'**
  String get bidAnalyzerUseCaseScope;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @upgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get upgrade;

  /// No description provided for @signInRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in required'**
  String get signInRequired;

  /// No description provided for @checkConnectionTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get checkConnectionTryAgain;

  /// No description provided for @pullToRefreshTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Pull to refresh or try again in a moment.'**
  String get pullToRefreshTryAgain;

  /// No description provided for @leadMarketEmptyFiltersTitle.
  ///
  /// In en, this message translates to:
  /// **'No leads match your filters'**
  String get leadMarketEmptyFiltersTitle;

  /// No description provided for @leadMarketEmptyFiltersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your feed loaded, but filters, service matching, or radius are hiding available leads.'**
  String get leadMarketEmptyFiltersSubtitle;

  /// No description provided for @leadMarketEmptyMarketTitle.
  ///
  /// In en, this message translates to:
  /// **'No leads available in this market right now'**
  String get leadMarketEmptyMarketTitle;

  /// No description provided for @leadMarketEmptyMarketSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You are set up to browse leads. New customer requests will appear here when they are posted.'**
  String get leadMarketEmptyMarketSubtitle;

  /// No description provided for @leadMarketCreditBalance.
  ///
  /// In en, this message translates to:
  /// **'{count} lead credits available'**
  String leadMarketCreditBalance(int count);

  /// No description provided for @leadMarketRadiusStatus.
  ///
  /// In en, this message translates to:
  /// **'Showing leads within {radius} miles of ZIP {zip}'**
  String leadMarketRadiusStatus(String radius, String zip);

  /// No description provided for @leadMarketZipMissing.
  ///
  /// In en, this message translates to:
  /// **'Add your ZIP or use location to improve local lead matching.'**
  String get leadMarketZipMissing;

  /// No description provided for @leadMarketPayoutReady.
  ///
  /// In en, this message translates to:
  /// **'Payouts are connected for paid jobs.'**
  String get leadMarketPayoutReady;

  /// No description provided for @leadMarketPayoutPending.
  ///
  /// In en, this message translates to:
  /// **'Payout setup is started but still pending.'**
  String get leadMarketPayoutPending;

  /// No description provided for @leadMarketPayoutBlocked.
  ///
  /// In en, this message translates to:
  /// **'Connect payouts before accepting paid jobs.'**
  String get leadMarketPayoutBlocked;

  /// No description provided for @leadMarketServiceFilterOn.
  ///
  /// In en, this message translates to:
  /// **'Matching your selected services only.'**
  String get leadMarketServiceFilterOn;

  /// No description provided for @leadMarketBuyCredits.
  ///
  /// In en, this message translates to:
  /// **'Buy credits'**
  String get leadMarketBuyCredits;

  /// No description provided for @leadMarketClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get leadMarketClearFilters;

  /// No description provided for @leadMarketExpandRadius.
  ///
  /// In en, this message translates to:
  /// **'Expand radius'**
  String get leadMarketExpandRadius;

  /// No description provided for @availableLeads.
  ///
  /// In en, this message translates to:
  /// **'Available Leads'**
  String get availableLeads;

  /// No description provided for @availableLeadsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse and purchase customer project leads'**
  String get availableLeadsSubtitle;

  /// No description provided for @leadMarketServiceRadius.
  ///
  /// In en, this message translates to:
  /// **'Service radius'**
  String get leadMarketServiceRadius;

  /// No description provided for @leadMarketOnlyWithinRadius.
  ///
  /// In en, this message translates to:
  /// **'Only leads within {range} of ZIP {zip}'**
  String leadMarketOnlyWithinRadius(String range, String zip);

  /// No description provided for @leadMarketSetZipDistance.
  ///
  /// In en, this message translates to:
  /// **'Set your ZIP to filter leads by distance'**
  String get leadMarketSetZipDistance;

  /// No description provided for @useMyLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my location'**
  String get useMyLocation;

  /// No description provided for @leadMarketplaceStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Lead marketplace status'**
  String get leadMarketplaceStatusTitle;

  /// No description provided for @leadMarketSharedCreditsShort.
  ///
  /// In en, this message translates to:
  /// **'{count} shared'**
  String leadMarketSharedCreditsShort(int count);

  /// No description provided for @leadMarketExclusiveCreditsShort.
  ///
  /// In en, this message translates to:
  /// **'{count} exclusive'**
  String leadMarketExclusiveCreditsShort(int count);

  /// No description provided for @leadMarketDistanceFromZip.
  ///
  /// In en, this message translates to:
  /// **'{miles} mi from {zip}'**
  String leadMarketDistanceFromZip(String miles, String zip);

  /// No description provided for @leadMarketSetZipShort.
  ///
  /// In en, this message translates to:
  /// **'Set ZIP'**
  String get leadMarketSetZipShort;

  /// No description provided for @leadMarketAddServices.
  ///
  /// In en, this message translates to:
  /// **'Add services'**
  String get leadMarketAddServices;

  /// No description provided for @leadMarketServicesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} services'**
  String leadMarketServicesCount(int count);

  /// No description provided for @leadMarketPayoutsReadyShort.
  ///
  /// In en, this message translates to:
  /// **'Payouts ready'**
  String get leadMarketPayoutsReadyShort;

  /// No description provided for @leadMarketPayoutsBlockedShort.
  ///
  /// In en, this message translates to:
  /// **'Payouts blocked'**
  String get leadMarketPayoutsBlockedShort;

  /// No description provided for @leadMarketPayoutBlockedExplain.
  ///
  /// In en, this message translates to:
  /// **'Connect payouts before accepting paid jobs. You can still review market demand and buy credits.'**
  String get leadMarketPayoutBlockedExplain;

  /// No description provided for @leadCreditActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Lead credit activity'**
  String get leadCreditActivityTitle;

  /// No description provided for @leadCreditActivityEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Purchases and unlocks will appear here.'**
  String get leadCreditActivityEmptySubtitle;

  /// No description provided for @leadCreditActivitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Latest purchases, unlocks, refunds, and failed credits.'**
  String get leadCreditActivitySubtitle;

  /// No description provided for @leadCreditActivityEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'When you buy credits or unlock a lead, this ledger gives you a receipt-style history.'**
  String get leadCreditActivityEmptyBody;

  /// No description provided for @leadCreditActivityPurchased.
  ///
  /// In en, this message translates to:
  /// **'Credits purchased'**
  String get leadCreditActivityPurchased;

  /// No description provided for @leadCreditActivityUsed.
  ///
  /// In en, this message translates to:
  /// **'Lead unlocked'**
  String get leadCreditActivityUsed;

  /// No description provided for @leadCreditActivityRefunded.
  ///
  /// In en, this message translates to:
  /// **'Credits refunded'**
  String get leadCreditActivityRefunded;

  /// No description provided for @leadCreditActivityFailed.
  ///
  /// In en, this message translates to:
  /// **'Credit failed'**
  String get leadCreditActivityFailed;

  /// No description provided for @leadCreditActivityGeneric.
  ///
  /// In en, this message translates to:
  /// **'Credit activity'**
  String get leadCreditActivityGeneric;

  /// No description provided for @leadCreditActivityJobRef.
  ///
  /// In en, this message translates to:
  /// **'Job {jobId}'**
  String leadCreditActivityJobRef(String jobId);

  /// No description provided for @leadCreditActivityPackRef.
  ///
  /// In en, this message translates to:
  /// **'Pack {packId}'**
  String leadCreditActivityPackRef(String packId);

  /// No description provided for @leadCreditActivityLeadCreditsRef.
  ///
  /// In en, this message translates to:
  /// **'Lead credits'**
  String get leadCreditActivityLeadCreditsRef;

  /// No description provided for @leadMarketEarlyAccess.
  ///
  /// In en, this message translates to:
  /// **'Early Access'**
  String get leadMarketEarlyAccess;

  /// No description provided for @leadMarketManualQuote.
  ///
  /// In en, this message translates to:
  /// **'Manual quote'**
  String get leadMarketManualQuote;

  /// No description provided for @leadMarketInstantPriceReady.
  ///
  /// In en, this message translates to:
  /// **'Instant price ready'**
  String get leadMarketInstantPriceReady;

  /// No description provided for @leadMarketMatchesYourServices.
  ///
  /// In en, this message translates to:
  /// **'Matches your services'**
  String get leadMarketMatchesYourServices;

  /// No description provided for @leadMarketPhotoCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No photos} =1{1 photo} other{{count} photos}}'**
  String leadMarketPhotoCount(int count);

  /// No description provided for @leadMarketManualQuoteFallbackReason.
  ///
  /// In en, this message translates to:
  /// **'Customer details should be reviewed before quoting.'**
  String get leadMarketManualQuoteFallbackReason;

  /// No description provided for @leadMarketMayNeedFollowUp.
  ///
  /// In en, this message translates to:
  /// **'May need follow-up: {fields}'**
  String leadMarketMayNeedFollowUp(String fields);

  /// No description provided for @leadMarketUnlockModel.
  ///
  /// In en, this message translates to:
  /// **'Unlock model'**
  String get leadMarketUnlockModel;

  /// No description provided for @leadMarketUnlockModelDescription.
  ///
  /// In en, this message translates to:
  /// **'1 shared credit unlocks contact. 1 exclusive credit locks the lead to you.'**
  String get leadMarketUnlockModelDescription;

  /// No description provided for @leadMarketOneCredit.
  ///
  /// In en, this message translates to:
  /// **'1 credit'**
  String get leadMarketOneCredit;

  /// No description provided for @leadMarketSharedUnlockCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No shared unlocks yet} =1{1 shared unlock} other{{count} shared unlocks}}'**
  String leadMarketSharedUnlockCount(int count);

  /// No description provided for @leadMarketExclusiveAvailable.
  ///
  /// In en, this message translates to:
  /// **'Exclusive available'**
  String get leadMarketExclusiveAvailable;

  /// No description provided for @leadMarketSharedOnly.
  ///
  /// In en, this message translates to:
  /// **'Shared only'**
  String get leadMarketSharedOnly;

  /// No description provided for @leadMarketBudgetLabel.
  ///
  /// In en, this message translates to:
  /// **'Budget: {amount}'**
  String leadMarketBudgetLabel(String amount);

  /// No description provided for @leadMarketBudgetNotSet.
  ///
  /// In en, this message translates to:
  /// **'Budget not provided yet'**
  String get leadMarketBudgetNotSet;

  /// No description provided for @leadMarketDistanceAway.
  ///
  /// In en, this message translates to:
  /// **'{distance} away'**
  String leadMarketDistanceAway(String distance);

  /// No description provided for @leadMarketPostedDate.
  ///
  /// In en, this message translates to:
  /// **'Posted {date}'**
  String leadMarketPostedDate(String date);

  /// No description provided for @leadMarketViewUnlockLead.
  ///
  /// In en, this message translates to:
  /// **'View & unlock lead'**
  String get leadMarketViewUnlockLead;

  /// No description provided for @leadMarketBuyLeads.
  ///
  /// In en, this message translates to:
  /// **'Buy leads'**
  String get leadMarketBuyLeads;

  /// No description provided for @leadMarketBuyLeadsToSeeJobs.
  ///
  /// In en, this message translates to:
  /// **'Buy leads to see available jobs'**
  String get leadMarketBuyLeadsToSeeJobs;

  /// No description provided for @leadMarketCreditsRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'You need lead credits to view the job feed and unlock customer contact info.'**
  String get leadMarketCreditsRequiredBody;

  /// No description provided for @leadMarketLeadsLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Leads are locked'**
  String get leadMarketLeadsLockedTitle;

  /// No description provided for @leadMarketLeadsLockedBody.
  ///
  /// In en, this message translates to:
  /// **'You need lead credits or a direct invite to view available leads. If you just bought credits, give it a moment and try again.'**
  String get leadMarketLeadsLockedBody;

  /// No description provided for @leadDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Lead Details'**
  String get leadDetailTitle;

  /// No description provided for @leadDetailContactLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Client contact locked'**
  String get leadDetailContactLockedTitle;

  /// No description provided for @leadDetailUnlockExplainerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose shared or exclusive access'**
  String get leadDetailUnlockExplainerTitle;

  /// No description provided for @leadDetailUnlockExplainerBody.
  ///
  /// In en, this message translates to:
  /// **'Shared access reveals the customer contact while the lead stays available. Exclusive access locks the lead to you so other contractors cannot unlock it.'**
  String get leadDetailUnlockExplainerBody;

  /// No description provided for @leadDetailSharedUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Shared lead unlocked. Contact details are now available.'**
  String get leadDetailSharedUnlocked;

  /// No description provided for @leadDetailExclusiveUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Exclusive lead unlocked. Only you can access this contact.'**
  String get leadDetailExclusiveUnlocked;

  /// No description provided for @leadDetailUnlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Lead unlocked'**
  String get leadDetailUnlockedTitle;

  /// No description provided for @leadDetailUnlockedBody.
  ///
  /// In en, this message translates to:
  /// **'Next, contact the customer or send a quote while the project is fresh.'**
  String get leadDetailUnlockedBody;

  /// No description provided for @leadDetailSharedCredits.
  ///
  /// In en, this message translates to:
  /// **'Shared credits: {count}'**
  String leadDetailSharedCredits(int count);

  /// No description provided for @leadDetailExclusiveCredits.
  ///
  /// In en, this message translates to:
  /// **'Exclusive credits: {count}'**
  String leadDetailExclusiveCredits(int count);

  /// No description provided for @leadDetailCreditModel.
  ///
  /// In en, this message translates to:
  /// **'1 shared credit unlocks this lead while it remains available to other contractors. 1 exclusive credit locks the lead to you.'**
  String get leadDetailCreditModel;

  /// No description provided for @leadDetailUnlockSharedLead.
  ///
  /// In en, this message translates to:
  /// **'Unlock shared lead (1 credit)'**
  String get leadDetailUnlockSharedLead;

  /// No description provided for @leadDetailUnlockExclusiveLead.
  ///
  /// In en, this message translates to:
  /// **'Unlock exclusive lead (1 credit)'**
  String get leadDetailUnlockExclusiveLead;

  /// No description provided for @leadDetailBuySharedCredits.
  ///
  /// In en, this message translates to:
  /// **'Buy shared credits'**
  String get leadDetailBuySharedCredits;

  /// No description provided for @leadDetailBuyExclusiveCredits.
  ///
  /// In en, this message translates to:
  /// **'Buy exclusive credits'**
  String get leadDetailBuyExclusiveCredits;

  /// No description provided for @leadDetailBuyMoreCredits.
  ///
  /// In en, this message translates to:
  /// **'Buy more lead credits'**
  String get leadDetailBuyMoreCredits;

  /// No description provided for @pricingWhyThisPriceTitle.
  ///
  /// In en, this message translates to:
  /// **'Why this price'**
  String get pricingWhyThisPriceTitle;

  /// No description provided for @pricingWhyThisPriceBody.
  ///
  /// In en, this message translates to:
  /// **'{hours} hours at \${rate}/hr, {complexity} complexity, \${materials} materials, and a {markup}% standard markup.'**
  String pricingWhyThisPriceBody(
    String hours,
    String rate,
    String complexity,
    String materials,
    String markup,
  );

  /// No description provided for @pricingBackToJob.
  ///
  /// In en, this message translates to:
  /// **'Back to Job'**
  String get pricingBackToJob;

  /// No description provided for @pricingSendQuote.
  ///
  /// In en, this message translates to:
  /// **'Send quote'**
  String get pricingSendQuote;

  /// No description provided for @pricingAttachToJob.
  ///
  /// In en, this message translates to:
  /// **'Attach to job'**
  String get pricingAttachToJob;

  /// No description provided for @pricingCreateInvoice.
  ///
  /// In en, this message translates to:
  /// **'Create invoice'**
  String get pricingCreateInvoice;

  /// No description provided for @pricingSaveToClient.
  ///
  /// In en, this message translates to:
  /// **'Save to client'**
  String get pricingSaveToClient;

  /// No description provided for @pricingAttachJobFirst.
  ///
  /// In en, this message translates to:
  /// **'Open this calculator from a job before sending a quote.'**
  String get pricingAttachJobFirst;

  /// No description provided for @pricingAttachedToJob.
  ///
  /// In en, this message translates to:
  /// **'Estimate attached to job.'**
  String get pricingAttachedToJob;

  /// No description provided for @pricingSavedToClient.
  ///
  /// In en, this message translates to:
  /// **'Estimate saved to client.'**
  String get pricingSavedToClient;

  /// No description provided for @service.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get service;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @escrow.
  ///
  /// In en, this message translates to:
  /// **'Escrow'**
  String get escrow;

  /// No description provided for @approved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approved;

  /// No description provided for @pendingAdminApproval.
  ///
  /// In en, this message translates to:
  /// **'Pending Admin Approval'**
  String get pendingAdminApproval;

  /// No description provided for @payoutsConnected.
  ///
  /// In en, this message translates to:
  /// **'Payouts connected'**
  String get payoutsConnected;

  /// No description provided for @payoutsPending.
  ///
  /// In en, this message translates to:
  /// **'Payouts pending'**
  String get payoutsPending;

  /// No description provided for @payoutsSetup.
  ///
  /// In en, this message translates to:
  /// **'Payouts setup'**
  String get payoutsSetup;

  /// No description provided for @payoutsNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Payouts not connected'**
  String get payoutsNotConnected;

  /// No description provided for @accountOverview.
  ///
  /// In en, this message translates to:
  /// **'Account overview'**
  String get accountOverview;

  /// No description provided for @nonExclusiveCredits.
  ///
  /// In en, this message translates to:
  /// **'Non-exclusive credits: {count}'**
  String nonExclusiveCredits(int count);

  /// No description provided for @exclusiveCredits.
  ///
  /// In en, this message translates to:
  /// **'Exclusive credits: {count}'**
  String exclusiveCredits(int count);

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// No description provided for @updatePublicContractorInfo.
  ///
  /// In en, this message translates to:
  /// **'Update your public contractor info'**
  String get updatePublicContractorInfo;

  /// No description provided for @getVerified.
  ///
  /// In en, this message translates to:
  /// **'Get verified'**
  String get getVerified;

  /// No description provided for @improveTrustWinMoreWork.
  ///
  /// In en, this message translates to:
  /// **'Improve trust and win more work'**
  String get improveTrustWinMoreWork;

  /// No description provided for @analytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analytics;

  /// No description provided for @availability.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get availability;

  /// No description provided for @serviceArea.
  ///
  /// In en, this message translates to:
  /// **'Service area'**
  String get serviceArea;

  /// No description provided for @businessProfile.
  ///
  /// In en, this message translates to:
  /// **'Business profile'**
  String get businessProfile;

  /// No description provided for @qAndA.
  ///
  /// In en, this message translates to:
  /// **'Q&A'**
  String get qAndA;

  /// No description provided for @contractorPortalWelcomeFallback.
  ///
  /// In en, this message translates to:
  /// **'there'**
  String get contractorPortalWelcomeFallback;

  /// No description provided for @contractorHomeToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get contractorHomeToday;

  /// No description provided for @contractorHomeViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get contractorHomeViewAll;

  /// No description provided for @contractorHomeNewLeads.
  ///
  /// In en, this message translates to:
  /// **'New leads'**
  String get contractorHomeNewLeads;

  /// No description provided for @contractorHomeActiveCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Active'**
  String contractorHomeActiveCount(int count);

  /// No description provided for @contractorHomePayouts.
  ///
  /// In en, this message translates to:
  /// **'Payouts'**
  String get contractorHomePayouts;

  /// No description provided for @contractorHomeNextPayout.
  ///
  /// In en, this message translates to:
  /// **'Next payout'**
  String get contractorHomeNextPayout;

  /// No description provided for @contractorHomePayoutReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get contractorHomePayoutReady;

  /// No description provided for @contractorHomePayoutPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get contractorHomePayoutPending;

  /// No description provided for @contractorHomePayoutSetup.
  ///
  /// In en, this message translates to:
  /// **'Setup'**
  String get contractorHomePayoutSetup;

  /// No description provided for @contractorHomePayoutUnderReview.
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get contractorHomePayoutUnderReview;

  /// No description provided for @contractorHomeVerifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify account'**
  String get contractorHomeVerifyTitle;

  /// No description provided for @contractorHomeVerifySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Finish verification to build trust'**
  String get contractorHomeVerifySubtitle;

  /// No description provided for @contractorHomeAccountAllGood.
  ///
  /// In en, this message translates to:
  /// **'Account status all good'**
  String get contractorHomeAccountAllGood;

  /// No description provided for @contractorHomeCompleteSetup.
  ///
  /// In en, this message translates to:
  /// **'Complete setup'**
  String get contractorHomeCompleteSetup;

  /// No description provided for @contractorHomeToolQuote.
  ///
  /// In en, this message translates to:
  /// **'Quote'**
  String get contractorHomeToolQuote;

  /// No description provided for @contractorHomeToolEstimator.
  ///
  /// In en, this message translates to:
  /// **'Estimator'**
  String get contractorHomeToolEstimator;

  /// No description provided for @contractorHomeToolScheduler.
  ///
  /// In en, this message translates to:
  /// **'Scheduler'**
  String get contractorHomeToolScheduler;

  /// No description provided for @contractorHomeToolBidAnalyzer.
  ///
  /// In en, this message translates to:
  /// **'Bid Analyzer'**
  String get contractorHomeToolBidAnalyzer;

  /// No description provided for @contractorHomeToolInspector.
  ///
  /// In en, this message translates to:
  /// **'Inspector'**
  String get contractorHomeToolInspector;

  /// No description provided for @contractorHomeToolsBasicSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Marketplace tools available. Upgrade for estimating and invoicing.'**
  String get contractorHomeToolsBasicSubtitle;

  /// No description provided for @contractorHomeToolsProSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Estimate, invoice, render, and manage jobs faster.'**
  String get contractorHomeToolsProSubtitle;

  /// No description provided for @contractorHomeToolsEnterpriseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Operations tools for crews, bids, quality, and multi-location growth.'**
  String get contractorHomeToolsEnterpriseSubtitle;

  /// No description provided for @contractorHomeToolBrowseLeads.
  ///
  /// In en, this message translates to:
  /// **'Browse Leads'**
  String get contractorHomeToolBrowseLeads;

  /// No description provided for @contractorHomeToolSubmitQuote.
  ///
  /// In en, this message translates to:
  /// **'Submit Quote'**
  String get contractorHomeToolSubmitQuote;

  /// No description provided for @contractorHomeToolBuyCredits.
  ///
  /// In en, this message translates to:
  /// **'Buy Credits'**
  String get contractorHomeToolBuyCredits;

  /// No description provided for @contractorHomeToolCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get contractorHomeToolCommunity;

  /// No description provided for @contractorHomeToolVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get contractorHomeToolVerify;

  /// No description provided for @contractorHomeToolUpgradePro.
  ///
  /// In en, this message translates to:
  /// **'Upgrade Pro'**
  String get contractorHomeToolUpgradePro;

  /// No description provided for @contractorHomeToolPricing.
  ///
  /// In en, this message translates to:
  /// **'Pricing'**
  String get contractorHomeToolPricing;

  /// No description provided for @contractorHomeToolSavedEstimates.
  ///
  /// In en, this message translates to:
  /// **'Estimates'**
  String get contractorHomeToolSavedEstimates;

  /// No description provided for @contractorHomeToolRender.
  ///
  /// In en, this message translates to:
  /// **'Render'**
  String get contractorHomeToolRender;

  /// No description provided for @contractorHomeToolInvoices.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get contractorHomeToolInvoices;

  /// No description provided for @contractorHomeToolSmartSchedule.
  ///
  /// In en, this message translates to:
  /// **'Scheduler'**
  String get contractorHomeToolSmartSchedule;

  /// No description provided for @contractorHomeToolMultiLocation.
  ///
  /// In en, this message translates to:
  /// **'Locations'**
  String get contractorHomeToolMultiLocation;

  /// No description provided for @contractorHomeToolSubMarket.
  ///
  /// In en, this message translates to:
  /// **'Sub Market'**
  String get contractorHomeToolSubMarket;

  /// No description provided for @contractorHomeToolPaymentLinks.
  ///
  /// In en, this message translates to:
  /// **'Pay Links'**
  String get contractorHomeToolPaymentLinks;

  /// No description provided for @contractorHomeToolProfitLoss.
  ///
  /// In en, this message translates to:
  /// **'P&L'**
  String get contractorHomeToolProfitLoss;

  /// No description provided for @contractorHomeToolCrewRoster.
  ///
  /// In en, this message translates to:
  /// **'Crew'**
  String get contractorHomeToolCrewRoster;

  /// No description provided for @contractorHomeReviews.
  ///
  /// In en, this message translates to:
  /// **'{count} reviews'**
  String contractorHomeReviews(int count);

  /// No description provided for @contractorHomeNoReviews.
  ///
  /// In en, this message translates to:
  /// **'No reviews'**
  String get contractorHomeNoReviews;

  /// No description provided for @contractorHomeYears.
  ///
  /// In en, this message translates to:
  /// **'{count} yrs'**
  String contractorHomeYears(int count);

  /// No description provided for @contractorHomeExperience.
  ///
  /// In en, this message translates to:
  /// **'Experience'**
  String get contractorHomeExperience;

  /// No description provided for @contractorHomeTier.
  ///
  /// In en, this message translates to:
  /// **'Tier'**
  String get contractorHomeTier;

  /// No description provided for @contractorPortalProRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Contractor Pro required'**
  String get contractorPortalProRequiredTitle;

  /// No description provided for @contractorPortalProRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'Unlock the Pricing Calculator, Cost Estimator, and Render Tool with Contractor Pro.'**
  String get contractorPortalProRequiredBody;

  /// No description provided for @contractorPortalEnterpriseRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Enterprise plan required'**
  String get contractorPortalEnterpriseRequiredTitle;

  /// No description provided for @contractorPortalEnterpriseBoardBody.
  ///
  /// In en, this message translates to:
  /// **'The Subcontractor Board is available on the Enterprise plan. Upgrade to post and browse subcontract jobs.'**
  String get contractorPortalEnterpriseBoardBody;

  /// No description provided for @contractorPortalEnterpriseToolsBody.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Enterprise for multi-location operations, subcontractor marketplace workflows, bid analysis, crew scheduling, and quality reports.'**
  String get contractorPortalEnterpriseToolsBody;

  /// No description provided for @contractorPortalBrowseJobs.
  ///
  /// In en, this message translates to:
  /// **'Browse jobs'**
  String get contractorPortalBrowseJobs;

  /// No description provided for @contractorPortalFindNewLeads.
  ///
  /// In en, this message translates to:
  /// **'Find new leads'**
  String get contractorPortalFindNewLeads;

  /// No description provided for @contractorPortalReplyFaster.
  ///
  /// In en, this message translates to:
  /// **'Reply faster'**
  String get contractorPortalReplyFaster;

  /// No description provided for @contractorPortalPortfolio.
  ///
  /// In en, this message translates to:
  /// **'Portfolio'**
  String get contractorPortalPortfolio;

  /// No description provided for @contractorPortalShowcaseYourWork.
  ///
  /// In en, this message translates to:
  /// **'Showcase your work'**
  String get contractorPortalShowcaseYourWork;

  /// No description provided for @contractorPortalPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get contractorPortalPayments;

  /// No description provided for @contractorPortalTrackEarnings.
  ///
  /// In en, this message translates to:
  /// **'Track earnings'**
  String get contractorPortalTrackEarnings;

  /// No description provided for @contractorPortalSubcontractJobs.
  ///
  /// In en, this message translates to:
  /// **'Subcontract jobs'**
  String get contractorPortalSubcontractJobs;

  /// No description provided for @contractorPortalViewPostedWork.
  ///
  /// In en, this message translates to:
  /// **'View posted work'**
  String get contractorPortalViewPostedWork;

  /// No description provided for @contractorPortalPostJob.
  ///
  /// In en, this message translates to:
  /// **'Post a job'**
  String get contractorPortalPostJob;

  /// No description provided for @contractorPortalShareOverflowWork.
  ///
  /// In en, this message translates to:
  /// **'Share overflow work'**
  String get contractorPortalShareOverflowWork;

  /// No description provided for @contractorPortalCrewRoster.
  ///
  /// In en, this message translates to:
  /// **'Crew roster'**
  String get contractorPortalCrewRoster;

  /// No description provided for @contractorPortalManageTeam.
  ///
  /// In en, this message translates to:
  /// **'Manage your team'**
  String get contractorPortalManageTeam;

  /// No description provided for @contractorPortalLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get contractorPortalLeaderboard;

  /// No description provided for @contractorPortalXpRankings.
  ///
  /// In en, this message translates to:
  /// **'XP rankings'**
  String get contractorPortalXpRankings;

  /// No description provided for @contractorPortalProfitLoss.
  ///
  /// In en, this message translates to:
  /// **'Profit & Loss'**
  String get contractorPortalProfitLoss;

  /// No description provided for @contractorPortalFinancialDashboard.
  ///
  /// In en, this message translates to:
  /// **'Financial dashboard'**
  String get contractorPortalFinancialDashboard;

  /// No description provided for @contractorPortalAiSupport.
  ///
  /// In en, this message translates to:
  /// **'AI Support'**
  String get contractorPortalAiSupport;

  /// No description provided for @contractorPortalInstantHelp.
  ///
  /// In en, this message translates to:
  /// **'Get instant help 24/7'**
  String get contractorPortalInstantHelp;

  /// No description provided for @contractorPortalNoClaimedJobs.
  ///
  /// In en, this message translates to:
  /// **'No claimed jobs yet'**
  String get contractorPortalNoClaimedJobs;

  /// No description provided for @contractorPortalNoClaimedJobsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse leads and purchase one to start a conversation with the customer.'**
  String get contractorPortalNoClaimedJobsSubtitle;

  /// No description provided for @contractorPortalCouldNotLoadJobs.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load jobs'**
  String get contractorPortalCouldNotLoadJobs;

  /// No description provided for @contractorPortalLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location: {location}'**
  String contractorPortalLocationLabel(String location);

  /// No description provided for @contractorPortalClaimedLabel.
  ///
  /// In en, this message translates to:
  /// **'Claimed: {date}'**
  String contractorPortalClaimedLabel(String date);

  /// No description provided for @contractorPortalCreatedLabel.
  ///
  /// In en, this message translates to:
  /// **'Created: {date}'**
  String contractorPortalCreatedLabel(String date);

  /// No description provided for @contractorPortalJobsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse and purchase customer project leads'**
  String get contractorPortalJobsSubtitle;

  /// No description provided for @contractorPortalMyClaimedJobs.
  ///
  /// In en, this message translates to:
  /// **'My Claimed Jobs'**
  String get contractorPortalMyClaimedJobs;

  /// No description provided for @contractorPortalPlanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your account, credits, and subscription'**
  String get contractorPortalPlanSubtitle;

  /// No description provided for @contractorPortalCouldNotLoadAccount.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load account info'**
  String get contractorPortalCouldNotLoadAccount;

  /// No description provided for @contractorPortalTrackPerformance.
  ///
  /// In en, this message translates to:
  /// **'Track performance and growth'**
  String get contractorPortalTrackPerformance;

  /// No description provided for @keepScheduleUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Keep your schedule up to date'**
  String get keepScheduleUpToDate;

  /// No description provided for @controlWhereYouGetLeads.
  ///
  /// In en, this message translates to:
  /// **'Control where you get leads'**
  String get controlWhereYouGetLeads;

  /// No description provided for @showcaseBestWork.
  ///
  /// In en, this message translates to:
  /// **'Showcase your best work'**
  String get showcaseBestWork;

  /// No description provided for @manageCompanyDetails.
  ///
  /// In en, this message translates to:
  /// **'Manage company details'**
  String get manageCompanyDetails;

  /// No description provided for @answerCustomerQuestions.
  ///
  /// In en, this message translates to:
  /// **'Answer common customer questions'**
  String get answerCustomerQuestions;

  /// No description provided for @adminOperationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Admin Operations'**
  String get adminOperationsTitle;

  /// No description provided for @adminOverviewTab.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get adminOverviewTab;

  /// No description provided for @adminPaymentsTab.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get adminPaymentsTab;

  /// No description provided for @adminDisputesTab.
  ///
  /// In en, this message translates to:
  /// **'Disputes'**
  String get adminDisputesTab;

  /// No description provided for @adminModerationTab.
  ///
  /// In en, this message translates to:
  /// **'Moderation'**
  String get adminModerationTab;

  /// No description provided for @adminCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Admin check failed: {error}'**
  String adminCheckFailed(String error);

  /// No description provided for @adminAccessRequired.
  ///
  /// In en, this message translates to:
  /// **'Admin access required. This screen is only available to approved operators.'**
  String get adminAccessRequired;

  /// No description provided for @disputeStatusUpdated.
  ///
  /// In en, this message translates to:
  /// **'Dispute status updated to {status}'**
  String disputeStatusUpdated(String status);

  /// No description provided for @errorWithMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String errorWithMessage(String message);

  /// No description provided for @resolveDispute.
  ///
  /// In en, this message translates to:
  /// **'Resolve Dispute'**
  String get resolveDispute;

  /// No description provided for @resolutionDetails.
  ///
  /// In en, this message translates to:
  /// **'Resolution Details'**
  String get resolutionDetails;

  /// No description provided for @resolve.
  ///
  /// In en, this message translates to:
  /// **'Resolve'**
  String get resolve;

  /// No description provided for @errorLoadingDisputes.
  ///
  /// In en, this message translates to:
  /// **'Error loading disputes:\n\n{error}'**
  String errorLoadingDisputes(String error);

  /// No description provided for @noActiveDisputes.
  ///
  /// In en, this message translates to:
  /// **'No active disputes'**
  String get noActiveDisputes;

  /// No description provided for @filtersAndSorting.
  ///
  /// In en, this message translates to:
  /// **'Filters & sorting'**
  String get filtersAndSorting;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @underReview.
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get underReview;

  /// No description provided for @resolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get resolved;

  /// No description provided for @closed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get closed;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// No description provided for @newestToOldest.
  ///
  /// In en, this message translates to:
  /// **'Newest to Oldest'**
  String get newestToOldest;

  /// No description provided for @oldestToNewest.
  ///
  /// In en, this message translates to:
  /// **'Oldest to Newest'**
  String get oldestToNewest;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @jobIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Job ID: {jobId}'**
  String jobIdLabel(String jobId);

  /// No description provided for @startReview.
  ///
  /// In en, this message translates to:
  /// **'Start Review'**
  String get startReview;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @disputeClosedWithoutResolution.
  ///
  /// In en, this message translates to:
  /// **'Dispute closed without resolution'**
  String get disputeClosedWithoutResolution;

  /// No description provided for @paymentOpsEscrowOperations.
  ///
  /// In en, this message translates to:
  /// **'Escrow Operations'**
  String get paymentOpsEscrowOperations;

  /// No description provided for @paymentOpsEscrowOperationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stuck, failed, refund, dispute, and payout states.'**
  String get paymentOpsEscrowOperationsSubtitle;

  /// No description provided for @paymentOpsNoEscrowIssues.
  ///
  /// In en, this message translates to:
  /// **'No escrow issues'**
  String get paymentOpsNoEscrowIssues;

  /// No description provided for @paymentOpsNoEscrowIssuesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Escrow records do not need admin attention.'**
  String get paymentOpsNoEscrowIssuesSubtitle;

  /// No description provided for @paymentOpsPaymentRecords.
  ///
  /// In en, this message translates to:
  /// **'Payment Records'**
  String get paymentOpsPaymentRecords;

  /// No description provided for @paymentOpsPaymentRecordsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stripe, app store, lead credit, and invoice records.'**
  String get paymentOpsPaymentRecordsSubtitle;

  /// No description provided for @paymentOpsNoPaymentIssues.
  ///
  /// In en, this message translates to:
  /// **'No payment issues'**
  String get paymentOpsNoPaymentIssues;

  /// No description provided for @paymentOpsNoPaymentIssuesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Payment records do not need attention.'**
  String get paymentOpsNoPaymentIssuesSubtitle;

  /// No description provided for @paymentOpsPayoutSetup.
  ///
  /// In en, this message translates to:
  /// **'Payout setup'**
  String get paymentOpsPayoutSetup;

  /// No description provided for @paymentOpsPayoutSetupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Contractors who cannot reliably receive payouts yet.'**
  String get paymentOpsPayoutSetupSubtitle;

  /// No description provided for @paymentOpsPayoutsReady.
  ///
  /// In en, this message translates to:
  /// **'All payout setups look ready'**
  String get paymentOpsPayoutsReady;

  /// No description provided for @paymentOpsPayoutsReadySubtitle.
  ///
  /// In en, this message translates to:
  /// **'No contractor payout blockers found.'**
  String get paymentOpsPayoutsReadySubtitle;

  /// No description provided for @needsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get needsAttention;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @escrowIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Escrow: {id}'**
  String escrowIdLabel(String id);

  /// No description provided for @jobLabel.
  ///
  /// In en, this message translates to:
  /// **'Job: {jobId}'**
  String jobLabel(String jobId);

  /// No description provided for @statusPayoutLabel.
  ///
  /// In en, this message translates to:
  /// **'Status: {status} • Payout: {payout}'**
  String statusPayoutLabel(String status, String payout);

  /// No description provided for @amountContractorPayoutLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount: {amount} • Contractor payout: {payout}'**
  String amountContractorPayoutLabel(String amount, String payout);

  /// No description provided for @openEscrow.
  ///
  /// In en, this message translates to:
  /// **'Open escrow'**
  String get openEscrow;

  /// No description provided for @openJob.
  ///
  /// In en, this message translates to:
  /// **'Open job'**
  String get openJob;

  /// No description provided for @markReviewed.
  ///
  /// In en, this message translates to:
  /// **'Mark reviewed'**
  String get markReviewed;

  /// No description provided for @idLabel.
  ///
  /// In en, this message translates to:
  /// **'ID: {id}'**
  String idLabel(String id);

  /// No description provided for @typeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type: {type}'**
  String typeLabel(String type);

  /// No description provided for @userLabel.
  ///
  /// In en, this message translates to:
  /// **'User: {userId}'**
  String userLabel(String userId);

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String statusLabel(String status);

  /// No description provided for @amountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount: {amount}'**
  String amountLabel(String amount);

  /// No description provided for @check.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get check;

  /// No description provided for @stripeAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'Stripe account: {account}'**
  String stripeAccountLabel(String account);

  /// No description provided for @detailsSubmittedLabel.
  ///
  /// In en, this message translates to:
  /// **'Details submitted: {value}'**
  String detailsSubmittedLabel(String value);

  /// No description provided for @payoutsEnabledLabel.
  ///
  /// In en, this message translates to:
  /// **'Payouts enabled: {value}'**
  String payoutsEnabledLabel(String value);

  /// No description provided for @missing.
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get missing;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'no'**
  String get no;

  /// No description provided for @escrowMarkedReviewed.
  ///
  /// In en, this message translates to:
  /// **'Escrow marked reviewed.'**
  String get escrowMarkedReviewed;

  /// No description provided for @couldNotMarkReviewed.
  ///
  /// In en, this message translates to:
  /// **'Could not mark reviewed: {error}'**
  String couldNotMarkReviewed(String error);

  /// No description provided for @escrows.
  ///
  /// In en, this message translates to:
  /// **'Escrows'**
  String get escrows;

  /// No description provided for @escrowAlerts.
  ///
  /// In en, this message translates to:
  /// **'Escrow alerts'**
  String get escrowAlerts;

  /// No description provided for @paymentAlerts.
  ///
  /// In en, this message translates to:
  /// **'Payment alerts'**
  String get paymentAlerts;

  /// No description provided for @allRecords.
  ///
  /// In en, this message translates to:
  /// **'All records'**
  String get allRecords;

  /// No description provided for @errorLoadingPaymentOperations.
  ///
  /// In en, this message translates to:
  /// **'Error loading payment operations:\n\n{message}'**
  String errorLoadingPaymentOperations(String message);

  /// No description provided for @errorLoadingJobs.
  ///
  /// In en, this message translates to:
  /// **'Error loading jobs:\n\n{error}'**
  String errorLoadingJobs(String error);

  /// No description provided for @noJobsFound.
  ///
  /// In en, this message translates to:
  /// **'No jobs found'**
  String get noJobsFound;

  /// No description provided for @inProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get inProgress;

  /// No description provided for @persistentJobBarWorkUnderway.
  ///
  /// In en, this message translates to:
  /// **'Work is underway.'**
  String get persistentJobBarWorkUnderway;

  /// No description provided for @persistentJobBarAwaitingReview.
  ///
  /// In en, this message translates to:
  /// **'Awaiting review'**
  String get persistentJobBarAwaitingReview;

  /// No description provided for @persistentJobBarCustomerReviewPrompt.
  ///
  /// In en, this message translates to:
  /// **'Leave a review to close this out.'**
  String get persistentJobBarCustomerReviewPrompt;

  /// No description provided for @persistentJobBarContractorReviewPending.
  ///
  /// In en, this message translates to:
  /// **'Customer review pending.'**
  String get persistentJobBarContractorReviewPending;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @allClaims.
  ///
  /// In en, this message translates to:
  /// **'All claims'**
  String get allClaims;

  /// No description provided for @unclaimed.
  ///
  /// In en, this message translates to:
  /// **'Unclaimed'**
  String get unclaimed;

  /// No description provided for @claimed.
  ///
  /// In en, this message translates to:
  /// **'Claimed'**
  String get claimed;

  /// No description provided for @serviceAToZ.
  ///
  /// In en, this message translates to:
  /// **'Service A to Z'**
  String get serviceAToZ;

  /// No description provided for @serviceZToA.
  ///
  /// In en, this message translates to:
  /// **'Service Z to A'**
  String get serviceZToA;

  /// No description provided for @deleteJobQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete Job?'**
  String get deleteJobQuestion;

  /// No description provided for @deleteJobPermanentWarning.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete this job request. This cannot be undone.'**
  String get deleteJobPermanentWarning;

  /// No description provided for @errorLoadingModerationQueue.
  ///
  /// In en, this message translates to:
  /// **'Error loading moderation queue: {error}'**
  String errorLoadingModerationQueue(String error);

  /// No description provided for @communityModeration.
  ///
  /// In en, this message translates to:
  /// **'Community moderation'**
  String get communityModeration;

  /// No description provided for @communityModerationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review reported posts, remove harmful content, restore false positives, or clear reviewed reports.'**
  String get communityModerationSubtitle;

  /// No description provided for @reported.
  ///
  /// In en, this message translates to:
  /// **'Reported'**
  String get reported;

  /// No description provided for @removed.
  ///
  /// In en, this message translates to:
  /// **'Removed'**
  String get removed;

  /// No description provided for @unknownAuthor.
  ///
  /// In en, this message translates to:
  /// **'Unknown author'**
  String get unknownAuthor;

  /// No description provided for @postIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Post {postId}'**
  String postIdLabel(String postId);

  /// No description provided for @reportCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{0 reports} =1{1 report} other{{count} reports}}'**
  String reportCount(int count);

  /// No description provided for @noCaption.
  ///
  /// In en, this message translates to:
  /// **'No caption'**
  String get noCaption;

  /// No description provided for @mediaAttachmentCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 media attachment} other{{count} media attachments}}'**
  String mediaAttachmentCount(int count);

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @postMarkedStatus.
  ///
  /// In en, this message translates to:
  /// **'Post marked {status}.'**
  String postMarkedStatus(String status);

  /// No description provided for @reportsMarkedReviewed.
  ///
  /// In en, this message translates to:
  /// **'Reports marked reviewed.'**
  String get reportsMarkedReviewed;

  /// No description provided for @leaveReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave a Review'**
  String get leaveReviewTitle;

  /// No description provided for @reviewSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to leave a review.'**
  String get reviewSignInRequired;

  /// No description provided for @reviewSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Review submitted'**
  String get reviewSubmitted;

  /// No description provided for @reviewTrustTitle.
  ///
  /// In en, this message translates to:
  /// **'Help the next homeowner choose confidently'**
  String get reviewTrustTitle;

  /// No description provided for @reviewTrustSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your review improves contractor quality, pricing trust, and safety for future jobs.'**
  String get reviewTrustSubtitle;

  /// No description provided for @rating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get rating;

  /// No description provided for @reviewRatingSemantics.
  ///
  /// In en, this message translates to:
  /// **'{count} star rating'**
  String reviewRatingSemantics(int count);

  /// No description provided for @reviewRatingHelper.
  ///
  /// In en, this message translates to:
  /// **'Selected rating: {count}/5'**
  String reviewRatingHelper(int count);

  /// No description provided for @reviewCommentLabel.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get reviewCommentLabel;

  /// No description provided for @reviewCommentHint.
  ///
  /// In en, this message translates to:
  /// **'What went well? Was the contractor on time, clear, and professional?'**
  String get reviewCommentHint;

  /// No description provided for @submitReview.
  ///
  /// In en, this message translates to:
  /// **'Submit Review'**
  String get submitReview;

  /// No description provided for @bidsSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to view bids.'**
  String get bidsSignInRequired;

  /// No description provided for @compareBids.
  ///
  /// In en, this message translates to:
  /// **'Compare Bids'**
  String get compareBids;

  /// No description provided for @noBidsYet.
  ///
  /// In en, this message translates to:
  /// **'No bids yet'**
  String get noBidsYet;

  /// No description provided for @noBidsYetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Contractors will submit bids soon'**
  String get noBidsYetSubtitle;

  /// No description provided for @completedJobsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} completed'**
  String completedJobsCount(int count);

  /// No description provided for @etaDays.
  ///
  /// In en, this message translates to:
  /// **'ETA: {count, plural, =1{1 day} other{{count} days}}'**
  String etaDays(int count);

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @counter.
  ///
  /// In en, this message translates to:
  /// **'Counter'**
  String get counter;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @viewCounterOffer.
  ///
  /// In en, this message translates to:
  /// **'View counter offer'**
  String get viewCounterOffer;

  /// No description provided for @bidStatusUpdated.
  ///
  /// In en, this message translates to:
  /// **'Bid {status}'**
  String bidStatusUpdated(String status);

  /// No description provided for @acceptBid.
  ///
  /// In en, this message translates to:
  /// **'Accept Bid'**
  String get acceptBid;

  /// No description provided for @acceptBidMessage.
  ///
  /// In en, this message translates to:
  /// **'Accept bid for {amount}?\n\nThis will assign the job to {contractorName}.'**
  String acceptBidMessage(String amount, String contractorName);

  /// No description provided for @acceptingBid.
  ///
  /// In en, this message translates to:
  /// **'Accepting bid...'**
  String get acceptingBid;

  /// No description provided for @bidAcceptedJobAssigned.
  ///
  /// In en, this message translates to:
  /// **'Bid accepted! Job assigned.'**
  String get bidAcceptedJobAssigned;

  /// No description provided for @counterOffer.
  ///
  /// In en, this message translates to:
  /// **'Counter Offer'**
  String get counterOffer;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @messageOptional.
  ///
  /// In en, this message translates to:
  /// **'Message (optional)'**
  String get messageOptional;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @counterOfferDefaultDescription.
  ///
  /// In en, this message translates to:
  /// **'Counter offer to original bid'**
  String get counterOfferDefaultDescription;

  /// No description provided for @counterOfferSent.
  ///
  /// In en, this message translates to:
  /// **'Counter offer sent'**
  String get counterOfferSent;

  /// No description provided for @compareQuotes.
  ///
  /// In en, this message translates to:
  /// **'Compare Quotes'**
  String get compareQuotes;

  /// No description provided for @noQuotesYet.
  ///
  /// In en, this message translates to:
  /// **'No quotes yet'**
  String get noQuotesYet;

  /// No description provided for @noQuotesYetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Contractors will submit quotes for your job request.'**
  String get noQuotesYetSubtitle;

  /// No description provided for @noQuotesStepRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Your request is posted'**
  String get noQuotesStepRequestTitle;

  /// No description provided for @noQuotesStepRequestBody.
  ///
  /// In en, this message translates to:
  /// **'Pros can review your details, photos, ZIP code, and service scope before responding.'**
  String get noQuotesStepRequestBody;

  /// No description provided for @noQuotesStepInviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite matched pros'**
  String get noQuotesStepInviteTitle;

  /// No description provided for @noQuotesStepInviteBody.
  ///
  /// In en, this message translates to:
  /// **'Review recommended contractors and invite the best matches to speed up responses.'**
  String get noQuotesStepInviteBody;

  /// No description provided for @noQuotesStepProtectTitle.
  ///
  /// In en, this message translates to:
  /// **'Accept with protected payment'**
  String get noQuotesStepProtectTitle;

  /// No description provided for @noQuotesStepProtectBody.
  ///
  /// In en, this message translates to:
  /// **'When you accept a quote, the job moves into the Job Command Center for chat, escrow, photos, invoice, and review.'**
  String get noQuotesStepProtectBody;

  /// No description provided for @noQuotesTrustLine.
  ///
  /// In en, this message translates to:
  /// **'You can keep inviting pros while you wait. No payment is due until you accept a quote or choose an instant-price offer.'**
  String get noQuotesTrustLine;

  /// No description provided for @noQuotesInvitePros.
  ///
  /// In en, this message translates to:
  /// **'Invite matched pros'**
  String get noQuotesInvitePros;

  /// No description provided for @quoteAccepted.
  ///
  /// In en, this message translates to:
  /// **'Quote accepted'**
  String get quoteAccepted;

  /// No description provided for @chooseTheRightPro.
  ///
  /// In en, this message translates to:
  /// **'Choose the right pro'**
  String get chooseTheRightPro;

  /// No description provided for @quoteAcceptedHeaderBody.
  ///
  /// In en, this message translates to:
  /// **'Your job is assigned. Open the Job Command Center to chat, track status, escrow, photos, invoice, and review.'**
  String get quoteAcceptedHeaderBody;

  /// No description provided for @compareQuotesHeaderBody.
  ///
  /// In en, this message translates to:
  /// **'Compare price, reviews, completed jobs, notes, warranty, scope, and timeline before accepting. After you accept, the Job Command Center keeps the whole job in one place.'**
  String get compareQuotesHeaderBody;

  /// No description provided for @quoteTagBestValue.
  ///
  /// In en, this message translates to:
  /// **'Best value'**
  String get quoteTagBestValue;

  /// No description provided for @quoteTagLowestPrice.
  ///
  /// In en, this message translates to:
  /// **'Lowest price'**
  String get quoteTagLowestPrice;

  /// No description provided for @quoteTagMostTrusted.
  ///
  /// In en, this message translates to:
  /// **'Most trusted'**
  String get quoteTagMostTrusted;

  /// No description provided for @quotesLower.
  ///
  /// In en, this message translates to:
  /// **'quotes'**
  String get quotesLower;

  /// No description provided for @pendingLower.
  ///
  /// In en, this message translates to:
  /// **'pending'**
  String get pendingLower;

  /// No description provided for @rangeLower.
  ///
  /// In en, this message translates to:
  /// **'range'**
  String get rangeLower;

  /// No description provided for @escrowAfterApproval.
  ///
  /// In en, this message translates to:
  /// **'Escrow after approval'**
  String get escrowAfterApproval;

  /// No description provided for @openJobCommandCenter.
  ///
  /// In en, this message translates to:
  /// **'Open Job Command Center'**
  String get openJobCommandCenter;

  /// No description provided for @unknownContractor.
  ///
  /// In en, this message translates to:
  /// **'Unknown Contractor'**
  String get unknownContractor;

  /// No description provided for @quoteEtaValue.
  ///
  /// In en, this message translates to:
  /// **'ETA: {value}'**
  String quoteEtaValue(String value);

  /// No description provided for @insured.
  ///
  /// In en, this message translates to:
  /// **'Insured'**
  String get insured;

  /// No description provided for @licensed.
  ///
  /// In en, this message translates to:
  /// **'Licensed'**
  String get licensed;

  /// No description provided for @reviewCountShort.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No reviews} =1{1 review} other{{count} reviews}}'**
  String reviewCountShort(int count);

  /// No description provided for @aiPrice.
  ///
  /// In en, this message translates to:
  /// **'AI price'**
  String get aiPrice;

  /// No description provided for @adjustedFromAi.
  ///
  /// In en, this message translates to:
  /// **'Adjusted from AI'**
  String get adjustedFromAi;

  /// No description provided for @revisionNumber.
  ///
  /// In en, this message translates to:
  /// **'Revision {number}'**
  String revisionNumber(int number);

  /// No description provided for @expiresDate.
  ///
  /// In en, this message translates to:
  /// **'Expires {date}'**
  String expiresDate(String date);

  /// No description provided for @scopeAttached.
  ///
  /// In en, this message translates to:
  /// **'Scope attached'**
  String get scopeAttached;

  /// No description provided for @protectedPaymentPath.
  ///
  /// In en, this message translates to:
  /// **'Protected payment path'**
  String get protectedPaymentPath;

  /// No description provided for @beforeYouAccept.
  ///
  /// In en, this message translates to:
  /// **'Before you accept'**
  String get beforeYouAccept;

  /// No description provided for @scopeOfWork.
  ///
  /// In en, this message translates to:
  /// **'Scope of work'**
  String get scopeOfWork;

  /// No description provided for @scopeMissing.
  ///
  /// In en, this message translates to:
  /// **'Ask for scope details before approving'**
  String get scopeMissing;

  /// No description provided for @warranty.
  ///
  /// In en, this message translates to:
  /// **'Warranty'**
  String get warranty;

  /// No description provided for @warrantyIncluded.
  ///
  /// In en, this message translates to:
  /// **'Included in this quote'**
  String get warrantyIncluded;

  /// No description provided for @warrantyNotListed.
  ///
  /// In en, this message translates to:
  /// **'Not listed'**
  String get warrantyNotListed;

  /// No description provided for @exclusions.
  ///
  /// In en, this message translates to:
  /// **'Exclusions'**
  String get exclusions;

  /// No description provided for @exclusionsListed.
  ///
  /// In en, this message translates to:
  /// **'Listed by contractor'**
  String get exclusionsListed;

  /// No description provided for @exclusionsNotListed.
  ///
  /// In en, this message translates to:
  /// **'Not listed'**
  String get exclusionsNotListed;

  /// No description provided for @deposit.
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get deposit;

  /// No description provided for @depositRequiredAmount.
  ///
  /// In en, this message translates to:
  /// **'{amount} required'**
  String depositRequiredAmount(String amount);

  /// No description provided for @depositNotListed.
  ///
  /// In en, this message translates to:
  /// **'No deposit listed'**
  String get depositNotListed;

  /// No description provided for @adjustment.
  ///
  /// In en, this message translates to:
  /// **'Adjustment'**
  String get adjustment;

  /// No description provided for @submittedDate.
  ///
  /// In en, this message translates to:
  /// **'Submitted {date}'**
  String submittedDate(String date);

  /// No description provided for @acceptQuote.
  ///
  /// In en, this message translates to:
  /// **'Accept Quote'**
  String get acceptQuote;

  /// No description provided for @continueJob.
  ///
  /// In en, this message translates to:
  /// **'Continue Job'**
  String get continueJob;

  /// No description provided for @acceptQuoteMessage.
  ///
  /// In en, this message translates to:
  /// **'Accept this quote for {amount} from {contractorName}?\n\nThe contractor will be assigned and your next steps will move to the Job Command Center.'**
  String acceptQuoteMessage(String amount, String contractorName);

  /// No description provided for @acceptingQuote.
  ///
  /// In en, this message translates to:
  /// **'Accepting quote...'**
  String get acceptingQuote;

  /// No description provided for @quoteAcceptedJobAssigned.
  ///
  /// In en, this message translates to:
  /// **'Quote accepted. Job assigned.'**
  String get quoteAcceptedJobAssigned;

  /// No description provided for @quoteDeclined.
  ///
  /// In en, this message translates to:
  /// **'Quote declined'**
  String get quoteDeclined;

  /// No description provided for @jobCommandCenterTitle.
  ///
  /// In en, this message translates to:
  /// **'Job Command Center'**
  String get jobCommandCenterTitle;

  /// No description provided for @jobDetailsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Job details'**
  String get jobDetailsTooltip;

  /// No description provided for @couldNotLoadJob.
  ///
  /// In en, this message translates to:
  /// **'Could not load job'**
  String get couldNotLoadJob;

  /// No description provided for @jobNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Job not found'**
  String get jobNotFoundTitle;

  /// No description provided for @jobNotFoundSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This job may have been removed or is unavailable.'**
  String get jobNotFoundSubtitle;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @accepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get accepted;

  /// No description provided for @completionRequested.
  ///
  /// In en, this message translates to:
  /// **'Completion Requested'**
  String get completionRequested;

  /// No description provided for @completionApproved.
  ///
  /// In en, this message translates to:
  /// **'Completion Approved'**
  String get completionApproved;

  /// No description provided for @escrowFunded.
  ///
  /// In en, this message translates to:
  /// **'Escrow Funded'**
  String get escrowFunded;

  /// No description provided for @customerView.
  ///
  /// In en, this message translates to:
  /// **'Customer view'**
  String get customerView;

  /// No description provided for @contractorView.
  ///
  /// In en, this message translates to:
  /// **'Contractor view'**
  String get contractorView;

  /// No description provided for @escrowAttached.
  ///
  /// In en, this message translates to:
  /// **'Escrow attached'**
  String get escrowAttached;

  /// No description provided for @disputeOpen.
  ///
  /// In en, this message translates to:
  /// **'Dispute open'**
  String get disputeOpen;

  /// No description provided for @customerJourney.
  ///
  /// In en, this message translates to:
  /// **'Customer journey'**
  String get customerJourney;

  /// No description provided for @customerJourneySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track the job from request to paid, completed, and reviewed.'**
  String get customerJourneySubtitle;

  /// No description provided for @jobStepRequest.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get jobStepRequest;

  /// No description provided for @jobStepQuotes.
  ///
  /// In en, this message translates to:
  /// **'Quotes'**
  String get jobStepQuotes;

  /// No description provided for @jobStepHire.
  ///
  /// In en, this message translates to:
  /// **'Hire'**
  String get jobStepHire;

  /// No description provided for @jobStepEscrow.
  ///
  /// In en, this message translates to:
  /// **'Escrow'**
  String get jobStepEscrow;

  /// No description provided for @jobStepWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get jobStepWork;

  /// No description provided for @jobStepReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get jobStepReview;

  /// No description provided for @nextBestAction.
  ///
  /// In en, this message translates to:
  /// **'Next best action'**
  String get nextBestAction;

  /// No description provided for @reviewIncomingQuotes.
  ///
  /// In en, this message translates to:
  /// **'Review incoming quotes'**
  String get reviewIncomingQuotes;

  /// No description provided for @submitAQuote.
  ///
  /// In en, this message translates to:
  /// **'Submit a quote'**
  String get submitAQuote;

  /// No description provided for @startWork.
  ///
  /// In en, this message translates to:
  /// **'Start work'**
  String get startWork;

  /// No description provided for @requestCompletion.
  ///
  /// In en, this message translates to:
  /// **'Request completion'**
  String get requestCompletion;

  /// No description provided for @approveCompletion.
  ///
  /// In en, this message translates to:
  /// **'Approve completion'**
  String get approveCompletion;

  /// No description provided for @checkEscrow.
  ///
  /// In en, this message translates to:
  /// **'Check escrow'**
  String get checkEscrow;

  /// No description provided for @openJobStatus.
  ///
  /// In en, this message translates to:
  /// **'Open job status'**
  String get openJobStatus;

  /// No description provided for @compareBidsChooseContractor.
  ///
  /// In en, this message translates to:
  /// **'Compare bids, chat with pros, and choose the right contractor.'**
  String get compareBidsChooseContractor;

  /// No description provided for @sendClearQuote.
  ///
  /// In en, this message translates to:
  /// **'Send a clear quote so the customer can approve the work.'**
  String get sendClearQuote;

  /// No description provided for @confirmWorkBeforeRelease.
  ///
  /// In en, this message translates to:
  /// **'Confirm the work before payment release continues.'**
  String get confirmWorkBeforeRelease;

  /// No description provided for @fundsVisibleFromEscrow.
  ///
  /// In en, this message translates to:
  /// **'Funds and release state are visible from escrow status.'**
  String get fundsVisibleFromEscrow;

  /// No description provided for @useStatusToAlign.
  ///
  /// In en, this message translates to:
  /// **'Use status to keep both sides aligned.'**
  String get useStatusToAlign;

  /// No description provided for @commandSectionWinConfirm.
  ///
  /// In en, this message translates to:
  /// **'Win & confirm work'**
  String get commandSectionWinConfirm;

  /// No description provided for @reviewQuotes.
  ///
  /// In en, this message translates to:
  /// **'Review quotes'**
  String get reviewQuotes;

  /// No description provided for @submitQuote.
  ///
  /// In en, this message translates to:
  /// **'Submit quote'**
  String get submitQuote;

  /// No description provided for @reviewQuotesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Compare contractor pricing and terms.'**
  String get reviewQuotesSubtitle;

  /// No description provided for @submitQuoteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send pricing, notes, and scope for this job.'**
  String get submitQuoteSubtitle;

  /// No description provided for @bids.
  ///
  /// In en, this message translates to:
  /// **'Bids'**
  String get bids;

  /// No description provided for @bidsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View bids and acceptance status.'**
  String get bidsSubtitle;

  /// No description provided for @commandSectionToolsForJob.
  ///
  /// In en, this message translates to:
  /// **'Tools for this job'**
  String get commandSectionToolsForJob;

  /// No description provided for @priceThisJob.
  ///
  /// In en, this message translates to:
  /// **'Price this job'**
  String get priceThisJob;

  /// No description provided for @priceThisJobSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open the calculator with this job attached.'**
  String get priceThisJobSubtitle;

  /// No description provided for @savedEstimates.
  ///
  /// In en, this message translates to:
  /// **'Saved estimates'**
  String get savedEstimates;

  /// No description provided for @savedEstimatesJobSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View estimates connected to this job or create one.'**
  String get savedEstimatesJobSubtitle;

  /// No description provided for @aiInvoiceMaker.
  ///
  /// In en, this message translates to:
  /// **'AI invoice maker'**
  String get aiInvoiceMaker;

  /// No description provided for @aiInvoiceMakerJobSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Draft an invoice with this client and job context.'**
  String get aiInvoiceMakerJobSubtitle;

  /// No description provided for @createRender.
  ///
  /// In en, this message translates to:
  /// **'Create render'**
  String get createRender;

  /// No description provided for @createRenderJobSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Attach render concepts back to this job.'**
  String get createRenderJobSubtitle;

  /// No description provided for @commandSectionCommunicateDocument.
  ///
  /// In en, this message translates to:
  /// **'Communicate & document'**
  String get commandSectionCommunicateDocument;

  /// No description provided for @chatWithContractor.
  ///
  /// In en, this message translates to:
  /// **'Chat with contractor'**
  String get chatWithContractor;

  /// No description provided for @chatWithClient.
  ///
  /// In en, this message translates to:
  /// **'Chat with client'**
  String get chatWithClient;

  /// No description provided for @openJobConversation.
  ///
  /// In en, this message translates to:
  /// **'Open the job conversation.'**
  String get openJobConversation;

  /// No description provided for @chatOpensAfterClaimed.
  ///
  /// In en, this message translates to:
  /// **'Chat opens after the job is claimed.'**
  String get chatOpensAfterClaimed;

  /// No description provided for @progressPhotos.
  ///
  /// In en, this message translates to:
  /// **'Progress photos'**
  String get progressPhotos;

  /// No description provided for @progressPhotosSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload and review job photos.'**
  String get progressPhotosSubtitle;

  /// No description provided for @timeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get timeline;

  /// No description provided for @timelineSubtitle.
  ///
  /// In en, this message translates to:
  /// **'See updates, milestones, and activity.'**
  String get timelineSubtitle;

  /// No description provided for @milestones.
  ///
  /// In en, this message translates to:
  /// **'Milestones'**
  String get milestones;

  /// No description provided for @milestonesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track major job checkpoints.'**
  String get milestonesSubtitle;

  /// No description provided for @commandSectionMoneyCompletion.
  ///
  /// In en, this message translates to:
  /// **'Money & completion'**
  String get commandSectionMoneyCompletion;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @statusJobSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start work, request completion, or approve it.'**
  String get statusJobSubtitle;

  /// No description provided for @createInvoice.
  ///
  /// In en, this message translates to:
  /// **'Create invoice'**
  String get createInvoice;

  /// No description provided for @invoice.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get invoice;

  /// No description provided for @createInvoiceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create or update the customer invoice.'**
  String get createInvoiceSubtitle;

  /// No description provided for @invoiceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review invoice details for this job.'**
  String get invoiceSubtitle;

  /// No description provided for @escrowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View secured funds and release status.'**
  String get escrowSubtitle;

  /// No description provided for @noEscrowAttached.
  ///
  /// In en, this message translates to:
  /// **'No escrow has been attached to this job yet.'**
  String get noEscrowAttached;

  /// No description provided for @receiptsExpensesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track materials, labor, and reimbursements.'**
  String get receiptsExpensesSubtitle;

  /// No description provided for @commandSectionTrustCloseout.
  ///
  /// In en, this message translates to:
  /// **'Trust & closeout'**
  String get commandSectionTrustCloseout;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @reviewCompletedWork.
  ///
  /// In en, this message translates to:
  /// **'Rate the completed contractor work.'**
  String get reviewCompletedWork;

  /// No description provided for @reviewOpensAfterCompleted.
  ///
  /// In en, this message translates to:
  /// **'Reviews open after the job is completed.'**
  String get reviewOpensAfterCompleted;

  /// No description provided for @viewDispute.
  ///
  /// In en, this message translates to:
  /// **'View dispute'**
  String get viewDispute;

  /// No description provided for @reportDispute.
  ///
  /// In en, this message translates to:
  /// **'Report dispute'**
  String get reportDispute;

  /// No description provided for @viewDisputeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open the latest dispute details.'**
  String get viewDisputeSubtitle;

  /// No description provided for @reportDisputeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Report an issue with this job.'**
  String get reportDisputeSubtitle;

  /// No description provided for @cancellation.
  ///
  /// In en, this message translates to:
  /// **'Cancellation'**
  String get cancellation;

  /// No description provided for @cancelRefundEligibility.
  ///
  /// In en, this message translates to:
  /// **'Cancel and check refund eligibility.'**
  String get cancelRefundEligibility;

  /// No description provided for @cancellationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Cancellation is unavailable for this status.'**
  String get cancellationUnavailable;

  /// No description provided for @escrowStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Escrow Status'**
  String get escrowStatusTitle;

  /// No description provided for @bookingNotFound.
  ///
  /// In en, this message translates to:
  /// **'Booking not found'**
  String get bookingNotFound;

  /// No description provided for @bookingNotFoundSubtitle.
  ///
  /// In en, this message translates to:
  /// **'It may have been deleted or the link is invalid.'**
  String get bookingNotFoundSubtitle;

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get goBack;

  /// No description provided for @confirmJobCompleteQuestion.
  ///
  /// In en, this message translates to:
  /// **'Confirm Job Complete?'**
  String get confirmJobCompleteQuestion;

  /// No description provided for @customerConfirmReleaseMessage.
  ///
  /// In en, this message translates to:
  /// **'You\'re verifying the work was completed to your satisfaction. Once the contractor also confirms, {amount} will be released.'**
  String customerConfirmReleaseMessage(String amount);

  /// No description provided for @contractorConfirmReleaseMessage.
  ///
  /// In en, this message translates to:
  /// **'You\'re verifying the job has been completed. Once the customer also confirms, your payment of {amount} will be released.'**
  String contractorConfirmReleaseMessage(String amount);

  /// No description provided for @confirmRelease.
  ///
  /// In en, this message translates to:
  /// **'Confirm & Release'**
  String get confirmRelease;

  /// No description provided for @notYet.
  ///
  /// In en, this message translates to:
  /// **'Not Yet'**
  String get notYet;

  /// No description provided for @confirmationRecorded.
  ///
  /// In en, this message translates to:
  /// **'Confirmation recorded!'**
  String get confirmationRecorded;

  /// No description provided for @cancelBookingQuestion.
  ///
  /// In en, this message translates to:
  /// **'Cancel Booking?'**
  String get cancelBookingQuestion;

  /// No description provided for @cancelBookingRefundWarning.
  ///
  /// In en, this message translates to:
  /// **'Your payment will be fully refunded. This action cannot be undone.'**
  String get cancelBookingRefundWarning;

  /// No description provided for @keepBooking.
  ///
  /// In en, this message translates to:
  /// **'Keep Booking'**
  String get keepBooking;

  /// No description provided for @bookingCancelledRefunded.
  ///
  /// In en, this message translates to:
  /// **'Booking cancelled & refunded.'**
  String get bookingCancelledRefunded;

  /// No description provided for @cancellationFailedTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Cancellation failed. Please try again.'**
  String get cancellationFailedTryAgain;

  /// No description provided for @priceOffered.
  ///
  /// In en, this message translates to:
  /// **'Price Offered'**
  String get priceOffered;

  /// No description provided for @paymentHeldInEscrow.
  ///
  /// In en, this message translates to:
  /// **'Payment Held in Escrow'**
  String get paymentHeldInEscrow;

  /// No description provided for @customerConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Customer Confirmed'**
  String get customerConfirmed;

  /// No description provided for @contractorConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Contractor Confirmed'**
  String get contractorConfirmed;

  /// No description provided for @payoutProcessing.
  ///
  /// In en, this message translates to:
  /// **'Payout Processing'**
  String get payoutProcessing;

  /// No description provided for @fundsReleased.
  ///
  /// In en, this message translates to:
  /// **'Funds Released'**
  String get fundsReleased;

  /// No description provided for @payoutFailed.
  ///
  /// In en, this message translates to:
  /// **'Payout Failed'**
  String get payoutFailed;

  /// No description provided for @declined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get declined;

  /// No description provided for @escrowMeaningOfferedTitle.
  ///
  /// In en, this message translates to:
  /// **'Price is ready'**
  String get escrowMeaningOfferedTitle;

  /// No description provided for @escrowMeaningOfferedBody.
  ///
  /// In en, this message translates to:
  /// **'The AI price has been created, but funds are not held yet.'**
  String get escrowMeaningOfferedBody;

  /// No description provided for @escrowMeaningOfferedNext.
  ///
  /// In en, this message translates to:
  /// **'Next: customer accepts and pays, or requests contractor quotes.'**
  String get escrowMeaningOfferedNext;

  /// No description provided for @escrowMeaningFundedTitle.
  ///
  /// In en, this message translates to:
  /// **'Money is protected'**
  String get escrowMeaningFundedTitle;

  /// No description provided for @escrowMeaningFundedBody.
  ///
  /// In en, this message translates to:
  /// **'The customer paid and funds are being held while the work is completed.'**
  String get escrowMeaningFundedBody;

  /// No description provided for @escrowMeaningFundedNext.
  ///
  /// In en, this message translates to:
  /// **'Next: complete the job, then both sides confirm completion.'**
  String get escrowMeaningFundedNext;

  /// No description provided for @escrowMeaningCustomerConfirmedTitle.
  ///
  /// In en, this message translates to:
  /// **'Customer confirmed completion'**
  String get escrowMeaningCustomerConfirmedTitle;

  /// No description provided for @escrowMeaningCustomerConfirmedBody.
  ///
  /// In en, this message translates to:
  /// **'The customer approved the completed work. The contractor still needs to confirm.'**
  String get escrowMeaningCustomerConfirmedBody;

  /// No description provided for @escrowMeaningCustomerConfirmedNext.
  ///
  /// In en, this message translates to:
  /// **'Next: contractor confirms so payout can continue.'**
  String get escrowMeaningCustomerConfirmedNext;

  /// No description provided for @escrowMeaningContractorConfirmedTitle.
  ///
  /// In en, this message translates to:
  /// **'Contractor confirmed completion'**
  String get escrowMeaningContractorConfirmedTitle;

  /// No description provided for @escrowMeaningContractorConfirmedBody.
  ///
  /// In en, this message translates to:
  /// **'The contractor marked the work complete. The customer still needs to approve it.'**
  String get escrowMeaningContractorConfirmedBody;

  /// No description provided for @escrowMeaningContractorConfirmedNext.
  ///
  /// In en, this message translates to:
  /// **'Next: customer confirms before payment release continues.'**
  String get escrowMeaningContractorConfirmedNext;

  /// No description provided for @escrowMeaningPayoutPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Payout is processing'**
  String get escrowMeaningPayoutPendingTitle;

  /// No description provided for @escrowMeaningPayoutPendingBody.
  ///
  /// In en, this message translates to:
  /// **'{amount} is being prepared for contractor payout.'**
  String escrowMeaningPayoutPendingBody(String amount);

  /// No description provided for @escrowMeaningPayoutPendingNext.
  ///
  /// In en, this message translates to:
  /// **'Next: Stripe confirms the transfer automatically.'**
  String get escrowMeaningPayoutPendingNext;

  /// No description provided for @escrowMeaningReleasedTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment released'**
  String get escrowMeaningReleasedTitle;

  /// No description provided for @escrowMeaningReleasedBody.
  ///
  /// In en, this message translates to:
  /// **'{amount} was released to the contractor.'**
  String escrowMeaningReleasedBody(String amount);

  /// No description provided for @escrowMeaningReleasedNext.
  ///
  /// In en, this message translates to:
  /// **'Next: customer can rate the AI price and leave a review.'**
  String get escrowMeaningReleasedNext;

  /// No description provided for @escrowMeaningPayoutFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Payout needs review'**
  String get escrowMeaningPayoutFailedTitle;

  /// No description provided for @escrowMeaningPayoutFailedBody.
  ///
  /// In en, this message translates to:
  /// **'The job is complete, but the contractor payout did not finish automatically.'**
  String get escrowMeaningPayoutFailedBody;

  /// No description provided for @escrowMeaningPayoutFailedNext.
  ///
  /// In en, this message translates to:
  /// **'Next: admin support should review and retry or resolve the payout.'**
  String get escrowMeaningPayoutFailedNext;

  /// No description provided for @escrowMeaningDeclinedTitle.
  ///
  /// In en, this message translates to:
  /// **'Escrow declined'**
  String get escrowMeaningDeclinedTitle;

  /// No description provided for @escrowMeaningDeclinedBody.
  ///
  /// In en, this message translates to:
  /// **'The AI price was declined, so this escrow was not funded.'**
  String get escrowMeaningDeclinedBody;

  /// No description provided for @escrowMeaningDeclinedNext.
  ///
  /// In en, this message translates to:
  /// **'Next: continue with contractor quotes or post a new request.'**
  String get escrowMeaningDeclinedNext;

  /// No description provided for @escrowMeaningCancelledTitle.
  ///
  /// In en, this message translates to:
  /// **'Escrow cancelled'**
  String get escrowMeaningCancelledTitle;

  /// No description provided for @escrowMeaningCancelledBody.
  ///
  /// In en, this message translates to:
  /// **'This booking was cancelled and the payment should be refunded.'**
  String get escrowMeaningCancelledBody;

  /// No description provided for @escrowMeaningCancelledRefundBody.
  ///
  /// In en, this message translates to:
  /// **'Refund status: {status}'**
  String escrowMeaningCancelledRefundBody(String status);

  /// No description provided for @escrowMeaningCancelledNext.
  ///
  /// In en, this message translates to:
  /// **'Next: check refund status or contact support if it does not update.'**
  String get escrowMeaningCancelledNext;

  /// No description provided for @paymentSummary.
  ///
  /// In en, this message translates to:
  /// **'Payment Summary'**
  String get paymentSummary;

  /// No description provided for @totalPaid.
  ///
  /// In en, this message translates to:
  /// **'Total Paid'**
  String get totalPaid;

  /// No description provided for @platformFeePercent.
  ///
  /// In en, this message translates to:
  /// **'Platform Fee (5%)'**
  String get platformFeePercent;

  /// No description provided for @contractorPayout.
  ///
  /// In en, this message translates to:
  /// **'Contractor Payout'**
  String get contractorPayout;

  /// No description provided for @payoutStatus.
  ///
  /// In en, this message translates to:
  /// **'Payout Status'**
  String get payoutStatus;

  /// No description provided for @refundStatus.
  ///
  /// In en, this message translates to:
  /// **'Refund Status'**
  String get refundStatus;

  /// No description provided for @stripeTransfer.
  ///
  /// In en, this message translates to:
  /// **'Stripe Transfer'**
  String get stripeTransfer;

  /// No description provided for @stripeRefund.
  ///
  /// In en, this message translates to:
  /// **'Stripe Refund'**
  String get stripeRefund;

  /// No description provided for @aiPriceOffered.
  ///
  /// In en, this message translates to:
  /// **'AI Price Offered'**
  String get aiPriceOffered;

  /// No description provided for @paymentFunded.
  ///
  /// In en, this message translates to:
  /// **'Payment Funded'**
  String get paymentFunded;

  /// No description provided for @awaitingPayment.
  ///
  /// In en, this message translates to:
  /// **'Awaiting payment'**
  String get awaitingPayment;

  /// No description provided for @afterBothConfirm.
  ///
  /// In en, this message translates to:
  /// **'After both confirm'**
  String get afterBothConfirm;

  /// No description provided for @escrowTimeline.
  ///
  /// In en, this message translates to:
  /// **'Escrow Timeline'**
  String get escrowTimeline;

  /// No description provided for @howEscrowWorks.
  ///
  /// In en, this message translates to:
  /// **'How Escrow Works'**
  String get howEscrowWorks;

  /// No description provided for @howEscrowStepOne.
  ///
  /// In en, this message translates to:
  /// **'You pay the AI price, and funds are held securely.'**
  String get howEscrowStepOne;

  /// No description provided for @howEscrowStepTwo.
  ///
  /// In en, this message translates to:
  /// **'A contractor claims your job and completes the work.'**
  String get howEscrowStepTwo;

  /// No description provided for @howEscrowStepThree.
  ///
  /// In en, this message translates to:
  /// **'Both you and the contractor confirm completion.'**
  String get howEscrowStepThree;

  /// No description provided for @howEscrowStepFour.
  ///
  /// In en, this message translates to:
  /// **'Funds are released to the contractor minus the platform fee.'**
  String get howEscrowStepFour;

  /// No description provided for @confirmJobComplete.
  ///
  /// In en, this message translates to:
  /// **'Confirm Job Complete'**
  String get confirmJobComplete;

  /// No description provided for @cancelling.
  ///
  /// In en, this message translates to:
  /// **'Cancelling...'**
  String get cancelling;

  /// No description provided for @cancelBooking.
  ///
  /// In en, this message translates to:
  /// **'Cancel Booking'**
  String get cancelBooking;

  /// No description provided for @contractorConfirmedPleaseRelease.
  ///
  /// In en, this message translates to:
  /// **'The contractor has confirmed. Please confirm to release payment.'**
  String get contractorConfirmedPleaseRelease;

  /// No description provided for @confirmReleasePayment.
  ///
  /// In en, this message translates to:
  /// **'Confirm & Release Payment'**
  String get confirmReleasePayment;

  /// No description provided for @waitingForContractor.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Contractor'**
  String get waitingForContractor;

  /// No description provided for @waitingForContractorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You\'ve confirmed completion. Once the contractor also confirms, funds will be released.'**
  String get waitingForContractorSubtitle;

  /// No description provided for @jobCompleteExclamation.
  ///
  /// In en, this message translates to:
  /// **'Job Complete!'**
  String get jobCompleteExclamation;

  /// No description provided for @releasedToContractor.
  ///
  /// In en, this message translates to:
  /// **'{amount} released to contractor.'**
  String releasedToContractor(String amount);

  /// No description provided for @rateAiPrice.
  ///
  /// In en, this message translates to:
  /// **'Rate the AI Price'**
  String get rateAiPrice;

  /// No description provided for @rateAiPriceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Help our AI learn by rating how fair the price was.'**
  String get rateAiPriceSubtitle;

  /// No description provided for @youRatedThisPrice.
  ///
  /// In en, this message translates to:
  /// **'You rated this price'**
  String get youRatedThisPrice;

  /// No description provided for @backToHome.
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get backToHome;

  /// No description provided for @payoutProcessingMessage.
  ///
  /// In en, this message translates to:
  /// **'{amount} is being prepared for contractor payout. This usually updates automatically after Stripe confirms the transfer.'**
  String payoutProcessingMessage(String amount);

  /// No description provided for @payoutNeedsAdminReview.
  ///
  /// In en, this message translates to:
  /// **'Payout Needs Admin Review'**
  String get payoutNeedsAdminReview;

  /// No description provided for @payoutNeedsAdminReviewMessage.
  ///
  /// In en, this message translates to:
  /// **'The job is complete, but the contractor payout did not finish automatically. Support can review this escrow and retry or resolve the payout.'**
  String get payoutNeedsAdminReviewMessage;

  /// No description provided for @bookingCancelled.
  ///
  /// In en, this message translates to:
  /// **'Booking Cancelled'**
  String get bookingCancelled;

  /// No description provided for @refundStatusValue.
  ///
  /// In en, this message translates to:
  /// **'Refund status: {status}'**
  String refundStatusValue(String status);

  /// No description provided for @paymentRefunded.
  ///
  /// In en, this message translates to:
  /// **'Your payment has been refunded.'**
  String get paymentRefunded;

  /// No description provided for @writeReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Write a Review'**
  String get writeReviewTitle;

  /// No description provided for @verifiedReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Verified job review'**
  String get verifiedReviewTitle;

  /// No description provided for @verifiedReviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This review is tied to a completed ProServe job, so future homeowners can trust the feedback.'**
  String get verifiedReviewSubtitle;

  /// No description provided for @rateYourExperience.
  ///
  /// In en, this message translates to:
  /// **'Rate your experience'**
  String get rateYourExperience;

  /// No description provided for @quality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get quality;

  /// No description provided for @timeliness.
  ///
  /// In en, this message translates to:
  /// **'Timeliness'**
  String get timeliness;

  /// No description provided for @communication.
  ///
  /// In en, this message translates to:
  /// **'Communication'**
  String get communication;

  /// No description provided for @reviewCategoryRatingSemantics.
  ///
  /// In en, this message translates to:
  /// **'{label} {count} of 5 stars'**
  String reviewCategoryRatingSemantics(String label, int count);

  /// No description provided for @overallRatingValue.
  ///
  /// In en, this message translates to:
  /// **'Overall: {rating}/5'**
  String overallRatingValue(String rating);

  /// No description provided for @shareYourExperience.
  ///
  /// In en, this message translates to:
  /// **'Share your experience'**
  String get shareYourExperience;

  /// No description provided for @reviewExperienceHint.
  ///
  /// In en, this message translates to:
  /// **'Tell us about the contractor\'s quality, timing, communication, and professionalism.'**
  String get reviewExperienceHint;

  /// No description provided for @reviewCommentRequired.
  ///
  /// In en, this message translates to:
  /// **'Please write a comment'**
  String get reviewCommentRequired;

  /// No description provided for @reviewCommentTooShort.
  ///
  /// In en, this message translates to:
  /// **'Comment must be at least 20 characters'**
  String get reviewCommentTooShort;

  /// No description provided for @reviewRemoveInappropriateLanguage.
  ///
  /// In en, this message translates to:
  /// **'Please remove inappropriate language'**
  String get reviewRemoveInappropriateLanguage;

  /// No description provided for @addPhotosOptional.
  ///
  /// In en, this message translates to:
  /// **'Add photos (optional)'**
  String get addPhotosOptional;

  /// No description provided for @reviewPhotosSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show before/after photos or highlight quality of work.'**
  String get reviewPhotosSubtitle;

  /// No description provided for @reviewPhotoSemantics.
  ///
  /// In en, this message translates to:
  /// **'Review photo {count}'**
  String reviewPhotoSemantics(int count);

  /// No description provided for @removePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get removePhoto;

  /// No description provided for @addPhotosCount.
  ///
  /// In en, this message translates to:
  /// **'Add Photos ({count}/5)'**
  String addPhotosCount(int count);

  /// No description provided for @submitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting...'**
  String get submitting;

  /// No description provided for @reviewTips.
  ///
  /// In en, this message translates to:
  /// **'Review Tips'**
  String get reviewTips;

  /// No description provided for @reviewTipSpecific.
  ///
  /// In en, this message translates to:
  /// **'• Be specific about quality and service'**
  String get reviewTipSpecific;

  /// No description provided for @reviewTipProfessionalism.
  ///
  /// In en, this message translates to:
  /// **'• Mention professionalism and communication'**
  String get reviewTipProfessionalism;

  /// No description provided for @reviewTipPhotos.
  ///
  /// In en, this message translates to:
  /// **'• Include before/after photos if applicable'**
  String get reviewTipPhotos;

  /// No description provided for @reviewTipHonest.
  ///
  /// In en, this message translates to:
  /// **'• Be honest but constructive'**
  String get reviewTipHonest;

  /// No description provided for @errorPickingPhotos.
  ///
  /// In en, this message translates to:
  /// **'Error picking photos: {error}'**
  String errorPickingPhotos(String error);

  /// No description provided for @onlyRequestingCustomerCanReview.
  ///
  /// In en, this message translates to:
  /// **'Only the customer who requested this job can review'**
  String get onlyRequestingCustomerCanReview;

  /// No description provided for @reviewOnlyAfterCompleted.
  ///
  /// In en, this message translates to:
  /// **'You can only review after the job is completed'**
  String get reviewOnlyAfterCompleted;

  /// No description provided for @reviewAlreadySubmittedForJob.
  ///
  /// In en, this message translates to:
  /// **'You already submitted a review for this job'**
  String get reviewAlreadySubmittedForJob;

  /// No description provided for @reviewSubmittedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Review submitted successfully!'**
  String get reviewSubmittedSuccessfully;

  /// No description provided for @errorSubmittingReview.
  ///
  /// In en, this message translates to:
  /// **'Error submitting review: {error}'**
  String errorSubmittingReview(String error);

  /// No description provided for @smartRequestStepTitle.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String smartRequestStepTitle(int current, int total);

  /// No description provided for @smartRequestResumeTitle.
  ///
  /// In en, this message translates to:
  /// **'Resume saved request?'**
  String get smartRequestResumeTitle;

  /// No description provided for @smartRequestResumeBody.
  ///
  /// In en, this message translates to:
  /// **'We found a saved job request. Continue where you left off or start fresh.'**
  String get smartRequestResumeBody;

  /// No description provided for @smartRequestResumeBodyWithDate.
  ///
  /// In en, this message translates to:
  /// **'We found a saved job request from {time}. Continue where you left off or start fresh.'**
  String smartRequestResumeBodyWithDate(String time);

  /// No description provided for @smartRequestStartFresh.
  ///
  /// In en, this message translates to:
  /// **'Start fresh'**
  String get smartRequestStartFresh;

  /// No description provided for @smartRequestResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get smartRequestResume;

  /// No description provided for @smartRequestDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard request?'**
  String get smartRequestDiscardTitle;

  /// No description provided for @smartRequestLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave request?'**
  String get smartRequestLeaveTitle;

  /// No description provided for @smartRequestDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'Your progress is saved automatically. Leave now and resume this request later.'**
  String get smartRequestDiscardBody;

  /// No description provided for @smartRequestStay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get smartRequestStay;

  /// No description provided for @smartRequestDiscard.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get smartRequestDiscard;

  /// No description provided for @smartRequestClearDraft.
  ///
  /// In en, this message translates to:
  /// **'Clear saved draft'**
  String get smartRequestClearDraft;

  /// No description provided for @smartRequestDraftCleared.
  ///
  /// In en, this message translates to:
  /// **'Saved draft cleared'**
  String get smartRequestDraftCleared;

  /// No description provided for @smartRequestDraftAutosave.
  ///
  /// In en, this message translates to:
  /// **'Draft saves automatically as you build the request.'**
  String get smartRequestDraftAutosave;

  /// No description provided for @smartRequestDraftSavedAt.
  ///
  /// In en, this message translates to:
  /// **'Draft saved at {time}'**
  String smartRequestDraftSavedAt(String time);

  /// No description provided for @smartRequestPhotoRequired.
  ///
  /// In en, this message translates to:
  /// **'Please add at least one photo of the project area.'**
  String get smartRequestPhotoRequired;

  /// No description provided for @smartRequestNoPhotosTitle.
  ///
  /// In en, this message translates to:
  /// **'Continue without photos?'**
  String get smartRequestNoPhotosTitle;

  /// No description provided for @smartRequestNoPhotosBody.
  ///
  /// In en, this message translates to:
  /// **'Photos help contractors understand the scope and quote faster. You can still continue now and add details instead.'**
  String get smartRequestNoPhotosBody;

  /// No description provided for @smartRequestAddPhotos.
  ///
  /// In en, this message translates to:
  /// **'Add photos'**
  String get smartRequestAddPhotos;

  /// No description provided for @smartRequestContinueWithoutPhotos.
  ///
  /// In en, this message translates to:
  /// **'Continue without photos'**
  String get smartRequestContinueWithoutPhotos;

  /// No description provided for @smartRequestZipInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid 5-digit ZIP code.'**
  String get smartRequestZipInvalid;

  /// No description provided for @smartRequestServiceRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select a service type.'**
  String get smartRequestServiceRequired;

  /// No description provided for @smartRequestMissingTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a little more detail?'**
  String get smartRequestMissingTitle;

  /// No description provided for @smartRequestMissingBody.
  ///
  /// In en, this message translates to:
  /// **'Contractors can quote faster when these fields are filled in: {fields}.\n\nYou can still submit now, but this lead may need follow-up questions.'**
  String smartRequestMissingBody(String fields);

  /// No description provided for @smartRequestReviewDetails.
  ///
  /// In en, this message translates to:
  /// **'Review details'**
  String get smartRequestReviewDetails;

  /// No description provided for @smartRequestSubmitAnyway.
  ///
  /// In en, this message translates to:
  /// **'Submit anyway'**
  String get smartRequestSubmitAnyway;

  /// No description provided for @smartRequestAiUnavailable.
  ///
  /// In en, this message translates to:
  /// **'AI analysis unavailable. You can fill in details manually.'**
  String get smartRequestAiUnavailable;

  /// No description provided for @smartRequestSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit request: {error}'**
  String smartRequestSubmitFailed(String error);

  /// No description provided for @smartRequestSnapTitle.
  ///
  /// In en, this message translates to:
  /// **'Snap & Describe'**
  String get smartRequestSnapTitle;

  /// No description provided for @smartRequestSnapSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Take or upload photos and we\'ll help build the request.'**
  String get smartRequestSnapSubtitle;

  /// No description provided for @smartRequestPhotoTrustTitle.
  ///
  /// In en, this message translates to:
  /// **'Photos make quotes more accurate'**
  String get smartRequestPhotoTrustTitle;

  /// No description provided for @smartRequestPhotoTrustSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add the project area, close-up damage, and any access details so contractors can quote with fewer follow-up questions.'**
  String get smartRequestPhotoTrustSubtitle;

  /// No description provided for @smartRequestProjectPhotos.
  ///
  /// In en, this message translates to:
  /// **'Project Photos'**
  String get smartRequestProjectPhotos;

  /// No description provided for @smartRequestPhotoPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Take a photo or upload from gallery'**
  String get smartRequestPhotoPlaceholder;

  /// No description provided for @smartRequestCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get smartRequestCamera;

  /// No description provided for @smartRequestGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get smartRequestGallery;

  /// No description provided for @smartRequestAddMorePhotos.
  ///
  /// In en, this message translates to:
  /// **'Add More'**
  String get smartRequestAddMorePhotos;

  /// No description provided for @smartRequestZipHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your ZIP code'**
  String get smartRequestZipHint;

  /// No description provided for @smartRequestServiceType.
  ///
  /// In en, this message translates to:
  /// **'Service Type'**
  String get smartRequestServiceType;

  /// No description provided for @smartRequestServiceSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search service, trade, or project type'**
  String get smartRequestServiceSearchHint;

  /// No description provided for @smartRequestNoMatchingService.
  ///
  /// In en, this message translates to:
  /// **'No matching service yet. Try a broader trade like roofing, plumbing, cleaning, or handyman.'**
  String get smartRequestNoMatchingService;

  /// No description provided for @smartRequestChooseClosestService.
  ///
  /// In en, this message translates to:
  /// **'Choose the closest service. Instant-price services can show an AI price; all other services become quote requests sent to matching pros.'**
  String get smartRequestChooseClosestService;

  /// No description provided for @smartRequestInstantPriceChip.
  ///
  /// In en, this message translates to:
  /// **'Instant price + pro matching'**
  String get smartRequestInstantPriceChip;

  /// No description provided for @smartRequestServiceSpecificQuoteChip.
  ///
  /// In en, this message translates to:
  /// **'Service-specific quote request'**
  String get smartRequestServiceSpecificQuoteChip;

  /// No description provided for @smartRequestManualQuoteChip.
  ///
  /// In en, this message translates to:
  /// **'Manual quote request'**
  String get smartRequestManualQuoteChip;

  /// No description provided for @smartRequestInstantPriceSupported.
  ///
  /// In en, this message translates to:
  /// **'Instant price supported. We will still collect photos and details for better contractor matching.'**
  String get smartRequestInstantPriceSupported;

  /// No description provided for @smartRequestNeedsProReview.
  ///
  /// In en, this message translates to:
  /// **'This service needs pro review before pricing.'**
  String get smartRequestNeedsProReview;

  /// No description provided for @smartRequestManualQuoteSupported.
  ///
  /// In en, this message translates to:
  /// **'{reason} We will send this as a quote request to matching pros.'**
  String smartRequestManualQuoteSupported(String reason);

  /// No description provided for @smartRequestHelpfulPhotosTitle.
  ///
  /// In en, this message translates to:
  /// **'Helpful photos'**
  String get smartRequestHelpfulPhotosTitle;

  /// No description provided for @smartRequestContinueToDetails.
  ///
  /// In en, this message translates to:
  /// **'Continue to details'**
  String get smartRequestContinueToDetails;

  /// No description provided for @smartRequestAnalyzeWithAi.
  ///
  /// In en, this message translates to:
  /// **'Analyze with AI'**
  String get smartRequestAnalyzeWithAi;

  /// No description provided for @smartRequestAiAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'AI is analyzing your photos...'**
  String get smartRequestAiAnalyzing;

  /// No description provided for @smartRequestAiAnalyzingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Estimating size, condition, and pricing'**
  String get smartRequestAiAnalyzingSubtitle;

  /// No description provided for @smartRequestAiDetectedDetails.
  ///
  /// In en, this message translates to:
  /// **'AI-Detected Details'**
  String get smartRequestAiDetectedDetails;

  /// No description provided for @smartRequestReviewAdjust.
  ///
  /// In en, this message translates to:
  /// **'Review and adjust the details below.'**
  String get smartRequestReviewAdjust;

  /// No description provided for @smartRequestDetailsChecklistInstant.
  ///
  /// In en, this message translates to:
  /// **'Review these details before pricing or sending to pros.'**
  String get smartRequestDetailsChecklistInstant;

  /// No description provided for @smartRequestDetailsChecklistManual.
  ///
  /// In en, this message translates to:
  /// **'This request will go to qualified pros for manual quotes. Clear answers help prevent callbacks and low-quality bids.'**
  String get smartRequestDetailsChecklistManual;

  /// No description provided for @smartRequestAiConfidence.
  ///
  /// In en, this message translates to:
  /// **'AI Confidence: {percent}%'**
  String smartRequestAiConfidence(String percent);

  /// No description provided for @smartRequestEstimatedSize.
  ///
  /// In en, this message translates to:
  /// **'Estimated Size (sqft)'**
  String get smartRequestEstimatedSize;

  /// No description provided for @smartRequestPropertyType.
  ///
  /// In en, this message translates to:
  /// **'Property Type'**
  String get smartRequestPropertyType;

  /// No description provided for @smartRequestHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get smartRequestHome;

  /// No description provided for @smartRequestBusiness.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get smartRequestBusiness;

  /// No description provided for @smartRequestSurfaceCondition.
  ///
  /// In en, this message translates to:
  /// **'Surface Condition'**
  String get smartRequestSurfaceCondition;

  /// No description provided for @smartRequestProjectCondition.
  ///
  /// In en, this message translates to:
  /// **'Project condition'**
  String get smartRequestProjectCondition;

  /// No description provided for @smartRequestExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get smartRequestExcellent;

  /// No description provided for @smartRequestFair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get smartRequestFair;

  /// No description provided for @smartRequestPoor.
  ///
  /// In en, this message translates to:
  /// **'Poor'**
  String get smartRequestPoor;

  /// No description provided for @smartRequestAiNotes.
  ///
  /// In en, this message translates to:
  /// **'AI Notes'**
  String get smartRequestAiNotes;

  /// No description provided for @smartRequestContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get smartRequestContinue;

  /// No description provided for @smartRequestTimelineBudget.
  ///
  /// In en, this message translates to:
  /// **'Timeline & Budget'**
  String get smartRequestTimelineBudget;

  /// No description provided for @smartRequestTimelineQuestion.
  ///
  /// In en, this message translates to:
  /// **'When do you need the work done?'**
  String get smartRequestTimelineQuestion;

  /// No description provided for @smartRequestTimelineStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get smartRequestTimelineStandard;

  /// No description provided for @smartRequestTimelineStandardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Within 1-2 weeks'**
  String get smartRequestTimelineStandardSubtitle;

  /// No description provided for @smartRequestTimelineAsap.
  ///
  /// In en, this message translates to:
  /// **'ASAP'**
  String get smartRequestTimelineAsap;

  /// No description provided for @smartRequestTimelineAsapSubtitle.
  ///
  /// In en, this message translates to:
  /// **'As soon as possible (+15% urgency premium)'**
  String get smartRequestTimelineAsapSubtitle;

  /// No description provided for @smartRequestTimelineFlexible.
  ///
  /// In en, this message translates to:
  /// **'Flexible'**
  String get smartRequestTimelineFlexible;

  /// No description provided for @smartRequestTimelineFlexibleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'No rush. I\'m flexible on timing'**
  String get smartRequestTimelineFlexibleSubtitle;

  /// No description provided for @smartRequestBudgetPreference.
  ///
  /// In en, this message translates to:
  /// **'Budget Preference'**
  String get smartRequestBudgetPreference;

  /// No description provided for @smartRequestBudgetFriendly.
  ///
  /// In en, this message translates to:
  /// **'Budget-Friendly'**
  String get smartRequestBudgetFriendly;

  /// No description provided for @smartRequestBudgetFriendlySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Lower end of market pricing'**
  String get smartRequestBudgetFriendlySubtitle;

  /// No description provided for @smartRequestBudgetRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get smartRequestBudgetRecommended;

  /// No description provided for @smartRequestBudgetRecommendedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fair market price for quality work'**
  String get smartRequestBudgetRecommendedSubtitle;

  /// No description provided for @smartRequestBudgetPremium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get smartRequestBudgetPremium;

  /// No description provided for @smartRequestBudgetPremiumSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Top-tier materials and craftsmanship'**
  String get smartRequestBudgetPremiumSubtitle;

  /// No description provided for @smartRequestReviewSubmit.
  ///
  /// In en, this message translates to:
  /// **'Review & Submit'**
  String get smartRequestReviewSubmit;

  /// No description provided for @smartRequestConfirmDetails.
  ///
  /// In en, this message translates to:
  /// **'Confirm your details and submit.'**
  String get smartRequestConfirmDetails;

  /// No description provided for @smartRequestPricingPathTitle.
  ///
  /// In en, this message translates to:
  /// **'Pricing path'**
  String get smartRequestPricingPathTitle;

  /// No description provided for @smartRequestManualQuotePathTitle.
  ///
  /// In en, this message translates to:
  /// **'Manual quote path'**
  String get smartRequestManualQuotePathTitle;

  /// No description provided for @smartRequestPricingPathSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This service can show an instant AI price, then you can invite pros or continue with quotes.'**
  String get smartRequestPricingPathSubtitle;

  /// No description provided for @smartRequestManualQuotePathSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pros will review your details, photos, and service checklist before sending quotes.'**
  String get smartRequestManualQuotePathSubtitle;

  /// No description provided for @smartRequestLeadDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Lead details for pros'**
  String get smartRequestLeadDetailsTitle;

  /// No description provided for @smartRequestLeadDetailsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add a few service details to help contractors quote with fewer follow-up questions.'**
  String get smartRequestLeadDetailsEmpty;

  /// No description provided for @smartRequestLeadDetailsFilled.
  ///
  /// In en, this message translates to:
  /// **'These structured details will be shown to matching contractors.'**
  String get smartRequestLeadDetailsFilled;

  /// No description provided for @smartRequestMissingHelpfulDetails.
  ///
  /// In en, this message translates to:
  /// **'Missing helpful details: {fields}'**
  String smartRequestMissingHelpfulDetails(String fields);

  /// No description provided for @smartRequestSummarySize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get smartRequestSummarySize;

  /// No description provided for @smartRequestSummarySizeNotProvided.
  ///
  /// In en, this message translates to:
  /// **'Not provided'**
  String get smartRequestSummarySizeNotProvided;

  /// No description provided for @smartRequestSummaryProperty.
  ///
  /// In en, this message translates to:
  /// **'Property'**
  String get smartRequestSummaryProperty;

  /// No description provided for @smartRequestSummaryCondition.
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get smartRequestSummaryCondition;

  /// No description provided for @smartRequestSummaryBudget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get smartRequestSummaryBudget;

  /// No description provided for @smartRequestSummaryPhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get smartRequestSummaryPhotos;

  /// No description provided for @smartRequestContactInformation.
  ///
  /// In en, this message translates to:
  /// **'Contact Information'**
  String get smartRequestContactInformation;

  /// No description provided for @smartRequestAdditionalNotesOptional.
  ///
  /// In en, this message translates to:
  /// **'Additional Notes (optional)'**
  String get smartRequestAdditionalNotesOptional;

  /// No description provided for @smartRequestSubmitRequest.
  ///
  /// In en, this message translates to:
  /// **'Submit Request'**
  String get smartRequestSubmitRequest;

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

  /// No description provided for @recommendedProsMissingZip.
  ///
  /// In en, this message translates to:
  /// **'No contractors found yet because the ZIP code is missing or unsupported.'**
  String get recommendedProsMissingZip;

  /// No description provided for @recommendedProsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No recommended pros are available for this project yet. Try expanding the service area or check back soon.'**
  String get recommendedProsEmpty;

  /// No description provided for @recommendedProsFallbackIntro.
  ///
  /// In en, this message translates to:
  /// **'Nearby pros who may fit this project.'**
  String get recommendedProsFallbackIntro;

  /// No description provided for @recommendedProsInviteSent.
  ///
  /// In en, this message translates to:
  /// **'Invite sent.'**
  String get recommendedProsInviteSent;

  /// No description provided for @recommendedProsRequestLiveTitle.
  ///
  /// In en, this message translates to:
  /// **'{service} request is live'**
  String recommendedProsRequestLiveTitle(String service);

  /// No description provided for @recommendedProsInvitedStatus.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 pro invited. Quotes will appear in Projects.} other{{count} pros invited. Quotes will appear in Projects.}}'**
  String recommendedProsInvitedStatus(int count);

  /// No description provided for @recommendedProsRequestLiveBody.
  ///
  /// In en, this message translates to:
  /// **'Pros can now review your details. Invite trusted pros or wait for quotes to appear in Projects.'**
  String get recommendedProsRequestLiveBody;

  /// No description provided for @topRecommendedPros.
  ///
  /// In en, this message translates to:
  /// **'Top Recommended Pros'**
  String get topRecommendedPros;

  /// No description provided for @completeAction.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get completeAction;

  /// No description provided for @sortLabel.
  ///
  /// In en, this message translates to:
  /// **'Sort:'**
  String get sortLabel;

  /// No description provided for @recommendedProsSortBestMatch.
  ///
  /// In en, this message translates to:
  /// **'Best Match'**
  String get recommendedProsSortBestMatch;

  /// No description provided for @recommendedProsSortClosest.
  ///
  /// In en, this message translates to:
  /// **'Closest'**
  String get recommendedProsSortClosest;

  /// No description provided for @recommendedProsSortHighestRated.
  ///
  /// In en, this message translates to:
  /// **'Highest Rated'**
  String get recommendedProsSortHighestRated;

  /// No description provided for @recommendedProsSortFastestResponse.
  ///
  /// In en, this message translates to:
  /// **'Fastest Response'**
  String get recommendedProsSortFastestResponse;

  /// No description provided for @recommendedProsFast.
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get recommendedProsFast;

  /// No description provided for @recommendedProsMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get recommendedProsMedium;

  /// No description provided for @recommendedProsSlow.
  ///
  /// In en, this message translates to:
  /// **'Slow'**
  String get recommendedProsSlow;

  /// No description provided for @recommendedProsInvited.
  ///
  /// In en, this message translates to:
  /// **'Invited'**
  String get recommendedProsInvited;

  /// No description provided for @recommendedProsInviting.
  ///
  /// In en, this message translates to:
  /// **'Inviting...'**
  String get recommendedProsInviting;

  /// No description provided for @recommendedProsStrongFit.
  ///
  /// In en, this message translates to:
  /// **'Strong project fit'**
  String get recommendedProsStrongFit;

  /// No description provided for @recommendedProsGoodFit.
  ///
  /// In en, this message translates to:
  /// **'Good project fit'**
  String get recommendedProsGoodFit;

  /// No description provided for @recommendedProsReviewProfile.
  ///
  /// In en, this message translates to:
  /// **'Review profile details'**
  String get recommendedProsReviewProfile;

  /// No description provided for @inviteToBid.
  ///
  /// In en, this message translates to:
  /// **'Invite to Bid'**
  String get inviteToBid;

  /// No description provided for @viewProfile.
  ///
  /// In en, this message translates to:
  /// **'View Profile'**
  String get viewProfile;

  /// No description provided for @projectStatusPaidMatching.
  ///
  /// In en, this message translates to:
  /// **'Paid - Matching Contractor'**
  String get projectStatusPaidMatching;

  /// No description provided for @projectStatusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get projectStatusInProgress;

  /// No description provided for @projectStatusCompletionRequested.
  ///
  /// In en, this message translates to:
  /// **'Completion Requested'**
  String get projectStatusCompletionRequested;

  /// No description provided for @projectStatusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get projectStatusApproved;

  /// No description provided for @projectStatusContractorName.
  ///
  /// In en, this message translates to:
  /// **'Contractor: {name}'**
  String projectStatusContractorName(String name);

  /// No description provided for @projectStatusContractorAssigned.
  ///
  /// In en, this message translates to:
  /// **'Contractor Assigned'**
  String get projectStatusContractorAssigned;

  /// No description provided for @projectStatusAssignedName.
  ///
  /// In en, this message translates to:
  /// **'Assigned: {name}'**
  String projectStatusAssignedName(String name);

  /// No description provided for @projectStatusAssigned.
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get projectStatusAssigned;

  /// No description provided for @projectStatusPriceOffered.
  ///
  /// In en, this message translates to:
  /// **'Price Offered'**
  String get projectStatusPriceOffered;

  /// No description provided for @regionWaitlistBadge.
  ///
  /// In en, this message translates to:
  /// **'{region} launch market'**
  String regionWaitlistBadge(String region);

  /// No description provided for @regionWaitlistTitle.
  ///
  /// In en, this message translates to:
  /// **'ProServe Hub is launching in Houston first.'**
  String get regionWaitlistTitle;

  /// No description provided for @regionWaitlistBody.
  ///
  /// In en, this message translates to:
  /// **'Your account is saved. We’ll notify you when we open in your area, and you can update your ZIP if this was a mistake.'**
  String get regionWaitlistBody;

  /// No description provided for @regionWaitlistRole.
  ///
  /// In en, this message translates to:
  /// **'Account type'**
  String get regionWaitlistRole;

  /// No description provided for @regionWaitlistRoleFallback.
  ///
  /// In en, this message translates to:
  /// **'Saved account'**
  String get regionWaitlistRoleFallback;

  /// No description provided for @regionWaitlistZip.
  ///
  /// In en, this message translates to:
  /// **'ZIP code'**
  String get regionWaitlistZip;

  /// No description provided for @regionWaitlistMissingZip.
  ///
  /// In en, this message translates to:
  /// **'Not set yet'**
  String get regionWaitlistMissingZip;

  /// No description provided for @regionWaitlistService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get regionWaitlistService;

  /// No description provided for @regionWaitlistServiceFallback.
  ///
  /// In en, this message translates to:
  /// **'Not selected yet'**
  String get regionWaitlistServiceFallback;

  /// No description provided for @regionWaitlistUpdateTitle.
  ///
  /// In en, this message translates to:
  /// **'Wrong ZIP?'**
  String get regionWaitlistUpdateTitle;

  /// No description provided for @regionWaitlistUpdateBody.
  ///
  /// In en, this message translates to:
  /// **'Enter a Houston-area ZIP to unlock the app now. Outside Houston, your account stays on the waitlist.'**
  String get regionWaitlistUpdateBody;

  /// No description provided for @regionWaitlistZipField.
  ///
  /// In en, this message translates to:
  /// **'ZIP code'**
  String get regionWaitlistZipField;

  /// No description provided for @regionWaitlistUpdateCta.
  ///
  /// In en, this message translates to:
  /// **'Update ZIP'**
  String get regionWaitlistUpdateCta;

  /// No description provided for @regionWaitlistSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get regionWaitlistSignOut;

  /// No description provided for @regionWaitlistInvalidZip.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 5-digit ZIP code.'**
  String get regionWaitlistInvalidZip;

  /// No description provided for @regionWaitlistSaved.
  ///
  /// In en, this message translates to:
  /// **'You’re still on the waitlist for this ZIP.'**
  String get regionWaitlistSaved;

  /// No description provided for @regionWaitlistUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Houston ZIP confirmed. App access unlocked.'**
  String get regionWaitlistUnlocked;

  /// No description provided for @regionWaitlistSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not update your ZIP right now. Please try again.'**
  String get regionWaitlistSaveFailed;

  /// No description provided for @regionWaitlistRequestBlocked.
  ///
  /// In en, this message translates to:
  /// **'ProServe Hub is launching in Houston first. Your account was saved to the waitlist.'**
  String get regionWaitlistRequestBlocked;

  /// No description provided for @deleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get deleted;

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
