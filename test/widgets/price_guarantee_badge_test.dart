import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proserve_hub/widgets/price_guarantee_badge.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('PriceGuaranteeBadge', () {
    testWidgets('compact mode shows pill badge', (tester) async {
      await tester.pumpWidget(
        wrap(const PriceGuaranteeBadge(estimatedPrice: 1000, compact: true)),
      );
      expect(find.text('AI Price Match'), findsOneWidget);
    });

    testWidgets('full mode shows guarantee details', (tester) async {
      await tester.pumpWidget(
        wrap(const PriceGuaranteeBadge(estimatedPrice: 1000, compact: false)),
      );
      expect(find.textContaining('Guarantee'), findsOneWidget);
      // 15% of 1000 = $150
      expect(find.textContaining('\$150'), findsOneWidget);
    });

    testWidgets('handles zero estimated price', (tester) async {
      await tester.pumpWidget(
        wrap(const PriceGuaranteeBadge(estimatedPrice: 0, compact: false)),
      );
      // Should still render without errors
      expect(find.byType(PriceGuaranteeBadge), findsOneWidget);
    });
  });
}
