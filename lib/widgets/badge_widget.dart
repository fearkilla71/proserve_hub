import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/contractor_badge.dart';

/// ── Ornate emblem badge widget ────────────────────────────────────────
///
/// Military/crest-style badges with metallic gradients, wings, rays,
/// shield shapes, and construction-themed icons. Inspired by ornate
/// medallions with a hardhat + tools construction feel.

enum BadgeSize { small, medium, large }

// ─── Metallic gradient palettes per tier ──────────────────────────────
class _MetallicPalette {
  const _MetallicPalette({
    required this.dark,
    required this.mid,
    required this.light,
    required this.highlight,
    required this.rim,
  });

  final Color dark;
  final Color mid;
  final Color light;
  final Color highlight;
  final Color rim;

  List<Color> get gradient => [dark, mid, light, mid, dark];
  List<double> get stops => [0.0, 0.25, 0.5, 0.75, 1.0];
}

const _bronzePalette = _MetallicPalette(
  dark: Color(0xFF6B3A1F),
  mid: Color(0xFFCD7F32),
  light: Color(0xFFE8B87A),
  highlight: Color(0xFFF5DEB3),
  rim: Color(0xFF8B5E3C),
);

const _silverPalette = _MetallicPalette(
  dark: Color(0xFF5A6270),
  mid: Color(0xFFA0AEC0),
  light: Color(0xFFD4DAE3),
  highlight: Color(0xFFF0F4F8),
  rim: Color(0xFF7A8694),
);

const _goldPalette = _MetallicPalette(
  dark: Color(0xFF7A5A00),
  mid: Color(0xFFDAA520),
  light: Color(0xFFFFD700),
  highlight: Color(0xFFFFF5CC),
  rim: Color(0xFFC49B00),
);

const _platinumPalette = _MetallicPalette(
  dark: Color(0xFF0E4D5E),
  mid: Color(0xFF22D3EE),
  light: Color(0xFF67E8F9),
  highlight: Color(0xFFCFFAFE),
  rim: Color(0xFF06B6D4),
);

const _legendaryPalette = _MetallicPalette(
  dark: Color(0xFF4A1D7A),
  mid: Color(0xFFA855F7),
  light: Color(0xFFC084FC),
  highlight: Color(0xFFEEDDFF),
  rim: Color(0xFF9333EA),
);

_MetallicPalette _paletteForTier(BadgeTier? tier) {
  if (tier == null) return _goldPalette;
  switch (tier) {
    case BadgeTier.bronze:
      return _bronzePalette;
    case BadgeTier.silver:
      return _silverPalette;
    case BadgeTier.gold:
      return _goldPalette;
    case BadgeTier.platinum:
      return _platinumPalette;
    case BadgeTier.legendary:
      return _legendaryPalette;
  }
}

_MetallicPalette _paletteForColor(Color color) {
  // Map profile badge colors to metallic palettes
  final hue = HSLColor.fromColor(color).hue;
  if (hue >= 30 && hue < 70) return _goldPalette; // amber/yellow
  if (hue >= 70 && hue < 160) {
    // green
    return const _MetallicPalette(
      dark: Color(0xFF0A3D1F),
      mid: Color(0xFF16A34A),
      light: Color(0xFF4ADE80),
      highlight: Color(0xFFBBF7D0),
      rim: Color(0xFF15803D),
    );
  }
  if (hue >= 200 && hue < 260) {
    // blue
    return const _MetallicPalette(
      dark: Color(0xFF1E3A5F),
      mid: Color(0xFF2563EB),
      light: Color(0xFF60A5FA),
      highlight: Color(0xFFDBEAFE),
      rim: Color(0xFF1D4ED8),
    );
  }
  if (hue >= 260 && hue < 310) {
    // purple
    return const _MetallicPalette(
      dark: Color(0xFF3B1764),
      mid: Color(0xFF7C3AED),
      light: Color(0xFFA78BFA),
      highlight: Color(0xFFEDE9FE),
      rim: Color(0xFF6D28D9),
    );
  }
  if (hue >= 160 && hue < 200) {
    // teal
    return const _MetallicPalette(
      dark: Color(0xFF0A3D3D),
      mid: Color(0xFF0D9488),
      light: Color(0xFF5EEAD4),
      highlight: Color(0xFFCCFBF1),
      rim: Color(0xFF0F766E),
    );
  }
  return _goldPalette;
}

// ─── Main badge widget ────────────────────────────────────────────────
class BadgeWidget extends StatelessWidget {
  const BadgeWidget({
    super.key,
    required this.badge,
    this.size = BadgeSize.medium,
    this.showLabel = true,
    this.onTap,
    this.earned = true,
  });

  final BadgeDef badge;
  final BadgeSize size;
  final bool showLabel;
  final VoidCallback? onTap;
  final bool earned;

  double get _diameter {
    switch (size) {
      case BadgeSize.small:
        return 36;
      case BadgeSize.medium:
        return 48;
      case BadgeSize.large:
        return 68;
    }
  }

  double get _iconSize {
    switch (size) {
      case BadgeSize.small:
        return 14;
      case BadgeSize.medium:
        return 20;
      case BadgeSize.large:
        return 28;
    }
  }

  double get _fontSize {
    switch (size) {
      case BadgeSize.small:
        return 9;
      case BadgeSize.medium:
        return 10;
      case BadgeSize.large:
        return 12;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = badge.tier != null
        ? _paletteForTier(badge.tier)
        : _paletteForColor(badge.color);

    final greyPalette = const _MetallicPalette(
      dark: Color(0xFF2A2A2A),
      mid: Color(0xFF4A4A4A),
      light: Color(0xFF6A6A6A),
      highlight: Color(0xFF8A8A8A),
      rim: Color(0xFF3A3A3A),
    );

    final activePalette = earned ? palette : greyPalette;

    // Build the emblem
    Widget emblem = SizedBox(
      width: _diameter,
      height: _diameter,
      child: CustomPaint(
        painter: _EmblemPainter(
          palette: activePalette,
          shape: badge.shape,
          tier: badge.tier,
          earned: earned,
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: _diameter * 0.02),
            child: Icon(
              badge.icon,
              size: _iconSize,
              color: earned ? Colors.white : Colors.grey.shade500,
              shadows: earned
                  ? [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );

    // Add wings/rays for higher tiers
    if (badge.tier != null && earned) {
      final tierIndex = badge.tier!.index;
      if (tierIndex >= BadgeTier.gold.index) {
        emblem = SizedBox(
          width: _diameter * 1.5,
          height: _diameter * 1.2,
          child: CustomPaint(
            painter: _WingsPainter(
              palette: activePalette,
              tier: badge.tier!,
              diameter: _diameter,
            ),
            child: Center(child: emblem),
          ),
        );
      }
    }

    // Glow effect
    if (earned) {
      emblem = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: palette.mid.withValues(alpha: 0.4),
              blurRadius: _diameter * 0.3,
              spreadRadius: _diameter * 0.05,
            ),
          ],
        ),
        child: emblem,
      );
    }

    final widget = onTap != null
        ? GestureDetector(onTap: onTap, child: emblem)
        : emblem;

    if (!showLabel) return widget;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        widget,
        const SizedBox(height: 4),
        SizedBox(
          width: _diameter * 1.5 + 4,
          child: Text(
            badge.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: _fontSize,
              fontWeight: FontWeight.w800,
              color: earned
                  ? Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.9)
                  : Colors.grey.shade600,
              height: 1.2,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Emblem painter (the core badge shape) ────────────────────────────
class _EmblemPainter extends CustomPainter {
  _EmblemPainter({
    required this.palette,
    required this.shape,
    required this.tier,
    required this.earned,
  });

  final _MetallicPalette palette;
  final BadgeShape shape;
  final BadgeTier? tier;
  final bool earned;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy);

    // Outer frame
    _drawFrame(canvas, size, cx, cy, r);

    // Inner shield/medallion
    _drawInner(canvas, size, cx, cy, r * 0.72);

    // Decorative rivets
    if (earned && r > 16) {
      _drawRivets(canvas, cx, cy, r);
    }

    // Top accent (crown/peak)
    if (earned && tier != null && tier!.index >= BadgeTier.silver.index) {
      _drawCrown(canvas, cx, cy, r);
    }
  }

  void _drawFrame(Canvas canvas, Size size, double cx, double cy, double r) {
    final path = _shapePath(cx, cy, r, shape);

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.save();
    canvas.translate(0, 2);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();

    // Metallic fill
    final gradient = ui.Gradient.sweep(
      Offset(cx, cy),
      palette.gradient,
      palette.stops,
    );
    final fillPaint = Paint()..shader = gradient;
    canvas.drawPath(path, fillPaint);

    // Highlight sweep (top-left)
    final highlightGrad = ui.Gradient.linear(
      Offset(cx - r, cy - r),
      Offset(cx + r * 0.3, cy + r * 0.3),
      [
        palette.highlight.withValues(alpha: 0.5),
        palette.highlight.withValues(alpha: 0.0),
      ],
    );
    final highlightPaint = Paint()..shader = highlightGrad;
    canvas.drawPath(path, highlightPaint);

    // Rim stroke
    final rimPaint = Paint()
      ..color = palette.rim
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.06;
    canvas.drawPath(path, rimPaint);

    // Inner rim (lighter)
    final innerRimPath = _shapePath(cx, cy, r * 0.88, shape);
    final innerRimPaint = Paint()
      ..color = palette.light.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.03;
    canvas.drawPath(innerRimPath, innerRimPaint);
  }

  void _drawInner(Canvas canvas, Size size, double cx, double cy, double r) {
    // Inner medallion with different metallic gradient direction
    final innerPath = _shapePath(cx, cy, r, shape);
    final innerGrad = ui.Gradient.linear(
      Offset(cx - r, cy - r),
      Offset(cx + r, cy + r),
      [palette.dark, palette.mid, palette.light, palette.mid],
      [0.0, 0.35, 0.65, 1.0],
    );
    final innerPaint = Paint()..shader = innerGrad;
    canvas.drawPath(innerPath, innerPaint);

    // Subtle inner shadow
    final innerShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.08
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawPath(innerPath, innerShadow);
  }

  void _drawRivets(Canvas canvas, double cx, double cy, double r) {
    final rivetPaint = Paint()..color = palette.highlight;
    final rivetShadow = Paint()..color = Colors.black.withValues(alpha: 0.3);
    final rivetR = r * 0.045;
    const count = 8;

    for (int i = 0; i < count; i++) {
      final angle = (2 * math.pi / count) * i - math.pi / 2;
      final dist = r * 0.82;
      final x = cx + dist * math.cos(angle);
      final y = cy + dist * math.sin(angle);
      canvas.drawCircle(Offset(x, y + 0.5), rivetR, rivetShadow);
      canvas.drawCircle(Offset(x, y), rivetR, rivetPaint);
    }
  }

  void _drawCrown(Canvas canvas, double cx, double cy, double r) {
    final crownH = r * 0.22;
    final crownW = r * 0.4;
    final topY = cy - r + r * 0.05;

    final path = Path()
      ..moveTo(cx - crownW, topY)
      ..lineTo(cx - crownW * 0.5, topY - crownH)
      ..lineTo(cx, topY - crownH * 0.4)
      ..lineTo(cx + crownW * 0.5, topY - crownH)
      ..lineTo(cx + crownW, topY)
      ..close();

    final grad = ui.Gradient.linear(
      Offset(cx, topY - crownH),
      Offset(cx, topY),
      [palette.highlight, palette.mid],
    );
    canvas.drawPath(path, Paint()..shader = grad);
    canvas.drawPath(
      path,
      Paint()
        ..color = palette.rim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  Path _shapePath(double cx, double cy, double r, BadgeShape shape) {
    switch (shape) {
      case BadgeShape.shield:
        return _shieldPath(cx, cy, r);
      case BadgeShape.hex:
        return _hexPath(cx, cy, r);
      case BadgeShape.diamond:
        return _diamondPath(cx, cy, r);
      case BadgeShape.star:
        return _starMedalPath(cx, cy, r);
      case BadgeShape.circle:
        return Path()
          ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    }
  }

  Path _shieldPath(double cx, double cy, double r) {
    return Path()
      ..moveTo(cx, cy - r)
      ..lineTo(cx + r * 0.85, cy - r * 0.55)
      ..lineTo(cx + r * 0.75, cy + r * 0.35)
      ..quadraticBezierTo(cx, cy + r * 1.05, cx, cy + r)
      ..quadraticBezierTo(cx, cy + r * 1.05, cx - r * 0.75, cy + r * 0.35)
      ..lineTo(cx - r * 0.85, cy - r * 0.55)
      ..close();
  }

  Path _hexPath(double cx, double cy, double r) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i - math.pi / 2;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  Path _diamondPath(double cx, double cy, double r) {
    return Path()
      ..moveTo(cx, cy - r)
      ..lineTo(cx + r * 0.7, cy)
      ..lineTo(cx, cy + r)
      ..lineTo(cx - r * 0.7, cy)
      ..close();
  }

  Path _starMedalPath(double cx, double cy, double r) {
    final path = Path();
    const points = 8;
    final outerR = r;
    final innerR = r * 0.7;
    for (int i = 0; i < points * 2; i++) {
      final angle = (math.pi / points) * i - math.pi / 2;
      final rad = i.isEven ? outerR : innerR;
      final x = cx + rad * math.cos(angle);
      final y = cy + rad * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _EmblemPainter old) {
    return palette != old.palette ||
        shape != old.shape ||
        tier != old.tier ||
        earned != old.earned;
  }
}

// ─── Wings painter (for gold+ tiers) ─────────────────────────────────
class _WingsPainter extends CustomPainter {
  _WingsPainter({
    required this.palette,
    required this.tier,
    required this.diameter,
  });

  final _MetallicPalette palette;
  final BadgeTier tier;
  final double diameter;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final wingSpan = diameter * 0.7;
    final wingH = diameter * 0.4;

    // Determine wing complexity by tier
    final feathers = tier.index >= BadgeTier.legendary.index
        ? 5
        : tier.index >= BadgeTier.platinum.index
        ? 4
        : 3;

    // Draw left wing
    _drawWing(canvas, cx, cy, wingSpan, wingH, feathers, isLeft: true);

    // Draw right wing
    _drawWing(canvas, cx, cy, wingSpan, wingH, feathers, isLeft: false);
  }

  void _drawWing(
    Canvas canvas,
    double cx,
    double cy,
    double span,
    double h,
    int feathers, {
    required bool isLeft,
  }) {
    final dir = isLeft ? -1.0 : 1.0;

    for (int i = feathers - 1; i >= 0; i--) {
      final featherSpan = span * (0.5 + 0.5 * (i / (feathers - 1)));
      final featherH = h * (0.4 + 0.6 * (i / (feathers - 1)));
      final yOffset = -featherH * 0.15 * i;
      final angle = -0.15 - 0.12 * i;

      final path = Path();
      final startX = cx + dir * diameter * 0.35;
      final startY = cy + yOffset;

      path.moveTo(startX, startY);
      path.quadraticBezierTo(
        startX + dir * featherSpan * 0.5,
        startY - featherH * 0.7 + angle * featherSpan,
        startX + dir * featherSpan,
        startY - featherH * 0.3 + angle * featherSpan,
      );
      path.quadraticBezierTo(
        startX + dir * featherSpan * 0.6,
        startY + featherH * 0.1,
        startX,
        startY + featherH * 0.15,
      );
      path.close();

      // Metallic gradient per feather
      final gradColors = [
        Color.lerp(palette.dark, palette.mid, i / feathers)!,
        Color.lerp(palette.mid, palette.light, i / feathers)!,
        Color.lerp(palette.light, palette.highlight, i / feathers)!,
      ];

      final grad = ui.Gradient.linear(
        Offset(startX, startY - featherH),
        Offset(startX + dir * featherSpan, startY),
        gradColors,
        [0.0, 0.5, 1.0],
      );

      // Shadow
      canvas.drawPath(
        path.shift(const Offset(0, 1.5)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );

      canvas.drawPath(path, Paint()..shader = grad);

      // Edge highlight
      canvas.drawPath(
        path,
        Paint()
          ..color = palette.rim.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WingsPainter old) {
    return palette != old.palette ||
        tier != old.tier ||
        diameter != old.diameter;
  }
}

// ─── Tooltip popup for badge details ──────────────────────────────────
class BadgeTooltipSheet extends StatelessWidget {
  const BadgeTooltipSheet({super.key, required this.badge, this.earned = true});

  final BadgeDef badge;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = badge.tier != null
        ? _paletteForTier(badge.tier)
        : _paletteForColor(badge.color);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Decorative line
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          BadgeWidget(
            badge: badge,
            size: BadgeSize.large,
            showLabel: false,
            earned: earned,
          ),
          const SizedBox(height: 16),
          Text(
            badge.label,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          if (badge.tier != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    palette.dark.withValues(alpha: 0.3),
                    palette.mid.withValues(alpha: 0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: palette.mid.withValues(alpha: 0.4)),
              ),
              child: Text(
                tierLabel(badge.tier!),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: palette.light,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            badge.description,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (badge.requirement.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.construction, size: 14, color: palette.mid),
                const SizedBox(width: 6),
                Text(
                  badge.requirement,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: palette.mid,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          if (!earned) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Not yet earned',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Show badge detail as a bottom sheet
void showBadgeDetail(
  BuildContext context,
  BadgeDef badge, {
  bool earned = true,
}) {
  showModalBottomSheet(
    context: context,
    builder: (_) => BadgeTooltipSheet(badge: badge, earned: earned),
  );
}

// ─── Compact badge row for contractor cards ───────────────────────────
class BadgeRow extends StatelessWidget {
  const BadgeRow({
    super.key,
    required this.badgeIds,
    this.maxVisible = 5,
    this.size = BadgeSize.small,
    this.showLabels = false,
  });

  final List<String> badgeIds;
  final int maxVisible;
  final BadgeSize size;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final badges = resolveBadges(badgeIds);
    if (badges.isEmpty) return const SizedBox.shrink();

    final visible = badges.take(maxVisible).toList();
    final overflow = badges.length - maxVisible;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...visible.map(
          (b) => BadgeWidget(
            badge: b,
            size: size,
            showLabel: showLabels,
            onTap: () => showBadgeDetail(context, b),
          ),
        ),
        if (overflow > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '+$overflow',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
