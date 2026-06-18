import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/proserve_theme.dart';

Future<String?> showLeadPackPurchaseSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _LeadPackPurchaseSheet(),
  );
}

class _LeadPackPurchaseSheet extends StatelessWidget {
  const _LeadPackPurchaseSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.55,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: ProServeColors.bgDeep,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: ProServeColors.lineStrong),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.38),
                blurRadius: 32,
                offset: const Offset(0, -12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Stack(
              children: [
                const Positioned.fill(child: _LeadPackBackground()),
                SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: ProServeColors.lineStrong,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _LeadPackHeader(),
                      const SizedBox(height: 18),
                      _InfoStrip(
                        icon: Icons.info_outline,
                        text:
                            'Non-exclusive leads can be bought by multiple contractors. Exclusive leads lock access to you.',
                      ),
                      const SizedBox(height: 18),
                      const _LeadPackSectionHeader(
                        title: 'Non-exclusive',
                        subtitle: 'Best for testing more opportunities.',
                        icon: Icons.groups_2_outlined,
                        accent: ProServeColors.accent,
                      ),
                      const SizedBox(height: 10),
                      const _LeadPackCard(
                        id: 'ne_1',
                        title: '1 lead',
                        price: r'$50',
                        subtitle: 'Single contact unlock',
                        detail: 'Multiple contractors may purchase this lead.',
                        accent: ProServeColors.accent,
                      ),
                      const _LeadPackCard(
                        id: 'ne_10',
                        title: '10 leads',
                        price: r'$450',
                        subtitle: r'Save $50',
                        detail: '10 non-exclusive lead credits.',
                        badge: 'Popular',
                        accent: ProServeColors.accent,
                      ),
                      const _LeadPackCard(
                        id: 'ne_20',
                        title: '20 leads',
                        price: r'$850',
                        subtitle: r'Save $150',
                        detail: '20 non-exclusive lead credits.',
                        badge: 'Best value',
                        accent: ProServeColors.accent,
                      ),
                      const SizedBox(height: 18),
                      const _LeadPackSectionHeader(
                        title: 'Exclusive',
                        subtitle: 'Best when you want less competition.',
                        icon: Icons.lock_outline,
                        accent: ProServeColors.accent2,
                      ),
                      const SizedBox(height: 10),
                      const _LeadPackCard(
                        id: 'ex_1',
                        title: '1 exclusive lead',
                        price: r'$80',
                        subtitle: 'Locked access',
                        detail:
                            'Only you can see and unlock the customer info.',
                        accent: ProServeColors.accent2,
                        featured: true,
                      ),
                      const _LeadPackCard(
                        id: 'ex_10',
                        title: '10 exclusive leads',
                        price: r'$720',
                        subtitle: r'Save $80',
                        detail: '10 exclusive lead credits.',
                        badge: 'Popular',
                        accent: ProServeColors.accent2,
                        featured: true,
                      ),
                      const _LeadPackCard(
                        id: 'ex_20',
                        title: '20 exclusive leads',
                        price: r'$1360',
                        subtitle: r'Save $240',
                        detail: '20 exclusive lead credits.',
                        badge: 'Best value',
                        accent: ProServeColors.accent2,
                        featured: true,
                      ),
                      const SizedBox(height: 8),
                      _InfoStrip(
                        icon: Icons.verified_user_outlined,
                        text:
                            'Credits are added after checkout is confirmed by the app store or Stripe.',
                        compact: true,
                      ),
                    ],
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

class _LeadPackHeader extends StatelessWidget {
  const _LeadPackHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: ProServeColors.cardGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: ProServeColors.accent.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: ProServeColors.ctaGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: ProServeColors.accent.withValues(alpha: 0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.local_activity_outlined,
              color: Color(0xFF041016),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Buy lead credits',
                  style: GoogleFonts.bebasNeue(
                    color: ProServeColors.ink,
                    fontSize: 30,
                    letterSpacing: 0.8,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose the pack that matches how aggressively you want to win work.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: ProServeColors.muted,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
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

class _LeadPackSectionHeader extends StatelessWidget {
  const _LeadPackSectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withValues(alpha: 0.24)),
          ),
          child: Icon(icon, color: accent, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: ProServeColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ProServeColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LeadPackCard extends StatelessWidget {
  const _LeadPackCard({
    required this.id,
    required this.title,
    required this.price,
    required this.subtitle,
    required this.detail,
    required this.accent,
    this.badge,
    this.featured = false,
  });

  final String id;
  final String title;
  final String price;
  final String subtitle;
  final String detail;
  final String? badge;
  final Color accent;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.pop(context, id),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: featured
                  ? accent.withValues(alpha: 0.1)
                  : ProServeColors.card.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: featured
                    ? accent.withValues(alpha: 0.42)
                    : ProServeColors.lineStrong,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: ProServeColors.ink,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ),
                          if (badge != null)
                            _PackBadge(label: badge!, accent: accent),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            price,
                            style: GoogleFonts.manrope(
                              color: accent,
                              fontWeight: FontWeight.w900,
                              fontSize: 24,
                              height: 1,
                            ),
                          ),
                          _MiniPill(label: subtitle, accent: accent),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        detail,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ProServeColors.muted,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accent.withValues(alpha: 0.26)),
                  ),
                  child: Icon(Icons.arrow_forward, color: accent, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PackBadge extends StatelessWidget {
  const _PackBadge({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          color: accent,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: ProServeColors.bgDeep.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: ProServeColors.ink,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({
    required this.icon,
    required this.text,
    this.compact = false,
  });

  final IconData icon;
  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: ProServeColors.accent2.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: ProServeColors.accent2.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: ProServeColors.accent2, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ProServeColors.muted,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeadPackBackground extends StatelessWidget {
  const _LeadPackBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _LeadPackBackgroundPainter());
  }
}

class _LeadPackBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..strokeWidth = 1;
    const step = 44.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final teal = Paint()
      ..shader =
          RadialGradient(
            colors: [
              ProServeColors.accent.withValues(alpha: 0.16),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.08, size.height * 0.05),
              radius: size.width * 0.52,
            ),
          );
    canvas.drawCircle(
      Offset(size.width * 0.08, size.height * 0.05),
      size.width * 0.52,
      teal,
    );

    final blue = Paint()
      ..shader =
          RadialGradient(
            colors: [
              ProServeColors.accent2.withValues(alpha: 0.14),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.95, size.height * 0.18),
              radius: size.width * 0.45,
            ),
          );
    canvas.drawCircle(
      Offset(size.width * 0.95, size.height * 0.18),
      size.width * 0.45,
      blue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
