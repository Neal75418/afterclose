import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/screens/stock_detail/widgets/mini_trend_chart.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/breadth_trend_row.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(3000, 2400);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  group('BreadthTrendRow', () {
    testWidgets('renders nothing when both data absent', (tester) async {
      await tester.pumpWidget(buildTestApp(const BreadthTrendRow()));

      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.byType(Column), findsNothing);
      expect(find.text('marketOverview.breadthTrend.title'), findsNothing);
    });

    testWidgets('displays new high / new low counts', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          const BreadthTrendRow(
            newHighLow: (newHighs: 156, newLows: 29),
            indexChangePercent: 0.8,
          ),
        ),
      );

      expect(find.text('marketOverview.breadthTrend.title'), findsOneWidget);
      expect(find.text('156'), findsOneWidget);
      expect(find.text('29'), findsOneWidget);
      expect(find.text('marketOverview.breadthTrend.newHigh'), findsOneWidget);
      expect(find.text('marketOverview.breadthTrend.newLow'), findsOneWidget);
    });

    testWidgets('renders AD line sparkline when >= 2 points', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          const BreadthTrendRow(
            adLine: [-20, 10, 60],
            newHighLow: (newHighs: 100, newLows: 20),
            indexChangePercent: 1.0,
          ),
        ),
      );

      expect(find.byType(MiniTrendChart), findsOneWidget);
      expect(find.text('marketOverview.breadthTrend.adLine'), findsOneWidget);
    });

    testWidgets('no sparkline when AD line has < 2 points', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          const BreadthTrendRow(
            adLine: [42],
            newHighLow: (newHighs: 100, newLows: 20),
            indexChangePercent: 1.0,
          ),
        ),
      );

      expect(find.byType(MiniTrendChart), findsNothing);
    });

    testWidgets('renders breadth-trend interpretation line', (tester) async {
      widenViewport(tester);
      // 指數漲 & 新高 > 新低 → confirmUp
      await tester.pumpWidget(
        buildTestApp(
          const BreadthTrendRow(
            newHighLow: (newHighs: 156, newLows: 29),
            indexChangePercent: 0.8,
          ),
        ),
      );

      expect(
        find.text('marketOverview.reading.breadthTrend.confirmUp'),
        findsOneWidget,
      );
    });

    testWidgets('no interpretation line when indexChangePercent absent', (
      tester,
    ) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          const BreadthTrendRow(newHighLow: (newHighs: 156, newLows: 29)),
        ),
      );

      // 仍顯示新高新低，但無判讀行（缺指數漲跌幅）
      expect(find.text('156'), findsOneWidget);
      expect(
        find.textContaining('marketOverview.reading.breadthTrend'),
        findsNothing,
      );
    });

    testWidgets('renders AD-line-only when new high/low absent', (
      tester,
    ) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          const BreadthTrendRow(adLine: [-20, 10, 60], indexChangePercent: 1.0),
        ),
      );

      // 有 sparkline，但無新高新低 chip、無判讀行（缺新高新低家數）
      expect(find.byType(MiniTrendChart), findsOneWidget);
      expect(find.text('marketOverview.breadthTrend.newHigh'), findsNothing);
      expect(
        find.textContaining('marketOverview.reading.breadthTrend'),
        findsNothing,
      );
    });
  });
}
