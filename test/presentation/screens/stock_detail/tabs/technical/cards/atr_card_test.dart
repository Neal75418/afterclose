import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/domain/services/technical_indicator_service.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical/cards/atr_card.dart';

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

  group('ATRCard', () {
    testWidgets('displays ATR(14) label', (tester) async {
      widenViewport(tester);
      final highs = List.generate(20, (i) => 105.0 + (i % 3));
      final lows = List.generate(20, (i) => 95.0 + (i % 3));
      final closes = List.generate(20, (i) => 100.0 + (i % 3));

      await tester.pumpWidget(
        buildTestApp(
          ATRCard(
            highs: highs,
            lows: lows,
            closes: closes,
            indicatorService: indicatorService,
          ),
        ),
      );

      expect(find.text('ATR(14)'), findsOneWidget);
    });

    testWidgets('returns SizedBox.shrink when ATR is null', (tester) async {
      widenViewport(tester);
      // Too few data points for ATR to compute
      await tester.pumpWidget(
        buildTestApp(
          ATRCard(
            highs: const [105],
            lows: const [95],
            closes: const [100],
            indicatorService: indicatorService,
          ),
        ),
      );

      expect(find.byType(ATRCard), findsOneWidget);
      // Should render SizedBox.shrink
      expect(find.text('ATR(14)'), findsNothing);
    });

    testWidgets('shows volatility percentage', (tester) async {
      widenViewport(tester);
      final highs = List.generate(20, (i) => 105.0 + (i % 3));
      final lows = List.generate(20, (i) => 95.0 + (i % 3));
      final closes = List.generate(20, (i) => 100.0 + (i % 3));

      await tester.pumpWidget(
        buildTestApp(
          ATRCard(
            highs: highs,
            lows: lows,
            closes: closes,
            indicatorService: indicatorService,
          ),
        ),
      );

      // Should show percentage value
      expect(find.textContaining('%'), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      final highs = List.generate(20, (i) => 105.0 + (i % 3));
      final lows = List.generate(20, (i) => 95.0 + (i % 3));
      final closes = List.generate(20, (i) => 100.0 + (i % 3));

      await tester.pumpWidget(
        buildTestApp(
          ATRCard(
            highs: highs,
            lows: lows,
            closes: closes,
            indicatorService: indicatorService,
          ),
          brightness: Brightness.dark,
        ),
      );

      expect(find.byType(ATRCard), findsOneWidget);
    });
  });
}
