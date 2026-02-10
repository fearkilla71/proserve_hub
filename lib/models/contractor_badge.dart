import 'package:flutter/material.dart';

/// ── Achievement badge system ──────────────────────────────────────────
///
/// Badges fall into two buckets:
///  1. **Profile badges** – manually toggled (Licensed, Insured, etc.)
///  2. **Achievement badges** – auto-earned from milestones (jobs, reviews, etc.)
///
/// Each badge has a unique visual: icon, color pair, tier, and shape style.

// ─── Badge shape variants ─────────────────────────────────────────────
enum BadgeShape { circle, hex, shield, diamond, star }

// ─── Badge tiers (for achievement badges) ─────────────────────────────
enum BadgeTier { bronze, silver, gold, platinum, legendary }

// ─── Badge category ───────────────────────────────────────────────────
enum BadgeCategory { profile, achievement }

// ─── Core badge definition ────────────────────────────────────────────
class BadgeDef {
  const BadgeDef({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.glowColor,
    required this.shape,
    required this.category,
    this.tier,
    this.description = '',
    this.requirement = '',
  });

  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final Color glowColor;
  final BadgeShape shape;
  final BadgeCategory category;
  final BadgeTier? tier;
  final String description;
  final String requirement;
}

// ─── Profile badges (contractor-selectable) ───────────────────────────
const List<BadgeDef> profileBadges = [
  BadgeDef(
    id: 'licensed',
    label: 'Licensed',
    icon: Icons.verified_user,
    color: Color(0xFF2563EB),
    glowColor: Color(0xFF60A5FA),
    shape: BadgeShape.shield,
    category: BadgeCategory.profile,
    description: 'State-licensed professional',
  ),
  BadgeDef(
    id: 'insured',
    label: 'Insured',
    icon: Icons.shield,
    color: Color(0xFF0D9488),
    glowColor: Color(0xFF5EEAD4),
    shape: BadgeShape.shield,
    category: BadgeCategory.profile,
    description: 'Carries general liability insurance',
  ),
  BadgeDef(
    id: 'background_checked',
    label: 'BG Checked',
    icon: Icons.fingerprint,
    color: Color(0xFF7C3AED),
    glowColor: Color(0xFFA78BFA),
    shape: BadgeShape.hex,
    category: BadgeCategory.profile,
    description: 'Background check verified',
  ),
  BadgeDef(
    id: 'family_owned',
    label: 'Family Owned',
    icon: Icons.home_work,
    color: Color(0xFFD97706),
    glowColor: Color(0xFFFBBF24),
    shape: BadgeShape.circle,
    category: BadgeCategory.profile,
    description: 'Family-owned & operated business',
  ),
  BadgeDef(
    id: 'eco_friendly',
    label: 'Eco Friendly',
    icon: Icons.eco,
    color: Color(0xFF16A34A),
    glowColor: Color(0xFF4ADE80),
    shape: BadgeShape.diamond,
    category: BadgeCategory.profile,
    description: 'Uses eco-friendly materials & practices',
  ),
  BadgeDef(
    id: 'quick_response',
    label: 'Quick Response',
    icon: Icons.bolt,
    color: Color(0xFFEAB308),
    glowColor: Color(0xFFFDE047),
    shape: BadgeShape.star,
    category: BadgeCategory.profile,
    description: 'Typically responds within 1 hour',
  ),
  BadgeDef(
    id: 'top_rated',
    label: 'Top Rated',
    icon: Icons.emoji_events,
    color: Color(0xFFF59E0B),
    glowColor: Color(0xFFFCD34D),
    shape: BadgeShape.star,
    category: BadgeCategory.profile,
    description: 'Consistently rated 4.5+ stars',
  ),
];

// ─── Achievement badges (auto-earned) ─────────────────────────────────

/// Job-completion milestones
const List<_JobMilestone> _jobMilestones = [
  _JobMilestone(1, BadgeTier.bronze, 'First Job', 'Complete your first job'),
  _JobMilestone(5, BadgeTier.bronze, 'Getting Started', 'Complete 5 jobs'),
  _JobMilestone(10, BadgeTier.silver, 'Reliable Pro', 'Complete 10 jobs'),
  _JobMilestone(25, BadgeTier.silver, 'Seasoned Pro', 'Complete 25 jobs'),
  _JobMilestone(50, BadgeTier.gold, 'Veteran', 'Complete 50 jobs'),
  _JobMilestone(100, BadgeTier.gold, 'Centurion', 'Complete 100 jobs'),
  _JobMilestone(
    250,
    BadgeTier.platinum,
    'Elite Contractor',
    'Complete 250 jobs',
  ),
  _JobMilestone(500, BadgeTier.legendary, 'Legend', 'Complete 500 jobs'),
];

/// Review-count milestones
const List<_ReviewMilestone> _reviewMilestones = [
  _ReviewMilestone(
    1,
    BadgeTier.bronze,
    'First Review',
    'Receive your first review',
  ),
  _ReviewMilestone(
    10,
    BadgeTier.silver,
    'Crowd Favorite',
    'Receive 10 reviews',
  ),
  _ReviewMilestone(25, BadgeTier.gold, 'Community Star', 'Receive 25 reviews'),
  _ReviewMilestone(
    50,
    BadgeTier.platinum,
    'Hall of Fame',
    'Receive 50 reviews',
  ),
];

/// Rating milestones
const List<_RatingMilestone> _ratingMilestones = [
  _RatingMilestone(
    4.5,
    10,
    BadgeTier.silver,
    'Highly Rated',
    'Maintain 4.5+ avg with 10+ reviews',
  ),
  _RatingMilestone(
    4.8,
    25,
    BadgeTier.gold,
    'Near Perfect',
    'Maintain 4.8+ avg with 25+ reviews',
  ),
  _RatingMilestone(
    5.0,
    10,
    BadgeTier.platinum,
    'Perfect Score',
    'Achieve a perfect 5.0 with 10+ reviews',
  ),
];

/// All achievement badge definitions (computed from milestones)
List<BadgeDef> get achievementBadges {
  final list = <BadgeDef>[];

  for (final m in _jobMilestones) {
    list.add(
      BadgeDef(
        id: 'jobs_${m.count}',
        label: m.label,
        icon: Icons.hardware,
        color: _tierColor(m.tier),
        glowColor: _tierGlow(m.tier),
        shape: _tierShape(m.tier),
        category: BadgeCategory.achievement,
        tier: m.tier,
        description: m.description,
        requirement: '${m.count} jobs completed',
      ),
    );
  }

  for (final m in _reviewMilestones) {
    list.add(
      BadgeDef(
        id: 'reviews_${m.count}',
        label: m.label,
        icon: Icons.engineering,
        color: _tierColor(m.tier),
        glowColor: _tierGlow(m.tier),
        shape: _tierShape(m.tier),
        category: BadgeCategory.achievement,
        tier: m.tier,
        description: m.description,
        requirement: '${m.count} reviews received',
      ),
    );
  }

  for (final m in _ratingMilestones) {
    list.add(
      BadgeDef(
        id: 'rating_${m.minRating.toStringAsFixed(1).replaceAll('.', '')}',
        label: m.label,
        icon: Icons.military_tech,
        color: _tierColor(m.tier),
        glowColor: _tierGlow(m.tier),
        shape: _tierShape(m.tier),
        category: BadgeCategory.achievement,
        tier: m.tier,
        description: m.description,
        requirement: '${m.minRating}+ avg rating, ${m.minReviews}+ reviews',
      ),
    );
  }

  return list;
}

/// Compute which achievement badges a contractor has earned
List<String> computeEarnedAchievements({
  required int totalJobsCompleted,
  required int reviewCount,
  required double avgRating,
}) {
  final earned = <String>[];

  for (final m in _jobMilestones) {
    if (totalJobsCompleted >= m.count) {
      earned.add('jobs_${m.count}');
    }
  }

  for (final m in _reviewMilestones) {
    if (reviewCount >= m.count) {
      earned.add('reviews_${m.count}');
    }
  }

  for (final m in _ratingMilestones) {
    if (avgRating >= m.minRating && reviewCount >= m.minReviews) {
      earned.add(
        'rating_${m.minRating.toStringAsFixed(1).replaceAll('.', '')}',
      );
    }
  }

  return earned;
}

/// Look up a badge by id from either profile or achievement lists
BadgeDef? badgeById(String id) {
  for (final b in profileBadges) {
    if (b.id == id) return b;
  }
  for (final b in achievementBadges) {
    if (b.id == id) return b;
  }
  return null;
}

/// Legacy migration: convert old badge strings to new ids
String migrateLegacyBadgeId(String oldBadge) {
  switch (oldBadge.toLowerCase().trim()) {
    case 'top rated':
      return 'top_rated';
    case 'family owned':
      return 'family_owned';
    case 'background checked':
      return 'background_checked';
    case 'licensed':
      return 'licensed';
    case 'insured':
      return 'insured';
    case 'eco friendly':
      return 'eco_friendly';
    case 'quick response':
      return 'quick_response';
    default:
      return oldBadge.toLowerCase().replaceAll(' ', '_');
  }
}

/// Resolve a list of badge ids (supporting legacy strings) into BadgeDefs
List<BadgeDef> resolveBadges(List<String> ids) {
  final results = <BadgeDef>[];
  for (final raw in ids) {
    final id = migrateLegacyBadgeId(raw);
    final def = badgeById(id);
    if (def != null) results.add(def);
  }
  return results;
}

// ─── Tier visual mapping ──────────────────────────────────────────────
Color _tierColor(BadgeTier tier) {
  switch (tier) {
    case BadgeTier.bronze:
      return const Color(0xFFCD7F32);
    case BadgeTier.silver:
      return const Color(0xFFA0AEC0);
    case BadgeTier.gold:
      return const Color(0xFFEAB308);
    case BadgeTier.platinum:
      return const Color(0xFF06B6D4);
    case BadgeTier.legendary:
      return const Color(0xFFA855F7);
  }
}

Color _tierGlow(BadgeTier tier) {
  switch (tier) {
    case BadgeTier.bronze:
      return const Color(0xFFD4A574);
    case BadgeTier.silver:
      return const Color(0xFFCBD5E1);
    case BadgeTier.gold:
      return const Color(0xFFFDE047);
    case BadgeTier.platinum:
      return const Color(0xFF67E8F9);
    case BadgeTier.legendary:
      return const Color(0xFFC084FC);
  }
}

BadgeShape _tierShape(BadgeTier tier) {
  switch (tier) {
    case BadgeTier.bronze:
      return BadgeShape.circle;
    case BadgeTier.silver:
      return BadgeShape.hex;
    case BadgeTier.gold:
      return BadgeShape.shield;
    case BadgeTier.platinum:
      return BadgeShape.diamond;
    case BadgeTier.legendary:
      return BadgeShape.star;
  }
}

String tierLabel(BadgeTier tier) {
  switch (tier) {
    case BadgeTier.bronze:
      return 'Bronze';
    case BadgeTier.silver:
      return 'Silver';
    case BadgeTier.gold:
      return 'Gold';
    case BadgeTier.platinum:
      return 'Platinum';
    case BadgeTier.legendary:
      return 'Legendary';
  }
}

// ─── Internal milestone structs ───────────────────────────────────────
class _JobMilestone {
  const _JobMilestone(this.count, this.tier, this.label, this.description);
  final int count;
  final BadgeTier tier;
  final String label;
  final String description;
}

class _ReviewMilestone {
  const _ReviewMilestone(this.count, this.tier, this.label, this.description);
  final int count;
  final BadgeTier tier;
  final String label;
  final String description;
}

class _RatingMilestone {
  const _RatingMilestone(
    this.minRating,
    this.minReviews,
    this.tier,
    this.label,
    this.description,
  );
  final double minRating;
  final int minReviews;
  final BadgeTier tier;
  final String label;
  final String description;
}
