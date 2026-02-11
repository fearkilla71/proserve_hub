import 'package:flutter/material.dart';
import '../services/escrow_stats_service.dart';
import '../theme/proserve_theme.dart';

/// Social proof banner showing real-time escrow stats.
///
/// Displays: total bookings, avg savings, satisfaction rating.
class SocialProofBanner extends StatefulWidget {
  const SocialProofBanner({super.key});

  @override
  State<SocialProofBanner> createState() => _SocialProofBannerState();
}

class _SocialProofBannerState extends State<SocialProofBanner> {
  final _service = EscrowStatsService();
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _service.getAggregateStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 80,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_stats == null) return const SizedBox.shrink();

    final totalBookings = _stats!['totalBookings'] as int;
    final avgSavings = (_stats!['avgSavings'] as double);
    final avgRating = (_stats!['avgRating'] as double);
    final ratingCount = (_stats!['ratingCount'] as int);

    // Don't show if no data yet
    if (totalBookings == 0) {
      // Show a "Be the first" encouragement instead
      return _BeFirstBanner();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              Icon(
                Icons.people_outline,
                color: ProServeColors.accent2,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'Join Homeowners Who Save',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Stats row
          Row(
            children: [
              _StatChip(
                icon: Icons.verified_user,
                value: '$totalBookings+',
                label: 'Jobs Booked',
                color: ProServeColors.success,
              ),
              const SizedBox(width: 12),
              _StatChip(
                icon: Icons.savings_outlined,
                value: '\$${avgSavings.toStringAsFixed(0)}',
                label: 'Avg. Saved',
                color: ProServeColors.accent2,
              ),
              if (ratingCount > 0) ...[
                const SizedBox(width: 12),
                _StatChip(
                  icon: Icons.star,
                  value: avgRating.toStringAsFixed(1),
                  label: 'Price Rating',
                  color: ProServeColors.warning,
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          // Trust badges
          Row(
            children: [
              _TrustBadge(
                icon: Icons.shield_outlined,
                label: 'Money-Back Guarantee',
              ),
              const SizedBox(width: 8),
              _TrustBadge(icon: Icons.lock_outline, label: 'Secure Escrow'),
            ],
          ),
        ],
      ),
    );
  }
}

class _BeFirstBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ProServeColors.accent2.withValues(alpha: 0.10),
            ProServeColors.success.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ProServeColors.accent2.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ProServeColors.accent2.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.rocket_launch,
              color: ProServeColors.accent2,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Early Adopter Pricing',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'You\'re among the first to use AI pricing — enjoy the best rates!',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            Text(
              label,
              style: TextStyle(color: Colors.white54, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TrustBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: ProServeColors.success, size: 14),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
