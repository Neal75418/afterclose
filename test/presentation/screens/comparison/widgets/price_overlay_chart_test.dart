import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/screens/comparison/widgets/price_overlay_chart.dart';

import '../../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 4000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  final defaultDate = DateTime(2026, 2, 13);

  List<DailyPriceEntry> createPriceHistory(
    String symbol, {
    int days = 30,
    double startPrice = 100,
  }) {
    return List.generate(
      days,
      (i) => DailyPriceEntry(
        symbol: symbol,
        date: defaultDate.subtract(Duration(days: days - i)),
        open: startPrice + i * 0.5,
        high: startPrice + i * 0.5 + 2,
        low: startPrice + i * 0.5 - 2,
        close: startPrice + i * 0.5,
        volume: 50000,
      ),
    );
  }

  group('PriceOverlayChart', () {
    testWidgets('returns SizedBox.shrink when no price data', (tester) async {
      widenViewport(tester);

      await tester.pumpWidget(
        buildTestApp(
          const PriceOverlayChart(
            symbols: ['2330'],
            priceHistoriesMap: {},
            stocksMap: {},
          ),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('renders chart with price histories', (tester) async {
      widenViewport(tester);

      final histories = {
        '2330': createPriceHistory('2330', startPrice: 580),
        '2317': createPriceHistory('2317', startPrice: 95),
      };

      final stocks = {
        '2330': StockMasterEntry(
          symbol: '2330',
          name: '台積電',
          market: 'TWSE',
          isActive: true,
          updatedAt: defaultDate,
        ),
        '2317': StockMasterEntry(
          symbol: '2317',
          name: '鴻海',
          market: 'TWSE',
          isActive: true,
          updatedAt: defaultDate,
        ),
      };

      await tester.pumpWidget(
        buildTestApp(
          PriceOverlayChart(
            symbols: const ['2330', '2317'],
            priceHistoriesMap: histories,
            stocksMap: stocks,
          ),
        ),
      );

      // Chart title
      expect(find.textContaining('comparison.chartTitle'), findsOneWidget);
      // Legend should show stock names
      expect(find.textContaining('台積電'), findsOneWidget);
      expect(find.textContaining('鴻海'), findsOneWidget);
    });

    testWidgets('shows percentage labels on Y axis', (tester) async {
      widenViewport(tester);

      final histories = {'2330': createPriceHistory('2330')};

      await tester.pumpWidget(
        buildTestApp(
          PriceOverlayChart(
            symbols: const ['2330'],
            priceHistoriesMap: histories,
            stocksMap: const {},
          ),
        ),
      );

      // Should show percentage format on axis
      expect(find.textContaining('%'), findsAtLeastNWidgets(1));
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);

      final histories = {'2330': createPriceHistory('2330')};

      await tester.pumpWidget(
        buildTestApp(
          PriceOverlayChart(
            symbols: const ['2330'],
            priceHistoriesMap: histories,
            stocksMap: const {},
          ),
          brightness: Brightness.dark,
        ),
      );

      expect(find.textContaining('comparison.chartTitle'), findsOneWidget);
    });
  });
}
