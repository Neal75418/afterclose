import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/screens/stock_detail/tabs/fundamentals/profitability_card.dart';

import '../../../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  group('ProfitabilityCard', () {
    testWidgets('returns SizedBox.shrink when metrics are empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(const ProfitabilityCard(metrics: {})),
      );

      expect(find.byType(Card), findsNothing);
    });

    testWidgets('returns SizedBox.shrink when Revenue is zero', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const ProfitabilityCard(metrics: {'Revenue': 0, 'GrossProfit': 50}),
        ),
      );

      expect(find.byType(Card), findsNothing);
    });

    testWidgets('displays gross margin when Revenue and GrossProfit exist', (
      tester,
    ) async {
      // GrossProfit 500 / Revenue 1000 = 50.0%
      await tester.pumpWidget(
        buildTestApp(
          const ProfitabilityCard(
            metrics: {'Revenue': 1000, 'GrossProfit': 500},
          ),
        ),
      );

      expect(find.byType(Card), findsOneWidget);
      expect(find.text('50.0%'), findsOneWidget);
    });

    testWidgets('displays ROE directly without Revenue', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ProfitabilityCard(metrics: {'ROE': 15.5})),
      );

      expect(find.byType(Card), findsOneWidget);
      expect(find.text('15.5%'), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const ProfitabilityCard(metrics: {'Revenue': 1000, 'NetIncome': 200}),
          brightness: Brightness.dark,
        ),
      );

      expect(find.byType(ProfitabilityCard), findsOneWidget);
    });
  });

  group('ProfitMetric', () {
    test('stores label and value', () {
      const metric = ProfitMetric('Margin', 25.3);
      expect(metric.label, 'Margin');
      expect(metric.value, 25.3);
    });
  });
}
