import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/proserve_theme.dart';
import 'service_select_page.dart';
import 'nearby_contractors_page.dart';
import 'job_detail_page.dart';
import 'conversations_list_screen.dart';
import 'browse_contractors_screen.dart';
import 'customer_analytics_screen.dart';
import 'customer_profile_screen.dart';
import 'account_profile_screen.dart';
import 'customer_ai_estimator_wizard_page.dart';
import 'landing_page.dart';
import 'submit_review_screen.dart';
import 'community_feed_screen.dart';
import 'favorite_contractors_screen.dart';
import 'referral_screen.dart';

import '../services/customer_portal_nav.dart';
import '../services/fcm_service.dart';
import '../widgets/profile_completion_card.dart';
import '../widgets/skeleton.dart';
import '../widgets/persistent_job_state_bar.dart';

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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SubmitReviewScreen(
                    contractorId: contractorId,
                    jobId: jobId,
                  ),
                ),
              );
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

  Widget _homeServiceTile({
    required BuildContext context,
    required String title,
    required IconData icon,
    String? assetSvg,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: () {
        final handler = onTap;
        if (handler != null) {
          handler();
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ServiceSelectPage()),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: ProServeColors.cardElevated,
                  border: Border.all(color: ProServeColors.line),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: assetSvg == null
                        ? Icon(icon, color: ProServeColors.accent2, size: 32)
                        : SvgPicture.asset(
                            assetSvg,
                            fit: BoxFit.contain,
                            colorFilter: const ColorFilter.mode(
                              ProServeColors.accent2,
                              BlendMode.srcIn,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    color: ProServeColors.ink,
                  ),
                ),
              ),
            ),
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
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ServiceSelectPage(),
                              ),
                            );
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
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ServiceSelectPage()),
                );
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
    final scheme = Theme.of(context).colorScheme;

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
                  tooltip: 'Profile',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CustomerProfileScreen(),
                      ),
                    );
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ServiceSelectPage(),
                        ),
                      );
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ConversationsListScreen(),
                        ),
                      );
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FavoriteContractorsScreen(),
                        ),
                      );
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ReferralScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ServiceSelectPage()),
                );
              },
              child: AbsorbPointer(
                child: TextField(
                  readOnly: true,
                  decoration: const InputDecoration(
                    hintText: 'What do you need help with?',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ProfileCompletionCard(
              onTapComplete: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AccountProfileScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Recommended for you',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.78,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _homeServiceTile(
                  context: context,
                  title: 'Interior\nPainting',
                  icon: Icons.format_paint,
                  assetSvg: 'assets/tiles/interior_painting.svg',
                ),
                _homeServiceTile(
                  context: context,
                  title: 'Drywall\nRepair',
                  icon: Icons.build,
                  assetSvg: 'assets/tiles/handyman.svg',
                ),
                _homeServiceTile(
                  context: context,
                  title: 'Cabinet\nEstimate',
                  icon: Icons.kitchen,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CustomerAiEstimatorWizardPage(
                          initialService: 'cabinet_painting',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ServiceSelectPage(),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.onSurface,
                ),
                child: const Text('Show more'),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(
          'Team',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Text(
          'This section is not set up yet.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ConversationsListScreen(),
                        ),
                      );
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
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ServiceSelectPage(),
                            ),
                          );
                        },
                        child: const Text('Start a New Request'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const CustomerAiEstimatorWizardPage(),
                            ),
                          );
                        },
                        child: const Text('AI Estimator'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CustomerAnalyticsScreen(),
                            ),
                          );
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
                                        final data = doc.data();
                                        final service =
                                            (data['service'] ?? 'Service')
                                                .toString();
                                        final location =
                                            (data['location'] ?? 'Unknown')
                                                .toString();
                                        final description =
                                            (data['description'] ?? '')
                                                .toString();

                                        final claimed = data['claimed'] == true;
                                        final claimedByName =
                                            (data['claimedByName'] as String?)
                                                ?.trim() ??
                                            '';
                                        final contractorId =
                                            (data['claimedBy'] as String?)
                                                ?.trim() ??
                                            '';
                                        final canReview = _canLeaveReview(data);
                                        final createdAt = _formatTimestamp(
                                          data['createdAt'],
                                        );
                                        final claimedAt = _formatTimestamp(
                                          data['claimedAt'],
                                        );

                                        final statusText = claimed
                                            ? (claimedByName.isNotEmpty
                                                  ? 'Assigned: $claimedByName'
                                                  : 'Assigned')
                                            : 'Pending';

                                        return Card(
                                          child: Column(
                                            children: [
                                              ListTile(
                                                title: Text(service),
                                                subtitle: Text(
                                                  [
                                                    'Location: $location',
                                                    statusText,
                                                    if (claimedAt.isNotEmpty)
                                                      'Assigned at: $claimedAt',
                                                    if (claimedAt.isEmpty &&
                                                        createdAt.isNotEmpty)
                                                      'Created at: $createdAt',
                                                    if (description
                                                        .trim()
                                                        .isNotEmpty)
                                                      'Notes: ${description.trim()}',
                                                  ].join('\n'),
                                                ),
                                                isThreeLine: true,
                                                onTap: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          JobDetailPage(
                                                            jobId: doc.id,
                                                            jobData: data,
                                                          ),
                                                    ),
                                                  );
                                                },
                                              ),
                                              if (canReview)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                        12,
                                                        0,
                                                        12,
                                                        12,
                                                      ),
                                                  child: _buildReviewAction(
                                                    context: context,
                                                    jobId: doc.id,
                                                    contractorId: contractorId,
                                                  ),
                                                ),
                                            ],
                                          ),
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
                            final data = doc.data();
                            final service = (data['service'] ?? 'Service')
                                .toString();
                            final location = (data['location'] ?? 'Unknown')
                                .toString();
                            final description = (data['description'] ?? '')
                                .toString();
                            final zip =
                                (data['zip'] ??
                                        data['zipcode'] ??
                                        data['jobZip'] ??
                                        '')
                                    .toString()
                                    .trim();

                            final claimed = data['claimed'] == true;
                            final claimedByName =
                                (data['claimedByName'] as String?)?.trim() ??
                                '';
                            final contractorId =
                                (data['claimedBy'] as String?)?.trim() ?? '';
                            final canReview = _canLeaveReview(data);
                            final createdAt = _formatTimestamp(
                              data['createdAt'],
                            );
                            final claimedAt = _formatTimestamp(
                              data['claimedAt'],
                            );

                            final statusText = claimed
                                ? (claimedByName.isNotEmpty
                                      ? 'Assigned: $claimedByName'
                                      : 'Assigned')
                                : 'Pending';

                            return Card(
                              child: Column(
                                children: [
                                  ListTile(
                                    title: Text(service),
                                    subtitle: Text(
                                      [
                                        'Location: $location',
                                        statusText,
                                        if (claimedAt.isNotEmpty)
                                          'Assigned at: $claimedAt',
                                        if (claimedAt.isEmpty &&
                                            createdAt.isNotEmpty)
                                          'Created at: $createdAt',
                                        if (description.trim().isNotEmpty)
                                          'Notes: ${description.trim()}',
                                      ].join('\n'),
                                    ),
                                    isThreeLine: true,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => JobDetailPage(
                                            jobId: doc.id,
                                            jobData: data,
                                          ),
                                        ),
                                      );
                                    },
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        StreamBuilder<
                                          DocumentSnapshot<Map<String, dynamic>>
                                        >(
                                          stream: FirebaseFirestore.instance
                                              .collection('chats')
                                              .doc(doc.id)
                                              .snapshots(),
                                          builder: (context, chatSnap) {
                                            final chatData = chatSnap.data
                                                ?.data();
                                            final unreadRaw =
                                                chatData?['unread'];
                                            final unreadMap = unreadRaw is Map
                                                ? unreadRaw.map(
                                                    (k, v) => MapEntry(
                                                      k.toString(),
                                                      v,
                                                    ),
                                                  )
                                                : <String, dynamic>{};

                                            final me = FirebaseAuth
                                                .instance
                                                .currentUser
                                                ?.uid;
                                            final unreadMeRaw = me == null
                                                ? null
                                                : unreadMap[me];
                                            final unreadMe = unreadMeRaw is num
                                                ? unreadMeRaw.toInt()
                                                : 0;

                                            if (unreadMe <= 0) {
                                              return const SizedBox.shrink();
                                            }

                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                right: 8,
                                              ),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.error,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                ),
                                                child: Text(
                                                  unreadMe.toString(),
                                                  style: TextStyle(
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.onError,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        if (zip.isNotEmpty)
                                          IconButton(
                                            tooltip: 'Nearby Contractors',
                                            icon: const Icon(
                                              Icons.near_me_outlined,
                                            ),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      NearbyContractorsPage(
                                                        jobZip: zip,
                                                      ),
                                                ),
                                              );
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (canReview)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        0,
                                        12,
                                        12,
                                      ),
                                      child: _buildReviewAction(
                                        context: context,
                                        jobId: doc.id,
                                        contractorId: contractorId,
                                      ),
                                    ),
                                ],
                              ),
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
