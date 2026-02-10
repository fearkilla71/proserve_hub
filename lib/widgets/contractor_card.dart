import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/contractor_badge.dart';
import 'badge_widget.dart';

class ContractorCardData {
  const ContractorCardData({
    required this.displayName,
    required this.contactLine,
    required this.logoUrl,
    required this.headline,
    required this.bio,
    required this.ratingValue,
    required this.reviewCount,
    required this.yearsExp,
    required this.badges,
    required this.themeKey,
    required this.gradientStart,
    required this.gradientEnd,
    required this.avatarStyle,
    required this.avatarShape,
    required this.texture,
    required this.textureOpacity,
    required this.showBanner,
    required this.bannerIcon,
    required this.avatarGlow,
    required this.latestReview,
    this.totalJobsCompleted = 0,
  });

  final String displayName;
  final String contactLine;
  final String logoUrl;
  final String headline;
  final String bio;
  final double ratingValue;
  final int reviewCount;
  final int yearsExp;
  final List<String> badges;
  final String themeKey;
  final Color gradientStart;
  final Color gradientEnd;
  final String avatarStyle;
  final String avatarShape;
  final String texture;
  final double textureOpacity;
  final bool showBanner;
  final String bannerIcon;
  final bool avatarGlow;
  final String latestReview;
  final int totalJobsCompleted;
}

class ContractorCard extends StatelessWidget {
  const ContractorCard({
    super.key,
    required this.data,
    this.onEdit,
    this.showEdit = true,
  });

  final ContractorCardData data;
  final VoidCallback? onEdit;
  final bool showEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = data.themeKey == 'custom'
        ? data.gradientEnd
        : _cardThemeAccent(data.themeKey, scheme);
    final gradient = LinearGradient(
      colors: [data.gradientStart, data.gradientEnd],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 12),
            child: child,
          ),
        );
      },
      child: Card(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: accent.withValues(alpha: 0.35)),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(decoration: BoxDecoration(gradient: gradient)),
              ),
            ),
            if (data.texture != 'none')
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CustomPaint(
                    painter: _CardTexturePainter(
                      texture: data.texture,
                      color: scheme.onSurfaceVariant,
                      opacity: data.textureOpacity,
                    ),
                  ),
                ),
              ),
            if (data.showBanner)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: _StatusBanner(data: data, accent: accent),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AvatarBadge(
                        name: data.displayName,
                        logoUrl: data.logoUrl,
                        shape: data.avatarShape,
                        style: data.avatarStyle,
                        glow: data.avatarGlow,
                        accent: accent,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.displayName,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              data.contactLine,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      if (showEdit && onEdit != null)
                        TextButton.icon(
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('Edit'),
                        ),
                    ],
                  ),
                  if (data.headline.isNotEmpty || data.bio.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      data.headline.isNotEmpty ? data.headline : data.bio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatChip(
                        label: data.ratingValue > 0
                            ? '${data.ratingValue.toStringAsFixed(1)} (${data.reviewCount})'
                            : 'No ratings yet',
                        icon: Icons.star,
                        color: accent,
                      ),
                      if (data.yearsExp > 0)
                        _StatChip(
                          label: '${data.yearsExp} yrs exp',
                          icon: Icons.timeline,
                          color: accent,
                        ),
                      _StatChip(
                        label: _levelLabel(data.reviewCount),
                        icon: Icons.military_tech_outlined,
                        color: accent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    data.latestReview.isNotEmpty
                        ? '"${data.latestReview}"'
                        : 'No review comments yet.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (data.badges.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    BadgeRow(
                      badgeIds: data.badges,
                      maxVisible: 5,
                      size: BadgeSize.small,
                    ),
                  ],
                  // Achievement badges (auto-earned)
                  Builder(
                    builder: (context) {
                      final earned = computeEarnedAchievements(
                        totalJobsCompleted: data.totalJobsCompleted,
                        reviewCount: data.reviewCount,
                        avgRating: data.ratingValue,
                      );
                      if (earned.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          Text(
                            'ACHIEVEMENTS',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  color: scheme.onSurfaceVariant.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                          ),
                          const SizedBox(height: 8),
                          BadgeRow(
                            badgeIds: earned,
                            maxVisible: 4,
                            size: BadgeSize.small,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _levelLabel(int reviewCount) {
    if (reviewCount >= 60) return 'Platinum';
    if (reviewCount >= 30) return 'Gold';
    if (reviewCount >= 10) return 'Silver';
    return 'Bronze';
  }

  static Color _cardThemeAccent(String themeKey, ColorScheme scheme) {
    switch (themeKey) {
      case 'forest':
        return const Color(0xFF2E7D32);
      case 'amber':
        return const Color(0xFFFF8F00);
      case 'slate':
        return const Color(0xFF546E7A);
      case 'ocean':
        return const Color(0xFF1E88E5);
      case 'rose':
        return const Color(0xFFD81B60);
      case 'sunburst':
        return const Color(0xFFF4511E);
      case 'ember':
        return const Color(0xFFE65100);
      case 'neon':
        return const Color(0xFF00C853);
      case 'carbon':
        return const Color(0xFF37474F);
      case 'gold':
        return const Color(0xFFFFD54F);
      case 'navy':
      default:
        return scheme.primary;
    }
  }

  static IconData _bannerIconFromKey(String key) {
    switch (key) {
      case 'spark':
        return Icons.auto_awesome;
      case 'bolt':
        return Icons.bolt;
      case 'shield':
        return Icons.shield_outlined;
      case 'star':
        return Icons.star_outline;
      case 'check':
        return Icons.verified_outlined;
      default:
        return Icons.auto_awesome;
    }
  }
}

/// ── Status Banner ────────────────────────────────────────────────────
/// Shows the contractor's top achievement tier + status line.
/// Meaningful content: tier level, jobs completed, response speed.
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.data, required this.accent});

  final ContractorCardData data;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final earned = computeEarnedAchievements(
      totalJobsCompleted: data.totalJobsCompleted,
      reviewCount: data.reviewCount,
      avgRating: data.ratingValue,
    );

    // Find highest tier earned
    BadgeTier? highestTier;
    String tierText = '';
    for (final id in earned.reversed) {
      final b = badgeById(id);
      if (b != null && b.tier != null) {
        final t = b.tier!;
        if (highestTier == null || t.index > highestTier.index) {
          highestTier = t;
        }
      }
    }

    if (highestTier != null) {
      tierText = '${tierLabel(highestTier)} Pro';
    }

    // Build status items
    final items = <Widget>[];
    if (tierText.isNotEmpty) {
      items.add(
        _bannerChip(icon: Icons.military_tech, text: tierText, color: accent),
      );
    }
    if (data.totalJobsCompleted > 0) {
      items.add(
        _bannerChip(
          icon: Icons.check_circle_outline,
          text: '${data.totalJobsCompleted} jobs',
          color: accent,
        ),
      );
    }
    items.add(
      Icon(
        ContractorCard._bannerIconFromKey(data.bannerIcon),
        size: 14,
        color: accent,
      ),
    );

    return Container(
      height: 30,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.2),
            accent.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            if (items.length > 1) ...[
              ...items
                  .take(items.length - 1)
                  .expand((w) => [w, const SizedBox(width: 10)]),
            ],
            const Spacer(),
            items.last,
          ],
        ),
      ),
    );
  }

  Widget _bannerChip({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({
    required this.name,
    required this.logoUrl,
    required this.shape,
    required this.style,
    required this.glow,
    required this.accent,
  });

  final String name;
  final String logoUrl;
  final String shape;
  final String style;
  final bool glow;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final monogram = name.isNotEmpty ? name[0].toUpperCase() : 'C';
    final hasLogo = logoUrl.isNotEmpty && style != 'monogram';
    final avatar = CircleAvatar(
      radius: 26,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      backgroundImage: hasLogo ? NetworkImage(logoUrl) : null,
      child: hasLogo
          ? null
          : Text(
              monogram,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
    );

    final decorated = Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: glow
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.25),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
        border: Border.all(color: accent.withValues(alpha: 0.6), width: 2),
      ),
      child: avatar,
    );

    switch (shape) {
      case 'hex':
        return ClipPath(clipper: _HexClipper(), child: decorated);
      case 'shield':
        return ClipPath(clipper: _ShieldClipper(), child: decorated);
      case 'circle':
      default:
        return decorated;
    }
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
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
}

class _CardTexturePainter extends CustomPainter {
  _CardTexturePainter({
    required this.texture,
    required this.color,
    required this.opacity,
  });

  final String texture;
  final Color color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    switch (texture) {
      case 'dots':
        for (double y = 8; y < size.height; y += 12) {
          for (double x = 8; x < size.width; x += 12) {
            canvas.drawCircle(Offset(x, y), 1.2, paint);
          }
        }
        break;
      case 'grid':
        for (double x = 0; x < size.width; x += 16) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        }
        for (double y = 0; y < size.height; y += 16) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
        break;
      case 'waves':
        final path = Path();
        for (double y = 12; y < size.height; y += 20) {
          path.reset();
          path.moveTo(0, y);
          for (double x = 0; x <= size.width; x += 20) {
            path.quadraticBezierTo(
              x + 10,
              y + math.sin((x / size.width) * math.pi * 2) * 6,
              x + 20,
              y,
            );
          }
          canvas.drawPath(path, paint);
        }
        break;
      default:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _CardTexturePainter oldDelegate) {
    return texture != oldDelegate.texture ||
        color != oldDelegate.color ||
        opacity != oldDelegate.opacity;
  }
}

class _HexClipper extends CustomClipper<Path> {
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

class _ShieldClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w, h * 0.2)
      ..lineTo(w * 0.85, h)
      ..lineTo(w * 0.5, h * 0.85)
      ..lineTo(w * 0.15, h)
      ..lineTo(0, h * 0.2)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
