import 'package:flutter/material.dart';
import '../theme/proserve_theme.dart';

/// "AI Price Match" guarantee badge.
///
/// Shown on Instant Quote results and AI Price Offer screens.
/// Credits the customer if final cost exceeds estimate by >15%.
class PriceGuaranteeBadge extends StatelessWidget {
  final double estimatedPrice;
  final bool compact;

  const PriceGuaranteeBadge({
    super.key,
    required this.estimatedPrice,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompact(context);
    return _buildFull(context);
  }

  Widget _buildCompact(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ProServeColors.accent.withValues(alpha: 0.15),
            ProServeColors.accent2.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ProServeColors.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_outlined, size: 14, color: ProServeColors.accent),
          const SizedBox(width: 4),
          Text(
            'AI Price Match',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: ProServeColors.accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFull(BuildContext context) {
    final threshold = estimatedPrice * 0.15;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ProServeColors.accent.withValues(alpha: 0.08),
            ProServeColors.accent2.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ProServeColors.accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ProServeColors.accent.withValues(alpha: 0.2),
                  ProServeColors.accent2.withValues(alpha: 0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.verified, color: ProServeColors.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Price Match Guarantee',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  'If the final cost exceeds this estimate by more than '
                  '15% (\$${threshold.toStringAsFixed(0)}+), '
                  'we\'ll credit you the difference.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
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
