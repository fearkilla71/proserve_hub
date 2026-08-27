import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../services/version_check_service.dart';
import '../state/app_state.dart';
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
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _bodyFade;
  late final Animation<Offset> _bodySlide;
  late final Animation<double> _footerFade;

  @override
  void initState() {
    super.initState();
    _introCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _headerFade = CurvedAnimation(
      parent: _introCtrl,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );
    _headerSlide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _introCtrl,
            curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
          ),
        );
    _bodyFade = CurvedAnimation(
      parent: _introCtrl,
      curve: const Interval(0.2, 0.75, curve: Curves.easeOut),
    );
    _bodySlide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _introCtrl,
            curve: const Interval(0.2, 0.75, curve: Curves.easeOut),
          ),
        );
    _footerFade = CurvedAnimation(
      parent: _introCtrl,
      curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
    );
    _introCtrl.forward();
    _checkOnboarding();
    _checkAppVersion();
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

  Future<void> _checkAppVersion() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      await VersionCheckService.instance.checkForUpdate(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: ProServeColors.heroGradient),
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          Positioned(
            top: -110,
            right: -90,
            child: _buildOrb(
              220,
              ProServeColors.accent2.withValues(alpha: 0.13),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -120,
            child: _buildOrb(260, ProServeColors.accent.withValues(alpha: 0.1)),
          ),
          Positioned.fill(
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 520;
                  final isCompactHeight = constraints.maxHeight < 760;
                  final horizontalPadding = constraints.maxWidth < 380
                      ? 16.0
                      : 20.0;

                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      isCompactHeight ? 12 : 18,
                      horizontalPadding,
                      24,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 620),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FadeTransition(
                              opacity: _headerFade,
                              child: SlideTransition(
                                position: _headerSlide,
                                child: _LandingHeader(l10n: l10n),
                              ),
                            ),
                            SizedBox(height: isCompactHeight ? 16 : 24),
                            FadeTransition(
                              opacity: _bodyFade,
                              child: SlideTransition(
                                position: _bodySlide,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _HeroCopy(
                                      l10n: l10n,
                                      compact: isCompactHeight,
                                    ),
                                    SizedBox(height: isCompactHeight ? 14 : 20),
                                    _RoleChoiceSection(
                                      l10n: l10n,
                                      twoColumn: isWide,
                                    ),
                                    SizedBox(height: isCompactHeight ? 16 : 24),
                                    _TrustStrip(l10n: l10n),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: isCompactHeight ? 12 : 18),
                            FadeTransition(
                              opacity: _footerFade,
                              child: _BuiltForTradesCard(l10n: l10n),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrb(double size, Color color) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [BoxShadow(color: color, blurRadius: size * 0.42)],
        ),
      ),
    );
  }
}

class _LandingHeader extends StatelessWidget {
  const _LandingHeader({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.bebasNeue(
                fontSize: 29,
                height: 1,
                letterSpacing: 1.7,
                color: ProServeColors.ink,
              ),
              children: const [
                TextSpan(text: 'PROSERVE '),
                TextSpan(
                  text: 'HUB',
                  style: TextStyle(color: ProServeColors.accent2),
                ),
              ],
            ),
          ),
        ),
        _LanguageMenu(l10n: l10n),
      ],
    );
  }
}

class _LanguageMenu extends StatelessWidget {
  const _LanguageMenu({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final appState = AppState.of(context);
    final code = appState.locale?.languageCode;
    final label = switch (code) {
      'es' => 'Español',
      'en' => 'English',
      _ => l10n.landingLanguageSystem,
    };

    return PopupMenuButton<Locale?>(
      tooltip: l10n.language,
      onSelected: (locale) {
        appState.setLocale(locale);
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: null, child: Text(l10n.landingLanguageSystem)),
        const PopupMenuItem(value: Locale('en'), child: Text('English')),
        const PopupMenuItem(value: Locale('es'), child: Text('Español')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: ProServeColors.card.withValues(alpha: 0.54),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ProServeColors.lineStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language, size: 17, color: ProServeColors.ink),
            const SizedBox(width: 7),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: ProServeColors.ink,
              ),
            ),
            const SizedBox(width: 3),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: ProServeColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.l10n, required this.compact});

  final AppLocalizations l10n;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Badge(label: l10n.landingBadge),
        SizedBox(height: compact ? 14 : 22),
        RichText(
          text: TextSpan(
            style: GoogleFonts.manrope(
              fontSize: compact ? 31 : 35,
              height: 1.08,
              letterSpacing: 0,
              fontWeight: FontWeight.w900,
              color: ProServeColors.ink,
            ),
            children: [
              TextSpan(text: l10n.landingHeadlinePrefix),
              TextSpan(
                text: l10n.landingHeadlineAccent,
                style: const TextStyle(color: ProServeColors.accent2),
              ),
            ],
          ),
        ),
        SizedBox(height: compact ? 10 : 16),
        Text(
          l10n.landingSubtitle,
          style: GoogleFonts.manrope(
            fontSize: compact ? 14.5 : 16,
            height: 1.45,
            color: ProServeColors.muted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _RoleChoiceSection extends StatelessWidget {
  const _RoleChoiceSection({required this.l10n, required this.twoColumn});

  final AppLocalizations l10n;
  final bool twoColumn;

  @override
  Widget build(BuildContext context) {
    final homeowner = _RoleCard(
      title: l10n.landingHomeownerTitle,
      body: l10n.landingHomeownerBody,
      bullets: [
        l10n.landingHomeownerBulletVerified,
        l10n.landingHomeownerBulletQuotes,
        l10n.landingHomeownerBulletEscrow,
      ],
      cta: l10n.landingHomeownerCta,
      footnote: l10n.landingHomeownerFootnote,
      accent: ProServeColors.accent,
      backgroundAccent: ProServeColors.accent.withValues(alpha: 0.14),
      icon: Icons.home_rounded,
      onTap: () => context.push('/customer-login'),
      compact: !twoColumn,
    );
    final contractor = _RoleCard(
      title: l10n.landingContractorTitle,
      body: l10n.landingContractorBody,
      bullets: [
        l10n.landingContractorBulletLeads,
        l10n.landingContractorBulletTools,
        l10n.landingContractorBulletPaid,
      ],
      cta: l10n.landingContractorCta,
      footnote: l10n.landingContractorFootnote,
      accent: ProServeColors.accent2,
      backgroundAccent: ProServeColors.accent2.withValues(alpha: 0.16),
      icon: Icons.business_center_rounded,
      onTap: () => context.push('/contractor-login'),
      compact: !twoColumn,
    );

    if (!twoColumn) {
      return Column(
        children: [homeowner, const SizedBox(height: 12), contractor],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: homeowner),
        const SizedBox(width: 12),
        Expanded(child: contractor),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.body,
    required this.bullets,
    required this.cta,
    required this.footnote,
    required this.accent,
    required this.backgroundAccent,
    required this.icon,
    required this.onTap,
    required this.compact,
  });

  final String title;
  final String body;
  final List<String> bullets;
  final String cta;
  final String footnote;
  final Color accent;
  final Color backgroundAccent;
  final IconData icon;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $body. $cta',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.all(compact ? 15 : 18),
            decoration: BoxDecoration(
              color: ProServeColors.card.withValues(alpha: 0.74),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
              gradient: LinearGradient(
                colors: [
                  backgroundAccent,
                  ProServeColors.card.withValues(alpha: 0.78),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: compact ? 46 : 54,
                      height: compact ? 46 : 54,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(compact ? 14 : 16),
                        gradient: LinearGradient(
                          colors: [accent, accent.withValues(alpha: 0.65)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.18),
                            blurRadius: compact ? 14 : 22,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        icon,
                        color: ProServeColors.ink,
                        size: compact ? 25 : 29,
                      ),
                    ),
                    SizedBox(width: compact ? 13 : 0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!compact) const SizedBox(height: 22),
                          Text(
                            title,
                            style: GoogleFonts.manrope(
                              fontSize: compact ? 19 : 22,
                              height: 1.12,
                              fontWeight: FontWeight.w900,
                              color: ProServeColors.ink,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            body,
                            style: GoogleFonts.manrope(
                              fontSize: compact ? 12.6 : 13.5,
                              height: compact ? 1.32 : 1.42,
                              fontWeight: FontWeight.w500,
                              color: ProServeColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 12 : 18),
                ...bullets.map(
                  (bullet) => Padding(
                    padding: EdgeInsets.only(bottom: compact ? 7 : 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 19,
                          height: 19,
                          margin: const EdgeInsets.only(top: 1),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accent.withValues(alpha: 0.22),
                          ),
                          child: Icon(Icons.check, size: 13, color: accent),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            bullet,
                            style: GoogleFonts.manrope(
                              fontSize: 12.2,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                              color: ProServeColors.ink.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: compact ? 8 : 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accent, ProServeColors.accent2],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        constraints: BoxConstraints(
                          minHeight: compact ? 46 : 50,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                cta,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.manrope(
                                  fontSize: compact ? 14 : 14.5,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF041016),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward,
                              size: 19,
                              color: Color(0xFF041016),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: compact ? 9 : 12),
                Center(
                  child: Text(
                    footnote,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: ProServeColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrustStrip extends StatelessWidget {
  const _TrustStrip({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      decoration: BoxDecoration(
        color: ProServeColors.card.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ProServeColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TrustItem(
              icon: Icons.verified_user_outlined,
              title: l10n.landingTrustVerifiedTitle,
              body: l10n.landingTrustVerifiedBody,
              color: ProServeColors.accent,
            ),
          ),
          _VerticalDivider(),
          Expanded(
            child: _TrustItem(
              icon: Icons.lock_outline,
              title: l10n.landingTrustEscrowTitle,
              body: l10n.landingTrustEscrowBody,
              color: ProServeColors.accent2,
            ),
          ),
          _VerticalDivider(),
          Expanded(
            child: _TrustItem(
              icon: Icons.trending_up_rounded,
              title: l10n.landingTrustTrackingTitle,
              body: l10n.landingTrustTrackingBody,
              color: ProServeColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustItem extends StatelessWidget {
  const _TrustItem({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(height: 10),
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.manrope(
            fontSize: 12.5,
            height: 1.15,
            fontWeight: FontWeight.w900,
            color: ProServeColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.manrope(
            fontSize: 11,
            height: 1.25,
            color: ProServeColors.muted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _BuiltForTradesCard extends StatelessWidget {
  const _BuiltForTradesCard({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      decoration: BoxDecoration(
        color: ProServeColors.card.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ProServeColors.line),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome,
            color: ProServeColors.accent2,
            size: 34,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.landingBuiltTitle,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: ProServeColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.landingBuiltSubtitle,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: ProServeColors.muted,
                    fontWeight: FontWeight.w500,
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

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: ProServeColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: ProServeColors.accent.withValues(alpha: 0.24),
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.manrope(
          fontSize: 12,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w900,
          color: ProServeColors.accent,
        ),
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 112,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: ProServeColors.line,
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..strokeWidth = 0.5;

    const spacing = 54.0;
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
