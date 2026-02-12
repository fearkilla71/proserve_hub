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
import '../services/fcm_service.dart';
import '../services/conversation_service.dart';
import '../services/trusted_pros_service.dart';
import '../widgets/escrow_bookings_card.dart';
import '../widgets/profile_completion_card.dart';
import '../widgets/skeleton.dart';
import '../widgets/persistent_job_state_bar.dart';
import 'onboarding_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';

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
      return _RequestsFetchResult(docs: primary.docs, usedFallback: false);
    }

    final fallback = await _myRequestsFallbackQuery(uid)
        .get(const GetOptions(source: Source.serverAndCache))
        .timeout(const Duration(seconds: 10));

    return _RequestsFetchResult(docs: fallback.docs, usedFallback: true);
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
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(child: child),
          Positioned(
            left: 0,
            right: 0,
            bottom: 80 + bottomInset,
            child: const PersistentJobStateBar(role: JobBarRole.customer),
          ),
        ],
      ),
      floatingActionButton: fab,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Browse',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Project',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: 'Team',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum),
            label: 'Community',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeHero(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E2A1E), Color(0xFF0A1E38)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ProServeColors.accent.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: ProServeColors.accent.withValues(alpha: 0.1),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Orb top-right
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ProServeColors.accent2.withValues(alpha: 0.1),
              ),
            ),
          ),
          // Orb bottom-left
          Positioned(
            left: -20,
            bottom: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ProServeColors.accent.withValues(alpha: 0.08),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BOOK A PRO IN MINUTES',
                  style: GoogleFonts.bebasNeue(
                    fontSize: 26,
                    letterSpacing: 1.5,
                    color: ProServeColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tell us what you need, compare quotes, and track the job here.',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: ProServeColors.muted,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    _HeroPill(label: 'Verified pros'),
                    _HeroPill(label: 'Upfront pricing'),
                    _HeroPill(label: 'Project tracking'),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: ProServeColors.ctaGradient,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: ProServeColors.accent.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: FilledButton(
                          onPressed: () {
                            context.push('/select-service');
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                          ),
                          child: const Text('Start a request'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() => _tabIndex = 1);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ProServeColors.ink,
                          side: BorderSide(color: ProServeColors.lineStrong),
                          backgroundColor: ProServeColors.card.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        child: const Text('Browse pros'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextActionCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ProServeColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ProServeColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: ProServeColors.ctaGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: ProServeColors.accent.withValues(alpha: 0.25),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: const Icon(Icons.flash_on, color: Color(0xFF041016)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next action',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: ProServeColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kick off a new request or check your messages.',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: ProServeColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.tonal(
              onPressed: () {
                context.push('/select-service');
              },
              style: FilledButton.styleFrom(
                backgroundColor: ProServeColors.accent.withValues(alpha: 0.15),
                foregroundColor: ProServeColors.accent,
              ),
              child: const Text('Start'),
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
            : (fallback.isNotEmpty ? fallback : 'there');

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Welcome, $name',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Notifications',
                  onPressed: () {
                    context.push('/notifications');
                  },
                  icon: const Icon(Icons.notifications_outlined),
                ),
                IconButton(
                  tooltip: 'Profile',
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
              child: _buildNextActionCard(context),
              fade: _nextFade,
              slide: _nextSlide,
            ),
            const SizedBox(height: 16),
            Text(
              'Quick actions',
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
                    title: 'Start request',
                    subtitle: 'Post a job in minutes',
                    icon: Icons.add_circle_outline,
                    onTap: () {
                      context.push('/select-service');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _quickActionTile(
                    context: context,
                    title: 'Browse pros',
                    subtitle: 'Compare nearby contractors',
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
                    title: 'Messages',
                    subtitle: 'Open your inbox',
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
                    title: 'Project tracker',
                    subtitle: 'View active requests',
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
                    title: 'Saved pros',
                    subtitle: 'Your favorite contractors',
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
                    title: 'Referral',
                    subtitle: 'Share & earn credit',
                    icon: Icons.card_giftcard,
                    onTap: () {
                      context.push('/referral');
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
                title: 'My Estimates',
                subtitle: 'View saved AI estimates',
                icon: Icons.calculate_outlined,
                onTap: () {
                  context.push('/saved-estimates');
                },
              ),
            ),
            const SizedBox(height: 16),
            const EscrowBookingsCard(isCustomer: true),
          ],
        );
      },
    );
  }

  Widget _buildSearchTab(BuildContext context) {
    return const BrowseContractorsScreen(showBackButton: false);
  }

  Widget _buildTeamTab(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please sign in.'));
    }
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // ── Header ──
        Text(
          'My Team',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          'Your hired pros and trusted contacts.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),

        // ────────────────────────────────────────────
        // SECTION 1 — My Hired Pros
        // ────────────────────────────────────────────
        _TeamSectionHeader(
          title: 'Hired Pros',
          subtitle: 'Contractors you\'ve completed jobs with.',
          icon: Icons.handshake_outlined,
        ),
        const SizedBox(height: 10),
        _HiredProsList(userId: user.uid),

        const SizedBox(height: 28),

        // ────────────────────────────────────────────
        // SECTION 2 — Trusted Pros Circle
        // ────────────────────────────────────────────
        _TeamSectionHeader(
          title: 'Trusted Pros',
          subtitle: 'Your curated shortlist — add notes, organize by trade.',
          icon: Icons.verified_user_outlined,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Share my list',
                icon: const Icon(Icons.share_outlined, size: 20),
                onPressed: () => _shareTrustedList(context),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _showAddTrustedProSheet(context),
                icon: const Icon(Icons.person_add_alt, size: 18),
                label: const Text('Add'),
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
                    'Add Trusted Pro',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // --- Search for contractor ---
                  TextField(
                    controller: contractorIdController,
                    decoration: InputDecoration(
                      labelText: 'Search contractor name',
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
                                'No contractors found.',
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
                      labelText: 'Trade / speciality',
                      hintText: 'e.g. Plumber, Electrician',
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
                      labelText: 'Private note',
                      hintText: 'e.g. Great with tile, fast response',
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
                                    '${selectedContractorName ?? 'Pro'} added to trusted list.',
                                  ),
                                ),
                              );
                            },
                      child: const Text('Add to Trusted List'),
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
                'Edit Trusted Pro',
                style: Theme.of(
                  ctx,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: tradeController,
                decoration: InputDecoration(
                  labelText: 'Trade / speciality',
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
                  labelText: 'Private note',
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
                            title: const Text('Remove?'),
                            content: const Text(
                              'Remove this contractor from your trusted list?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('Remove'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true || !ctx.mounted) return;
                        await TrustedProsService.instance.remove(contractorId);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                      },
                      child: const Text('Remove'),
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Updated.')),
                        );
                      },
                      child: const Text('Save'),
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
                    tooltip: 'Inbox',
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
                      'Project',
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
                        child: const Text('Start a New Request'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        onPressed: () {
                          context.push('/ai-estimator');
                        },
                        child: const Text('AI Estimator'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          context.push('/customer-analytics');
                        },
                        child: const Text('Analytics'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'My Requests',
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
                                    'Couldn\'t load your requests',
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
                                      label: const Text('Retry'),
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
                                              'Still loading your requests…',
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
                                                label: const Text('Retry'),
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
                                    return const Text(
                                      'No requests yet. Start a new request to see it here.',
                                    );
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
                                            'Showing legacy requests (clientId).',
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
                                          label: const Text('Refresh'),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          );
                        }

                        final docs = jobsSnap.data!.docs.toList();
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
                          return const Text(
                            'No requests yet. Start a new request to see it here.',
                          );
                        }

                        return Column(
                          children: docs.map((doc) {
                            return _buildRequestCard(
                              context: context,
                              docId: doc.id,
                              data: doc.data(),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
                _buildTeamTab(context),
                const CommunityFeedScreen(),
              ],
            ),
          ),
        );
      },
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
    final statusInfo = _getStatusInfo(status, claimed, claimedByName);

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
                // AI / Escrow badge
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
                          Icons.auto_awesome,
                          size: 12,
                          color: Colors.black87,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'AI Price',
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
                context.push('/job/$docId', extra: {'jobData': data});
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
    String claimedByName,
  ) {
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
      default:
        if (claimed) {
          final name = claimedByName.isNotEmpty
              ? 'Assigned: $claimedByName'
              : 'Assigned';
          return _StatusInfo(name, Colors.blue);
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ProServeColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ProServeColors.accent.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: ProServeColors.accent,
        ),
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
            title: 'No pros yet',
            message:
                'Once you complete a job, your contractors will appear here.',
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
                            name.isNotEmpty ? name : 'Contractor',
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
                                label: '${info.totalJobs} jobs',
                                icon: Icons.work_outline,
                              ),
                              const SizedBox(width: 8),
                              if (info.activeJobs > 0)
                                _StatChip(
                                  label: '${info.activeJobs} active',
                                  icon: Icons.timelapse,
                                  color: Colors.orange,
                                ),
                              if (info.activeJobs == 0 &&
                                  info.completedJobs > 0)
                                _StatChip(
                                  label: '${info.completedJobs} done',
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
                        label: const Text('Message'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          context.push('/contractor/${info.contractorId}');
                        },
                        icon: const Icon(Icons.person_outline, size: 16),
                        label: const Text('Profile'),
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
                        label: const Text('Rebook'),
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
            title: 'No trusted pros yet',
            message:
                'Add contractors you trust so you can find them fast, add notes, and share your list.',
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
