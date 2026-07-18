import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical/ohlcv_card.dart';

import '../../../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  DailyPriceEntry createPrice({
    String symbol = '2330',
    double? open = 575.0,
    double? high = 585.0,
    double? low = 572.0,
    double? close = 580.0,
    double? volume = 25000000,
  }) {
    return DailyPriceEntry(
      symbol: symbol,
      date: DateTime(2026, 2, 19),
      open: open,
      high: high,
      low: low,
      close: close,
      volume: volume,
    );
  }

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(4000, 3000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  group('OhlcvCard', () {
    testWidgets('displays candlestick_chart icon', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(OhlcvCard(latestPrice: createPrice(), priceChange: 2.5)),
      );

      expect(find.byIcon(Icons.candlestick_chart), findsOneWidget);
    });

    testWidgets('displays bar_chart icon for volume', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(OhlcvCard(latestPrice: createPrice(), priceChange: 2.5)),
      );

      expect(find.byIcon(Icons.bar_chart), findsOneWidget);
    });

    testWidgets('displays OHLC price values', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          OhlcvCard(
            latestPrice: createPrice(
              open: 575.0,
              high: 585.0,
              low: 572.0,
              close: 580.0,
            ),
            priceChange: 2.5,
          ),
        ),
      );

      expect(find.text('575.00'), findsOneWidget);
      expect(find.text('585.00'), findsOneWidget);
      expect(find.text('572.00'), findsOneWidget);
      expect(find.text('580.00'), findsOneWidget);
    });

    testWidgets('shows trending_up icon for positive change', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(OhlcvCard(latestPrice: createPrice(), priceChange: 2.5)),
      );

      expect(find.byIcon(Icons.trending_up), findsOneWidget);
    });

    testWidgets('shows trending_down icon for negative change', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(OhlcvCard(latestPrice: createPrice(), priceChange: -1.5)),
      );

      expect(find.byIcon(Icons.trending_down), findsOneWidget);
    });

    testWidgets('handles null latestPrice', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(const OhlcvCard(latestPrice: null, priceChange: null)),
      );

      // Should show dashes for null values
      expect(find.text('-'), findsWidgets);
    });

    testWidgets('handles null priceChange (no badge shown)', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(OhlcvCard(latestPrice: createPrice(), priceChange: null)),
      );

      expect(find.byIcon(Icons.trending_up), findsNothing);
      expect(find.byIcon(Icons.trending_down), findsNothing);
    });

    testWidgets('平盤（0%）顯示中性 badge：無 + 號、trending_flat、中性色', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(OhlcvCard(latestPrice: createPrice(), priceChange: 0)),
      );

      // 平盤不得帶 + 號
      expect(find.text('+0.00%'), findsNothing);
      expect(find.textContaining('0.00%'), findsWidgets);
      // 中性箭頭，不得為漲/跌箭頭
      expect(find.byIcon(Icons.trending_flat), findsOneWidget);
      expect(find.byIcon(Icons.trending_up), findsNothing);
      expect(find.byIcon(Icons.trending_down), findsNothing);
      // 收盤價配色為中性
      final closeText = tester.widget<Text>(find.text('580.00'));
      expect(closeText.style?.color, AppTheme.neutralColor);
    });

    testWidgets('微負值（-0.004）捨入後歸零，中性色且無漲箭頭', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          OhlcvCard(latestPrice: createPrice(), priceChange: -0.004),
        ),
      );

      expect(find.byIcon(Icons.trending_up), findsNothing);
      expect(find.byIcon(Icons.trending_flat), findsOneWidget);
      final closeText = tester.widget<Text>(find.text('580.00'));
      expect(closeText.style?.color, AppTheme.neutralColor);
    });
  });
}
