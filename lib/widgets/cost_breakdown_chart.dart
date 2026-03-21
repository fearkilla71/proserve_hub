import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/proserve_theme.dart';

/// Donut chart showing cost breakdown: Labor, Materials, Platform Fee, Escrow.
class CostBreakdownChart extends StatelessWidget {
  final double totalPrice;
  final double? laborPercent;
  final double? materialsPercent;
  final double platformFeePercent;

  const CostBreakdownChart({
    super.key,
    required this.totalPrice,
    this.laborPercent,
    this.materialsPercent,
    this.platformFeePercent = 5.0,
  });

  @override
  Widget build(BuildContext context) {
    // Default split: 55% labor, 35% materials, 5% platform, 5% escrow protection
    final labor = (laborPercent ?? 55).clamp(0, 100).toDouble();
    final materials = (materialsPercent ?? 35).clamp(0, 100).toDouble();
    final platform = platformFeePercent.clamp(0.0, 100.0);
    final escrow = (100.0 - labor - materials - platform).clamp(0.0, 100.0);

    final laborAmt = totalPrice * labor / 100;
    final materialsAmt = totalPrice * materials / 100;
    final platformAmt = totalPrice * platform / 100;
    final escrowAmt = totalPrice * escrow / 100;

    final sections = [
      _Section('Labor', labor, laborAmt, ProServeColors.accent2),
      _Section('Materials', materials, materialsAmt, ProServeColors.accent3),
      _Section('Platform Fee', platform, platformAmt, ProServeColors.accent),
      _Section('Escrow Protection', escrow, escrowAmt, ProServeColors.warning),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ProServeColors.card.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ProServeColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.donut_large, size: 18, color: ProServeColors.accent2),
              const SizedBox(width: 8),
              Text(
                'Cost Breakdown',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: Row(
              children: [
                // Donut chart
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 36,
                      sections: sections.map((s) {
                        return PieChartSectionData(
                          value: s.percent,
                          color: s.color,
                          radius: 28,
                          showTitle: false,
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Legend
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: sections.map((s) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: s.color,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                s.label,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                              ),
                            ),
                            Text(
                              '\$${s.amount.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: s.color,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
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

class _Section {
  final String label;
  final double percent;
  final double amount;
  final Color color;

  _Section(this.label, this.percent, this.amount, this.color);
}
