import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/proserve_theme.dart';
import 'onboarding_screen.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _introCtrl;
  late final Animation<double> _logoFade;
  late final Animation<Offset> _logoSlide;
  late final Animation<double> _bodyFade;
  late final Animation<Offset> _bodySlide;
  late final Animation<double> _btnFade;

  @override
  void initState() {
    super.initState();
    _introCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoFade = CurvedAnimation(
      parent: _introCtrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _logoSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _introCtrl,
            curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
          ),
        );
    _bodyFade = CurvedAnimation(
      parent: _introCtrl,
      curve: const Interval(0.25, 0.75, curve: Curves.easeOut),
    );
    _bodySlide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _introCtrl,
            curve: const Interval(0.25, 0.75, curve: Curves.easeOut),
          ),
        );
    _btnFade = CurvedAnimation(
      parent: _introCtrl,
      curve: const Interval(0.45, 1.0, curve: Curves.easeOut),
    );
    _introCtrl.forward();
    _checkOnboarding();
  }

  @override
  void dispose() {
    _introCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool('onboarding_complete') ?? false;

    if (!completed && mounted) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const OnboardingScreen()));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient (matches landing page body)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: ProServeColors.heroGradient,
              ),
            ),
          ),

          // Grid overlay (like the landing page ::before pseudo-element)
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),

          // Floating orbs
          Positioned(
            top: -80,
            right: -40,
            child: _buildOrb(
              180,
              ProServeColors.accent2.withValues(alpha: 0.2),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -60,
            child: _buildOrb(
              220,
              ProServeColors.accent.withValues(alpha: 0.18),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.35,
            right: -50,
            child: _buildOrb(
              160,
              ProServeColors.accent3.withValues(alpha: 0.15),
            ),
          ),

          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Tag pill
                      FadeTransition(
                        opacity: _logoFade,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: ProServeColors.accent.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: ProServeColors.accent.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                            ),
                            child: Text(
                              'AI-powered contractor OS',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: ProServeColors.accent,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Logo card
                      FadeTransition(
                        opacity: _logoFade,
                        child: SlideTransition(
                          position: _logoSlide,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 30,
                            ),
                            decoration: BoxDecoration(
                              color: ProServeColors.card.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: ProServeColors.line),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 30,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Icon with glow
                                Container(
                                  width: 92,
                                  height: 92,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [
                                        ProServeColors.accent,
                                        ProServeColors.accent2,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: ProServeColors.accent.withValues(
                                          alpha: 0.35,
                                        ),
                                        blurRadius: 30,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.handshake_rounded,
                                    size: 48,
                                    color: Color(0xFF041016),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'PROSERVE HUB',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.bebasNeue(
                                    fontSize: 36,
                                    letterSpacing: 2,
                                    color: ProServeColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ShaderMask(
                                  shaderCallback: (bounds) => ProServeColors
                                      .ctaGradient
                                      .createShader(bounds),
                                  child: Text(
                                    'Connect. Hire. Get Work Done.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.manrope(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Your all-in-one hub for contractors and homeowners to keep projects moving.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.manrope(
                                    fontSize: 14,
                                    color: ProServeColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Feature pills
                      FadeTransition(
                        opacity: _bodyFade,
                        child: SlideTransition(
                          position: _bodySlide,
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _featurePill('Verified pros'),
                              _featurePill('Upfront pricing'),
                              _featurePill('Project tracking'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // CTA buttons
                      FadeTransition(
                        opacity: _btnFade,
                        child: Column(
                          children: [
                            ProServeCTAButton(
                              label: 'I Need Services',
                              icon: Icons.arrow_forward,
                              onPressed: () {
                                context.push('/customer-login');
                              },
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () {
                                  context.push('/contractor-login');
                                },
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 54),
                                  side: BorderSide(
                                    color: ProServeColors.lineStrong,
                                  ),
                                  backgroundColor: ProServeColors.card
                                      .withValues(alpha: 0.6),
                                ),
                                child: const Text('I Provide Services'),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Sign up is available on the next screen.',
                              textAlign: TextAlign.center,
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: size * 0.5)],
      ),
    );
  }

  Widget _featurePill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: ProServeColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: ProServeColors.accent.withValues(alpha: 0.15),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: ProServeColors.accent,
        ),
      ),
    );
  }
}

/// Subtle grid overlay matching the landing page background
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 0.5;

    const spacing = 48.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
