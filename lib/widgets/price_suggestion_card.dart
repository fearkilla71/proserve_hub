import 'package:flutter/material.dart';

class PriceSuggestionCard extends StatelessWidget {
  final Map<String, double> prices;
  final void Function(double) onSelect;

  const PriceSuggestionCard({
    super.key,
    required this.prices,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.outlineVariant,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Suggested Pricing',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                _priceTile(
                  context,
                  label: 'Budget',
                  price: prices['low']!,
                  tint: scheme.surfaceContainerHighest,
                  onTap: onSelect,
                ),
                _priceTile(
                  context,
                  label: 'Recommended',
                  price: prices['recommended']!,
                  tint: scheme.primaryContainer,
                  onTap: onSelect,
                ),
                _priceTile(
                  context,
                  label: 'Premium',
                  price: prices['premium']!,
                  tint: scheme.secondaryContainer,
                  onTap: onSelect,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _priceTile(
    BuildContext context, {
    required String label,
    required double price,
    required Color tint,
    required void Function(double) onTap,
  }) {
    return Card(
      child: ListTile(
        title: Text(label),
        subtitle: Text('\$${price.toStringAsFixed(0)}'),
        trailing: const Icon(Icons.arrow_forward),
        onTap: () => onTap(price),
        tileColor: tint,
      ),
    );
  }
}
