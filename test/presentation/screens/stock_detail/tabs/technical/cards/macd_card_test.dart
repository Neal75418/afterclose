import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/domain/services/technical_indicator_service.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical/cards/macd_card.dart';

import '../../../../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  final indicatorService = TechnicalIndicatorService();

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 4000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  group('MACDCard', () {
    testWidgets('displays MACD(12,26,9) label', (tester) async {
      widenViewport(tester);
      final prices = List.generate(40, (i) => 100.0 + (i % 7) * 2 - 6);
      await tester.pumpWidget(
        buildTestApp(
          MACDCard(prices: prices, indicatorService: indicatorService),
        ),
      );

      expect(find.text('MACD(12,26,9)'), findsOneWidget);
    });

    testWidgets('displays DIF DEA HIST labels', (tester) async {
      widenViewport(tester);
      final prices = List.generate(40, (i) => 100.0 + (i % 7) * 2 - 6);
      await tester.pumpWidget(
        buildTestApp(
          MACDCard(prices: prices, indicatorService: indicatorService),
        ),
      );

      expect(find.text('DIF'), findsOneWidget);
      expect(find.text('DEA'), findsOneWidget);
      expect(find.text('HIST'), findsOneWidget);
    });

    testWidgets('shows bullish with rising prices', (tester) async {
      widenViewport(tester);
      final prices = List.generate(40, (i) => 100.0 + i * 1.5);
      await tester.pumpWidget(
        buildTestApp(
          MACDCard(prices: prices, indicatorService: indicatorService),
        ),
      );

      expect(find.byType(MACDCard), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      final prices = List.generate(40, (i) => 100.0 + (i % 7) * 2 - 6);
      await tester.pumpWidget(
        buildTestApp(
          MACDCard(prices: prices, indicatorService: indicatorService),
          brightness: Brightness.dark,
        ),
      );

      expect(find.text('MACD(12,26,9)'), findsOneWidget);
    });
  });
}
