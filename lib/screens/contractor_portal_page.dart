import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

import 'contractor_login_page.dart';
import 'community_feed_screen.dart';

import '../l10n/app_localizations.dart';
import '../services/fcm_service.dart';
import '../widgets/animated_states.dart';
import '../widgets/page_header.dart';
import '../widgets/escrow_bookings_card.dart';
import '../theme/proserve_theme.dart';
import '../widgets/profile_completion_card.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/persistent_job_state_bar.dart';
import '../widgets/contractor_portal_helpers.dart';
import '../widgets/contractor_tools_hub.dart';
import '../widgets/tools_quick_actions_sheet.dart';
import '../widgets/contractor_card_builder.dart';
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

  Future<void> _openEnterpriseFeature({required VoidCallback open}) async {
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
      debugPrint('Enterprise unlock check failed: $e');
    }

    if (unlocked) {
      open();
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
                  l10n.contractorPortalEnterpriseBoardBody,
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
    final contentBottomPadding = 96.0 + bottomInset;
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
            bottom: 80 + bottomInset,
            child: const PersistentJobStateBar(role: JobBarRole.contractor),
          ),
        ],
      ),
      floatingActionButton: fab,
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

  Widget _quickActionTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: scheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContractorCard({
    required BuildContext context,
    required User user,
    required Map<String, dynamic>? data,
    required String fallbackName,
  }) {
    return buildContractorCardFromDoc(
      context: context,
      user: user,
      data: data,
      fallbackName: fallbackName,
    );
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

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.welcome(name),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: l10n.notifications,
                  onPressed: () {
                    context.push('/notifications');
                  },
                  icon: const Icon(Icons.notifications_outlined),
                ),
                IconButton(
                  tooltip: l10n.help,
                  onPressed: () {
                    context.push('/contractor-profile-settings');
                  },
                  icon: const Icon(Icons.help_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: contractorStream,
              builder: (context, contractorSnap) {
                return _buildContractorCard(
                  context: context,
                  user: user,
                  data: contractorSnap.data?.data(),
                  fallbackName: name,
                );
              },
            ),
            const SizedBox(height: 16),
            const EscrowBookingsCard(isCustomer: false),
            const SizedBox(height: 20),
            Text(
              l10n.quickActions,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _quickActionTile(
                    context: context,
                    title: l10n.contractorPortalBrowseJobs,
                    subtitle: l10n.contractorPortalFindNewLeads,
                    icon: Icons.work_outline,
                    onTap: () {
                      context.push('/job-feed');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _quickActionTile(
                    context: context,
                    title: l10n.messages,
                    subtitle: l10n.contractorPortalReplyFaster,
                    icon: Icons.chat_bubble_outline,
                    onTap: () {
                      context.push('/conversations');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _quickActionTile(
                    context: context,
                    title: l10n.contractorPortalPortfolio,
                    subtitle: l10n.contractorPortalShowcaseYourWork,
                    icon: Icons.photo_library_outlined,
                    onTap: () {
                      context.push(
                        '/portfolio/${user.uid}',
                        extra: {'isEditable': true},
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _quickActionTile(
                    context: context,
                    title: l10n.contractorPortalPayments,
                    subtitle: l10n.contractorPortalTrackEarnings,
                    icon: Icons.payments_outlined,
                    onTap: () {
                      context.push('/payment-history');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _quickActionTile(
                    context: context,
                    title: l10n.contractorPortalSubcontractJobs,
                    subtitle: l10n.contractorPortalViewPostedWork,
                    icon: Icons.handshake_outlined,
                    onTap: () => _openEnterpriseFeature(
                      open: () => context.push('/subcontract-board'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _quickActionTile(
                    context: context,
                    title: l10n.contractorPortalPostJob,
                    subtitle: l10n.contractorPortalShareOverflowWork,
                    icon: Icons.add_circle_outline,
                    onTap: () => _openEnterpriseFeature(
                      open: () => context.push('/contractor-post-job'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _quickActionTile(
                    context: context,
                    title: l10n.contractorPortalCrewRoster,
                    subtitle: l10n.contractorPortalManageTeam,
                    icon: Icons.groups_outlined,
                    onTap: () => _openEnterpriseFeature(
                      open: () => context.push('/crew-roster'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _quickActionTile(
                    context: context,
                    title: l10n.contractorPortalLeaderboard,
                    subtitle: l10n.contractorPortalXpRankings,
                    icon: Icons.emoji_events_outlined,
                    onTap: () => context.push('/leaderboard'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _quickActionTile(
                    context: context,
                    title: l10n.contractorPortalProfitLoss,
                    subtitle: l10n.contractorPortalFinancialDashboard,
                    icon: Icons.analytics_outlined,
                    onTap: () => _openEnterpriseFeature(
                      open: () => context.push('/pnl-dashboard'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _quickActionTile(
                    context: context,
                    title: l10n.contractorPortalAiSupport,
                    subtitle: l10n.contractorPortalInstantHelp,
                    icon: Icons.support_agent,
                    onTap: () => context.push('/ai-support-chat'),
                  ),
                ),
              ],
            ),
          ],
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
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
            fab: _tabIndex == 0
                ? FloatingActionButton(
                    tooltip: l10n.messages,
                    onPressed: () {
                      context.push('/conversations');
                    },
                    child: const Icon(Icons.mail_outline),
                  )
                : (_tabIndex == 3
                      ? FloatingActionButton(
                          onPressed: () => _showToolsQuickActions(context),
                          child: const Icon(Icons.add),
                        )
                      : null),
            child: IndexedStack(
              index: _tabIndex,
              children: [
                _buildHomeTab(context: context, user: user),
                _buildSearchTab(context),
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
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
