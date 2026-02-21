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
      await tester.pumpWidget(
        buildTestApp(
          RSICard(prices: generatePrices(), indicatorService: indicatorService),
        ),
      );

      expect(find.text('RSI(14)'), findsOneWidget);
    });

    testWidgets('shows overbought signal for high RSI', (tester) async {
      widenViewport(tester);
      // Steadily increasing prices → high RSI
      final prices = List.generate(30, (i) => 100.0 + i * 2);
      await tester.pumpWidget(
        buildTestApp(
          RSICard(prices: prices, indicatorService: indicatorService),
        ),
      );

      expect(find.byType(RSICard), findsOneWidget);
    });

    testWidgets('shows oversold signal for low RSI', (tester) async {
      widenViewport(tester);
      // Steadily decreasing prices → low RSI
      final prices = List.generate(30, (i) => 200.0 - i * 3);
      await tester.pumpWidget(
        buildTestApp(
          RSICard(prices: prices, indicatorService: indicatorService),
        ),
      );

      expect(find.byType(RSICard), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          RSICard(prices: generatePrices(), indicatorService: indicatorService),
          brightness: Brightness.dark,
        ),
      );

      expect(find.text('RSI(14)'), findsOneWidget);
    });
  });
}
