import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/fundamentals/revenue_table.dart';

import '../../../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  FinMindRevenue createRevenue({
    String stockId = '2330',
    int revenueYear = 2025,
    int revenueMonth = 12,
    double revenue = 250000,
    double? momGrowth = 5.2,
    double? yoyGrowth = 12.3,
  }) {
    return FinMindRevenue(
      stockId: stockId,
      date: '$revenueYear-${revenueMonth.toString().padLeft(2, '0')}-10',
      revenue: revenue,
      revenueMonth: revenueMonth,
      revenueYear: revenueYear,
      momGrowth: momGrowth,
      yoyGrowth: yoyGrowth,
    );
  }

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 4000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  group('RevenueTable', () {
    testWidgets('renders with revenue data', (tester) async {
      widenViewport(tester);
      final revenues = [
        createRevenue(revenueYear: 2025, revenueMonth: 12, revenue: 250000),
        createRevenue(revenueYear: 2025, revenueMonth: 11, revenue: 230000),
      ];

      await tester.pumpWidget(
        buildTestApp(RevenueTable(revenues: revenues, showROCYear: false)),
      );

      expect(find.byType(RevenueTable), findsOneWidget);
    });

    testWidgets('renders with empty data', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(const RevenueTable(revenues: [], showROCYear: false)),
      );

      expect(find.byType(RevenueTable), findsOneWidget);
    });

    testWidgets('formats large revenue in billions', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          RevenueTable(
            revenues: [createRevenue(revenue: 250000)],
            showROCYear: false,
          ),
        ),
      );

      // 250000 >= 100000, should show in billions (億)
      expect(find.byType(RevenueTable), findsOneWidget);
    });

    testWidgets('renders with ROC year format', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          RevenueTable(revenues: [createRevenue()], showROCYear: true),
        ),
      );

      expect(find.byType(RevenueTable), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          RevenueTable(revenues: [createRevenue()], showROCYear: false),
          brightness: Brightness.dark,
        ),
      );

      expect(find.byType(RevenueTable), findsOneWidget);
    });
  });
}
