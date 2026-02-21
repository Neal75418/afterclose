import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:k_chart_plus/k_chart_plus.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/technical_indicator_service.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical/indicator_cards.dart';

import '../../../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  final indicatorService = TechnicalIndicatorService();

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 4000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  List<DailyPriceEntry> generatePriceHistory({int count = 30}) {
    return List.generate(
      count,
      (i) => DailyPriceEntry(
        symbol: '2330',
        date: DateTime(2026, 1, 1 + i),
        open: 100.0 + (i % 5),
        high: 105.0 + (i % 5),
        low: 95.0 + (i % 5),
        close: 100.0 + (i % 5) * 2 - 4,
        volume: 1000000.0 + i * 50000,
      ),
    );
  }

  group('IndicatorCardsSection', () {
    testWidgets('shows insufficient data card when < 14 prices', (
      tester,
    ) async {
      widenViewport(tester);
      final shortHistory = generatePriceHistory(count: 5);

      await tester.pumpWidget(
        buildTestApp(
          IndicatorCardsSection(
            priceHistory: shortHistory,
            secondaryIndicators: {SecondaryState.RSI},
            mainIndicators: {},
            indicatorService: indicatorService,
          ),
        ),
      );

      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('displays RSI card when RSI indicator selected', (
      tester,
    ) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          IndicatorCardsSection(
            priceHistory: generatePriceHistory(),
            secondaryIndicators: {SecondaryState.RSI},
            mainIndicators: {},
            indicatorService: indicatorService,
          ),
        ),
      );

      expect(find.text('RSI(14)'), findsOneWidget);
    });

    testWidgets('displays MACD card when MACD indicator selected', (
      tester,
    ) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          IndicatorCardsSection(
            priceHistory: generatePriceHistory(count: 40),
            secondaryIndicators: {SecondaryState.MACD},
            mainIndicators: {},
            indicatorService: indicatorService,
          ),
        ),
      );

      expect(find.text('MACD(12,26,9)'), findsOneWidget);
    });

    testWidgets('displays Bollinger card when BOLL main indicator selected', (
      tester,
    ) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          IndicatorCardsSection(
            priceHistory: generatePriceHistory(),
            secondaryIndicators: {},
            mainIndicators: {MainState.BOLL},
            indicatorService: indicatorService,
          ),
        ),
      );

      expect(find.text('BOLL(20,2)'), findsOneWidget);
    });

    testWidgets('displays OBV and ATR cards always', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          IndicatorCardsSection(
            priceHistory: generatePriceHistory(),
            secondaryIndicators: {},
            mainIndicators: {},
            indicatorService: indicatorService,
          ),
        ),
      );

      expect(find.text('OBV'), findsOneWidget);
      expect(find.text('ATR(14)'), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          IndicatorCardsSection(
            priceHistory: generatePriceHistory(),
            secondaryIndicators: {SecondaryState.RSI},
            mainIndicators: {},
            indicatorService: indicatorService,
          ),
          brightness: Brightness.dark,
        ),
      );

      expect(find.byType(IndicatorCardsSection), findsOneWidget);
    });
  });
}
