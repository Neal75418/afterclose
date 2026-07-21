import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/models/finmind/revenue.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/fundamentals/revenue_table.dart';

import '../../../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  FinMindRevenue createRevenue({
    int year = 2026,
    int month = 6,
    double revenue = 100000,
    double? mom = 5.0,
    double? yoy = 30.0,
  }) {
    return FinMindRevenue(
      stockId: '2330',
      date: '$year-${month.toString().padLeft(2, '0')}-01',
      revenue: revenue,
      revenueYear: year,
      revenueMonth: month,
      momGrowth: mom,
      yoyGrowth: yoy,
    );
  }

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 4000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  group('RevenueTable 近3月均年增摘要列', () {
    testWidgets('三個月皆有 YoY → 顯示摘要列與正確均值', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          RevenueTable(
            revenues: [
              createRevenue(month: 4, yoy: 30.0),
              createRevenue(month: 5, yoy: 40.0),
              createRevenue(month: 6, yoy: 53.0),
            ],
            showROCYear: false,
          ),
        ),
      );

      expect(find.text('stockDetail.revenueYoY3mAvg'), findsOneWidget);
      // (30+40+53)/3 = 41.0%，growth badge 格式為 +41.0%；
      // 均值刻意不等於任一單列 YoY，避免 finder 撞到表格列
      expect(find.text('+41.0%'), findsOneWidget);
    });

    testWidgets('不足三個月 → 不顯示摘要列（不硬湊）', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          RevenueTable(
            revenues: [
              createRevenue(month: 5, yoy: 40.0),
              createRevenue(month: 6, yoy: 50.0),
            ],
            showROCYear: false,
          ),
        ),
      );

      expect(find.text('stockDetail.revenueYoY3mAvg'), findsNothing);
    });

    testWidgets('最新三月中有 YoY 缺值 → 不顯示摘要列', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          RevenueTable(
            revenues: [
              createRevenue(month: 4, yoy: 30.0),
              createRevenue(month: 5, yoy: null),
              createRevenue(month: 6, yoy: 50.0),
            ],
            showROCYear: false,
          ),
        ),
      );

      expect(find.text('stockDetail.revenueYoY3mAvg'), findsNothing);
    });
  });
}
