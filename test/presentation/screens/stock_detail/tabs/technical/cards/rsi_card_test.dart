import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/domain/services/technical_indicator_service.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical/cards/rsi_card.dart';

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

  // Generate price data with enough points for RSI(14)
  List<double> generatePrices({double base = 100, int count = 30}) {
    return List.generate(count, (i) => base + (i % 5) * 2 - 4);
  }

  group('RSICard', () {
    testWidgets('displays RSI(14) label', (tester) async {
      widenViewport(tester);
      final prices = generatePrices();
      final rsi = indicatorService.calculateRSI(prices);
      await tester.pumpWidget(buildTestApp(RSICard(rsi: rsi, prices: prices)));

      expect(find.text('RSI(14)'), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      final prices = generatePrices();
      final rsi = indicatorService.calculateRSI(prices);
      await tester.pumpWidget(
        buildTestApp(
          RSICard(rsi: rsi, prices: prices),
          brightness: Brightness.dark,
        ),
      );

      expect(find.text('RSI(14)'), findsOneWidget);
    });
  });
}
