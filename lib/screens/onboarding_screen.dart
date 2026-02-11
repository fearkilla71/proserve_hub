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
          title: 'Welcome, Pro!',
          description:
              'Join thousands of professionals growing their business on ProServe Hub.',
          icon: Icons.construction,
          color: ProServeColors.accent,
        ),
        OnboardingPage(
          title: 'Get Quality Leads',
          description:
              'Browse local job postings and purchase leads that match your skills and service area.',
          icon: Icons.work,
          color: ProServeColors.accent2,
        ),
        OnboardingPage(
          title: 'Manage Your Schedule',
          description:
              'Set your availability, accept bookings, and keep your calendar organized in one place.',
          icon: Icons.calendar_month,
          color: ProServeColors.accent3,
        ),
        OnboardingPage(
          title: 'Build Your Portfolio',
          description:
              'Showcase before & after photos, collect reviews, and let your work speak for itself.',
          icon: Icons.photo_library,
          color: ProServeColors.accent,
        ),
        OnboardingPage(
          title: 'Get Paid Securely',
          description:
              'Send invoices, track expenses, and receive payments – all protected through ProServe Hub.',
          icon: Icons.account_balance_wallet,
          color: ProServeColors.accent2,
        ),
      ];
    } else if (widget.role == 'customer') {
      return [
        OnboardingPage(
          title: 'Welcome to ProServe Hub',
          description:
              'Find and hire trusted professionals for any home project – big or small.',
          icon: Icons.home_repair_service,
          color: ProServeColors.accent,
        ),
        OnboardingPage(
          title: 'Post Your Project',
          description:
              'Share photos and details. Our AI helps estimate costs so you know what to expect.',
          icon: Icons.camera_alt,
          color: ProServeColors.accent2,
        ),
        OnboardingPage(
          title: 'Compare & Choose',
          description:
              'Review bids from qualified contractors, check their ratings, and pick the best fit.',
          icon: Icons.compare_arrows,
          color: ProServeColors.accent3,
        ),
        OnboardingPage(
          title: 'Book & Track',
          description:
              'Schedule your contractor, receive booking confirmations, and track job progress live.',
          icon: Icons.track_changes,
          color: ProServeColors.accent,
        ),
        OnboardingPage(
          title: 'Pay Safely',
          description:
              'Your payments are held securely until you approve the completed work.',
          icon: Icons.verified_user,
          color: ProServeColors.accent2,
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
      ),
      OnboardingPage(
        title: 'Post Your Project',
        description:
            'Share photos and details. Our AI helps estimate costs instantly.',
        icon: Icons.camera_alt,
        color: ProServeColors.accent2,
      ),
      OnboardingPage(
        title: 'Get Matched Instantly',
        description:
            'Our smart algorithm finds the best contractors near you based on ratings, experience, and availability.',
        icon: Icons.auto_awesome,
        color: ProServeColors.accent3,
      ),
      OnboardingPage(
        title: 'Secure Payments',
        description:
            'Pay safely through ProServe Hub. Your payments are protected until the job is done.',
        icon: Icons.verified_user,
        color: ProServeColors.accent,
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
    return Scaffold(
      backgroundColor: ProServeColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _completeOnboarding,
                child: Text(
                  'Skip',
                  style: GoogleFonts.manrope(color: ProServeColors.muted),
                ),
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
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? ProServeColors.accent
                              : ProServeColors.line,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: ProServeColors.accent,
                        foregroundColor: ProServeColors.bgDeep,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                      child: Text(
                        _currentPage == _pages.length - 1
                            ? 'Get Started'
                            : 'Next',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w700,
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
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 500),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: page.color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(page.icon, size: 60, color: page.color),
                ),
              );
            },
          ),
          const SizedBox(height: 48),
          Text(
            page.title,
            style: GoogleFonts.bebasNeue(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: ProServeColors.ink,
              letterSpacing: 1.0,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            page.description,
            style: GoogleFonts.manrope(
              fontSize: 16,
              color: ProServeColors.muted,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
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

  OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
