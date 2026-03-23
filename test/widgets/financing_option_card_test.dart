import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proserve_hub/widgets/financing_option_card.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('FinancingOptionCard', () {
    testWidgets('hidden when price is below threshold', (tester) async {
      await tester.pumpWidget(wrap(const FinancingOptionCard(totalPrice: 500)));
      // Should render nothing for <$1000
      expect(find.byType(FinancingOptionCard), findsOneWidget);
      expect(find.text('Pay in 3'), findsNothing);
    });

    testWidgets('shows payment plans when price >= 1000', (tester) async {
      await tester.pumpWidget(
        wrap(const FinancingOptionCard(totalPrice: 3000)),
      );
      expect(find.text('Pay in 3'), findsOneWidget);
      expect(find.text('Pay in 6'), findsOneWidget);
      // 3000/3 = 1000, 3000/6 = 500
      expect(find.textContaining('1000'), findsOneWidget);
      expect(find.textContaining('500'), findsOneWidget);
    });

    testWidgets('shows zero interest badge', (tester) async {
      await tester.pumpWidget(
        wrap(const FinancingOptionCard(totalPrice: 2000)),
      );
      expect(find.textContaining('0%'), findsOneWidget);
    });
  });
}
