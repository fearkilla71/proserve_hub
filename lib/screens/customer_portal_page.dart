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

enum _CustomerProjectFilter { active, quotes, protected, completed, all }

class CustomerPortalPage extends StatefulWidget {
  const CustomerPortalPage({super.key});

  @override
  State<CustomerPortalPage> createState() => _CustomerPortalPageState();
}

class _CustomerPortalPageState extends State<CustomerPortalPage>
    with SingleTickerProviderStateMixin {
  int _tabIndex = 0;
  _CustomerProjectFilter _projectFilter = _CustomerProjectFilter.active;

  Future<_RequestsFetchResult>? _myRequestsDiagnose;
  late final AnimationController _homeIntroController;
  late final Animation<double> _heroFade;
  late final Animation<Offset> _heroSlide;

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

  Widget _tabScaffold({required Widget child, Widget? fab}) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: child,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: const PersistentJobStateBar(role: JobBarRole.customer),
          ),
        ],
      ),
      floatingActionButton: fab == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: fab,
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: NavigationBar(
        height: 76,
        backgroundColor: ProServeColors.bgDeep,
        surfaceTintColor: Colors.transparent,
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
              child: _CustomerActionCenter(
                userId: user.uid,
                requestsQuery: _myRequestsQuery(user.uid),
                canLeaveReview: _canLeaveReview,
                onStartProject: () => context.push('/smart-request'),
                onProjectTab: () => setState(() => _tabIndex = 2),
              ),
              fade: _heroFade,
              slide: _heroSlide,
            ),
            const SizedBox(height: 12),
            _CustomerShortcutPanel(
              title: l10n.customerCoreFlowTitle,
              subtitle: l10n.customerCoreFlowSubtitle,
              children: [
                Expanded(
                  child: _CustomerShortcutTile(
                    title: l10n.messages,
                    icon: Icons.chat_bubble_outline,
                    onTap: () {
                      context.push('/conversations');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CustomerShortcutTile(
                    title: l10n.browsePros,
                    icon: Icons.search,
                    onTap: () {
                      setState(() => _tabIndex = 1);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CustomerShortcutTile(
                    title: l10n.projectTracker,
                    icon: Icons.receipt_long,
                    onTap: () {
                      setState(() => _tabIndex = 2);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _CustomerMoreToolsSection(
              quickActionTile: _quickActionTile,
              parentContext: context,
            ),
            const SizedBox(height: 12),
            const EscrowBookingsCard(isCustomer: true),
            const SizedBox(height: 12),
            const MaintenanceReminderCard(),
            const SizedBox(height: 12),
            const SeasonalDealsCarousel(),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 0),
              child: NeighborhoodSocialProof(),
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
            child: IndexedStack(
              index: _tabIndex,
              children: [
                _buildHomeTab(context: context, user: user),
                _buildSearchTab(context),
                _buildProjectsTab(context: context, user: user),
                _buildTeamTab(context),
                const CommunityFeedScreen(title: 'Project Gallery'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProjectsTab({required BuildContext context, required User user}) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _myRequestsQuery(user.uid).snapshots(
            includeMetadataChanges: true,
          ),
          builder: (context, jobsSnap) {
            if (jobsSnap.hasError) {
              return _ProjectStateCard(
                icon: Icons.error_outline,
                title: l10n.couldNotLoadRequests,
                body: _prettyFirestoreError(jobsSnap.error!),
                actionLabel: l10n.retry,
                onAction: _retryMyRequests,
              );
            }

            if (!jobsSnap.hasData) {
              return FutureBuilder<void>(
                future: Future<void>.delayed(const Duration(seconds: 6)),
                builder: (context, delaySnap) {
                  if (delaySnap.connectionState != ConnectionState.done) {
                    return Column(
                      children: const [
                        SkeletonCard(),
                        SkeletonCard(),
                        SkeletonCard(),
                      ],
                    );
                  }

                  _myRequestsDiagnose ??= _runMyRequestsDiagnosticFetch(
                    user.uid,
                  );

                  return FutureBuilder<_RequestsFetchResult>(
                    future: _myRequestsDiagnose,
                    builder: (context, diagSnap) {
                      if (diagSnap.connectionState != ConnectionState.done) {
                        return Column(
                          children: const [SkeletonCard(), SkeletonCard()],
                        );
                      }
                      if (diagSnap.hasError) {
                        return _ProjectStateCard(
                          icon: Icons.cloud_off_outlined,
                          title: l10n.stillLoadingRequests,
                          body: _prettyFirestoreError(diagSnap.error!),
                          actionLabel: l10n.retry,
                          onAction: _retryMyRequests,
                        );
                      }
                      final docs = _sortedProjectDocs(
                        diagSnap.data?.docs ?? const [],
                      );
                      return _buildProjectContent(
                        context: context,
                        docs: docs,
                        usedFallback: diagSnap.data?.usedFallback == true,
                        isFromCache: false,
                      );
                    },
                  );
                },
              );
            }

            final docs = _sortedProjectDocs(jobsSnap.data!.docs);
            return _buildProjectContent(
              context: context,
              docs: docs,
              usedFallback: false,
              isFromCache: jobsSnap.data!.metadata.isFromCache,
            );
          },
        ),
      ],
    );
  }

  Widget _buildProjectContent({
    required BuildContext context,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required bool usedFallback,
    required bool isFromCache,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final filtered = docs.where((doc) => _matchesProjectFilter(doc.data()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProjectHeaderCard(
          activeCount: docs.where((doc) => _isActiveProject(doc.data())).length,
          quotesCount: docs.where((doc) => _hasWaitingQuotes(doc.data())).length,
          protectedCount: docs
              .where((doc) => _hasProtectedPayment(doc.data()))
              .length,
          reviewCount: docs.where((doc) => _canLeaveReview(doc.data())).length,
          onNewProject: () => context.push('/select-service'),
        ),
        const SizedBox(height: 12),
        _ProjectFilterBar(
          selected: _projectFilter,
          labelFor: (filter) => _projectFilterLabel(l10n, filter),
          onSelected: (filter) {
            setState(() => _projectFilter = filter);
          },
        ),
        const SizedBox(height: 12),
        if (usedFallback)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.showingLegacyRequests,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (isFromCache)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ProjectNotice(message: l10n.projectOfflineCached),
          ),
        if (docs.isEmpty)
          _ProjectStateCard(
            icon: Icons.folder_open_outlined,
            title: l10n.noRequestsYet,
            body: l10n.noRequestsYetSubtitle,
            actionLabel: l10n.customerStartProject,
            onAction: () => context.push('/smart-request'),
          )
        else if (filtered.isEmpty)
          _ProjectStateCard(
            icon: Icons.filter_alt_off_outlined,
            title: _projectEmptyTitle(l10n),
            body: _projectEmptyBody(l10n),
            actionLabel: l10n.projectFilterAll,
            onAction: () {
              setState(() => _projectFilter = _CustomerProjectFilter.all);
            },
          )
        else
          ...filtered.map(
            (doc) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildRequestCard(
                context: context,
                docId: doc.id,
                data: doc.data(),
              ),
            ),
          ),
        const SizedBox(height: 4),
        _ProjectToolsSection(
          onEstimator: () => context.push('/ai-estimator'),
          onAnalytics: () => context.push('/customer-analytics'),
        ),
      ],
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortedProjectDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final activeDocs = docs.where((d) {
      final s = (d.data()['status'] ?? '').toString().toLowerCase();
      return s != 'cancelled' && s != 'deleted';
    }).toList();
    activeDocs.sort((a, b) {
      final at = a.data()['createdAt'];
      final bt = b.data()['createdAt'];
      final aMs = at is Timestamp ? at.millisecondsSinceEpoch : 0;
      final bMs = bt is Timestamp ? bt.millisecondsSinceEpoch : 0;
      return bMs.compareTo(aMs);
    });
    return activeDocs;
  }

  bool _matchesProjectFilter(Map<String, dynamic> data) {
    switch (_projectFilter) {
      case _CustomerProjectFilter.active:
        return _isActiveProject(data);
      case _CustomerProjectFilter.quotes:
        return _hasWaitingQuotes(data);
      case _CustomerProjectFilter.protected:
        return _hasProtectedPayment(data);
      case _CustomerProjectFilter.completed:
        return _isCompletedProject(data);
      case _CustomerProjectFilter.all:
        return true;
    }
  }

  bool _isActiveProject(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString().toLowerCase();
    return !_isCompletedProject(data) &&
        status != 'cancelled' &&
        status != 'deleted';
  }

  bool _hasWaitingQuotes(Map<String, dynamic> data) {
    final quoteCount = (data['quoteCount'] as num?)?.toInt() ?? 0;
    return quoteCount > 0 && data['claimed'] != true;
  }

  bool _hasProtectedPayment(Map<String, dynamic> data) {
    return (data['escrowId'] ?? '').toString().trim().isNotEmpty ||
        data['instantBook'] == true;
  }

  bool _isCompletedProject(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString().toLowerCase();
    return status == 'completed' ||
        status == 'completion_approved' ||
        status == 'released';
  }

  String _projectFilterLabel(
    AppLocalizations l10n,
    _CustomerProjectFilter filter,
  ) {
    switch (filter) {
      case _CustomerProjectFilter.active:
        return l10n.projectFilterActive;
      case _CustomerProjectFilter.quotes:
        return l10n.projectFilterQuotes;
      case _CustomerProjectFilter.protected:
        return l10n.projectFilterProtected;
      case _CustomerProjectFilter.completed:
        return l10n.projectFilterCompleted;
      case _CustomerProjectFilter.all:
        return l10n.projectFilterAll;
    }
  }

  String _projectEmptyTitle(AppLocalizations l10n) {
    switch (_projectFilter) {
      case _CustomerProjectFilter.active:
        return l10n.projectEmptyActiveTitle;
      case _CustomerProjectFilter.quotes:
        return l10n.projectEmptyQuotesTitle;
      case _CustomerProjectFilter.protected:
        return l10n.projectEmptyProtectedTitle;
      case _CustomerProjectFilter.completed:
        return l10n.projectEmptyCompletedTitle;
      case _CustomerProjectFilter.all:
        return l10n.noRequestsYet;
    }
  }

  String _projectEmptyBody(AppLocalizations l10n) {
    switch (_projectFilter) {
      case _CustomerProjectFilter.active:
        return l10n.projectEmptyActiveBody;
      case _CustomerProjectFilter.quotes:
        return l10n.projectEmptyQuotesBody;
      case _CustomerProjectFilter.protected:
        return l10n.projectEmptyProtectedBody;
      case _CustomerProjectFilter.completed:
        return l10n.projectEmptyCompletedBody;
      case _CustomerProjectFilter.all:
        return l10n.noRequestsYetSubtitle;
    }
  }

  // ────────────────── Request Card Builder ──────────────────────

  Widget _buildRequestCard({
    required BuildContext context,
    required String docId,
    required Map<String, dynamic> data,
  }) {
    final l10n = AppLocalizations.of(context)!;
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
    final quoteCount = (data['quoteCount'] as num?)?.toInt() ?? 0;

    final statusInfo = _getStatusInfo(
      status,
      claimed,
      claimedByName,
      isEscrow: isEscrow,
    );
    final dateLabel = claimedAt.isNotEmpty
        ? '${l10n.projectAssignedLabel}: $claimedAt'
        : (createdAt.isNotEmpty
              ? '${l10n.projectCreatedLabel}: $createdAt'
              : '');
    final primaryLabel = canReview
        ? l10n.projectLeaveReview
        : escrowId.isNotEmpty
        ? l10n.projectCheckPayment
        : quoteCount > 0 && !claimed
        ? l10n.projectCompareQuotes
        : _isCompletedProject(data)
        ? l10n.projectViewSummary
        : claimed || status == 'accepted' || status == 'in_progress'
        ? l10n.projectOpenCommandCenter
        : l10n.projectViewProject;
    final primaryIcon = canReview
        ? Icons.rate_review_outlined
        : escrowId.isNotEmpty
        ? Icons.shield_outlined
        : quoteCount > 0 && !claimed
        ? Icons.compare_arrows_outlined
        : Icons.dashboard_customize_outlined;
    final primaryRoute = canReview
        ? '/submit-review/$docId/$contractorId'
        : escrowId.isNotEmpty
        ? '/escrow-status/$escrowId'
        : quoteCount > 0 && !claimed
        ? '/quotes/$docId'
        : '/job-command/$docId';

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.push('/job-command/$docId'),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ProServeColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ProServeColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      if (dateLabel.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          dateLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: ProServeColors.muted),
                        ),
                      ],
                    ],
                  ),
                ),
                _ProjectStatusChip(label: statusInfo.label, color: statusInfo.color),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ProjectInfoPill(
                  icon: Icons.place_outlined,
                  text: '${l10n.projectLocationLabel}: $location',
                ),
                if (quoteCount > 0)
                  _ProjectInfoPill(
                    icon: Icons.request_quote_outlined,
                    text: '$quoteCount ${l10n.quotes}',
                  ),
                if (claimedByName.isNotEmpty)
                  _ProjectInfoPill(
                    icon: Icons.handshake_outlined,
                    text: '${l10n.projectContractorLabel}: $claimedByName',
                  ),
                if (isEscrow)
                  _ProjectInfoPill(
                    icon: Icons.shield_outlined,
                    text: escrowPrice is num
                        ? '${l10n.escrow}: ${NumberFormat.simpleCurrency().format(escrowPrice)}'
                        : l10n.projectProtectedPayment,
                  ),
              ],
            ),
            if (description.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                description.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: ProServeColors.muted),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
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
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _ProjectInfoPill(
                        icon: Icons.mark_chat_unread_outlined,
                        text: '$unreadMe ${l10n.messages}',
                      ),
                    );
                  },
                ),
                if (zip.isNotEmpty)
                  IconButton(
                    tooltip: l10n.projectNearbyContractors,
                    icon: const Icon(
                      Icons.near_me_outlined,
                      size: 20,
                      color: ProServeColors.muted,
                    ),
                    onPressed: () => context.push('/nearby-contractors/$zip'),
                    visualDensity: VisualDensity.compact,
                  ),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () => context.push(primaryRoute),
                      icon: Icon(primaryIcon, size: 18),
                      label: Text(primaryLabel, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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

class _ProjectHeaderCard extends StatelessWidget {
  const _ProjectHeaderCard({
    required this.activeCount,
    required this.quotesCount,
    required this.protectedCount,
    required this.reviewCount,
    required this.onNewProject,
  });

  final int activeCount;
  final int quotesCount;
  final int protectedCount;
  final int reviewCount;
  final VoidCallback onNewProject;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.customerProjectsTitle,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.customerProjectsSubtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ProServeColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: onNewProject,
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: Text(l10n.projectNewProject),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ProjectMetricPill(
                value: activeCount,
                label: l10n.projectFilterActive,
                icon: Icons.work_outline,
              ),
              _ProjectMetricPill(
                value: quotesCount,
                label: l10n.projectFilterQuotes,
                icon: Icons.request_quote_outlined,
              ),
              _ProjectMetricPill(
                value: protectedCount,
                label: l10n.projectFilterProtected,
                icon: Icons.shield_outlined,
              ),
              _ProjectMetricPill(
                value: reviewCount,
                label: l10n.customerReviewsDue,
                icon: Icons.star_outline,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProjectMetricPill extends StatelessWidget {
  const _ProjectMetricPill({
    required this.value,
    required this.label,
    required this.icon,
  });

  final int value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ProServeColors.bgDeep.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ProServeColors.lineStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: ProServeColors.accent2),
          const SizedBox(width: 6),
          Text(
            '$value $label',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: ProServeColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectFilterBar extends StatelessWidget {
  const _ProjectFilterBar({
    required this.selected,
    required this.labelFor,
    required this.onSelected,
  });

  final _CustomerProjectFilter selected;
  final String Function(_CustomerProjectFilter filter) labelFor;
  final ValueChanged<_CustomerProjectFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _CustomerProjectFilter.values.map((filter) {
          final selectedFilter = selected == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(labelFor(filter)),
              selected: selectedFilter,
              onSelected: (_) => onSelected(filter),
              backgroundColor: ProServeColors.card,
              selectedColor: ProServeColors.accent.withValues(alpha: 0.18),
              side: BorderSide(
                color: selectedFilter
                    ? ProServeColors.accent
                    : ProServeColors.lineStrong,
              ),
              labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selectedFilter
                    ? ProServeColors.accent
                    : ProServeColors.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ProjectStateCard extends StatelessWidget {
  const _ProjectStateCard({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ProServeColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ProServeColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: ProServeColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: ProServeColors.accent),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: ProServeColors.muted),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.arrow_forward),
                label: Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProjectNotice extends StatelessWidget {
  const _ProjectNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ProServeColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ProServeColors.warning.withValues(alpha: 0.26)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 18,
            color: ProServeColors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ProServeColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectToolsSection extends StatelessWidget {
  const _ProjectToolsSection({
    required this.onEstimator,
    required this.onAnalytics,
  });

  final VoidCallback onEstimator;
  final VoidCallback onAnalytics;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: ProServeColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ProServeColors.line),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: const Icon(
            Icons.construction_outlined,
            color: ProServeColors.accent,
          ),
          title: Text(
            l10n.projectToolsTitle,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(l10n.projectToolsSubtitle),
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEstimator,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: Text(l10n.aiEstimator),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onAnalytics,
                    icon: const Icon(Icons.query_stats_outlined),
                    label: Text(l10n.analytics),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const EscrowBookingsCard(isCustomer: true),
          ],
        ),
      ),
    );
  }
}

class _ProjectStatusChip extends StatelessWidget {
  const _ProjectStatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ProjectInfoPill extends StatelessWidget {
  const _ProjectInfoPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: ProServeColors.bgDeep.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ProServeColors.lineStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: ProServeColors.accent2),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: ProServeColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerShortcutPanel extends StatelessWidget {
  const _CustomerShortcutPanel({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ProServeColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ProServeColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: ProServeColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: ProServeColors.muted),
          ),
          const SizedBox(height: 12),
          Row(children: children),
        ],
      ),
    );
  }
}

class _CustomerShortcutTile extends StatelessWidget {
  const _CustomerShortcutTile({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 78,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: ProServeColors.bgDeep.withValues(alpha: 0.40),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ProServeColors.lineStrong),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: ProServeColors.accent, size: 22),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: ProServeColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerMoreToolsSection extends StatelessWidget {
  const _CustomerMoreToolsSection({
    required this.quickActionTile,
    required this.parentContext,
  });

  final Widget Function({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  })
  quickActionTile;
  final BuildContext parentContext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(parentContext)!;
    return Container(
      decoration: BoxDecoration(
        color: ProServeColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ProServeColors.line),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: const Icon(
            Icons.apps_outlined,
            color: ProServeColors.accent,
          ),
          title: Text(
            l10n.customerMoreToolsTitle,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(l10n.customerMoreToolsSubtitle),
          children: [
            Row(
              children: [
                Expanded(
                  child: quickActionTile(
                    context: parentContext,
                    title: l10n.savedPros,
                    subtitle: l10n.customerQuickSavedProsSubtitle,
                    icon: Icons.favorite_border,
                    onTap: () => parentContext.push('/favorites'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: quickActionTile(
                    context: parentContext,
                    title: l10n.referral,
                    subtitle: l10n.customerQuickReferralSubtitle,
                    icon: Icons.card_giftcard,
                    onTap: () => parentContext.push('/referral'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: quickActionTile(
                    context: parentContext,
                    title: l10n.loyalty,
                    subtitle: l10n.customerQuickLoyaltySubtitle,
                    icon: Icons.loyalty_outlined,
                    onTap: () => parentContext.push('/loyalty-rewards'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: quickActionTile(
                    context: parentContext,
                    title: l10n.leaderboard,
                    subtitle: l10n.customerQuickLeaderboardSubtitle,
                    icon: Icons.emoji_events_outlined,
                    onTap: () => parentContext.push('/leaderboard'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: quickActionTile(
                    context: parentContext,
                    title: l10n.savedProjects,
                    subtitle: l10n.customerQuickSavedProjectsSubtitle,
                    icon: Icons.dashboard_customize_outlined,
                    onTap: () => parentContext.push('/project-boards'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: quickActionTile(
                    context: parentContext,
                    title: l10n.myEstimates,
                    subtitle: l10n.customerQuickMyEstimatesSubtitle,
                    icon: Icons.calculate_outlined,
                    onTap: () => parentContext.push('/saved-estimates'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            quickActionTile(
              context: parentContext,
              title: l10n.aiSupport,
              subtitle: l10n.customerQuickAiSupportSubtitle,
              icon: Icons.support_agent,
              onTap: () => parentContext.push('/ai-support-chat'),
            ),
          ],
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
    required this.onStartProject,
    required this.onProjectTab,
  });

  final String userId;
  final Query<Map<String, dynamic>> requestsQuery;
  final bool Function(Map<String, dynamic> data) canLeaveReview;
  final VoidCallback onStartProject;
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

        final topItem = actionable.isNotEmpty ? actionable.first : null;
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
        final reviewsDue = docs.where((doc) => canLeaveReview(doc.data())).length;
        final latestProject = docs.isNotEmpty ? docs.first : null;

        return Container(
          decoration: BoxDecoration(
            gradient: ProServeColors.cardGradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ProServeColors.lineStrong),
          ),
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
                            l10n.customerTodayTitle,
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
                      label: l10n.customerActiveProjects,
                    ),
                    _ActionMetricChip(
                      value: pendingQuotes.toString(),
                      label: l10n.customerQuotesWaiting,
                    ),
                    _ActionMetricChip(
                      value: protectedJobs.toString(),
                      label: l10n.customerProtectedPayments,
                    ),
                    _ActionMetricChip(
                      value: reviewsDue.toString(),
                      label: l10n.customerReviewsDue,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const LinearProgressIndicator()
                else if (docs.isEmpty)
                  _EmptyCustomerAction(onStartProject: onStartProject)
                else if (topItem == null)
                  _ActionCenterAllClear(onProjectTab: onProjectTab)
                else
                  _CustomerActionTile(item: topItem, prominent: true),
                if (latestProject != null) ...[
                  const SizedBox(height: 10),
                  _RecentCustomerProjectCard(
                    doc: latestProject,
                    onTap: () => context.push('/job-command/${latestProject.id}'),
                  ),
                ],
                if (openJobs > 0 && pendingQuotes == 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.customerActionCenterNoQuotesTip,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
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
  const _CustomerActionTile({required this.item, this.prominent = false});

  final _CustomerActionItem item;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push(item.route),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: prominent
              ? ProServeColors.accent.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: prominent
                ? ProServeColors.accent.withValues(alpha: 0.32)
                : scheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: ProServeColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: ProServeColors.accent, size: 20),
            ),
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
            const Icon(Icons.chevron_right, color: ProServeColors.muted),
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
      backgroundColor: ProServeColors.bgDeep.withValues(alpha: 0.40),
      side: BorderSide(color: ProServeColors.lineStrong),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: ProServeColors.ink,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _EmptyCustomerAction extends StatelessWidget {
  const _EmptyCustomerAction({required this.onStartProject});

  final VoidCallback onStartProject;

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
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ProServeColors.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: ProServeColors.accent.withValues(alpha: 0.20),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.shield_outlined,
                color: ProServeColors.accent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.customerActionEmptyTrust,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ProServeColors.ink,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: onStartProject,
          icon: const Icon(Icons.add_circle_outline),
          label: Text(l10n.customerStartProject),
        ),
      ],
    );
  }
}

class _RecentCustomerProjectCard extends StatelessWidget {
  const _RecentCustomerProjectCard({required this.doc, required this.onTap});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final service = (data['service'] ?? 'Project').toString();
    final status = (data['status'] ?? 'open').toString().replaceAll('_', ' ');
    final quoteCount = (data['quoteCount'] as num?)?.toInt() ?? 0;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ProServeColors.bgDeep.withValues(alpha: 0.36),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ProServeColors.lineStrong),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: ProServeColors.accent2.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.folder_open_outlined,
                color: ProServeColors.accent2,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    quoteCount > 0
                        ? '$quoteCount quotes waiting'
                        : 'Status: $status',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ProServeColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: ProServeColors.muted),
          ],
        ),
      ),
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
