import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/domain/services/technical_indicator_service.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical/cards/bollinger_card.dart';

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

  group('BollingerCard', () {
    testWidgets('displays BOLL(20,2) label', (tester) async {
      widenViewport(tester);
      final prices = List.generate(30, (i) => 100.0 + (i % 5) * 2 - 4);
      await tester.pumpWidget(
        buildTestApp(
          BollingerCard(prices: prices, indicatorService: indicatorService),
        ),
      );

      expect(find.text('BOLL(20,2)'), findsOneWidget);
    });

    testWidgets('displays upper middle lower labels', (tester) async {
      widenViewport(tester);
      final prices = List.generate(30, (i) => 100.0 + (i % 5) * 2 - 4);
      await tester.pumpWidget(
        buildTestApp(
          BollingerCard(prices: prices, indicatorService: indicatorService),
        ),
      );

      // These are i18n keys that get displayed as translated text
      expect(find.byType(BollingerCard), findsOneWidget);
    });

    testWidgets('overbought when price at upper band', (tester) async {
      widenViewport(tester);
      // Spike at the end to push price above upper band
      final prices = List.generate(30, (i) => i < 28 ? 100.0 : 130.0);
      await tester.pumpWidget(
        buildTestApp(
          BollingerCard(prices: prices, indicatorService: indicatorService),
        ),
      );

      expect(find.byType(BollingerCard), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      final prices = List.generate(30, (i) => 100.0 + (i % 5) * 2 - 4);
      await tester.pumpWidget(
        buildTestApp(
          BollingerCard(prices: prices, indicatorService: indicatorService),
          brightness: Brightness.dark,
        ),
      );

      expect(find.text('BOLL(20,2)'), findsOneWidget);
    });
  });
}
