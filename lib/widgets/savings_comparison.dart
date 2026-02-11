import 'package:flutter/material.dart';
import '../theme/proserve_theme.dart';

/// Visual comparison between AI price and typical contractor quotes.
///
/// Shows a bar chart-style comparison with animated savings callout.
class SavingsComparison extends StatelessWidget {
  final double aiPrice;
  final double estimatedMarketPrice;
  final double savingsAmount;
  final double savingsPercent;
  final double? discountPercent;
  final double? originalAiPrice;

  const SavingsComparison({
    super.key,
    required this.aiPrice,
    required this.estimatedMarketPrice,
    required this.savingsAmount,
    required this.savingsPercent,
    this.discountPercent,
    this.originalAiPrice,
  });

  @override
  Widget build(BuildContext context) {
    final maxPrice = estimatedMarketPrice * 1.05;
    final contractorWidth = (estimatedMarketPrice / maxPrice).clamp(0.0, 1.0);
    final aiWidth = (aiPrice / maxPrice).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ProServeColors.success.withValues(alpha: 0.08),
            ProServeColors.accent2.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ProServeColors.success.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: ProServeColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.trending_down,
                  color: ProServeColors.success,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'You\'re Saving Big',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              // Savings badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: ProServeColors.success.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'SAVE ${savingsPercent.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: ProServeColors.success,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Contractor price bar
          _PriceBar(
            label: 'Avg. Contractor Quote',
            price: estimatedMarketPrice,
            widthFraction: contractorWidth,
            color: Colors.white38,
            textColor: Colors.white54,
          ),
          const SizedBox(height: 8),

          // AI price bar
          _PriceBar(
            label: 'ProServe AI Price',
            price: aiPrice,
            widthFraction: aiWidth,
            color: ProServeColors.success,
            textColor: Colors.white,
            showStrikethrough:
                originalAiPrice != null && discountPercent != null,
            originalPrice: originalAiPrice,
          ),
          const SizedBox(height: 12),

          // Savings callout
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: ProServeColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle,
                  color: ProServeColors.success,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'You save \$${savingsAmount.toStringAsFixed(0)} compared to hiring directly',
                  style: TextStyle(
                    color: ProServeColors.success,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // Instant discount callout
          if (discountPercent != null && discountPercent! > 0) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: ProServeColors.accent2.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bolt, color: ProServeColors.accent2, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '${discountPercent!.toStringAsFixed(0)}% Instant Booking Discount Applied!',
                    style: TextStyle(
                      color: ProServeColors.accent2,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PriceBar extends StatelessWidget {
  final String label;
  final double price;
  final double widthFraction;
  final Color color;
  final Color textColor;
  final bool showStrikethrough;
  final double? originalPrice;

  const _PriceBar({
    required this.label,
    required this.price,
    required this.widthFraction,
    required this.color,
    required this.textColor,
    this.showStrikethrough = false,
    this.originalPrice,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Row(
              children: [
                if (showStrikethrough && originalPrice != null) ...[
                  Text(
                    '\$${originalPrice!.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: Colors.white38,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  '\$${price.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Stack(
          children: [
            Container(
              height: 8,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            FractionallySizedBox(
              widthFactor: widthFraction,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
