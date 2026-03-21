import 'package:flutter_test/flutter_test.dart';
import 'package:proserve_hub/widgets/cost_breakdown_chart.dart';

/// Unit tests for CostBreakdownChart construction logic.
/// Widget rendering tests are skipped because fl_chart's PieChart
/// relies on native render internals that crash the test compiler.
void main() {
  group('CostBreakdownChart construction', () {
    test('can be instantiated with default percentages', () {
      const chart = CostBreakdownChart(totalPrice: 2000);
      expect(chart.totalPrice, 2000);
      expect(chart.laborPercent, isNull);
      expect(chart.materialsPercent, isNull);
      expect(chart.platformFeePercent, 5.0);
    });

    test('can be instantiated with custom percentages', () {
      const chart = CostBreakdownChart(
        totalPrice: 5000,
        laborPercent: 60,
        materialsPercent: 30,
        platformFeePercent: 5,
      );
      expect(chart.totalPrice, 5000);
      expect(chart.laborPercent, 60);
      expect(chart.materialsPercent, 30);
      expect(chart.platformFeePercent, 5);
    });

    test('handles zero total price', () {
      const chart = CostBreakdownChart(totalPrice: 0);
      expect(chart.totalPrice, 0);
    });

    test('handles overflow percentages (sum > 100)', () {
      // 70 + 35 + 5 = 110 > 100
      const chart = CostBreakdownChart(
        totalPrice: 1000,
        laborPercent: 70,
        materialsPercent: 35,
        platformFeePercent: 5,
      );
      // Widget should at least construct without error
      expect(chart.totalPrice, 1000);
    });
  });
}
