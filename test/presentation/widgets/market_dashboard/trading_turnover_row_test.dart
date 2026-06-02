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

    testWidgets('formats small turnover (< 1000 億) with 2 decimals', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(3000, 2400);
      addTearDown(() => tester.view.resetPhysicalSize());

      // 500 億元 = 5e10 → 500.00
      const data = TradingTurnover(totalTurnover: 5e10);
      await tester.pumpWidget(
        buildTestApp(const TradingTurnoverRow(data: data)),
      );

      expect(find.textContaining('500.00'), findsOneWidget);
    });

    testWidgets('formats large turnover (>= 10000 億) with 2 decimals', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(3000, 2400);
      addTearDown(() => tester.view.resetPhysicalSize());

      // 12000 億元 = 1.2e12 → 12,000.00
      const data = TradingTurnover(totalTurnover: 1.2e12);
      await tester.pumpWidget(
        buildTestApp(const TradingTurnoverRow(data: data)),
      );

      expect(find.textContaining('12,000.00'), findsOneWidget);
    });

    // Regression — 2026-06 screenshot 顯示左卡片 5日均 badge 右側溢出 1.1px。
    // 觸發條件：半寬 dashboard 卡片 + 萬億級成交額 + 5 位數百分比。
    // FittedBox(scaleDown) 修正在此寬度下不應再 throw RenderFlex overflow。
    testWidgets(
      'narrow card with huge turnover + 5-digit percent does not overflow',
      (tester) async {
        const data = TradingTurnover(totalTurnover: 1.6494e12); // ~16,494 億
        // changePercent = (today - avg5d) / avg5d * 100 → ~28631%
        // 模擬 screenshot 的「+287..%」5 位數情境。
        const comparison = TurnoverComparison(
          todayTurnover: 1.6494e12,
          avg5dTurnover: 5.74e9,
        );

        await tester.pumpWidget(
          buildTestApp(
            const Center(
              child: SizedBox(
                width: 360, // 半寬 dashboard 卡片實測寬度 (~320-400)
                child: TradingTurnoverRow(
                  data: data,
                  turnoverComparison: comparison,
                ),
              ),
            ),
          ),
        );

        // 等動畫穩定，allow FittedBox 完成 scaleDown 量測
        await tester.pumpAndSettle();

        // 沒 RenderFlex overflow assertion 才算通過
        expect(tester.takeException(), isNull);
      },
    );
  });
}
