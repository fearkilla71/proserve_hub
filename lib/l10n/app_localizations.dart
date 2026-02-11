import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';

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
    Locale('fr'),
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
      <String>['en', 'es', 'fr'].contains(locale.languageCode);

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
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
