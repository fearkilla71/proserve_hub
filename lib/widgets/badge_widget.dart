import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/contractor_badge.dart';

/// ── Visual badge widget ───────────────────────────────────────────────
///
/// Renders a badge with its unique icon, shape, glow, and optional tier ring.
/// Three sizes: small (26), medium (36), large (48).

enum BadgeSize { small, medium, large }

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
        return 30;
      case BadgeSize.medium:
        return 40;
      case BadgeSize.large:
        return 52;
    }
  }

  double get _iconSize {
    switch (size) {
      case BadgeSize.small:
        return 14;
      case BadgeSize.medium:
        return 18;
      case BadgeSize.large:
        return 24;
    }
  }

  double get _fontSize {
    switch (size) {
      case BadgeSize.small:
        return 9;
      case BadgeSize.medium:
        return 10;
      case BadgeSize.large:
        return 11;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = earned ? badge.color : Colors.grey.shade700;
    final glow = earned ? badge.glowColor : Colors.grey.shade600;

    Widget icon = Container(
      width: _diameter,
      height: _diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: earned
            ? LinearGradient(
                colors: [color, glow],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: earned ? null : Colors.grey.shade800,
        boxShadow: earned
            ? [
                BoxShadow(
                  color: glow.withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Icon(
          badge.icon,
          size: _iconSize,
          color: earned ? Colors.white : Colors.grey.shade500,
        ),
      ),
    );

    // Apply shape clipping
    icon = _applyShape(icon, badge.shape);

    // Tier ring for achievement badges
    if (badge.tier != null && earned) {
      icon = _TierRing(tier: badge.tier!, diameter: _diameter, child: icon);
    }

    final widget = onTap != null
        ? GestureDetector(onTap: onTap, child: icon)
        : icon;

    if (!showLabel) return widget;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        widget,
        const SizedBox(height: 4),
        SizedBox(
          width: _diameter + 14,
          child: Text(
            badge.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: _fontSize,
              fontWeight: FontWeight.w700,
              color: earned
                  ? Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.9)
                  : Colors.grey.shade600,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _applyShape(Widget child, BadgeShape shape) {
    switch (shape) {
      case BadgeShape.hex:
        return ClipPath(clipper: _HexClip(), child: child);
      case BadgeShape.shield:
        return ClipPath(clipper: _ShieldClip(), child: child);
      case BadgeShape.diamond:
        return Transform.rotate(
          angle: math.pi / 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: _diameter * 0.82,
              height: _diameter * 0.82,
              child: Transform.rotate(angle: -math.pi / 4, child: child),
            ),
          ),
        );
      case BadgeShape.star:
        return ClipPath(clipper: _StarClip(), child: child);
      case BadgeShape.circle:
        return child;
    }
  }
}

// ─── Tier ring decoration ─────────────────────────────────────────────
class _TierRing extends StatelessWidget {
  const _TierRing({
    required this.tier,
    required this.diameter,
    required this.child,
  });

  final BadgeTier tier;
  final double diameter;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ringColor = _ringColor(tier);
    final ringWidth = diameter < 36 ? 1.5 : 2.0;

    return Container(
      padding: EdgeInsets.all(ringWidth + 1),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: ringWidth),
        boxShadow: [
          BoxShadow(color: ringColor.withValues(alpha: 0.2), blurRadius: 6),
        ],
      ),
      child: child,
    );
  }

  Color _ringColor(BadgeTier tier) {
    switch (tier) {
      case BadgeTier.bronze:
        return const Color(0xFFCD7F32);
      case BadgeTier.silver:
        return const Color(0xFFE2E8F0);
      case BadgeTier.gold:
        return const Color(0xFFFBBF24);
      case BadgeTier.platinum:
        return const Color(0xFF22D3EE);
      case BadgeTier.legendary:
        return const Color(0xFFC084FC);
    }
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
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BadgeWidget(
            badge: badge,
            size: BadgeSize.large,
            showLabel: false,
            earned: earned,
          ),
          const SizedBox(height: 12),
          Text(
            badge.label,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (badge.tier != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: badge.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                tierLabel(badge.tier!),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: badge.color,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            badge.description,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (badge.requirement.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              badge.requirement,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (!earned) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Not yet earned',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
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
      spacing: 6,
      runSpacing: 6,
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '+$overflow',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Clip paths ───────────────────────────────────────────────────────
class _HexClip extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w, h * 0.25)
      ..lineTo(w, h * 0.75)
      ..lineTo(w * 0.5, h)
      ..lineTo(0, h * 0.75)
      ..lineTo(0, h * 0.25)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _ShieldClip extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w, h * 0.15)
      ..quadraticBezierTo(w, h * 0.6, w * 0.5, h)
      ..quadraticBezierTo(0, h * 0.6, 0, h * 0.15)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _StarClip extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final outerR = size.width / 2;
    final innerR = outerR * 0.42;
    const points = 5;
    final path = Path();

    for (int i = 0; i < points * 2; i++) {
      final angle = (math.pi / points) * i - math.pi / 2;
      final r = i.isEven ? outerR : innerR;
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

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
