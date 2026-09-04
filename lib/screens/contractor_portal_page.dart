import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/intl.dart';

import 'contractor_login_page.dart';
import 'community_feed_screen.dart';
import 'job_feed_page.dart';

import '../l10n/app_localizations.dart';
import '../constants/release_flags.dart';
import '../services/lead_iap_service.dart';
import '../services/fcm_service.dart';
import '../services/escrow_service.dart';
import '../services/stripe_service.dart';
import '../widgets/animated_states.dart';
import '../widgets/page_header.dart';
import '../theme/proserve_theme.dart';
import '../widgets/profile_completion_card.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/persistent_job_state_bar.dart';
import '../widgets/contractor_portal_helpers.dart';
import '../widgets/contractor_tools_hub.dart';
import '../widgets/tools_quick_actions_sheet.dart';
import '../widgets/contractor_account_summary_card.dart';
import '../widgets/lead_pack_purchase_sheet.dart';
import '../widgets/proserve_refined_ui.dart';
import '../models/escrow_booking.dart';
import 'onboarding_screen.dart';

class ContractorPortalPage extends StatefulWidget {
  const ContractorPortalPage({super.key});

  @override
  State<ContractorPortalPage> createState() => _ContractorPortalPageState();
}

class _ContractorPortalPageState extends State<ContractorPortalPage> {
  int _tabIndex = 0;

  // Streams created once so nested StreamBuilder rebuilds don't recreate them.
  Stream<QuerySnapshot>? _claimedStream;
  Stream<QuerySnapshot>? _paidStream;

  @override
  void initState() {
    super.initState();
    _initJobStreams();
    // Show role-specific onboarding the first time a contractor opens the portal.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) OnboardingScreen.showIfNeeded(context, 'contractor');
    });
  }

  void _initJobStreams() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _claimedStream = FirebaseFirestore.instance
        .collection('job_requests')
        .where('claimedBy', isEqualTo: user.uid)
        .snapshots();
    _paidStream = FirebaseFirestore.instance
        .collection('job_requests')
        .where('paidBy', arrayContains: user.uid)
        .snapshots();
  }

  Future<void> _openPricingToolsOrSubscribe({
    required Future<void> Function() open,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    bool unlocked = false;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.serverAndCache));
      unlocked = pricingToolsUnlockedFromUserDoc(snap.data());
    } catch (e) {
      debugPrint('Pricing tools unlock check failed: $e');
    }

    if (unlocked) {
      await open();
      return;
    }

    if (!mounted) return;
    final shouldSubscribe = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.contractorPortalProRequiredTitle,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.contractorPortalProRequiredBody,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(l10n.notNow),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(l10n.subscribe),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shouldSubscribe == true && mounted) {
      context.push('/contractor-subscription');
    }
  }

  Future<void> _openEnterpriseToolOrSubscribe({
    required Future<void> Function() open,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    bool unlocked = false;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.serverAndCache));
      unlocked = isEnterpriseFromUserDoc(snap.data());
    } catch (e) {
      debugPrint('Enterprise tool unlock check failed: $e');
    }

    if (unlocked) {
      await open();
      return;
    }

    if (!mounted) return;
    final shouldSubscribe = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.contractorPortalEnterpriseRequiredTitle,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.contractorPortalEnterpriseToolsBody,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(l10n.notNow),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(l10n.upgrade),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shouldSubscribe == true && mounted) {
      context.push('/contractor-subscription');
    }
  }

  Future<void> _showToolsQuickActions(BuildContext context) async {
    await showToolsQuickActions(
      sheetContext: context,
      parentContext: this.context,
      openProToolOrSubscribe: _openPricingToolsOrSubscribe,
      openEnterpriseToolOrSubscribe: _openEnterpriseToolOrSubscribe,
    );
  }

  Future<void> _buyLeadCredits() async {
    final chosen = await showLeadPackPurchaseSheet(context);
    if (chosen == null || chosen.trim().isEmpty) return;

    if (LeadIapService.supported && LeadIapService.isIapPack(chosen)) {
      try {
        final iap = LeadIapService.instance;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Opening store...'),
              duration: Duration(seconds: 2),
            ),
          );
        }

        void handleUpdate(PurchaseDetails purchase) {
          if (!mounted) return;
          if (purchase.status == PurchaseStatus.purchased ||
              purchase.status == PurchaseStatus.restored) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Lead credits added!')),
            );
            iap.onPurchaseUpdate = null;
          } else if (purchase.status == PurchaseStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(purchase.error?.message ?? 'Purchase failed'),
              ),
            );
            iap.onPurchaseUpdate = null;
          } else if (purchase.status == PurchaseStatus.canceled) {
            iap.onPurchaseUpdate = null;
          }
        }

        iap.onPurchaseUpdate = handleUpdate;
        await iap.buy(chosen);
      } catch (e) {
        if (!mounted) return;
        final message = e.toString().replaceFirst('Exception: ', '').trim();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
      return;
    }

    try {
      await StripeService().buyLeadPack(packId: chosen);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete checkout to add lead credits.')),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '').trim();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String _homeToolsSubtitle(AppLocalizations l10n, String tier) {
    final publicTier = tier == 'enterprise' && !kShowEnterprisePublicSurfaces
        ? 'pro'
        : tier;
    return switch (publicTier) {
      'enterprise' => l10n.contractorHomeToolsEnterpriseSubtitle,
      'pro' => l10n.contractorHomeToolsProSubtitle,
      _ => l10n.contractorHomeToolsBasicSubtitle,
    };
  }

  List<_DashboardTool> _homeToolsForTier(
    BuildContext context,
    AppLocalizations l10n,
    String tier,
  ) {
    final publicTier = tier == 'enterprise' && !kShowEnterprisePublicSurfaces
        ? 'pro'
        : tier;

    if (publicTier == 'enterprise') {
      return [
        _DashboardTool(
          label: l10n.contractorHomeToolProfitLoss,
          icon: Icons.insights_outlined,
          color: ProServeColors.accent,
          onTap: () => _openEnterpriseToolOrSubscribe(
            open: () async => context.push('/pnl-dashboard'),
          ),
        ),
        _DashboardTool(
          label: l10n.contractorHomeToolCrewRoster,
          icon: Icons.groups_2_outlined,
          color: ProServeColors.accent,
          onTap: () => _openEnterpriseToolOrSubscribe(
            open: () async => context.push('/crew-roster'),
          ),
        ),
        _DashboardTool(
          label: l10n.contractorHomeToolBidAnalyzer,
          icon: Icons.analytics_outlined,
          color: ProServeColors.accent,
          onTap: () => _openEnterpriseToolOrSubscribe(
            open: () async => context.push('/bid-analyzer'),
          ),
        ),
        _DashboardTool(
          label: l10n.toolQuoteTemplatesTitle,
          icon: Icons.article_outlined,
          color: ProServeColors.accent2,
          onTap: () => _openPricingToolsOrSubscribe(
            open: () async => context.push('/quote-templates'),
          ),
        ),
        _DashboardTool(
          label: l10n.invoice,
          icon: Icons.receipt_long_outlined,
          color: ProServeColors.accent2,
          onTap: () => _openPricingToolsOrSubscribe(
            open: () async => context.push('/invoice-maker'),
          ),
        ),
        _DashboardTool(
          label: l10n.contractorHomeToolSmartSchedule,
          icon: Icons.event_available_outlined,
          color: ProServeColors.accent,
          onTap: () => _openEnterpriseToolOrSubscribe(
            open: () async => context.push('/smart-scheduling'),
          ),
        ),
      ];
    }

    if (publicTier == 'pro') {
      return [
        _DashboardTool(
          label: l10n.contractorHomeToolBrowseLeads,
          icon: Icons.local_activity_outlined,
          color: ProServeColors.accent,
          onTap: () => setState(() => _tabIndex = 1),
        ),
        _DashboardTool(
          label: l10n.contractorHomeToolPricing,
          icon: Icons.request_quote_outlined,
          color: ProServeColors.accent2,
          onTap: () => _openPricingToolsOrSubscribe(
            open: () async => context.push('/pricing-calculator'),
          ),
        ),
        _DashboardTool(
          label: l10n.invoice,
          icon: Icons.receipt_long_outlined,
          color: ProServeColors.accent2,
          onTap: () => _openPricingToolsOrSubscribe(
            open: () async => context.push('/invoice-maker'),
          ),
        ),
        _DashboardTool(
          label: l10n.contractorHomeToolEstimator,
          icon: Icons.calculate_outlined,
          color: ProServeColors.accent2,
          onTap: () => _openPricingToolsOrSubscribe(
            open: () async => context.push('/cost-estimator/painting'),
          ),
        ),
        _DashboardTool(
          label: l10n.contractorHomeToolSavedEstimates,
          icon: Icons.folder_copy_outlined,
          color: ProServeColors.accent,
          onTap: () => _openPricingToolsOrSubscribe(
            open: () async => context.push('/saved-estimates'),
          ),
        ),
        _DashboardTool(
          label: l10n.toolQuoteTemplatesTitle,
          icon: Icons.article_outlined,
          color: ProServeColors.accent2,
          onTap: () => _openPricingToolsOrSubscribe(
            open: () async => context.push('/quote-templates'),
          ),
        ),
      ];
    }

    return [
      _DashboardTool(
        label: l10n.contractorHomeToolBrowseLeads,
        icon: Icons.local_activity_outlined,
        color: ProServeColors.accent2,
        onTap: () => setState(() => _tabIndex = 1),
      ),
      _DashboardTool(
        label: l10n.contractorHomeToolSubmitQuote,
        icon: Icons.description_outlined,
        color: ProServeColors.accent2,
        onTap: () => setState(() => _tabIndex = 1),
      ),
      _DashboardTool(
        label: l10n.contractorHomeToolBuyCredits,
        icon: Icons.confirmation_number_outlined,
        color: ProServeColors.accent,
        onTap: _buyLeadCredits,
      ),
      _DashboardTool(
        label: l10n.contractorHomeToolBrowseLeads,
        icon: Icons.work_outline,
        color: ProServeColors.accent2,
        onTap: () => setState(() => _tabIndex = 1),
      ),
      _DashboardTool(
        label: l10n.contractorHomeToolVerify,
        icon: Icons.verified_user_outlined,
        color: ProServeColors.warning,
        onTap: () => context.push('/contractor-profile-settings'),
      ),
      _DashboardTool(
        label: l10n.contractorHomeToolUpgradePro,
        icon: Icons.workspace_premium_outlined,
        color: ProServeColors.accent,
        onTap: () => context.push('/contractor-subscription'),
      ),
    ];
  }

  Widget _tabScaffold({required Widget child, Widget? fab}) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: child),
            const PersistentJobStateBar(role: JobBarRole.contractor),
          ],
        ),
      ),
      floatingActionButton: fab == null
          ? null
          : Padding(padding: const EdgeInsets.only(bottom: 8), child: fab),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.home,
          ),
          NavigationDestination(
            icon: const Icon(Icons.local_activity_outlined),
            selectedIcon: const Icon(Icons.local_activity),
            label: l10n.jobs,
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long),
            label: l10n.plan,
          ),
          NavigationDestination(
            icon: const Icon(Icons.build_outlined),
            selectedIcon: const Icon(Icons.build),
            label: l10n.tools,
          ),
          NavigationDestination(
            icon: const Icon(Icons.forum_outlined),
            selectedIcon: const Icon(Icons.forum),
            label: l10n.community,
          ),
        ],
      ),
    );
  }

  Widget _buildLeadFirstPanel(Map<String, dynamic>? userData) {
    final scheme = Theme.of(context).colorScheme;
    final leadCreditsRaw = userData?['leadCredits'] ?? userData?['credits'];
    final leadCredits = leadCreditsRaw is num ? leadCreditsRaw.toInt() : 0;
    final exclusiveRaw = userData?['exclusiveLeadCredits'];
    final exclusiveCredits = exclusiveRaw is num ? exclusiveRaw.toInt() : 0;
    final payoutReady =
        userData?['stripePayoutsEnabled'] == true ||
        userData?['payoutsEnabled'] == true;
    final payoutPending = userData?['stripeDetailsSubmitted'] == true;
    final payoutLabel = payoutReady
        ? 'Payouts ready'
        : (payoutPending ? 'Payouts pending' : 'Connect payouts');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: ProServeColors.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ProServeColors.lineStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ProServeColors.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.local_activity_outlined,
                  color: ProServeColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lead marketplace',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Browse matched projects, unlock contact, then send a quote.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ProfessionalStatusChip(
                icon: Icons.confirmation_number_outlined,
                label: '$leadCredits shared credits',
                color: ProServeColors.accent,
              ),
              _ProfessionalStatusChip(
                icon: Icons.lock_outline,
                label: '$exclusiveCredits exclusive',
                color: ProServeColors.accent2,
              ),
              _ProfessionalStatusChip(
                icon: payoutReady
                    ? Icons.verified_user_outlined
                    : Icons.account_balance_wallet_outlined,
                label: payoutLabel,
                color: payoutReady
                    ? ProServeColors.accent
                    : ProServeColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => setState(() => _tabIndex = 1),
                  icon: const Icon(Icons.search),
                  label: const Text('Browse leads'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _buyLeadCredits,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Buy credits'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayMetrics(
    BuildContext context,
    Map<String, dynamic>? userData,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final payoutReady =
        userData?['stripePayoutsEnabled'] == true ||
        userData?['payoutsEnabled'] == true;
    final payoutPending = userData?['stripeDetailsSubmitted'] == true;
    final payoutAmount = _moneyFrom(
      userData?['nextPayoutAmount'] ??
          userData?['pendingPayoutAmount'] ??
          userData?['availablePayoutAmount'],
    );
    final payoutValue = payoutAmount > 0
        ? NumberFormat.currency(
            symbol: '\$',
            decimalDigits: 0,
          ).format(payoutAmount)
        : (payoutReady
              ? l10n.contractorHomePayoutReady
              : (payoutPending
                    ? l10n.contractorHomePayoutPending
                    : l10n.contractorHomePayoutSetup));
    final payoutSubtitle = payoutReady
        ? l10n.contractorHomeNextPayout
        : (payoutPending
              ? l10n.contractorHomePayoutUnderReview
              : l10n.payoutsNotConnected);

    final verified =
        userData?['verified'] == true ||
        userData?['isVerified'] == true ||
        (userData?['verificationStatus'] as String?)?.toLowerCase() ==
            'verified';

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _jobsMetricCard(context)),
            const SizedBox(width: 10),
            Expanded(
              child: _DashboardMetricCard(
                title: l10n.contractorHomePayouts,
                subtitle: payoutSubtitle,
                value: payoutValue,
                icon: Icons.attach_money_rounded,
                accent: ProServeColors.accent2,
                onTap: () => context.push('/payment-history'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _DashboardStatusCard(
          title: verified ? l10n.verifiedPro : l10n.contractorHomeVerifyTitle,
          subtitle: verified
              ? l10n.contractorHomeAccountAllGood
              : l10n.contractorHomeVerifySubtitle,
          icon: verified ? Icons.verified_user_outlined : Icons.policy_outlined,
          accent: verified ? ProServeColors.accent : ProServeColors.warning,
          trailingIcon: verified ? Icons.check_rounded : Icons.arrow_forward,
          onTap: () => context.push('/verification'),
        ),
      ],
    );
  }

  Widget _jobsMetricCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_claimedStream == null || _paidStream == null) {
      return _DashboardMetricCard(
        title: l10n.jobs,
        subtitle: l10n.contractorPortalFindNewLeads,
        value: '0',
        icon: Icons.assignment_outlined,
        accent: ProServeColors.accent2,
        onTap: () => context.push('/job-feed'),
      );
    }

    return StreamBuilder<List<QueryDocumentSnapshot>>(
      stream: _combinedJobStream(_claimedStream!, _paidStream!),
      builder: (context, snap) {
        final count = snap.data?.length ?? 0;
        return _DashboardMetricCard(
          title: l10n.jobs,
          subtitle: l10n.contractorHomeNewLeads,
          value: l10n.contractorHomeActiveCount(count),
          icon: Icons.assignment_outlined,
          accent: ProServeColors.accent2,
          onTap: () => context.push('/job-feed'),
        );
      },
    );
  }

  double _moneyFrom(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  Widget _buildHomeTab({required BuildContext context, required User user}) {
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final subscriptionTier = effectiveSubscriptionTier(data);
        final rawName = (data?['name'] as String?)?.trim() ?? '';
        final fallback = (user.email ?? '').split('@').first.trim();
        final name = rawName.isNotEmpty
            ? rawName
            : (fallback.isNotEmpty
                  ? fallback
                  : l10n.contractorPortalWelcomeFallback);
        final contractorStream = FirebaseFirestore.instance
            .collection('contractors')
            .doc(user.uid)
            .snapshots();

        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: ProServeColors.heroGradient,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _ContractorDashboardHeader(
                title: 'Today',
                onNotifications: () => context.push('/notifications'),
                onHelp: () => context.push('/contractor-profile-settings'),
              ),
              const SizedBox(height: 14),
              _buildLeadFirstPanel(data),
              const SizedBox(height: 12),
              _buildTodayMetrics(context, data),
              const SizedBox(height: 12),
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: contractorStream,
                builder: (context, contractorSnap) {
                  return ContractorAccountSummaryCard(
                    data: contractorSnap.data?.data() ?? data,
                    fallbackName: name,
                    fallbackEmail: user.email ?? '',
                    onEdit: () => context.push('/edit-card'),
                    onSetup: () => context.push('/contractor-profile-settings'),
                  );
                },
              ),
              const SizedBox(height: 18),
              _DashboardSectionHeader(
                title: l10n.tools,
                subtitle: _homeToolsSubtitle(l10n, subscriptionTier),
                actionLabel: l10n.contractorHomeViewAll,
                onAction: () => setState(() => _tabIndex = 3),
              ),
              const SizedBox(height: 10),
              _ContractorToolGrid(
                tools: _homeToolsForTier(context, l10n, subscriptionTier),
              ),
              const SizedBox(height: 18),
              _DashboardSectionHeader(
                title: l10n.escrow,
                actionLabel: l10n.contractorHomeViewAll,
                onAction: () => context.push('/payment-history'),
              ),
              const SizedBox(height: 10),
              const _ContractorEscrowSummaryCard(),
            ],
          ),
        );
      },
    );
  }

  /// Merges two Firestore query streams into a single de-duplicated,
  /// sorted list. Emits whenever either source stream emits.
  Stream<List<QueryDocumentSnapshot>> _combinedJobStream(
    Stream<QuerySnapshot> claimedStream,
    Stream<QuerySnapshot> paidStream,
  ) {
    List<QueryDocumentSnapshot>? lastClaimed;
    List<QueryDocumentSnapshot>? lastPaid;

    List<QueryDocumentSnapshot> merge() {
      final merged = <String, QueryDocumentSnapshot>{};
      if (lastClaimed != null) {
        for (final doc in lastClaimed!) {
          merged[doc.id] = doc;
        }
      }
      if (lastPaid != null) {
        for (final doc in lastPaid!) {
          merged[doc.id] = doc;
        }
      }
      final docs = merged.values.toList();
      docs.sort((a, b) {
        final ad = a.data() as Map<String, dynamic>;
        final bd = b.data() as Map<String, dynamic>;
        int ms(Map<String, dynamic> d) {
          final ca = d['claimedAt'];
          final cr = d['createdAt'];
          if (ca is Timestamp) return ca.millisecondsSinceEpoch;
          if (cr is Timestamp) return cr.millisecondsSinceEpoch;
          return 0;
        }

        return ms(bd).compareTo(ms(ad));
      });
      return docs;
    }

    late final StreamController<List<QueryDocumentSnapshot>> controller;
    StreamSubscription? subClaimed;
    StreamSubscription? subPaid;

    controller = StreamController<List<QueryDocumentSnapshot>>(
      onListen: () {
        subClaimed = claimedStream.listen(
          (snap) {
            lastClaimed = snap.docs;
            controller.add(merge());
          },
          onError: (e) {
            debugPrint('[Jobs] claimedBy stream error: $e');
            lastClaimed ??= [];
            if (lastPaid != null) controller.add(merge());
          },
        );
        subPaid = paidStream.listen(
          (snap) {
            lastPaid = snap.docs;
            controller.add(merge());
          },
          onError: (e) {
            debugPrint('[Jobs] paidBy stream error: $e');
            lastPaid ??= [];
            if (lastClaimed != null) controller.add(merge());
          },
        );
      },
      onCancel: () {
        subClaimed?.cancel();
        subPaid?.cancel();
      },
    );

    return controller.stream;
  }

  Widget _buildSearchTab(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Center(child: Text(l10n.signInRequired));
    }
    return const JobFeedPage();
  }

  Widget _buildToolsTab(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Center(child: Text(l10n.signInRequired));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();

        Future<void> openSubscription() async {
          context.push('/contractor-subscription');
        }

        return ContractorToolsHub(
          userData: data,
          openSubscription: openSubscription,
          openProToolOrSubscribe: _openPricingToolsOrSubscribe,
          openEnterpriseToolOrSubscribe: _openEnterpriseToolOrSubscribe,
        );
      },
    );
  }

  List<Widget> _planActionRows(BuildContext context, String uid) {
    final l10n = AppLocalizations.of(context)!;
    final actions = <_PlanAction>[
      _PlanAction(
        icon: Icons.account_circle_outlined,
        title: l10n.editProfile,
        subtitle: l10n.updatePublicContractorInfo,
        onTap: () => context.push('/customer-profile'),
      ),
      _PlanAction(
        icon: Icons.verified_outlined,
        title: l10n.getVerified,
        subtitle: l10n.improveTrustWinMoreWork,
        onTap: () => context.push('/verification'),
      ),
      _PlanAction(
        icon: Icons.analytics_outlined,
        title: l10n.analytics,
        subtitle: l10n.contractorPortalTrackPerformance,
        onTap: () => context.push('/contractor-analytics'),
      ),
      _PlanAction(
        icon: Icons.calendar_month_outlined,
        title: l10n.availability,
        subtitle: l10n.keepScheduleUpToDate,
        onTap: () => context.push('/availability-calendar'),
      ),
      _PlanAction(
        icon: Icons.map_outlined,
        title: l10n.serviceArea,
        subtitle: l10n.controlWhereYouGetLeads,
        onTap: () => context.push('/service-area'),
      ),
      _PlanAction(
        icon: Icons.photo_library_outlined,
        title: l10n.contractorPortalPortfolio,
        subtitle: l10n.showcaseBestWork,
        onTap: () =>
            context.push('/portfolio/$uid', extra: {'isEditable': true}),
      ),
      _PlanAction(
        icon: Icons.business_outlined,
        title: l10n.businessProfile,
        subtitle: l10n.manageCompanyDetails,
        onTap: () => context.push('/business-profile'),
      ),
      _PlanAction(
        icon: Icons.question_answer_outlined,
        title: l10n.qAndA,
        subtitle: l10n.answerCustomerQuestions,
        onTap: () => context.push('/qanda/$uid', extra: {'isContractor': true}),
      ),
    ];

    return [
      for (var i = 0; i < actions.length; i++) ...[
        _PlanActionRow(action: actions[i]),
        if (i != actions.length - 1)
          const Divider(height: 1, color: ProServeColors.line),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          return const ContractorLoginPage();
        }

        // Sync FCM token (mobile only). Safe no-op on desktop/web.
        FcmService.syncTokenOnce();

        return PopScope(
          canPop: false,
          child: _tabScaffold(
            fab: _tabIndex == 3
                ? FloatingActionButton(
                    tooltip: l10n.quickActions,
                    onPressed: () => _showToolsQuickActions(context),
                    child: const Icon(Icons.add),
                  )
                : null,
            child: IndexedStack(
              index: _tabIndex,
              children: [
                _buildHomeTab(context: context, user: user),
                _buildSearchTab(context),
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    PageHeader(
                      title: l10n.plan,
                      subtitle: l10n.contractorPortalPlanSubtitle,
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
                    ),
                    ProfileCompletionCard(
                      onTapComplete: () {
                        context.push('/customer-profile');
                      },
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .snapshots(),
                      builder: (context, snap) {
                        final isLoading =
                            snap.connectionState == ConnectionState.waiting &&
                            !snap.hasData;

                        if (snap.hasError) {
                          return AnimatedStateSwitcher(
                            stateKey: 'plan_user_error',
                            child: EmptyStateCard(
                              icon: Icons.error_outline,
                              title: l10n.contractorPortalCouldNotLoadAccount,
                              subtitle: l10n.pullToRefreshTryAgain,
                              action: OutlinedButton.icon(
                                onPressed: () => setState(() {}),
                                icon: const Icon(Icons.refresh),
                                label: Text(l10n.retry),
                              ),
                            ),
                          );
                        }

                        if (isLoading) {
                          return const AnimatedStateSwitcher(
                            stateKey: 'plan_user_loading',
                            child: ProServeSurfaceCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SkeletonLoader(width: 160, height: 16),
                                  SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      SkeletonLoader(width: 120, height: 28),
                                      SkeletonLoader(width: 110, height: 28),
                                      SkeletonLoader(width: 110, height: 28),
                                    ],
                                  ),
                                  SizedBox(height: 16),
                                  SkeletonLoader(
                                    width: double.infinity,
                                    height: 44,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final data = snap.data?.data() as Map<String, dynamic>?;
                        final approved = data?['approved'] == true;
                        final nonExclusiveRaw =
                            data?['leadCredits'] ?? data?['credits'];
                        final nonExclusiveCredits = nonExclusiveRaw is num
                            ? nonExclusiveRaw.toInt()
                            : 0;
                        final exclusiveRaw = data?['exclusiveLeadCredits'];
                        final exclusiveCredits = exclusiveRaw is num
                            ? exclusiveRaw.toInt()
                            : 0;

                        final stripeAccountId =
                            (data?['stripeAccountId'] as String?)?.trim() ?? '';
                        final payoutsEnabled =
                            data?['stripePayoutsEnabled'] == true;
                        final detailsSubmitted =
                            data?['stripeDetailsSubmitted'] == true;

                        final statusText = approved
                            ? l10n.approved
                            : l10n.pendingAdminApproval;
                        final statusTone = approved
                            ? ProServeColors.accent
                            : ProServeColors.warning;

                        final payoutsLabel = payoutsEnabled
                            ? l10n.payoutsConnected
                            : (detailsSubmitted
                                  ? l10n.payoutsPending
                                  : l10n.payoutsSetup);
                        final payoutsTone = payoutsEnabled
                            ? ProServeColors.accent
                            : ProServeColors.warning;

                        return AnimatedStateSwitcher(
                          stateKey: 'plan_user_loaded',
                          child: Column(
                            children: [
                              ProServeSurfaceCard(
                                highlight: approved,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            l10n.accountOverview,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w900,
                                                ),
                                          ),
                                        ),
                                        Icon(
                                          approved
                                              ? Icons.verified
                                              : Icons.pending_actions,
                                          color: statusTone,
                                          size: 30,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        ProServeStatusPill(
                                          label: statusText,
                                          icon: approved
                                              ? Icons.verified
                                              : Icons.pending_actions,
                                          color: statusTone,
                                        ),
                                        ProServeStatusPill(
                                          label: payoutsLabel,
                                          icon: payoutsEnabled
                                              ? Icons
                                                    .account_balance_wallet_outlined
                                              : Icons.payments_outlined,
                                          color: payoutsTone,
                                        ),
                                        ProServeStatusPill(
                                          label: l10n.nonExclusiveCredits(
                                            nonExclusiveCredits,
                                          ),
                                          icon: Icons.local_offer_outlined,
                                          color: ProServeColors.accent2,
                                        ),
                                        ProServeStatusPill(
                                          label: l10n.exclusiveCredits(
                                            exclusiveCredits,
                                          ),
                                          icon: Icons.lock_outline,
                                          color: ProServeColors.accent2,
                                        ),
                                        if (stripeAccountId.isEmpty)
                                          ProServeStatusPill(
                                            label: l10n.payoutsNotConnected,
                                            icon: Icons.link_off,
                                            color: ProServeColors.warning,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              ProServeSurfaceCard(
                                padding: EdgeInsets.zero,
                                child: Column(
                                  children: _planActionRows(context, user.uid),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
                _buildToolsTab(context),
                const CommunityFeedScreen(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ContractorDashboardHeader extends StatelessWidget {
  const _ContractorDashboardHeader({
    required this.title,
    required this.onNotifications,
    required this.onHelp,
  });

  final String title;
  final VoidCallback onNotifications;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
        _ShellIconButton(
          tooltip: l10n.notifications,
          icon: Icons.notifications_none_rounded,
          onPressed: onNotifications,
        ),
        const SizedBox(width: 8),
        _ShellIconButton(
          tooltip: l10n.help,
          icon: Icons.help_outline_rounded,
          onPressed: onHelp,
        ),
      ],
    );
  }
}

class _ShellIconButton extends StatelessWidget {
  const _ShellIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: ProServeColors.card.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ProServeColors.line),
          ),
          child: Icon(icon, color: ProServeColors.ink, size: 21),
        ),
      ),
    );
  }
}

class _DashboardSurface extends StatelessWidget {
  const _DashboardSurface({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.borderColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    final content = Ink(
      padding: padding,
      decoration: BoxDecoration(
        gradient: ProServeColors.cardGradient,
        borderRadius: radius,
        border: Border.all(color: borderColor ?? ProServeColors.lineStrong),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return content;
    return InkWell(onTap: onTap, borderRadius: radius, child: content);
  }
}

class _DashboardMetricCard extends StatelessWidget {
  const _DashboardMetricCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String value;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _DashboardSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: ProServeColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: ProServeColors.muted,
                size: 22,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardStatusCard extends StatelessWidget {
  const _DashboardStatusCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.trailingIcon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final IconData trailingIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _DashboardSurface(
      onTap: onTap,
      borderColor: accent.withValues(alpha: 0.22),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: accent, size: 27),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ProServeColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(trailingIcon, color: accent, size: 22),
          ),
        ],
      ),
    );
  }
}

class _DashboardSectionHeader extends StatelessWidget {
  const _DashboardSectionHeader({
    required this.title,
    this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String? subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ProServeColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

class _DashboardTool {
  const _DashboardTool({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _ProfessionalStatusChip extends StatelessWidget {
  const _ProfessionalStatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContractorToolGrid extends StatelessWidget {
  const _ContractorToolGrid({required this.tools});

  final List<_DashboardTool> tools;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tools.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.42,
      ),
      itemBuilder: (context, index) {
        final tool = tools[index];
        return _DashboardToolTile(tool: tool);
      },
    );
  }
}

class _PlanAction {
  const _PlanAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _PlanActionRow extends StatelessWidget {
  const _PlanActionRow({required this.action});

  final _PlanAction action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: ProServeColors.accent2.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: ProServeColors.accent2.withValues(alpha: 0.18),
                  ),
                ),
                child: Icon(action.icon, color: ProServeColors.accent2),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      action.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ProServeColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.chevron_right,
                color: ProServeColors.muted,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardToolTile extends StatelessWidget {
  const _DashboardToolTile({required this.tool});

  final _DashboardTool tool;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: tool.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            gradient: ProServeColors.cardGradient,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ProServeColors.lineStrong),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(tool.icon, color: tool.color, size: 24),
              const SizedBox(height: 6),
              Text(
                tool.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: ProServeColors.ink,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContractorEscrowSummaryCard extends StatelessWidget {
  const _ContractorEscrowSummaryCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    return StreamBuilder<List<EscrowBooking>>(
      stream: EscrowService.instance.watchContractorBookings(),
      builder: (context, snapshot) {
        final bookings = snapshot.data ?? const <EscrowBooking>[];
        final active = bookings.where(_isActive).toList();
        final total = active.fold<double>(
          0,
          (runningTotal, booking) => runningTotal + booking.aiPrice,
        );

        return _DashboardSurface(
          onTap: () => context.push('/payment-history'),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: ProServeColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: ProServeColors.accent.withValues(alpha: 0.22),
                  ),
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: ProServeColors.accent,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.contractorHomeActiveCount(active.length),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                fmt.format(total),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: ProServeColors.muted,
              ),
            ],
          ),
        );
      },
    );
  }

  static bool _isActive(EscrowBooking booking) {
    final now = DateTime.now();
    if (booking.status == EscrowStatus.offered &&
        now.difference(booking.createdAt).inHours >= 24) {
      return false;
    }
    return booking.status == EscrowStatus.offered ||
        booking.status == EscrowStatus.funded ||
        booking.status == EscrowStatus.customerConfirmed ||
        booking.status == EscrowStatus.contractorConfirmed;
  }
}
