// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'ProServe Hub';

  @override
  String get selectService => 'Sélectionner un Service';

  @override
  String get browseContractors => 'Parcourir les Entrepreneurs';

  @override
  String get savedContractors => 'Entrepreneurs Enregistrés';

  @override
  String get instantBook => 'Réservation Instantanée';

  @override
  String get viewAvailability => 'Voir la Disponibilité';

  @override
  String get requestJob => 'Demander un Travail';

  @override
  String get cancelJob => 'Annuler le Travail';

  @override
  String get referralPromo => 'Parrainage et Promos';

  @override
  String get bookingConfirmed => 'Réservation Confirmée';

  @override
  String get noErrors => 'Aucune erreur enregistrée.';

  @override
  String get quickActions => 'Actions rapides';

  @override
  String get startRequest => 'Démarrer une demande';

  @override
  String get browsePros => 'Parcourir les pros';

  @override
  String get messages => 'Messages';

  @override
  String get projectTracker => 'Suivi de projet';

  @override
  String get savedPros => 'Pros enregistrés';

  @override
  String get referral => 'Parrainage';

  @override
  String welcome(String name) {
    return 'Bienvenue, $name';
  }

  @override
  String get notifications => 'Notifications';

  @override
  String get settings => 'Paramètres';

  @override
  String get language => 'Langue';

  @override
  String get signOut => 'Déconnexion';

  @override
  String get signIn => 'Connexion';

  @override
  String get profile => 'Profil';

  @override
  String get home => 'Accueil';

  @override
  String get search => 'Rechercher';

  @override
  String get project => 'Projet';

  @override
  String get community => 'Communauté';

  @override
  String get tools => 'Outils';

  @override
  String get jobs => 'Emplois';

  @override
  String get plan => 'Plan';

  @override
  String get renderTool => 'Outil de Rendu';

  @override
  String get compare => 'Comparer';

  @override
  String get exitCompare => 'Quitter la comparaison';

  @override
  String get before => 'AVANT';

  @override
  String get after => 'APRÈS';

  @override
  String get myEstimates => 'Mes Estimations';

  @override
  String get noEstimatesYet => 'Aucune estimation pour le moment';

  @override
  String get getAiEstimate => 'Obtenir une Estimation IA';

  @override
  String get postAsJobRequest => 'Publier comme Demande';

  @override
  String get deleteEstimate => 'Supprimer l\'Estimation';

  @override
  String get receiptsExpenses => 'Reçus et Dépenses';

  @override
  String get exportCsv => 'Exporter CSV';

  @override
  String get exportPdf => 'Exporter PDF';

  @override
  String get noReceiptsYet => 'Aucun reçu pour le moment.';

  @override
  String get availabilityCalendar => 'Calendrier de Disponibilité';

  @override
  String get allDayAvailable => 'Disponible Toute la Journée';

  @override
  String get allDayUnavailable => 'Indisponible Toute la Journée';

  @override
  String get aiEstimator => 'Estimateur IA';

  @override
  String get startNewRequest => 'Nouvelle Demande';

  @override
  String get activity => 'Activité';

  @override
  String get noNotificationsYet => 'Aucune notification';

  @override
  String get chooseNotifications =>
      'Choisissez les notifications que vous souhaitez recevoir.';

  @override
  String get referralDashboard => 'Tableau de Parrainage';

  @override
  String get totalReferrals => 'Total des Parrainages';

  @override
  String get creditsEarned => 'Crédits Gagnés';

  @override
  String get yourReferralCode => 'Votre Code de Parrainage';

  @override
  String get interiorPainting => 'Peinture Intérieure';

  @override
  String get cabinetPainting => 'Peinture d\'Armoires';

  @override
  String get drywallRepair => 'Réparation de Cloison Sèche';

  @override
  String get pressureWashing => 'Lavage à Pression';

  @override
  String get exteriorPainting => 'Peinture Extérieure';

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
