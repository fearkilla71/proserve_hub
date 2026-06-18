import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/proserve_theme.dart';

class OnboardingScreen extends StatefulWidget {
  /// Optional role – when provided, shows role-specific onboarding pages.
  /// Accepted values: `'customer'`, `'contractor'`, or `null` (generic).
  final String? role;

  const OnboardingScreen({super.key, this.role});

  /// Launch role-specific onboarding if the user hasn't seen it yet.
  /// Call from the portal page's `initState`.
  static Future<void> showIfNeeded(BuildContext context, String role) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'onboarding_${role}_complete';
    if (prefs.getBool(key) ?? false) return;
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => OnboardingScreen(role: role)),
    );
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late final List<OnboardingPage> _pages = _buildPages();

  List<OnboardingPage> _buildPages() {
    if (widget.role == 'contractor') {
      return [
        OnboardingPage(
          title: 'Run Your Business From One Dashboard',
          description:
              'Set up your contractor profile, service area, tools, and payment workflow before leads start moving.',
          icon: Icons.dashboard_customize_outlined,
          color: ProServeColors.accent,
          proof: 'Profile, tools, leads, and payouts stay connected.',
        ),
        OnboardingPage(
          title: 'Browse Local Leads',
          description:
              'See homeowner requests that match your services and area, then unlock the right opportunities.',
          icon: Icons.location_searching_outlined,
          color: ProServeColors.accent2,
          proof: 'Use credits only when a lead is worth pursuing.',
        ),
        OnboardingPage(
          title: 'Quote, Schedule, Invoice',
          description:
              'Turn estimates into quotes, manage work, send invoices, and keep customers updated from one flow.',
          icon: Icons.receipt_long_outlined,
          color: ProServeColors.accent3,
          proof: 'Your tools should move with the job, not sit alone.',
        ),
        OnboardingPage(
          title: 'Build Trust',
          description:
              'Complete verification, collect reviews, show services, and keep your business card professional.',
          icon: Icons.verified_user_outlined,
          color: ProServeColors.accent,
          proof: 'Trust signals help customers choose faster.',
        ),
        OnboardingPage(
          title: 'Connect Payouts',
          description:
              'Connect Stripe payouts so escrow releases and invoice payments can reach your business.',
          icon: Icons.account_balance_wallet,
          color: ProServeColors.accent2,
          proof: 'Next: finish profile setup and connect payouts.',
        ),
      ];
    } else if (widget.role == 'customer') {
      return [
        OnboardingPage(
          title: 'Post The Job Once',
          description:
              'Share photos, service details, and timing so local pros can quote the real scope.',
          icon: Icons.add_home_work_outlined,
          color: ProServeColors.accent,
          proof: 'Good details lead to better bids.',
        ),
        OnboardingPage(
          title: 'Compare Verified Pros',
          description:
              'Review bids, ratings, service fit, and contractor profile details before choosing.',
          icon: Icons.compare_arrows_outlined,
          color: ProServeColors.accent2,
          proof: 'You stay in control of who gets the job.',
        ),
        OnboardingPage(
          title: 'Pay Safely',
          description:
              'Escrow helps protect payment until the work reaches the agreed completion point.',
          icon: Icons.lock_outline,
          color: ProServeColors.accent3,
          proof: 'Clear payment states reduce job stress.',
        ),
        OnboardingPage(
          title: 'Track Every Step',
          description:
              'Keep quote, chat, photos, invoice, escrow, timeline, and review connected to the job.',
          icon: Icons.track_changes_outlined,
          color: ProServeColors.accent,
          proof: 'Next: post your first project or review active jobs.',
        ),
      ];
    }

    // Generic / first-time user pages (no role known yet).
    return [
      OnboardingPage(
        title: 'Welcome to ProServe Hub',
        description:
            'Connect with trusted professionals for all your home service needs.',
        icon: Icons.handshake,
        color: ProServeColors.accent,
        proof: 'Choose your role and start with a clear next step.',
      ),
      OnboardingPage(
        title: 'Post Your Project',
        description:
            'Share photos and details. Our AI helps estimate costs instantly.',
        icon: Icons.camera_alt,
        color: ProServeColors.accent2,
        proof: 'Homeowners get clearer quotes faster.',
      ),
      OnboardingPage(
        title: 'Manage Work',
        description:
            'Contractors can quote, invoice, schedule, and track paid work from one dashboard.',
        icon: Icons.business_center_outlined,
        color: ProServeColors.accent3,
        proof: 'Built for both sides of the job.',
      ),
      OnboardingPage(
        title: 'Secure Payments',
        description:
            'Pay safely through ProServe Hub. Your payments are protected until the job is done.',
        icon: Icons.verified_user,
        color: ProServeColors.accent,
        proof: 'Escrow safety keeps the project accountable.',
      ),
    ];
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    // Mark the appropriate onboarding as complete.
    if (widget.role != null) {
      await prefs.setBool('onboarding_${widget.role}_complete', true);
    } else {
      await prefs.setBool('onboarding_complete', true);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roleLabel = widget.role == 'contractor'
        ? 'Contractor setup'
        : widget.role == 'customer'
        ? 'Customer setup'
        : 'ProServe setup';
    return Scaffold(
      backgroundColor: ProServeColors.bgDeep,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: ProServeColors.heroGradient),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: ProServeColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: ProServeColors.accent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          roleLabel,
                          style: GoogleFonts.manrope(
                            color: ProServeColors.accent,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _completeOnboarding,
                        child: Text(
                          'Skip',
                          style: GoogleFonts.manrope(
                            color: ProServeColors.muted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      return _buildPage(_pages[index]);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _pages.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentPage == index ? 28 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? ProServeColors.accent
                                  : ProServeColors.lineStrong,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: Icon(
                            _currentPage == _pages.length - 1
                                ? Icons.arrow_forward
                                : Icons.chevron_right,
                          ),
                          onPressed: () {
                            if (_currentPage == _pages.length - 1) {
                              _completeOnboarding();
                            } else {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                          label: Text(
                            _currentPage == _pages.length - 1
                                ? _finalActionLabel()
                                : 'Next',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _finalActionLabel() {
    return switch (widget.role) {
      'contractor' => 'Go to contractor dashboard',
      'customer' => 'Post or track a job',
      _ => 'Get started',
    };
  }

  Widget _buildPage(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: ProServeColors.cardGradient,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: page.color.withValues(alpha: 0.24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              children: [
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 450),
                  tween: Tween(begin: 0.92, end: 1.0),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          color: page.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: page.color.withValues(alpha: 0.32),
                          ),
                        ),
                        child: Icon(page.icon, size: 42, color: page.color),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 28),
                Text(
                  page.title,
                  style: GoogleFonts.bebasNeue(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: ProServeColors.ink,
                    letterSpacing: 1.0,
                    height: 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Text(
                  page.description,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    color: ProServeColors.muted,
                    height: 1.48,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: page.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: page.color.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: page.color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          page.proof,
                          style: GoogleFonts.manrope(
                            color: ProServeColors.ink,
                            fontWeight: FontWeight.w800,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String proof;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.proof,
  });
}
