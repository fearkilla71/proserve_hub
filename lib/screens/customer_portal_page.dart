import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../theme/proserve_theme.dart';
import 'browse_contractors_screen.dart';
import 'landing_page.dart';
import 'community_feed_screen.dart';

import '../services/customer_portal_nav.dart';
import '../services/escrow_service.dart';
import '../services/fcm_service.dart';
import '../services/conversation_service.dart';
import '../services/trusted_pros_service.dart';
import '../widgets/escrow_bookings_card.dart';
import '../widgets/maintenance_reminder_card.dart';
import '../widgets/neighborhood_social_proof.dart';
import '../widgets/profile_completion_card.dart';
import '../widgets/seasonal_deals_carousel.dart';
import '../widgets/skeleton.dart';
import '../widgets/persistent_job_state_bar.dart';
import 'onboarding_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';

class _RequestsFetchResult {
  const _RequestsFetchResult({required this.docs, required this.usedFallback});

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final bool usedFallback;
}

class CustomerPortalPage extends StatefulWidget {
  const CustomerPortalPage({super.key});

  @override
  State<CustomerPortalPage> createState() => _CustomerPortalPageState();
}

class _CustomerPortalPageState extends State<CustomerPortalPage>
    with SingleTickerProviderStateMixin {
  int _tabIndex = 0;

  Future<_RequestsFetchResult>? _myRequestsDiagnose;
  late final AnimationController _homeIntroController;
  late final Animation<double> _heroFade;
  late final Animation<Offset> _heroSlide;
  late final Animation<double> _nextFade;
  late final Animation<Offset> _nextSlide;

  @override
  void initState() {
    super.initState();
    _homeIntroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _heroFade = CurvedAnimation(
      parent: _homeIntroController,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
    );
    _heroSlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _homeIntroController,
            curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
          ),
        );
    _nextFade = CurvedAnimation(
      parent: _homeIntroController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    );
    _nextSlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _homeIntroController,
            curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
          ),
        );
    _homeIntroController.forward();
    CustomerPortalNav.tabRequest.addListener(_handleTabRequest);
    // Patch any existing escrow bookings that are missing fields on job_requests
    EscrowService.instance.syncEscrowFieldsToJobRequests();
    // Show role-specific onboarding the first time a customer opens the portal.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) OnboardingScreen.showIfNeeded(context, 'customer');
    });
  }

  @override
  void dispose() {
    CustomerPortalNav.tabRequest.removeListener(_handleTabRequest);
    _homeIntroController.dispose();
    super.dispose();
  }

  Widget _fadeSlide({
    required Widget child,
    required Animation<double> fade,
    required Animation<Offset> slide,
  }) {
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }

  void _handleTabRequest() {
    final requested = CustomerPortalNav.tabRequest.value;
    if (requested == null || !mounted) return;
    setState(() {
      _tabIndex = requested.clamp(0, 4);
    });
    CustomerPortalNav.clear();
  }

  String _prettyFirestoreError(Object error) {
    if (error is FirebaseException) {
      final code = error.code.trim();
      final message = error.message?.trim();
      if (message != null && message.isNotEmpty) {
        return 'Firestore error ($code): $message';
      }
      return 'Firestore error ($code)';
    }
    return error.toString();
  }

  Query<Map<String, dynamic>> _myRequestsQuery(String uid) {
    return FirebaseFirestore.instance
        .collection('job_requests')
        .where('requesterUid', isEqualTo: uid);
  }

  Query<Map<String, dynamic>> _myRequestsFallbackQuery(String uid) {
    // Backward compatibility for older jobs that used clientId instead of
    // requesterUid.
    return FirebaseFirestore.instance
        .collection('job_requests')
        .where('clientId', isEqualTo: uid);
  }

  Future<_RequestsFetchResult> _runMyRequestsDiagnosticFetch(String uid) async {
    final primary = await _myRequestsQuery(uid)
        .get(const GetOptions(source: Source.serverAndCache))
        .timeout(const Duration(seconds: 10));

    if (primary.docs.isNotEmpty) {
      final filtered = primary.docs.where((d) {
        final s = (d.data()['status'] ?? '').toString().toLowerCase();
        return s != 'cancelled' && s != 'deleted';
      }).toList();
      return _RequestsFetchResult(docs: filtered, usedFallback: false);
    }

    final fallback = await _myRequestsFallbackQuery(uid)
        .get(const GetOptions(source: Source.serverAndCache))
        .timeout(const Duration(seconds: 10));

    final filteredFb = fallback.docs.where((d) {
      final s = (d.data()['status'] ?? '').toString().toLowerCase();
      return s != 'cancelled' && s != 'deleted';
    }).toList();
    return _RequestsFetchResult(docs: filteredFb, usedFallback: true);
  }

  void _retryMyRequests() {
    try {
      FirebaseFirestore.instance.enableNetwork();
    } catch (_) {
      // Best-effort.
    }
    setState(() {
      _myRequestsDiagnose = null;
    });
  }

  String _formatTimestamp(dynamic ts) {
    if (ts is Timestamp) {
      return DateFormat.yMMMd().add_jm().format(ts.toDate());
    }
    return '';
  }

  bool _canLeaveReview(Map<String, dynamic> data) {
    final claimed = data['claimed'] == true;
    final contractorId = (data['claimedBy'] as String?)?.trim() ?? '';
    final status = (data['status'] as String?)?.trim().toLowerCase() ?? '';
    return claimed && contractorId.isNotEmpty && status == 'completed';
  }

  Widget _buildReviewAction({
    required BuildContext context,
    required String jobId,
    required String contractorId,
  }) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('jobId', isEqualTo: jobId)
          .snapshots(),
      builder: (context, reviewSnap) {
        if (!reviewSnap.hasData) {
          return const SizedBox.shrink();
        }

        final me = FirebaseAuth.instance.currentUser?.uid ?? '';
        final alreadyReviewed = reviewSnap.data!.docs.any((d) {
          final data = d.data();
          final customerId = (data['customerId'] as String?)?.trim() ?? '';
          return customerId == me;
        });

        if (alreadyReviewed) {
          return SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Review Submitted'),
            ),
          );
        }

        return SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            onPressed: () {
              context.push('/submit-review/$jobId/$contractorId');
            },
            child: const Text('Leave a Review'),
          ),
        );
      },
    );
  }

  Widget _tabScaffold({required Widget child, Widget? fab}) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final l10n = AppLocalizations.of(context)!;
    const navHeight = 80.0;
    const persistentBarReserve = 92.0;
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
            child: const PersistentJobStateBar(role: JobBarRole.customer),
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
            label: l10n.browse,
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long),
            label: l10n.project,
          ),
          NavigationDestination(
            icon: const Icon(Icons.group_outlined),
            selectedIcon: const Icon(Icons.group),
            label: l10n.team,
          ),
          NavigationDestination(
            icon: const Icon(Icons.photo_library_outlined),
            selectedIcon: const Icon(Icons.photo_library),
            label: l10n.gallery,
          ),
        ],
      ),
    );
  }

  Widget _buildHomeHero(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Card(
      color: scheme.primaryContainer.withValues(alpha: 0.72),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.customerHomeHeroTitle,
              style: GoogleFonts.bebasNeue(
                fontSize: 26,
                letterSpacing: 1.2,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.customerHomeHeroSubtitle,
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: scheme.onPrimaryContainer.withValues(alpha: 0.82),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _HeroPill(label: l10n.verifiedPros),
                _HeroPill(label: l10n.upfrontPricing),
                _HeroPill(label: l10n.projectTracking),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => context.push('/smart-request'),
                    child: Text(l10n.startRequest),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _tabIndex = 1),
                    child: Text(l10n.browsePros),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/instant-quote'),
                icon: const Icon(Icons.camera_alt, size: 18),
                label: Text(l10n.snapForInstantQuote),
              ),
            ),
          ],
        ),
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
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: ProServeColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: ProServeColors.line),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: ProServeColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: ProServeColors.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: ProServeColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: ProServeColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
            : (fallback.isNotEmpty ? fallback : l10n.customerWelcomeFallback);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
                  tooltip: l10n.profile,
                  onPressed: () {
                    context.push('/customer-profile');
                  },
                  icon: const Icon(Icons.account_circle_outlined),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _fadeSlide(
              child: _buildHomeHero(context),
              fade: _heroFade,
              slide: _heroSlide,
            ),
            const SizedBox(height: 12),
            _fadeSlide(
              child: _CustomerActionCenter(
                userId: user.uid,
                requestsQuery: _myRequestsQuery(user.uid),
                canLeaveReview: _canLeaveReview,
                onProjectTab: () => setState(() => _tabIndex = 2),
              ),
              fade: _nextFade,
              slide: _nextSlide,
            ),
            const SizedBox(height: 12),
            _fadeSlide(
              child: const EscrowBookingsCard(isCustomer: true),
              fade: _nextFade,
              slide: _nextSlide,
            ),
            const SizedBox(height: 12),

            // ── Maintenance Reminders (Feature E) ──
            const MaintenanceReminderCard(),
            const SizedBox(height: 12),

            // ── Seasonal Deals & Flash Offers (Feature F) ──
            const SeasonalDealsCarousel(),
            const SizedBox(height: 12),

            // ── Neighborhood Social Proof (Feature G) ──
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 0),
              child: NeighborhoodSocialProof(),
            ),
            const SizedBox(height: 16),

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
                    title: l10n.startRequest,
                    subtitle: l10n.customerQuickStartRequestSubtitle,
                    icon: Icons.add_circle_outline,
                    onTap: () {
                      context.push('/smart-request');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _quickActionTile(
                    context: context,
                    title: l10n.browsePros,
                    subtitle: l10n.customerQuickBrowseProsSubtitle,
                    icon: Icons.search,
                    onTap: () {
                      setState(() => _tabIndex = 1);
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
                    title: l10n.messages,
                    subtitle: l10n.customerQuickMessagesSubtitle,
                    icon: Icons.chat_bubble_outline,
                    onTap: () {
                      context.push('/conversations');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _quickActionTile(
                    context: context,
                    title: l10n.projectTracker,
                    subtitle: l10n.customerQuickProjectTrackerSubtitle,
                    icon: Icons.receipt_long,
                    onTap: () {
                      setState(() => _tabIndex = 2);
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
                    title: l10n.savedPros,
                    subtitle: l10n.customerQuickSavedProsSubtitle,
                    icon: Icons.favorite_border,
                    onTap: () {
                      context.push('/favorites');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _quickActionTile(
                    context: context,
                    title: l10n.referral,
                    subtitle: l10n.customerQuickReferralSubtitle,
                    icon: Icons.card_giftcard,
                    onTap: () {
                      context.push('/referral');
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
                    title: l10n.loyalty,
                    subtitle: l10n.customerQuickLoyaltySubtitle,
                    icon: Icons.loyalty_outlined,
                    onTap: () {
                      context.push('/loyalty-rewards');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _quickActionTile(
                    context: context,
                    title: l10n.leaderboard,
                    subtitle: l10n.customerQuickLeaderboardSubtitle,
                    icon: Icons.emoji_events_outlined,
                    onTap: () {
                      context.push('/leaderboard');
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
                    title: l10n.savedProjects,
                    subtitle: l10n.customerQuickSavedProjectsSubtitle,
                    icon: Icons.dashboard_customize_outlined,
                    onTap: () {
                      context.push('/project-boards');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _quickActionTile(
                    context: context,
                    title: l10n.myEstimates,
                    subtitle: l10n.customerQuickMyEstimatesSubtitle,
                    icon: Icons.calculate_outlined,
                    onTap: () {
                      context.push('/saved-estimates');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: _quickActionTile(
                context: context,
                title: l10n.aiSupport,
                subtitle: l10n.customerQuickAiSupportSubtitle,
                icon: Icons.support_agent,
                onTap: () {
                  context.push('/ai-support-chat');
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchTab(BuildContext context) {
    return const BrowseContractorsScreen(showBackButton: false);
  }

  Widget _buildTeamTab(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Center(child: Text(l10n.signInRequired));
    }
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // ── Header ──
        Text(
          l10n.myTeam,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.myTeamSubtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),

        // ────────────────────────────────────────────
        // SECTION 1 — My Hired Pros
        // ────────────────────────────────────────────
        _TeamSectionHeader(
          title: l10n.hiredPros,
          subtitle: l10n.hiredProsSubtitle,
          icon: Icons.handshake_outlined,
        ),
        const SizedBox(height: 10),
        _HiredProsList(userId: user.uid),

        const SizedBox(height: 28),

        // ────────────────────────────────────────────
        // SECTION 2 — Trusted Pros Circle
        // ────────────────────────────────────────────
        _TeamSectionHeader(
          title: l10n.trustedPros,
          subtitle: l10n.trustedProsSubtitle,
          icon: Icons.verified_user_outlined,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: l10n.shareMyList,
                icon: const Icon(Icons.share_outlined, size: 20),
                onPressed: () => _shareTrustedList(context),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _showAddTrustedProSheet(context),
                icon: const Icon(Icons.person_add_alt, size: 18),
                label: Text(l10n.add),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _TrustedProsList(
          onEdit: (contractorId, currentTrade, currentNote) =>
              _showEditTrustedSheet(
                context,
                contractorId: contractorId,
                currentTrade: currentTrade,
                currentNote: currentNote,
              ),
        ),
      ],
    );
  }

  // ── Add trusted pro bottom sheet ──
  Future<void> _showAddTrustedProSheet(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final contractorIdController = TextEditingController();
    final tradeController = TextEditingController();
    final noteController = TextEditingController();
    String? selectedContractorId;
    String? selectedContractorName;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.addTrustedPro,
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // --- Search for contractor ---
                  TextField(
                    controller: contractorIdController,
                    decoration: InputDecoration(
                      labelText: l10n.searchContractorName,
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Theme.of(
                        ctx,
                      ).colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) => setSheetState(() {}),
                  ),
                  if (contractorIdController.text.trim().length >= 2) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 160,
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('contractors')
                            .limit(50)
                            .snapshots(),
                        builder: (ctx, snap) {
                          if (!snap.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final query = contractorIdController.text
                              .trim()
                              .toLowerCase();
                          final matches = snap.data!.docs.where((d) {
                            final data = d.data();
                            final name =
                                (data['businessName'] ??
                                        data['publicName'] ??
                                        data['name'] ??
                                        '')
                                    .toString()
                                    .toLowerCase();
                            return name.contains(query);
                          }).toList();

                          if (matches.isEmpty) {
                            return Center(
                              child: Text(
                                l10n.noContractorsFound,
                                style: Theme.of(ctx).textTheme.bodySmall,
                              ),
                            );
                          }

                          return ListView.separated(
                            itemCount: matches.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final d = matches[i];
                              final data = d.data();
                              final name =
                                  (data['businessName'] ??
                                          data['publicName'] ??
                                          data['name'] ??
                                          'Unnamed')
                                      .toString();
                              final profileImg = (data['profileImage'] ?? '')
                                  .toString();
                              final isSelected = selectedContractorId == d.id;
                              return ListTile(
                                dense: true,
                                selected: isSelected,
                                leading: CircleAvatar(
                                  radius: 18,
                                  backgroundImage: profileImg.isNotEmpty
                                      ? CachedNetworkImageProvider(profileImg)
                                      : null,
                                  child: profileImg.isEmpty
                                      ? Text(
                                          name.isNotEmpty
                                              ? name[0].toUpperCase()
                                              : '?',
                                        )
                                      : null,
                                ),
                                title: Text(name),
                                trailing: isSelected
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                      )
                                    : null,
                                onTap: () {
                                  setSheetState(() {
                                    selectedContractorId = d.id;
                                    selectedContractorName = name;
                                  });
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                  if (selectedContractorName != null) ...[
                    const SizedBox(height: 8),
                    Chip(
                      avatar: const Icon(Icons.person, size: 16),
                      label: Text(selectedContractorName!),
                      onDeleted: () => setSheetState(() {
                        selectedContractorId = null;
                        selectedContractorName = null;
                      }),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: tradeController,
                    decoration: InputDecoration(
                      labelText: l10n.tradeSpecialty,
                      hintText: l10n.tradeSpecialtyHint,
                      prefixIcon: const Icon(Icons.construction),
                      filled: true,
                      fillColor: Theme.of(
                        ctx,
                      ).colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    decoration: InputDecoration(
                      labelText: l10n.privateNote,
                      hintText: l10n.privateNoteHint,
                      prefixIcon: const Icon(Icons.sticky_note_2_outlined),
                      filled: true,
                      fillColor: Theme.of(
                        ctx,
                      ).colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: selectedContractorId == null
                          ? null
                          : () async {
                              await TrustedProsService.instance.add(
                                selectedContractorId!,
                                trade: tradeController.text.trim(),
                                note: noteController.text.trim(),
                              );
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    l10n.addedToTrustedList(
                                      selectedContractorName ?? l10n.pro,
                                    ),
                                  ),
                                ),
                              );
                            },
                      child: Text(l10n.addToTrustedList),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Edit trusted pro ──
  Future<void> _showEditTrustedSheet(
    BuildContext context, {
    required String contractorId,
    required String currentTrade,
    required String currentNote,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final tradeController = TextEditingController(text: currentTrade);
    final noteController = TextEditingController(text: currentNote);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.editTrustedPro,
                style: Theme.of(
                  ctx,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: tradeController,
                decoration: InputDecoration(
                  labelText: l10n.tradeSpecialty,
                  prefixIcon: const Icon(Icons.construction),
                  filled: true,
                  fillColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  labelText: l10n.privateNote,
                  prefixIcon: const Icon(Icons.sticky_note_2_outlined),
                  filled: true,
                  fillColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: ctx,
                          builder: (c) => AlertDialog(
                            title: Text(l10n.removeQuestion),
                            content: Text(l10n.removeTrustedProConfirm),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: Text(l10n.cancel),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: Text(l10n.remove),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true || !ctx.mounted) return;
                        await TrustedProsService.instance.remove(contractorId);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                      },
                      child: Text(l10n.remove),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        await TrustedProsService.instance.update(
                          contractorId,
                          trade: tradeController.text.trim(),
                          note: noteController.text.trim(),
                        );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(l10n.updated)));
                      },
                      child: Text(l10n.save),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Share trusted list ──
  Future<void> _shareTrustedList(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('trusted_pros')
        .get();

    if (snap.docs.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your trusted list is empty.')),
      );
      return;
    }

    // Fetch contractor names
    final lines = <String>[];
    for (final doc in snap.docs) {
      final cSnap = await FirebaseFirestore.instance
          .collection('contractors')
          .doc(doc.id)
          .get();
      final cData = cSnap.data() ?? {};
      final name =
          (cData['businessName'] ??
                  cData['publicName'] ??
                  cData['name'] ??
                  'Unknown')
              .toString();
      final trade = (doc.data()['trade'] ?? '').toString();
      lines.add(trade.isNotEmpty ? '$name ($trade)' : name);
    }

    final text =
        'My trusted pros on ProServe Hub:\n\n${lines.map((l) => '• $l').join('\n')}\n\nDownload ProServe Hub to find & book verified pros!';

    await Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        final user = snap.data;
        if (user == null) {
          return const LandingPage();
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
                : null,
            child: IndexedStack(
              index: _tabIndex,
              children: [
                _buildHomeTab(context: context, user: user),
                _buildSearchTab(context),
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    Text(
                      l10n.project,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    const ProfileCompletionCard(),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          context.push('/select-service');
                        },
                        child: Text(l10n.startNewRequest),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        onPressed: () {
                          context.push('/ai-estimator');
                        },
                        child: Text(l10n.aiEstimator),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          context.push('/customer-analytics');
                        },
                        child: Text(l10n.analytics),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const EscrowBookingsCard(isCustomer: true),
                    const SizedBox(height: 24),
                    Text(
                      l10n.myRequests,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _myRequestsQuery(
                        user.uid,
                      ).snapshots(includeMetadataChanges: true),
                      builder: (context, jobsSnap) {
                        if (jobsSnap.hasError) {
                          final pretty = _prettyFirestoreError(jobsSnap.error!);
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.couldNotLoadRequests,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(pretty),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: _retryMyRequests,
                                      icon: const Icon(Icons.refresh),
                                      label: Text(l10n.retry),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        if (!jobsSnap.hasData) {
                          return FutureBuilder<void>(
                            future: Future<void>.delayed(
                              const Duration(seconds: 6),
                            ),
                            builder: (context, delaySnap) {
                              if (delaySnap.connectionState !=
                                  ConnectionState.done) {
                                return Column(
                                  children: const [
                                    SkeletonCard(),
                                    SkeletonCard(),
                                    SkeletonCard(),
                                  ],
                                );
                              }

                              _myRequestsDiagnose ??=
                                  _runMyRequestsDiagnosticFetch(user.uid);

                              return FutureBuilder<_RequestsFetchResult>(
                                future: _myRequestsDiagnose,
                                builder: (context, diagSnap) {
                                  if (diagSnap.connectionState !=
                                      ConnectionState.done) {
                                    return Column(
                                      children: const [
                                        SkeletonCard(),
                                        SkeletonCard(),
                                      ],
                                    );
                                  }

                                  if (diagSnap.hasError) {
                                    final pretty = _prettyFirestoreError(
                                      diagSnap.error!,
                                    );
                                    return Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              l10n.stillLoadingRequests,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(pretty),
                                            const SizedBox(height: 12),
                                            SizedBox(
                                              width: double.infinity,
                                              child: OutlinedButton.icon(
                                                onPressed: _retryMyRequests,
                                                icon: const Icon(Icons.refresh),
                                                label: Text(l10n.retry),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }

                                  final result = diagSnap.data;
                                  final docs = result?.docs ?? const [];
                                  if (docs.isEmpty) {
                                    return _buildEmptyRequestsState(context);
                                  }

                                  // Render what we got from the one-shot
                                  // fetch so the screen is usable even if the
                                  // realtime stream is stuck.
                                  final sorted = docs.toList();
                                  sorted.sort((a, b) {
                                    final at = a.data()['createdAt'];
                                    final bt = b.data()['createdAt'];
                                    final aMs = at is Timestamp
                                        ? at.millisecondsSinceEpoch
                                        : 0;
                                    final bMs = bt is Timestamp
                                        ? bt.millisecondsSinceEpoch
                                        : 0;
                                    return bMs.compareTo(aMs);
                                  });

                                  return Column(
                                    children: [
                                      if (result?.usedFallback == true)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          child: Text(
                                            l10n.showingLegacyRequests,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ),
                                      ...sorted.map((doc) {
                                        return _buildRequestCard(
                                          context: context,
                                          docId: doc.id,
                                          data: doc.data(),
                                        );
                                      }),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: _retryMyRequests,
                                          icon: const Icon(Icons.refresh),
                                          label: Text(l10n.refresh),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          );
                        }

                        final docs = jobsSnap.data!.docs.where((d) {
                          final s = (d.data()['status'] ?? '')
                              .toString()
                              .toLowerCase();
                          return s != 'cancelled' && s != 'deleted';
                        }).toList();
                        docs.sort((a, b) {
                          final ad = a.data();
                          final bd = b.data();
                          final at = ad['createdAt'];
                          final bt = bd['createdAt'];
                          final aMs = at is Timestamp
                              ? at.millisecondsSinceEpoch
                              : 0;
                          final bMs = bt is Timestamp
                              ? bt.millisecondsSinceEpoch
                              : 0;
                          return bMs.compareTo(aMs);
                        });

                        if (docs.isEmpty) {
                          return _buildEmptyRequestsState(context);
                        }

                        final isFromCache = jobsSnap.data!.metadata.isFromCache;

                        return Column(
                          children: [
                            if (isFromCache)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.cloud_off,
                                      size: 16,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Showing cached data — you appear to be offline',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ...docs.map((doc) {
                              return _buildRequestCard(
                                context: context,
                                docId: doc.id,
                                data: doc.data(),
                              );
                            }),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                _buildTeamTab(context),
                const CommunityFeedScreen(title: 'Project Gallery'),
              ],
            ),
          ),
        );
      },
    );
  }

  // ────────────────── Empty Requests State ────────────────────

  Widget _buildEmptyRequestsState(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 56,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.noRequestsYet,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.noRequestsYetSubtitle,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.push('/smart-request'),
              icon: const Icon(Icons.add),
              label: Text(l10n.startRequest),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────── Request Card Builder ──────────────────────

  Widget _buildRequestCard({
    required BuildContext context,
    required String docId,
    required Map<String, dynamic> data,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final service = (data['service'] ?? 'Service').toString();
    final location = (data['location'] ?? 'Unknown').toString();
    final description = (data['description'] ?? '').toString();
    final zip = (data['zip'] ?? data['zipcode'] ?? data['jobZip'] ?? '')
        .toString()
        .trim();

    final claimed = data['claimed'] == true;
    final claimedByName = (data['claimedByName'] as String?)?.trim() ?? '';
    final contractorId = (data['claimedBy'] as String?)?.trim() ?? '';
    final canReview = _canLeaveReview(data);
    final createdAt = _formatTimestamp(data['createdAt']);
    final claimedAt = _formatTimestamp(data['claimedAt']);

    final isEscrow =
        data['instantBook'] == true ||
        (data['escrowId'] ?? '').toString().isNotEmpty;
    final escrowPrice = data['escrowPrice'];
    final status = (data['status'] ?? 'open').toString();
    final escrowId = (data['escrowId'] ?? '').toString();

    // Status pipeline
    final statusInfo = _getStatusInfo(
      status,
      claimed,
      claimedByName,
      isEscrow: isEscrow,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row with service title + status badge ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
            child: Row(
              children: [
                // Escrow vs Regular badge
                if (isEscrow) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
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
                        const SizedBox(width: 4),
                        Text(
                          'Escrow',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: ProServeColors.muted.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Regular',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: ProServeColors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    service,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Unread badge + nearby icon
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('chats')
                      .doc(docId)
                      .snapshots()
                      .handleError((_) {}),
                  builder: (context, chatSnap) {
                    final chatData = chatSnap.data?.data();
                    final unreadRaw = chatData?['unread'];
                    final unreadMap = unreadRaw is Map
                        ? unreadRaw.map((k, v) => MapEntry(k.toString(), v))
                        : <String, dynamic>{};
                    final me = FirebaseAuth.instance.currentUser?.uid;
                    final unreadMeRaw = me == null ? null : unreadMap[me];
                    final unreadMe = unreadMeRaw is num
                        ? unreadMeRaw.toInt()
                        : 0;

                    if (unreadMe <= 0) return const SizedBox.shrink();

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.error,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        unreadMe.toString(),
                        style: TextStyle(
                          color: scheme.onError,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
                if (zip.isNotEmpty)
                  IconButton(
                    tooltip: 'Nearby Contractors',
                    icon: const Icon(Icons.near_me_outlined, size: 20),
                    onPressed: () {
                      context.push('/nearby-contractors/$zip');
                    },
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),

          // ── Status indicator row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusInfo.color,
                    boxShadow: [
                      BoxShadow(
                        color: statusInfo.color.withValues(alpha: 0.4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  statusInfo.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: statusInfo.color,
                  ),
                ),
                if (isEscrow && escrowPrice is num) ...[
                  const Spacer(),
                  Text(
                    '\$${escrowPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: ProServeColors.accent,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Details ──
          InkWell(
            onTap: () {
              if (isEscrow && escrowId.isNotEmpty) {
                context.push('/escrow-status/$escrowId');
              } else {
                context.push('/job-command/$docId');
              }
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Location: $location',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (claimedAt.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Assigned at: $claimedAt',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (claimedAt.isEmpty && createdAt.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Created at: $createdAt',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (description.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        description.trim(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Review button ──
          if (canReview)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _buildReviewAction(
                context: context,
                jobId: docId,
                contractorId: contractorId,
              ),
            ),
        ],
      ),
    );
  }

  /// Returns status label + color for the pipeline indicator.
  _StatusInfo _getStatusInfo(
    String status,
    bool claimed,
    String claimedByName, {
    bool isEscrow = false,
  }) {
    switch (status) {
      case 'escrow_funded':
        return _StatusInfo('Paid — Matching Contractor', Colors.amber);
      case 'in_progress':
        return _StatusInfo('In Progress', Colors.blue);
      case 'completion_requested':
        return _StatusInfo('Completion Requested', Colors.orange);
      case 'completion_approved':
        return _StatusInfo('Approved', ProServeColors.accent);
      case 'completed':
        return _StatusInfo('Completed', ProServeColors.accent);
      case 'cancelled':
        return _StatusInfo('Cancelled', Colors.red);
      case 'deleted':
        return _StatusInfo('Deleted', Colors.red);
      default:
        if (isEscrow && claimed) {
          final name = claimedByName.isNotEmpty
              ? 'Contractor: $claimedByName'
              : 'Contractor Assigned';
          return _StatusInfo(name, Colors.blue);
        }
        if (claimed) {
          final name = claimedByName.isNotEmpty
              ? 'Assigned: $claimedByName'
              : 'Assigned';
          return _StatusInfo(name, Colors.blue);
        }
        if (isEscrow) {
          return _StatusInfo('Price Offered', ProServeColors.accent);
        }
        return _StatusInfo('Pending', Colors.grey);
    }
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _CustomerActionCenter extends StatelessWidget {
  const _CustomerActionCenter({
    required this.userId,
    required this.requestsQuery,
    required this.canLeaveReview,
    required this.onProjectTab,
  });

  final String userId;
  final Query<Map<String, dynamic>> requestsQuery;
  final bool Function(Map<String, dynamic> data) canLeaveReview;
  final VoidCallback onProjectTab;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: requestsQuery.snapshots(),
      builder: (context, snapshot) {
        final docs =
            snapshot.data?.docs.where((d) {
              final status = (d.data()['status'] ?? '')
                  .toString()
                  .toLowerCase();
              return status != 'cancelled' && status != 'deleted';
            }).toList() ??
            const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        docs.sort((a, b) {
          final at = a.data()['createdAt'];
          final bt = b.data()['createdAt'];
          final aMs = at is Timestamp ? at.millisecondsSinceEpoch : 0;
          final bMs = bt is Timestamp ? bt.millisecondsSinceEpoch : 0;
          return bMs.compareTo(aMs);
        });

        final actionable =
            docs
                .map(
                  (doc) =>
                      _CustomerActionItem.fromDoc(doc, canLeaveReview, l10n),
                )
                .where((item) => item.priority > 0)
                .toList()
              ..sort((a, b) => b.priority.compareTo(a.priority));

        final topItems = actionable.take(3).toList();
        final openJobs = docs.where((doc) {
          final data = doc.data();
          final claimed = data['claimed'] == true;
          final status = (data['status'] ?? '').toString().toLowerCase();
          return !claimed && (status.isEmpty || status == 'open');
        }).length;
        final pendingQuotes = docs.where((doc) {
          final data = doc.data();
          final quoteCount = (data['quoteCount'] as num?)?.toInt() ?? 0;
          final claimed = data['claimed'] == true;
          return quoteCount > 0 && !claimed;
        }).length;
        final protectedJobs = docs.where((doc) {
          final data = doc.data();
          return (data['escrowId'] ?? '').toString().trim().isNotEmpty ||
              data['instantBook'] == true;
        }).length;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.task_alt_outlined,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.actionCenter,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.customerActionCenterSubtitle,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ActionMetricChip(
                      value: docs.length.toString(),
                      label: l10n.active,
                    ),
                    _ActionMetricChip(
                      value: pendingQuotes.toString(),
                      label: l10n.quotes,
                    ),
                    _ActionMetricChip(
                      value: protectedJobs.toString(),
                      label: l10n.protected,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const LinearProgressIndicator()
                else if (docs.isEmpty)
                  _EmptyCustomerAction(onProjectTab: onProjectTab)
                else if (topItems.isEmpty)
                  _ActionCenterAllClear(onProjectTab: onProjectTab)
                else
                  ...topItems.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _CustomerActionTile(item: item),
                    ),
                  ),
                if (openJobs > 0 && pendingQuotes == 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.customerActionCenterNoQuotesTip,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onProjectTab,
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: Text(l10n.viewAllProjects),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CustomerActionItem {
  const _CustomerActionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.priority,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final int priority;

  static _CustomerActionItem fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    bool Function(Map<String, dynamic> data) canLeaveReview,
    AppLocalizations l10n,
  ) {
    final data = doc.data();
    final jobId = doc.id;
    final service = (data['service'] ?? 'your project').toString();
    final status = (data['status'] ?? 'open').toString().toLowerCase();
    final quoteCount = (data['quoteCount'] as num?)?.toInt() ?? 0;
    final claimed = data['claimed'] == true;
    final escrowId = (data['escrowId'] ?? '').toString().trim();
    final contractorId = (data['claimedBy'] as String?)?.trim() ?? '';

    if (canLeaveReview(data)) {
      return _CustomerActionItem(
        icon: Icons.rate_review_outlined,
        title: l10n.reviewService(service),
        subtitle: l10n.customerActionReviewSubtitle,
        route: '/submit-review/$jobId/$contractorId',
        priority: 100,
      );
    }

    if (escrowId.isNotEmpty) {
      return _CustomerActionItem(
        icon: Icons.shield_outlined,
        title: l10n.checkProtectedPayment,
        subtitle: l10n.customerActionEscrowSubtitle(service),
        route: '/escrow-status/$escrowId',
        priority: status.contains('completion') ? 95 : 80,
      );
    }

    if (quoteCount > 0 && !claimed) {
      return _CustomerActionItem(
        icon: Icons.compare_arrows_outlined,
        title: l10n.compareQuoteCount(quoteCount),
        subtitle: l10n.customerActionCompareSubtitle,
        route: '/quotes/$jobId',
        priority: 90,
      );
    }

    if (claimed || status == 'accepted' || status == 'in_progress') {
      return _CustomerActionItem(
        icon: Icons.dashboard_customize_outlined,
        title: l10n.trackService(service),
        subtitle: l10n.customerActionTrackSubtitle,
        route: '/job-command/$jobId',
        priority: 70,
      );
    }

    if (status == 'open') {
      return _CustomerActionItem(
        icon: Icons.person_search_outlined,
        title: l10n.waitingForQuotes,
        subtitle: l10n.customerActionWaitingSubtitle,
        route: '/job-command/$jobId',
        priority: 50,
      );
    }

    return _CustomerActionItem(
      icon: Icons.info_outline,
      title: '',
      subtitle: '',
      route: '',
      priority: 0,
    );
  }
}

class _CustomerActionTile extends StatelessWidget {
  const _CustomerActionTile({required this.item});

  final _CustomerActionItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push(item.route),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(item.icon, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _ActionMetricChip extends StatelessWidget {
  const _ActionMetricChip({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$value $label'),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _EmptyCustomerAction extends StatelessWidget {
  const _EmptyCustomerAction({required this.onProjectTab});

  final VoidCallback onProjectTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.customerActionEmptyBody,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () => context.push('/smart-request'),
          icon: const Icon(Icons.add_circle_outline),
          label: Text(l10n.postYourFirstJob),
        ),
      ],
    );
  }
}

class _ActionCenterAllClear extends StatelessWidget {
  const _ActionCenterAllClear({required this.onProjectTab});

  final VoidCallback onProjectTab;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.customerActionAllClearBody,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// Team tab helper widgets
// ─────────────────────────────────────────────────────

/// Section header used in the Team tab.
class _TeamSectionHeader extends StatelessWidget {
  const _TeamSectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: scheme.primary, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Lists contractors the customer has completed jobs with.
class _HiredProsList extends StatelessWidget {
  const _HiredProsList({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('job_requests')
          .where('requesterUid', isEqualTo: userId)
          .limit(100)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error loading jobs: ${snap.error}'),
            ),
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        // Deduplicate contractors — group by claimedBy
        final hiredMap = <String, _HiredProInfo>{};
        for (final doc in snap.data!.docs) {
          final data = doc.data();
          final claimed = data['claimed'] == true;
          final contractorId = (data['claimedBy'] as String?)?.trim() ?? '';
          if (!claimed || contractorId.isEmpty) continue;

          final status = (data['status'] ?? 'open').toString();
          final name = (data['claimedByName'] as String?)?.trim() ?? '';
          final service = (data['service'] ?? '').toString();
          final isCompleted =
              status == 'completed' || status == 'completion_approved';

          if (!hiredMap.containsKey(contractorId)) {
            hiredMap[contractorId] = _HiredProInfo(
              contractorId: contractorId,
              displayName: name,
              services: {service},
              totalJobs: 1,
              completedJobs: isCompleted ? 1 : 0,
              activeJobs: (!isCompleted && status != 'cancelled') ? 1 : 0,
              lastJobId: doc.id,
              lastStatus: status,
            );
          } else {
            final existing = hiredMap[contractorId]!;
            existing.services.add(service);
            existing.totalJobs++;
            if (isCompleted) existing.completedJobs++;
            if (!isCompleted && status != 'cancelled') existing.activeJobs++;
            if (name.isNotEmpty && existing.displayName.isEmpty) {
              existing.displayName = name;
            }
            existing.lastJobId = doc.id;
            existing.lastStatus = status;
          }
        }

        if (hiredMap.isEmpty) {
          return _EmptyTeamCard(
            icon: Icons.people_outline,
            title: l10n.noProsYet,
            message: l10n.noProsYetSubtitle,
          );
        }

        final pros = hiredMap.values.toList()
          ..sort((a, b) => b.totalJobs.compareTo(a.totalJobs));

        return Column(
          children: pros.map((info) => _HiredProCard(info: info)).toList(),
        );
      },
    );
  }
}

class _HiredProInfo {
  _HiredProInfo({
    required this.contractorId,
    required this.displayName,
    required this.services,
    required this.totalJobs,
    required this.completedJobs,
    required this.activeJobs,
    required this.lastJobId,
    required this.lastStatus,
  });

  final String contractorId;
  String displayName;
  final Set<String> services;
  int totalJobs;
  int completedJobs;
  int activeJobs;
  String lastJobId;
  String lastStatus;
}

/// Card for a single hired contractor.
class _HiredProCard extends StatelessWidget {
  const _HiredProCard({required this.info});

  final _HiredProInfo info;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('contractors')
          .doc(info.contractorId)
          .get(),
      builder: (context, cSnap) {
        final cData = cSnap.data?.data() ?? {};
        final name =
            (cData['businessName'] ??
                    cData['publicName'] ??
                    cData['name'] ??
                    info.displayName)
                .toString();
        final profileImg = (cData['profileImage'] ?? '').toString();
        final avgRating = (cData['averageRating'] as num?)?.toDouble() ?? 0.0;
        final servicesText = info.services
            .where((s) => s.isNotEmpty)
            .take(3)
            .join(', ');

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: profileImg.isNotEmpty
                          ? CachedNetworkImageProvider(profileImg)
                          : null,
                      child: profileImg.isEmpty
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 18),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isNotEmpty ? name : l10n.contractor,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (servicesText.isNotEmpty)
                            Text(
                              servicesText,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _StatChip(
                                label: l10n.jobsCount(info.totalJobs),
                                icon: Icons.work_outline,
                              ),
                              const SizedBox(width: 8),
                              if (info.activeJobs > 0)
                                _StatChip(
                                  label: l10n.activeCount(info.activeJobs),
                                  icon: Icons.timelapse,
                                  color: Colors.orange,
                                ),
                              if (info.activeJobs == 0 &&
                                  info.completedJobs > 0)
                                _StatChip(
                                  label: l10n.doneCount(info.completedJobs),
                                  icon: Icons.check_circle_outline,
                                  color: Colors.green,
                                ),
                              if (avgRating > 0) ...[
                                const SizedBox(width: 8),
                                Icon(Icons.star, size: 14, color: Colors.amber),
                                const SizedBox(width: 2),
                                Text(
                                  avgRating.toStringAsFixed(1),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final convId =
                              await ConversationService.getOrCreateConversation(
                                otherUserId: info.contractorId,
                                otherUserName: name,
                              );
                          if (!context.mounted) return;
                          context.push('/chat/$convId');
                        },
                        icon: const Icon(Icons.chat_bubble_outline, size: 16),
                        label: Text(l10n.message),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          context.push('/contractor/${info.contractorId}');
                        },
                        icon: const Icon(Icons.person_outline, size: 16),
                        label: Text(l10n.profile),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () {
                          // Rebook — go to service select
                          context.push('/select-service');
                        },
                        icon: const Icon(Icons.replay, size: 16),
                        label: Text(l10n.rebook),
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
  }
}

/// Lists the customer's trusted/curated pros.
class _TrustedProsList extends StatelessWidget {
  const _TrustedProsList({required this.onEdit});

  final void Function(String contractorId, String trade, String note) onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: TrustedProsService.instance.watchAll(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return _EmptyTeamCard(
            icon: Icons.verified_user_outlined,
            title: l10n.noTrustedProsYet,
            message: l10n.noTrustedProsYetSubtitle,
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data();
            final trade = (data['trade'] ?? '').toString();
            final note = (data['note'] ?? '').toString();

            return _TrustedProCard(
              contractorId: doc.id,
              trade: trade,
              note: note,
              onEdit: () => onEdit(doc.id, trade, note),
            );
          }).toList(),
        );
      },
    );
  }
}

class _TrustedProCard extends StatelessWidget {
  const _TrustedProCard({
    required this.contractorId,
    required this.trade,
    required this.note,
    required this.onEdit,
  });

  final String contractorId;
  final String trade;
  final String note;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('contractors')
          .doc(contractorId)
          .get(),
      builder: (context, cSnap) {
        final cData = cSnap.data?.data() ?? {};
        final name =
            (cData['businessName'] ??
                    cData['publicName'] ??
                    cData['name'] ??
                    'Contractor')
                .toString();
        final profileImg = (cData['profileImage'] ?? '').toString();

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push('/contractor/$contractorId'),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundImage: profileImg.isNotEmpty
                        ? CachedNetworkImageProvider(profileImg)
                        : null,
                    child: profileImg.isEmpty
                        ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (trade.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.construction,
                                  size: 13,
                                  color: scheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  trade,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: scheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        if (note.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.sticky_note_2_outlined,
                                  size: 13,
                                  color: scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    note,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                          fontStyle: FontStyle.italic,
                                        ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.icon, this.color});

  final String label;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 3),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: c,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StatusInfo {
  final String label;
  final Color color;
  const _StatusInfo(this.label, this.color);
}

class _EmptyTeamCard extends StatelessWidget {
  const _EmptyTeamCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: scheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
