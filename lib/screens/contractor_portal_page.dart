import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'job_detail_page.dart';
import 'job_feed_page.dart';
import 'conversations_list_screen.dart';
import 'verification_screen.dart';
import 'contractor_analytics_screen.dart';
import 'availability_calendar_screen.dart';
import 'service_area_screen.dart';
import 'portfolio_screen.dart';
import 'business_profile_screen.dart';
import 'contractor_login_page.dart';
import 'qanda_screen.dart';
import 'pricing_calculator_screen.dart';
import 'cost_estimator_screen.dart';
import 'render_tool_screen.dart';
import 'invoice_maker_screen.dart';
import 'contractor_profile_screen.dart';
import 'account_profile_screen.dart';
import 'payment_history_screen.dart';
import 'contractor_subscription_screen.dart';
import 'contractor_subcontract_board_screen.dart';
import 'community_feed_screen.dart';

import '../services/fcm_service.dart';
import '../widgets/animated_states.dart';
import '../widgets/contractor_card.dart';
import '../widgets/page_header.dart';
import '../widgets/profile_completion_card.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/persistent_job_state_bar.dart';

class ContractorPortalPage extends StatefulWidget {
  const ContractorPortalPage({super.key});

  @override
  State<ContractorPortalPage> createState() => _ContractorPortalPageState();
}

class _ContractorPortalPageState extends State<ContractorPortalPage> {
  int _tabIndex = 0;

  bool _pricingToolsUnlockedFromUserDoc(Map<String, dynamic>? data) {
    if (data == null) return false;
    return data['pricingToolsPro'] == true ||
        data['contractorPro'] == true ||
        data['isPro'] == true;
  }

  String _formatTimestamp(dynamic ts) {
    if (ts is Timestamp) {
      return DateFormat.yMMMd().add_jm().format(ts.toDate());
    }
    return '';
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
      unlocked = _pricingToolsUnlockedFromUserDoc(snap.data());
    } catch (_) {
      // Best-effort.
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
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contractor Pro required',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  'Unlock the Pricing Calculator, Cost Estimator, and Render Tool with Contractor Pro.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Not now'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Subscribe'),
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
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ContractorSubscriptionScreen()),
      );
    }
  }

  Future<void> _showToolsQuickActions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final rootContext = this.context;
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            shrinkWrap: true,
            children: [
              Text(
                'Tools',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.auto_awesome_outlined),
                      ),
                      title: const Text('AI Invoice Maker'),
                      subtitle: const Text(
                        'Generate line items and export PDF',
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        await _openPricingToolsOrSubscribe(
                          open: () async {
                            Navigator.push(
                              rootContext,
                              MaterialPageRoute(
                                builder: (_) => const InvoiceMakerScreen(),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.calculate)),
                      title: const Text('Pricing Calculator'),
                      onTap: () async {
                        Navigator.pop(context);
                        await _openPricingToolsOrSubscribe(
                          open: () async {
                            Navigator.push(
                              rootContext,
                              MaterialPageRoute(
                                builder: (_) => const PricingCalculatorScreen(),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.receipt_long),
                      ),
                      title: const Text('Cost Estimator'),
                      onTap: () async {
                        Navigator.pop(context);
                        await _openPricingToolsOrSubscribe(
                          open: () async {
                            showDialog(
                              context: rootContext,
                              builder: (context) => AlertDialog(
                                title: const Text('Select Service Type'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children:
                                      [
                                        'Interior Painting',
                                        'Exterior Painting',
                                        'Cabinet Painting',
                                        'Drywall Repair',
                                        'Pressure Washing',
                                      ].map((service) {
                                        return ListTile(
                                          title: Text(service),
                                          onTap: () {
                                            Navigator.pop(context);
                                            Navigator.push(
                                              rootContext,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    CostEstimatorScreen(
                                                      serviceType: service,
                                                    ),
                                              ),
                                            );
                                          },
                                        );
                                      }).toList(),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.palette_outlined),
                      ),
                      title: const Text('Render Tool'),
                      subtitle: const Text('Preview wall colors on photos'),
                      onTap: () async {
                        Navigator.pop(context);
                        await _openPricingToolsOrSubscribe(
                          open: () async {
                            Navigator.push(
                              rootContext,
                              MaterialPageRoute(
                                builder: (_) => const RenderToolScreen(),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.workspace_premium),
                      ),
                      title: const Text('Subscribe (\$11.99/mo)'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          rootContext,
                          MaterialPageRoute(
                            builder: (_) =>
                                const ContractorSubscriptionScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statusPill({
    required BuildContext context,
    required String label,
    required IconData icon,
    Color? sideColor,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final borderColor = sideColor ?? scheme.outlineVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: sideColor ?? scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
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
            child: const PersistentJobStateBar(role: JobBarRole.contractor),
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
            label: 'Jobs',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Plan',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_outlined),
            selectedIcon: Icon(Icons.build),
            label: 'Tools',
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
    final scheme = Theme.of(context).colorScheme;
    final themeKey =
        (data?['cardTheme'] as String?)?.trim().toLowerCase() ?? 'navy';
    final defaultGradient = _defaultGradientForTheme(themeKey, scheme);
    final gradientStart = _colorFromDoc(
      data?['gradientStart'],
      defaultGradient[0],
    );
    final gradientEnd = _colorFromDoc(data?['gradientEnd'], defaultGradient[1]);
    final displayName =
        (data?['publicName'] as String?)?.trim().isNotEmpty == true
        ? (data?['publicName'] as String).trim()
        : ((data?['businessName'] as String?)?.trim().isNotEmpty == true
              ? (data?['businessName'] as String).trim()
              : ((data?['companyName'] as String?)?.trim().isNotEmpty == true
                    ? (data?['companyName'] as String).trim()
                    : ((data?['name'] as String?)?.trim().isNotEmpty == true
                          ? (data?['name'] as String).trim()
                          : fallbackName)));
    final phone = (data?['publicPhone'] as String?)?.trim() ?? '';
    final headline = (data?['headline'] as String?)?.trim() ?? '';
    final bio = (data?['bio'] as String?)?.trim() ?? '';
    final logoUrl = (data?['logoUrl'] as String?)?.trim() ?? '';
    final avatarStyle = (data?['avatarStyle'] as String?)?.trim() ?? 'monogram';
    final avatarShape = (data?['avatarShape'] as String?)?.trim() ?? 'circle';
    final texture = (data?['cardTexture'] as String?)?.trim() ?? 'none';
    final textureOpacityRaw = data?['textureOpacity'];
    final textureOpacity = textureOpacityRaw is num
        ? textureOpacityRaw.toDouble().clamp(0.04, 0.5)
        : 0.12;
    final showBanner = data?['showBanner'] as bool? ?? true;
    final bannerIcon = (data?['bannerIcon'] as String?)?.trim() ?? 'spark';
    final avatarGlow = data?['avatarGlow'] as bool? ?? false;
    final avgRating = (data?['avgRating'] ?? data?['averageRating']);
    final ratingValue = avgRating is num ? avgRating.toDouble() : 0.0;
    final reviewCountRaw = data?['reviewCount'] ?? data?['totalReviews'];
    final reviewCount = reviewCountRaw is num ? reviewCountRaw.toInt() : 0;
    final yearsExpRaw = data?['yearsExperience'];
    final yearsExp = yearsExpRaw is num ? yearsExpRaw.toInt() : 0;
    final badges =
        (data?['badges'] as List?)
            ?.whereType<String>()
            .map((badge) => badge.trim())
            .where((badge) => badge.isNotEmpty)
            .toList() ??
        <String>[];
    final totalJobsRaw = data?['totalJobsCompleted'];
    final totalJobsCompleted = totalJobsRaw is num ? totalJobsRaw.toInt() : 0;

    final reviewStream = FirebaseFirestore.instance
        .collection('reviews')
        .where('contractorId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: reviewStream,
      builder: (context, reviewSnap) {
        String latestReview = '';
        if (reviewSnap.hasData && reviewSnap.data!.docs.isNotEmpty) {
          final review = reviewSnap.data!.docs.first.data();
          latestReview = (review['comment'] as String?)?.trim() ?? '';
        }

        return ContractorCard(
          data: ContractorCardData(
            displayName: displayName,
            contactLine: phone.isNotEmpty ? phone : (user.email ?? ''),
            logoUrl: logoUrl,
            headline: headline,
            bio: bio,
            ratingValue: ratingValue,
            reviewCount: reviewCount,
            yearsExp: yearsExp,
            badges: badges,
            themeKey: themeKey,
            gradientStart: gradientStart,
            gradientEnd: gradientEnd,
            avatarStyle: avatarStyle,
            avatarShape: avatarShape,
            texture: texture,
            textureOpacity: textureOpacity,
            showBanner: showBanner,
            bannerIcon: bannerIcon,
            avatarGlow: avatarGlow,
            latestReview: latestReview,
            totalJobsCompleted: totalJobsCompleted,
          ),
          onEdit: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AccountProfileScreen()),
            );
          },
        );
      },
    );
  }

  List<Color> _defaultGradientForTheme(String themeKey, ColorScheme scheme) {
    switch (themeKey) {
      case 'forest':
        return const [Color(0xFF0F3D2E), Color(0xFF3BAA6B)];
      case 'amber':
        return const [Color(0xFF4E2A0C), Color(0xFFFFA726)];
      case 'slate':
        return const [Color(0xFF1F2937), Color(0xFF94A3B8)];
      case 'ocean':
        return const [Color(0xFF0F172A), Color(0xFF38BDF8)];
      case 'rose':
        return const [Color(0xFF4C0519), Color(0xFFFB7185)];
      case 'sunburst':
        return const [Color(0xFF2C1200), Color(0xFFFF6D00)];
      case 'ember':
        return const [Color(0xFF2B0C0C), Color(0xFFFF7043)];
      case 'neon':
        return const [Color(0xFF051A13), Color(0xFF00E676)];
      case 'carbon':
        return const [Color(0xFF111827), Color(0xFF374151)];
      case 'gold':
        return const [Color(0xFF3A2A00), Color(0xFFFFD54F)];
      case 'navy':
      default:
        return [scheme.primary.withValues(alpha: 0.9), scheme.primary];
    }
  }

  Color _colorFromDoc(dynamic value, Color fallback) {
    if (value is int) {
      return Color(value);
    }
    return fallback;
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
        final contractorStream = FirebaseFirestore.instance
            .collection('contractors')
            .doc(user.uid)
            .snapshots();

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
                  tooltip: 'Help',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ContractorProfileScreen(),
                      ),
                    );
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
            const SizedBox(height: 20),
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
                    title: 'Browse jobs',
                    subtitle: 'Find new leads',
                    icon: Icons.work_outline,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const JobFeedPage()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _quickActionTile(
                    context: context,
                    title: 'Messages',
                    subtitle: 'Reply faster',
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
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _quickActionTile(
                    context: context,
                    title: 'Portfolio',
                    subtitle: 'Showcase your work',
                    icon: Icons.photo_library_outlined,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PortfolioScreen(
                            contractorId: user.uid,
                            isEditable: true,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _quickActionTile(
                    context: context,
                    title: 'Payments',
                    subtitle: 'Track earnings',
                    icon: Icons.payments_outlined,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PaymentHistoryScreen(),
                        ),
                      );
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
                    title: 'Subcontract jobs',
                    subtitle: 'View posted work',
                    icon: Icons.handshake_outlined,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const ContractorSubcontractBoardScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _quickActionTile(
                    context: context,
                    title: 'Post a job',
                    subtitle: 'Share overflow work',
                    icon: Icons.add_circle_outline,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ContractorPostJobScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchTab(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Sign in required'));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const PageHeader(
          title: 'Jobs',
          subtitle: 'Browse and purchase customer project leads',
          padding: EdgeInsets.fromLTRB(0, 0, 0, 12),
        ),
        Text('My Claimed Jobs', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('job_requests')
              .where('claimedBy', isEqualTo: user.uid)
              .snapshots(),
          builder: (context, claimedSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('job_requests')
                  .where('paidBy', arrayContains: user.uid)
                  .snapshots(),
              builder: (context, paidSnap) {
                if (claimedSnap.hasError) {
                  return const AnimatedStateSwitcher(
                    stateKey: 'claimed_error',
                    child: EmptyStateCard(
                      icon: Icons.error_outline,
                      title: 'Couldn\'t load claimed jobs',
                      subtitle: 'Try again in a moment.',
                    ),
                  );
                }
                if (!claimedSnap.hasData) {
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

                final merged = <String, QueryDocumentSnapshot>{};
                for (final doc in claimedSnap.data!.docs) {
                  merged[doc.id] = doc;
                }
                if (!paidSnap.hasError && paidSnap.hasData) {
                  for (final doc in paidSnap.data!.docs) {
                    merged[doc.id] = doc;
                  }
                }

                final docs = merged.values.toList();
                int sortMs(QueryDocumentSnapshot doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final claimedAt = data['claimedAt'];
                  final createdAt = data['createdAt'];
                  if (claimedAt is Timestamp) {
                    return claimedAt.millisecondsSinceEpoch;
                  }
                  if (createdAt is Timestamp) {
                    return createdAt.millisecondsSinceEpoch;
                  }
                  return 0;
                }

                docs.sort((a, b) => sortMs(b).compareTo(sortMs(a)));

                if (docs.isEmpty) {
                  return AnimatedStateSwitcher(
                    stateKey: 'claimed_empty',
                    child: EmptyStateCard(
                      icon: Icons.work_outline,
                      title: 'No claimed jobs yet',
                      subtitle:
                          'Browse leads and purchase one to start a conversation with the customer.',
                    ),
                  );
                }

                return AnimatedStateSwitcher(
                  stateKey: 'claimed_list',
                  child: Column(
                    children: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final service = (data['service'] ?? 'Service').toString();
                      final location = (data['location'] ?? 'Unknown')
                          .toString();
                      final claimedAt = _formatTimestamp(data['claimedAt']);
                      final createdAt = _formatTimestamp(data['createdAt']);

                      final subtitleParts = <String>[];
                      subtitleParts.add('Location: $location');
                      if (claimedAt.isNotEmpty) {
                        subtitleParts.add('Claimed: $claimedAt');
                      }
                      if (claimedAt.isEmpty && createdAt.isNotEmpty) {
                        subtitleParts.add('Created: $createdAt');
                      }

                      return Card(
                        child: ListTile(
                          title: Text(service),
                          subtitle: Text(subtitleParts.join('\n')),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    JobDetailPage(jobId: doc.id, jobData: data),
                              ),
                            );
                          },
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const JobFeedPage()),
              );
            },
            child: const Text('Browse jobs'),
          ),
        ),
      ],
    );
  }

  Widget _buildToolsTab(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Sign in required'));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final unlocked = _pricingToolsUnlockedFromUserDoc(data);

        Future<void> openSubscription() async {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ContractorSubscriptionScreen(),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const PageHeader(
              title: 'Tools',
              subtitle: 'AI-powered tools to help you win more work',
              padding: EdgeInsets.fromLTRB(0, 0, 0, 12),
            ),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.auto_awesome_outlined),
                    title: const Text('AI Invoice Maker'),
                    subtitle: const Text(
                      'Generate line items, terms, and export PDF',
                    ),
                    trailing: Icon(unlocked ? Icons.chevron_right : Icons.lock),
                    onTap: () async {
                      await _openPricingToolsOrSubscribe(
                        open: () async {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const InvoiceMakerScreen(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(unlocked ? Icons.calculate : Icons.lock),
                    title: const Text('Pricing Calculator'),
                    subtitle: const Text('Better pricing, faster quotes'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await _openPricingToolsOrSubscribe(
                        open: () async {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PricingCalculatorScreen(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(unlocked ? Icons.receipt_long : Icons.lock),
                    title: const Text('Cost Estimator'),
                    subtitle: const Text('Quick cost breakdown by service'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await _openPricingToolsOrSubscribe(
                        open: () async {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Select Service Type'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children:
                                    [
                                      'Interior Painting',
                                      'Exterior Painting',
                                      'Cabinet Painting',
                                      'Drywall Repair',
                                      'Pressure Washing',
                                    ].map((service) {
                                      return ListTile(
                                        title: Text(service),
                                        onTap: () {
                                          Navigator.pop(context);
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  CostEstimatorScreen(
                                                    serviceType: service,
                                                  ),
                                            ),
                                          );
                                        },
                                      );
                                    }).toList(),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      unlocked ? Icons.palette_outlined : Icons.lock,
                    ),
                    title: const Text('Render Tool'),
                    subtitle: const Text('Preview wall colors on photos'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await _openPricingToolsOrSubscribe(
                        open: () async {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RenderToolScreen(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const Divider(height: 1),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Contractor Pro',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        if (unlocked)
                          const Chip(
                            label: Text('Active'),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      r'$11.99 / month',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Unlocks: Pricing Calculator + Cost Estimator.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.workspace_premium),
                        onPressed: openSubscription,
                        label: Text(
                          unlocked ? 'Manage subscription' : 'Subscribe',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    const PageHeader(
                      title: 'Plan',
                      subtitle:
                          'Manage your account, credits, and subscription',
                      padding: EdgeInsets.fromLTRB(0, 0, 0, 12),
                    ),
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
                              title: 'Couldn\'t load account info',
                              subtitle:
                                  'Pull to refresh or try again in a moment.',
                              action: OutlinedButton.icon(
                                onPressed: () => setState(() {}),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
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
                            ? 'Approved'
                            : 'Pending Admin Approval';
                        final statusTone = approved
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.tertiary;

                        final payoutsLabel = payoutsEnabled
                            ? 'Payouts connected'
                            : (detailsSubmitted
                                  ? 'Payouts pending'
                                  : 'Payouts setup');

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
                                              'Account overview',
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
                                          _statusPill(
                                            context: context,
                                            label: statusText,
                                            icon: approved
                                                ? Icons.verified
                                                : Icons.pending_actions,
                                            sideColor: statusTone,
                                          ),
                                          _statusPill(
                                            context: context,
                                            label: payoutsLabel,
                                            icon: payoutsEnabled
                                                ? Icons
                                                      .account_balance_wallet_outlined
                                                : Icons.payments_outlined,
                                          ),
                                          _statusPill(
                                            context: context,
                                            label:
                                                'Non-exclusive credits: $nonExclusiveCredits',
                                            icon: Icons.local_offer_outlined,
                                          ),
                                          _statusPill(
                                            context: context,
                                            label:
                                                'Exclusive credits: $exclusiveCredits',
                                            icon: Icons.lock_outline,
                                          ),
                                          if (stripeAccountId.isEmpty)
                                            _statusPill(
                                              context: context,
                                              label: 'Payouts not connected',
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
                                    _actionTile(
                                      context: context,
                                      icon: Icons.account_circle_outlined,
                                      title: 'Edit profile',
                                      subtitle:
                                          'Update your public contractor info',
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const AccountProfileScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                    const Divider(height: 1),
                                    _actionTile(
                                      context: context,
                                      icon: Icons.verified_outlined,
                                      title: 'Get verified',
                                      subtitle:
                                          'Improve trust and win more work',
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const VerificationScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                    const Divider(height: 1),
                                    _actionTile(
                                      context: context,
                                      icon: Icons.analytics_outlined,
                                      title: 'Analytics',
                                      subtitle: 'Track performance and growth',
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const ContractorAnalyticsScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                    const Divider(height: 1),
                                    _actionTile(
                                      context: context,
                                      icon: Icons.calendar_month_outlined,
                                      title: 'Availability',
                                      subtitle: 'Keep your schedule up to date',
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const AvailabilityCalendarScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                    const Divider(height: 1),
                                    _actionTile(
                                      context: context,
                                      icon: Icons.map_outlined,
                                      title: 'Service area',
                                      subtitle: 'Control where you get leads',
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const ServiceAreaScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                    const Divider(height: 1),
                                    _actionTile(
                                      context: context,
                                      icon: Icons.photo_library_outlined,
                                      title: 'Portfolio',
                                      subtitle: 'Showcase your best work',
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => PortfolioScreen(
                                              contractorId: user.uid,
                                              isEditable: true,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    const Divider(height: 1),
                                    _actionTile(
                                      context: context,
                                      icon: Icons.business_outlined,
                                      title: 'Business profile',
                                      subtitle: 'Manage company details',
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const BusinessProfileScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                    const Divider(height: 1),
                                    _actionTile(
                                      context: context,
                                      icon: Icons.question_answer_outlined,
                                      title: 'Q&A',
                                      subtitle:
                                          'Answer common customer questions',
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => QandAScreen(
                                              contractorId: user.uid,
                                              isContractor: true,
                                            ),
                                          ),
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
