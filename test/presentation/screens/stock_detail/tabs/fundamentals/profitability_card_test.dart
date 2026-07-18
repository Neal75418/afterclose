import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/theme/app_theme.dart';
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

    testWidgets('平盤指標（0%）顯示中性色', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ProfitabilityCard(metrics: {'ROE': 0})),
      );

      final t = tester.widget<Text>(find.text('0.0%'));
      expect(t.style?.color, AppTheme.getFlatColor(Brightness.light));
    });

    testWidgets('微負指標（-0.004）捨入歸零：中性色、無 -0.0%', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ProfitabilityCard(metrics: {'ROE': -0.004})),
      );

      expect(find.text('-0.0%'), findsNothing);
      final t = tester.widget<Text>(find.text('0.0%'));
      expect(t.style?.color, AppTheme.getFlatColor(Brightness.light));
    });
  });
}
