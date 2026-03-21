import 'package:flutter/material.dart';
import '../theme/proserve_theme.dart';

/// Tiered verification badge: Verified → Trusted Pro → Elite Pro.
enum VerificationTier { none, verified, trustedPro, elitePro }

VerificationTier tierFromString(String? value) {
  switch (value) {
    case 'verified':
      return VerificationTier.verified;
    case 'trusted_pro':
      return VerificationTier.trustedPro;
    case 'elite_pro':
      return VerificationTier.elitePro;
    default:
      return VerificationTier.none;
  }
}

class VerificationTierBadge extends StatelessWidget {
  final VerificationTier tier;
  final bool showLabel;
  final double size;

  const VerificationTierBadge({
    super.key,
    required this.tier,
    this.showLabel = true,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    if (tier == VerificationTier.none) return const SizedBox.shrink();

    final config = _tierConfig(tier);

    if (!showLabel) {
      return Tooltip(
        message: config.label,
        child: Icon(config.icon, color: config.color, size: size),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            config.color.withValues(alpha: 0.15),
            config.color.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: config.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: 14, color: config.color),
          const SizedBox(width: 4),
          Text(
            config.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: config.color,
            ),
          ),
        ],
      ),
    );
  }

  static _TierConfig _tierConfig(VerificationTier tier) {
    switch (tier) {
      case VerificationTier.verified:
        return _TierConfig(
          label: 'Verified',
          icon: Icons.verified_outlined,
          color: ProServeColors.accent2,
        );
      case VerificationTier.trustedPro:
        return _TierConfig(
          label: 'Trusted Pro',
          icon: Icons.verified,
          color: ProServeColors.accent,
        );
      case VerificationTier.elitePro:
        return _TierConfig(
          label: 'Elite Pro',
          icon: Icons.workspace_premium,
          color: const Color(0xFFFFD700),
        );
      case VerificationTier.none:
        return _TierConfig(
          label: '',
          icon: Icons.circle,
          color: Colors.transparent,
        );
    }
  }
}

class _TierConfig {
  final String label;
  final IconData icon;
  final Color color;

  _TierConfig({
    required this.label,
    required this.icon,
    required this.color,
  });
}

/// Full detail card showing tier criteria & benefits.
class VerificationTierCard extends StatelessWidget {
  final VerificationTier currentTier;
  final int completedJobs;
  final double avgRating;
  final int yearsActive;

  const VerificationTierCard({
    super.key,
    required this.currentTier,
    required this.completedJobs,
    required this.avgRating,
    required this.yearsActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ProServeColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ProServeColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.military_tech,
                color: ProServeColors.accent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Verification Tiers',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _TierRow(
            tier: VerificationTier.verified,
            current: currentTier,
            requirement: '5+ jobs, 3.5+ rating',
            met: completedJobs >= 5 && avgRating >= 3.5,
          ),
          const SizedBox(height: 8),
          _TierRow(
            tier: VerificationTier.trustedPro,
            current: currentTier,
            requirement: '25+ jobs, 4.2+ rating, 1+ year',
            met: completedJobs >= 25 && avgRating >= 4.2 && yearsActive >= 1,
          ),
          const SizedBox(height: 8),
          _TierRow(
            tier: VerificationTier.elitePro,
            current: currentTier,
            requirement: '100+ jobs, 4.7+ rating, 2+ years',
            met: completedJobs >= 100 && avgRating >= 4.7 && yearsActive >= 2,
          ),
        ],
      ),
    );
  }
}

class _TierRow extends StatelessWidget {
  final VerificationTier tier;
  final VerificationTier current;
  final String requirement;
  final bool met;

  const _TierRow({
    required this.tier,
    required this.current,
    required this.requirement,
    required this.met,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrent = tier == current;
    final config = VerificationTierBadge._tierConfig(tier);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrent
            ? config.color.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isCurrent
            ? Border.all(color: config.color.withValues(alpha: 0.3))
            : Border.all(color: ProServeColors.line),
      ),
      child: Row(
        children: [
          Icon(
            config.icon,
            color: met ? config.color : ProServeColors.muted,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color:
                        met ? config.color : ProServeColors.muted,
                    fontSize: 13,
                  ),
                ),
                Text(
                  requirement,
                  style: TextStyle(
                    fontSize: 11,
                    color: ProServeColors.muted,
                  ),
                ),
              ],
            ),
          ),
          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: config.color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'CURRENT',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: config.color,
                  letterSpacing: 1,
                ),
              ),
            )
          else if (met)
            Icon(Icons.check_circle, color: ProServeColors.success, size: 20),
        ],
      ),
    );
  }
}
