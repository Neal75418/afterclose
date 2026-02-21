import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/domain/services/technical_indicator_service.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical/cards/kd_card.dart';

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

  group('KDCard', () {
    testWidgets('displays KDJ(9,3,3) label', (tester) async {
      widenViewport(tester);
      final highs = List.generate(30, (i) => 110.0 + (i % 5));
      final lows = List.generate(30, (i) => 90.0 + (i % 5));
      final closes = List.generate(30, (i) => 100.0 + (i % 5));

      await tester.pumpWidget(
        buildTestApp(
          KDCard(
            highs: highs,
            lows: lows,
            closes: closes,
            indicatorService: indicatorService,
          ),
        ),
      );

      expect(find.text('KDJ(9,3,3)'), findsOneWidget);
    });

    testWidgets('displays K and D values', (tester) async {
      widenViewport(tester);
      final highs = List.generate(30, (i) => 110.0 + (i % 5));
      final lows = List.generate(30, (i) => 90.0 + (i % 5));
      final closes = List.generate(30, (i) => 100.0 + (i % 5));

      await tester.pumpWidget(
        buildTestApp(
          KDCard(
            highs: highs,
            lows: lows,
            closes: closes,
            indicatorService: indicatorService,
          ),
        ),
      );

      // Should display K: and D: prefix values
      expect(find.textContaining('K:'), findsOneWidget);
      expect(find.textContaining('D:'), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      final highs = List.generate(30, (i) => 110.0 + (i % 5));
      final lows = List.generate(30, (i) => 90.0 + (i % 5));
      final closes = List.generate(30, (i) => 100.0 + (i % 5));

      await tester.pumpWidget(
        buildTestApp(
          KDCard(
            highs: highs,
            lows: lows,
            closes: closes,
            indicatorService: indicatorService,
          ),
          brightness: Brightness.dark,
        ),
      );

      expect(find.text('KDJ(9,3,3)'), findsOneWidget);
    });
  });
}
