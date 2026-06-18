import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'contractor_login_page.dart';
import 'community_feed_screen.dart';

import '../l10n/app_localizations.dart';
import '../services/fcm_service.dart';
import '../services/escrow_service.dart';
import '../widgets/animated_states.dart';
import '../widgets/page_header.dart';
import '../theme/proserve_theme.dart';
import '../widgets/profile_completion_card.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/persistent_job_state_bar.dart';
import '../widgets/contractor_portal_helpers.dart';
import '../widgets/contractor_tools_hub.dart';
import '../widgets/tools_quick_actions_sheet.dart';
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

  Widget _tabScaffold({required Widget child, Widget? fab}) {
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    const navHeight = 80.0;
    const persistentBarReserve = 0.0;
    final contentBottomPadding = navHeight + persistentBarReserve + bottomInset;
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: EdgeInsets.only(bottom: contentBottomPadding),
              child: child,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: navHeight + bottomInset,
            child: const PersistentJobStateBar(role: JobBarRole.contractor),
          ),
        ],
      ),
      floatingActionButton: fab == null
          ? null
          : Padding(
              padding: EdgeInsets.only(bottom: persistentBarReserve),
              child: fab,
            ),
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
            icon: const Icon(Icons.search_outlined),
            selectedIcon: const Icon(Icons.search),
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
                title: l10n.contractorHomeToday,
                onNotifications: () => context.push('/notifications'),
                onHelp: () => context.push('/contractor-profile-settings'),
              ),
              const SizedBox(height: 14),
              _buildTodayMetrics(context, data),
              const SizedBox(height: 12),
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: contractorStream,
                builder: (context, contractorSnap) {
                  return _ContractorAccountSummaryCard(
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
                actionLabel: l10n.contractorHomeViewAll,
                onAction: () => setState(() => _tabIndex = 3),
              ),
              const SizedBox(height: 10),
              _ContractorToolGrid(
                tools: [
                  _DashboardTool(
                    label: l10n.contractorHomeToolQuote,
                    icon: Icons.description_outlined,
                    color: ProServeColors.accent2,
                    onTap: () => context.push('/pricing-calculator'),
                  ),
                  _DashboardTool(
                    label: l10n.invoice,
                    icon: Icons.receipt_long_outlined,
                    color: ProServeColors.accent2,
                    onTap: () => context.push('/invoice-maker'),
                  ),
                  _DashboardTool(
                    label: l10n.contractorHomeToolEstimator,
                    icon: Icons.calculate_outlined,
                    color: ProServeColors.accent2,
                    onTap: () => context.push('/cost-estimator/painting'),
                  ),
                  _DashboardTool(
                    label: l10n.contractorHomeToolScheduler,
                    icon: Icons.calendar_month_outlined,
                    color: ProServeColors.accent2,
                    onTap: () => context.push('/availability-calendar'),
                  ),
                  _DashboardTool(
                    label: l10n.contractorHomeToolBidAnalyzer,
                    icon: Icons.query_stats_outlined,
                    color: ProServeColors.accent2,
                    onTap: () => _openEnterpriseToolOrSubscribe(
                      open: () async => context.push('/bid-analyzer'),
                    ),
                  ),
                  _DashboardTool(
                    label: l10n.contractorHomeToolInspector,
                    icon: Icons.shield_outlined,
                    color: ProServeColors.accent2,
                    onTap: () => _openEnterpriseToolOrSubscribe(
                      open: () async => context.push('/quality-inspector'),
                    ),
                  ),
                ],
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

  /// Combines two state-level streams (claimedBy + paidBy) into a single
  /// merged list. Streams are created once in [initState] so they are never
  /// recreated on rebuild, which prevents the flash/flicker issue.
  Widget _buildClaimedJobsList(String uid) {
    final l10n = AppLocalizations.of(context)!;
    if (_claimedStream == null || _paidStream == null) {
      return AnimatedStateSwitcher(
        stateKey: 'claimed_empty',
        child: EmptyStateCard(
          icon: Icons.work_outline,
          title: l10n.contractorPortalNoClaimedJobs,
          subtitle: l10n.contractorPortalNoClaimedJobsSubtitle,
        ),
      );
    }

    // Use a combined stream so both queries are stable references.
    final combined = _combinedJobStream(_claimedStream!, _paidStream!);

    return StreamBuilder<List<QueryDocumentSnapshot>>(
      stream: combined,
      builder: (context, snap) {
        if (snap.hasError) {
          debugPrint('[Jobs] combined stream error: ${snap.error}');
          return AnimatedStateSwitcher(
            stateKey: 'claimed_error',
            child: EmptyStateCard(
              icon: Icons.error_outline,
              title: l10n.contractorPortalCouldNotLoadJobs,
              subtitle: l10n.checkConnectionTryAgain,
            ),
          );
        }

        if (!snap.hasData) {
          return AnimatedStateSwitcher(
            stateKey: 'claimed_loading',
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: const [
                    ListTileSkeleton(),
                    Divider(height: 1),
                    ListTileSkeleton(),
                    Divider(height: 1),
                    ListTileSkeleton(),
                  ],
                ),
              ),
            ),
          );
        }

        final docs = snap.data!;
        if (docs.isEmpty) {
          return AnimatedStateSwitcher(
            stateKey: 'claimed_empty',
            child: EmptyStateCard(
              icon: Icons.work_outline,
              title: l10n.contractorPortalNoClaimedJobs,
              subtitle: l10n.contractorPortalNoClaimedJobsSubtitle,
            ),
          );
        }

        return AnimatedStateSwitcher(
          stateKey: 'claimed_list_${docs.length}',
          child: Column(
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final service = (data['service'] ?? l10n.service).toString();
              final location = (data['location'] ?? l10n.unknown).toString();
              final claimedAt = formatTimestamp(data['claimedAt']);
              final createdAt = formatTimestamp(data['createdAt']);

              final subtitleParts = <String>[];
              subtitleParts.add(l10n.contractorPortalLocationLabel(location));
              if (claimedAt.isNotEmpty) {
                subtitleParts.add(l10n.contractorPortalClaimedLabel(claimedAt));
              }
              if (claimedAt.isEmpty && createdAt.isNotEmpty) {
                subtitleParts.add(l10n.contractorPortalCreatedLabel(createdAt));
              }

              final isEscrow =
                  data['instantBook'] == true ||
                  (data['escrowId'] ?? '').toString().isNotEmpty;

              return Card(
                child: ListTile(
                  leading: isEscrow
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                ProServeColors.accent,
                                ProServeColors.accent.withValues(alpha: 0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                size: 12,
                                color: Colors.black87,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                l10n.escrow,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        )
                      : null,
                  title: Text(service),
                  subtitle: Text(subtitleParts.join('\n')),
                  onTap: () {
                    context.push('/job-command/${doc.id}');
                  },
                ),
              );
            }).toList(),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        PageHeader(
          title: l10n.jobs,
          subtitle: l10n.contractorPortalJobsSubtitle,
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
        ),
        Text(
          l10n.contractorPortalMyClaimedJobs,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        _buildClaimedJobsList(user.uid),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            onPressed: () {
              context.push('/job-feed');
            },
            child: Text(l10n.contractorPortalBrowseJobs),
          ),
        ),
      ],
    );
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
                            child: Card(
                              child: Padding(
                                padding: EdgeInsets.all(16),
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
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.tertiary;

                        final payoutsLabel = payoutsEnabled
                            ? l10n.payoutsConnected
                            : (detailsSubmitted
                                  ? l10n.payoutsPending
                                  : l10n.payoutsSetup);

                        return AnimatedStateSwitcher(
                          stateKey: 'plan_user_loaded',
                          child: Column(
                            children: [
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              l10n.accountOverview,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
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
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          contractorStatusPill(
                                            context: context,
                                            label: statusText,
                                            icon: approved
                                                ? Icons.verified
                                                : Icons.pending_actions,
                                            sideColor: statusTone,
                                          ),
                                          contractorStatusPill(
                                            context: context,
                                            label: payoutsLabel,
                                            icon: payoutsEnabled
                                                ? Icons
                                                      .account_balance_wallet_outlined
                                                : Icons.payments_outlined,
                                          ),
                                          contractorStatusPill(
                                            context: context,
                                            label: l10n.nonExclusiveCredits(
                                              nonExclusiveCredits,
                                            ),
                                            icon: Icons.local_offer_outlined,
                                          ),
                                          contractorStatusPill(
                                            context: context,
                                            label: l10n.exclusiveCredits(
                                              exclusiveCredits,
                                            ),
                                            icon: Icons.lock_outline,
                                          ),
                                          if (stripeAccountId.isEmpty)
                                            contractorStatusPill(
                                              context: context,
                                              label: l10n.payoutsNotConnected,
                                              icon: Icons.link_off,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Card(
                                child: Column(
                                  children: [
                                    contractorActionTile(
                                      context: context,
                                      icon: Icons.account_circle_outlined,
                                      title: l10n.editProfile,
                                      subtitle: l10n.updatePublicContractorInfo,
                                      onTap: () {
                                        context.push('/customer-profile');
                                      },
                                    ),
                                    const Divider(height: 1),
                                    contractorActionTile(
                                      context: context,
                                      icon: Icons.verified_outlined,
                                      title: l10n.getVerified,
                                      subtitle: l10n.improveTrustWinMoreWork,
                                      onTap: () {
                                        context.push('/verification');
                                      },
                                    ),
                                    const Divider(height: 1),
                                    contractorActionTile(
                                      context: context,
                                      icon: Icons.analytics_outlined,
                                      title: l10n.analytics,
                                      subtitle:
                                          l10n.contractorPortalTrackPerformance,
                                      onTap: () {
                                        context.push('/contractor-analytics');
                                      },
                                    ),
                                    const Divider(height: 1),
                                    contractorActionTile(
                                      context: context,
                                      icon: Icons.calendar_month_outlined,
                                      title: l10n.availability,
                                      subtitle: l10n.keepScheduleUpToDate,
                                      onTap: () {
                                        context.push('/availability-calendar');
                                      },
                                    ),
                                    const Divider(height: 1),
                                    contractorActionTile(
                                      context: context,
                                      icon: Icons.map_outlined,
                                      title: l10n.serviceArea,
                                      subtitle: l10n.controlWhereYouGetLeads,
                                      onTap: () {
                                        context.push('/service-area');
                                      },
                                    ),
                                    const Divider(height: 1),
                                    contractorActionTile(
                                      context: context,
                                      icon: Icons.photo_library_outlined,
                                      title: l10n.contractorPortalPortfolio,
                                      subtitle: l10n.showcaseBestWork,
                                      onTap: () {
                                        context.push(
                                          '/portfolio/${user.uid}',
                                          extra: {'isEditable': true},
                                        );
                                      },
                                    ),
                                    const Divider(height: 1),
                                    contractorActionTile(
                                      context: context,
                                      icon: Icons.business_outlined,
                                      title: l10n.businessProfile,
                                      subtitle: l10n.manageCompanyDetails,
                                      onTap: () {
                                        context.push('/business-profile');
                                      },
                                    ),
                                    const Divider(height: 1),
                                    contractorActionTile(
                                      context: context,
                                      icon: Icons.question_answer_outlined,
                                      title: l10n.qAndA,
                                      subtitle: l10n.answerCustomerQuestions,
                                      onTap: () {
                                        context.push(
                                          '/qanda/${user.uid}',
                                          extra: {'isContractor': true},
                                        );
                                      },
                                    ),
                                  ],
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
              letterSpacing: -0.2,
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
                    letterSpacing: -0.3,
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
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

class _ContractorAccountSummaryCard extends StatelessWidget {
  const _ContractorAccountSummaryCard({
    required this.data,
    required this.fallbackName,
    required this.fallbackEmail,
    required this.onEdit,
    required this.onSetup,
  });

  final Map<String, dynamic>? data;
  final String fallbackName;
  final String fallbackEmail;
  final VoidCallback onEdit;
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final displayName = _firstText([
      data?['publicName'],
      data?['businessName'],
      data?['companyName'],
      data?['name'],
      fallbackName,
    ]);
    final contractorName = _firstText([data?['name'], fallbackName]);
    final contact = _firstText([data?['publicPhone'], fallbackEmail]);
    final logoUrl = _firstText([data?['logoUrl']]);
    final rating = _numFrom(data?['avgRating'] ?? data?['averageRating']);
    final reviewCount = _intFrom(data?['reviewCount'] ?? data?['totalReviews']);
    final years = _intFrom(data?['yearsExperience']);
    final tier = _tierFor(reviewCount);
    final setupComplete =
        displayName.isNotEmpty && (contact.isNotEmpty || logoUrl.isNotEmpty);
    final badgeLabels = _professionalBadges(data?['badges']);

    return _DashboardSurface(
      borderColor: ProServeColors.accent2.withValues(alpha: 0.18),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _AccountAvatar(name: displayName, logoUrl: logoUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      contractorName == displayName
                          ? contact
                          : '$contractorName • $contact',
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
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: setupComplete ? onEdit : onSetup,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  setupComplete
                      ? l10n.editProfile
                      : l10n.contractorHomeCompleteSetup,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  icon: Icons.star_rounded,
                  value: rating > 0 ? rating.toStringAsFixed(1) : '—',
                  label: reviewCount > 0
                      ? l10n.contractorHomeReviews(reviewCount)
                      : l10n.contractorHomeNoReviews,
                  accent: ProServeColors.warning,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  icon: Icons.work_history_outlined,
                  value: years > 0 ? l10n.contractorHomeYears(years) : '—',
                  label: l10n.contractorHomeExperience,
                  accent: ProServeColors.accent2,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  icon: Icons.verified_outlined,
                  value: tier,
                  label: l10n.contractorHomeTier,
                  accent: ProServeColors.accent,
                ),
              ),
            ],
          ),
          if (badgeLabels.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: badgeLabels
                  .map(
                    (label) => _ProfessionalChip(
                      label: label,
                      icon: Icons.check_circle_outline,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  static String _firstText(List<dynamic> values) {
    for (final value in values) {
      final text = (value as String?)?.trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static double _numFrom(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static int _intFrom(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static String _tierFor(int reviewCount) {
    if (reviewCount >= 75) return 'Platinum';
    if (reviewCount >= 25) return 'Gold';
    if (reviewCount >= 5) return 'Silver';
    return 'Starter';
  }

  static List<String> _professionalBadges(dynamic raw) {
    final list = raw is List
        ? raw.whereType<String>()
        : const Iterable<String>.empty();
    return list
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .map((value) => value.replaceAll('_', ' '))
        .map(
          (value) => value
              .split(' ')
              .map(
                (part) => part.isEmpty
                    ? part
                    : '${part[0].toUpperCase()}${part.substring(1)}',
              )
              .join(' '),
        )
        .take(3)
        .toList();
  }
}

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({required this.name, required this.logoUrl});

  final String name;
  final String logoUrl;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: ProServeColors.ctaGradient,
        border: Border.all(color: ProServeColors.lineStrong),
      ),
      child: ClipOval(
        child: logoUrl.isEmpty
            ? Center(
                child: Text(
                  initial,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF041016),
                  ),
                ),
              )
            : Image.network(
                logoUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Text(
                    initial,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF041016),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ProServeColors.line),
      ),
      child: Column(
        children: [
          Icon(icon, color: accent, size: 18),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: ProServeColors.muted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfessionalChip extends StatelessWidget {
  const _ProfessionalChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: ProServeColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: ProServeColors.accent.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: ProServeColors.accent, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: ProServeColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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
        childAspectRatio: 1.12,
      ),
      itemBuilder: (context, index) {
        final tool = tools[index];
        return _DashboardToolTile(tool: tool);
      },
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(tool.icon, color: tool.color, size: 28),
              const SizedBox(height: 8),
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
