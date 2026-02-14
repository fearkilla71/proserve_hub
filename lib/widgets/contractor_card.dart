import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/contractor_badge.dart';
import 'badge_widget.dart';
import 'card_aura_painter.dart';

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
    this.aura = AuraType.none,
    this.responseTime = '',
    this.completionRate = 0,
    this.certifications = const [],
    this.servicesOffered = const [],
    this.memberSince = '',
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
  // New fields
  final AuraType aura;
  final String responseTime;
  final int completionRate;
  final List<String> certifications;
  final List<String> servicesOffered;
  final String memberSince;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 3D Flippable Contractor Card
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class ContractorCard extends StatefulWidget {
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
  State<ContractorCard> createState() => _ContractorCardState();
}

class _ContractorCardState extends State<ContractorCard>
    with TickerProviderStateMixin {
  late final AnimationController _flipController;
  late final AnimationController _auraController;
  late final Animation<double> _flipAnimation;
  bool _showFront = true;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flipAnimation = Tween<double>(begin: 0, end: math.pi).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    );
    _flipController.addListener(() {
      final halfWay = _flipAnimation.value >= math.pi / 2;
      if (halfWay != !_showFront) {
        setState(() => _showFront = !halfWay);
      }
    });

    _auraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.data.aura != AuraType.none) {
      _auraController.repeat();
    }
  }

  @override
  void didUpdateWidget(ContractorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data.aura != oldWidget.data.aura) {
      if (widget.data.aura != AuraType.none) {
        _auraController.repeat();
      } else {
        _auraController.stop();
        _auraController.reset();
      }
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    _auraController.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    if (_flipController.isAnimating) return;
    if (_flipController.isCompleted) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, fadeValue, child) {
        return Opacity(
          opacity: fadeValue,
          child: Transform.translate(
            offset: Offset(0, (1 - fadeValue) * 12),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if ((details.velocity.pixelsPerSecond.dx).abs() > 100) {
            _toggleFlip();
          }
        },
        onDoubleTap: _toggleFlip,
        child: AnimatedBuilder(
          animation: Listenable.merge([_flipAnimation, _auraController]),
          builder: (context, _) {
            final angle = _flipAnimation.value;
            return _buildAuraWrapper(
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..rotateY(angle),
                child: angle < math.pi / 2
                    ? _CardFront(
                        data: widget.data,
                        onEdit: widget.onEdit,
                        showEdit: widget.showEdit,
                        onFlip: _toggleFlip,
                      )
                    : Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(math.pi),
                        child: _CardBack(
                          data: widget.data,
                          onFlip: _toggleFlip,
                        ),
                      ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAuraWrapper({required Widget child}) {
    if (widget.data.aura == AuraType.none) return child;

    return CustomPaint(
      foregroundPainter: CardAuraPainter(
        aura: widget.data.aura,
        t: _auraController.value,
        borderRadius: 20,
      ),
      child: child,
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Card Front Side (enhanced existing design)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _CardFront extends StatelessWidget {
  const _CardFront({
    required this.data,
    required this.onFlip,
    this.onEdit,
    this.showEdit = true,
  });

  final ContractorCardData data;
  final VoidCallback onFlip;
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

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: accent.withValues(alpha: 0.35)),
      ),
      child: Stack(
        children: [
          // Gradient background
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(decoration: BoxDecoration(gradient: gradient)),
            ),
          ),
          // Texture overlay
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
          // Banner
          if (data.showBanner)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: _StatusBanner(data: data, accent: accent),
            ),
          // Content
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
                      aura: data.aura,
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
                // Flip hint
                const SizedBox(height: 8),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.swipe,
                        size: 14,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Swipe or double-tap to flip',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
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

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Card Back Side — Stats Dashboard + Certifications
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _CardBack extends StatelessWidget {
  const _CardBack({required this.data, required this.onFlip});

  final ContractorCardData data;
  final VoidCallback onFlip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = data.themeKey == 'custom'
        ? data.gradientEnd
        : _cardThemeAccent(data.themeKey, scheme);

    // Darker version of gradient for back
    final darkStart = Color.lerp(data.gradientStart, Colors.black, 0.3)!;
    final darkEnd = Color.lerp(data.gradientEnd, Colors.black, 0.2)!;

    return Card(
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
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [darkStart, darkEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          // Circuit board texture for the back
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CustomPaint(
                painter: _CardTexturePainter(
                  texture: 'circuit',
                  color: accent,
                  opacity: 0.06,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(Icons.analytics_outlined, color: accent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'STATS & CREDENTIALS',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: accent,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: onFlip,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent.withValues(alpha: 0.15),
                        ),
                        child: Icon(
                          Icons.flip_to_front,
                          size: 18,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Stats Grid
                Row(
                  children: [
                    Expanded(
                      child: _BackStatBox(
                        icon: Icons.check_circle_outline,
                        value: '${data.totalJobsCompleted}',
                        label: 'Jobs done',
                        accent: accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _BackStatBox(
                        icon: Icons.star,
                        value: data.ratingValue > 0
                            ? data.ratingValue.toStringAsFixed(1)
                            : '—',
                        label: '${data.reviewCount} reviews',
                        accent: accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _BackStatBox(
                        icon: Icons.speed,
                        value: data.responseTime.isNotEmpty
                            ? data.responseTime
                            : '—',
                        label: 'Response',
                        accent: accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _BackStatBox(
                        icon: Icons.timeline,
                        value: data.yearsExp > 0 ? '${data.yearsExp} yrs' : '—',
                        label: 'Experience',
                        accent: accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _BackStatBox(
                        icon: Icons.trending_up,
                        value: data.completionRate > 0
                            ? '${data.completionRate}%'
                            : '—',
                        label: 'Completion',
                        accent: accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _BackStatBox(
                        icon: Icons.calendar_today,
                        value: data.memberSince.isNotEmpty
                            ? data.memberSince
                            : '—',
                        label: 'Member since',
                        accent: accent,
                      ),
                    ),
                  ],
                ),
                // Certifications
                if (data.certifications.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'CERTIFICATIONS',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: data.certifications.map((cert) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, size: 12, color: accent),
                            const SizedBox(width: 4),
                            Text(
                              cert,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
                // Services offered
                if (data.servicesOffered.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'SERVICES',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: data.servicesOffered.map((svc) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          svc,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                // Level progression bar
                const SizedBox(height: 14),
                _LevelProgressBar(
                  reviewCount: data.reviewCount,
                  accent: accent,
                ),
                // Flip hint
                const SizedBox(height: 8),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.swipe,
                        size: 14,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Swipe or double-tap to flip back',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
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

// ─── Level Progress Bar ──────────────────────────────────────────────
class _LevelProgressBar extends StatelessWidget {
  const _LevelProgressBar({required this.reviewCount, required this.accent});

  final int reviewCount;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    String currentLevel;
    String nextLevel;
    int current;
    int needed;

    if (reviewCount >= 60) {
      currentLevel = 'Platinum';
      nextLevel = 'Max level';
      current = reviewCount;
      needed = reviewCount; // full bar
    } else if (reviewCount >= 30) {
      currentLevel = 'Gold';
      nextLevel = 'Platinum (60)';
      current = reviewCount - 30;
      needed = 30;
    } else if (reviewCount >= 10) {
      currentLevel = 'Silver';
      nextLevel = 'Gold (30)';
      current = reviewCount - 10;
      needed = 20;
    } else {
      currentLevel = 'Bronze';
      nextLevel = 'Silver (10)';
      current = reviewCount;
      needed = 10;
    }

    final progress = needed > 0 ? (current / needed).clamp(0.0, 1.0) : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              currentLevel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
            Text(
              nextLevel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: scheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(accent),
          ),
        ),
      ],
    );
  }
}

// ─── Back Stat Box ───────────────────────────────────────────────────
class _BackStatBox extends StatelessWidget {
  const _BackStatBox({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
              fontSize: 9,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Shared Components (existing, enhanced)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

String _levelLabel(int reviewCount) {
  if (reviewCount >= 60) return 'Platinum';
  if (reviewCount >= 30) return 'Gold';
  if (reviewCount >= 10) return 'Silver';
  return 'Bronze';
}

Color _cardThemeAccent(String themeKey, ColorScheme scheme) {
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

IconData _bannerIconFromKey(String key) {
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

/// ── Status Banner ────────────────────────────────────────────────────
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

    BadgeTier? highestTier;
    for (final id in earned.reversed) {
      final b = badgeById(id);
      if (b != null && b.tier != null) {
        final t = b.tier!;
        if (highestTier == null || t.index > highestTier.index) {
          highestTier = t;
        }
      }
    }

    String tierText = '';
    if (highestTier != null) {
      tierText = '${tierLabel(highestTier)} Pro';
    }

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
      Icon(_bannerIconFromKey(data.bannerIcon), size: 14, color: accent),
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
    this.aura = AuraType.none,
  });

  final String name;
  final String logoUrl;
  final String shape;
  final String style;
  final bool glow;
  final Color accent;
  final AuraType aura;

  Color _auraGlowColor() {
    switch (aura) {
      case AuraType.lightning:
        return const Color(0xFF4FC3F7);
      case AuraType.fire:
        return const Color(0xFFFF6D00);
      case AuraType.rainbow:
        return const Color(0xFFE040FB);
      case AuraType.ice:
        return const Color(0xFF80DEEA);
      case AuraType.gold:
        return const Color(0xFFFFD54F);
      default:
        return accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final monogram = name.isNotEmpty ? name[0].toUpperCase() : 'C';
    final hasLogo = logoUrl.isNotEmpty && style != 'monogram';
    final avatar = CircleAvatar(
      radius: 26,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      backgroundImage: hasLogo ? CachedNetworkImageProvider(logoUrl) : null,
      child: hasLogo
          ? null
          : Text(
              monogram,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
    );

    final glowColor = aura != AuraType.none ? _auraGlowColor() : accent;
    final hasGlow = glow || aura != AuraType.none;

    final decorated = Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: hasGlow
            ? [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.35),
                  blurRadius: aura != AuraType.none ? 20 : 12,
                  spreadRadius: aura != AuraType.none ? 3 : 1,
                ),
                if (aura != AuraType.none)
                  BoxShadow(
                    color: glowColor.withValues(alpha: 0.15),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
              ]
            : null,
        border: Border.all(
          color: (aura != AuraType.none ? glowColor : accent)
              .withValues(alpha: 0.6),
          width: aura != AuraType.none ? 2.5 : 2,
        ),
      ),
      child: avatar,
    );

    switch (shape) {
      case 'hex':
        return ClipPath(clipper: _HexClipper(), child: decorated);
      case 'shield':
        return ClipPath(clipper: _ShieldClipper(), child: decorated);
      case 'diamond':
        return Transform.rotate(
          angle: math.pi / 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Transform.rotate(angle: -math.pi / 4, child: avatar),
            ),
          ),
        );
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
        paint.style = PaintingStyle.fill;
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
      case 'diamonds':
        paint.style = PaintingStyle.stroke;
        for (double y = 0; y < size.height; y += 20) {
          for (double x = 0; x < size.width; x += 20) {
            final path = Path()
              ..moveTo(x + 10, y)
              ..lineTo(x + 20, y + 10)
              ..lineTo(x + 10, y + 20)
              ..lineTo(x, y + 10)
              ..close();
            canvas.drawPath(path, paint);
          }
        }
        break;
      case 'crosshatch':
        for (double i = -size.height; i < size.width; i += 12) {
          canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), paint);
          canvas.drawLine(Offset(i + size.height, 0), Offset(i, size.height), paint);
        }
        break;
      case 'circuit':
        final rng = math.Random(42);
        paint.strokeWidth = 0.8;
        for (int i = 0; i < 30; i++) {
          final x1 = rng.nextDouble() * size.width;
          final y1 = rng.nextDouble() * size.height;
          final horizontal = rng.nextBool();
          final len = 10 + rng.nextDouble() * 30;
          final x2 = horizontal ? x1 + len : x1;
          final y2 = horizontal ? y1 : y1 + len;
          canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
          // Node dot
          paint.style = PaintingStyle.fill;
          canvas.drawCircle(Offset(x2, y2), 1.5, paint);
          paint.style = PaintingStyle.stroke;
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
