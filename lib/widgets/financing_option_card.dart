import 'package:flutter/material.dart';
import '../theme/proserve_theme.dart';

/// "Pay in 3" / "Pay in 6" financing option card shown for jobs >$1k.
class FinancingOptionCard extends StatelessWidget {
  final double totalPrice;
  final VoidCallback? onSelectPlan;

  const FinancingOptionCard({
    super.key,
    required this.totalPrice,
    this.onSelectPlan,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPrice < 1000) return const SizedBox.shrink();

    final payIn3 = totalPrice / 3;
    final payIn6 = totalPrice / 6;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ProServeColors.accent3.withValues(alpha: 0.08),
            ProServeColors.accent2.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ProServeColors.accent3.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: ProServeColors.accent3.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.credit_score,
                  color: ProServeColors.accent3,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Payment Plans Available',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ProServeColors.accent3.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '0% INTEREST',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: ProServeColors.accent3,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PlanOption(
                  label: 'Pay in 3',
                  perMonth: payIn3,
                  months: 3,
                  selected: false,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PlanOption(
                  label: 'Pay in 6',
                  perMonth: payIn6,
                  months: 6,
                  selected: false,
                ),
              ),
            ],
          ),
          if (onSelectPlan != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onSelectPlan,
                style: OutlinedButton.styleFrom(
                  foregroundColor: ProServeColors.accent3,
                  side: BorderSide(
                    color: ProServeColors.accent3.withValues(alpha: 0.4),
                  ),
                ),
                child: const Text(
                  'Choose a payment plan',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanOption extends StatelessWidget {
  final String label;
  final double perMonth;
  final int months;
  final bool selected;

  const _PlanOption({
    required this.label,
    required this.perMonth,
    required this.months,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected
            ? ProServeColors.accent3.withValues(alpha: 0.15)
            : ProServeColors.card.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected
              ? ProServeColors.accent3.withValues(alpha: 0.4)
              : ProServeColors.line,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: ProServeColors.accent3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '\$${perMonth.toStringAsFixed(0)}/mo',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          Text(
            'for $months months',
            style: TextStyle(fontSize: 11, color: ProServeColors.muted),
          ),
        ],
      ),
    );
  }
}
