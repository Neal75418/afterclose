import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/providers/market_overview_provider.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/trading_turnover_row.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  group('TradingTurnoverRow', () {
    testWidgets('returns empty when totalTurnover is 0', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const TradingTurnoverRow(data: TradingTurnover())),
      );

      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.byIcon(Icons.paid_rounded), findsNothing);
    });

    testWidgets('displays icon and formatted value', (tester) async {
      // Widen the test surface to avoid overflow from untranslated key strings
      tester.view.physicalSize = const Size(3000, 2400);
      addTearDown(() => tester.view.resetPhysicalSize());

      const data = TradingTurnover(totalTurnover: 642195569620);
      await tester.pumpWidget(
        buildTestApp(const TradingTurnoverRow(data: data)),
      );

      expect(find.byIcon(Icons.paid_rounded), findsOneWidget);
      expect(find.byType(TradingTurnoverRow), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      tester.view.physicalSize = const Size(3000, 2400);
      addTearDown(() => tester.view.resetPhysicalSize());

      const data = TradingTurnover(totalTurnover: 100000000000);
      await tester.pumpWidget(
        buildTestApp(
          const TradingTurnoverRow(data: data),
          brightness: Brightness.dark,
        ),
      );

      expect(find.byType(TradingTurnoverRow), findsOneWidget);
    });
  });
}
