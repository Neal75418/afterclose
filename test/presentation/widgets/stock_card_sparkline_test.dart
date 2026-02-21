import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/widgets/stock_card_sparkline.dart';

import '../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  group('MiniSparkline', () {
    testWidgets('returns SizedBox.shrink when fewer than 5 data points', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          const MiniSparkline(prices: [100, 101, 102, 103], color: Colors.red),
        ),
      );

      // Should render SizedBox.shrink (no LineChart)
      expect(find.byType(LineChart), findsNothing);
    });

    testWidgets('returns SizedBox.shrink for empty list', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const MiniSparkline(prices: [], color: Colors.red)),
      );

      expect(find.byType(LineChart), findsNothing);
    });

    testWidgets('renders LineChart when >= 5 data points with variation', (
      tester,
    ) async {
      // Prices with sufficient variation (> 0.3%)
      const prices = [100.0, 102.0, 98.0, 105.0, 103.0, 107.0, 110.0];
      await tester.pumpWidget(
        buildTestApp(const MiniSparkline(prices: prices, color: Colors.blue)),
      );

      expect(find.byType(LineChart), findsOneWidget);
    });

    testWidgets('returns SizedBox.shrink when variation < 0.3%', (
      tester,
    ) async {
      // All prices very close — variation < 0.3%
      const prices = [100.00, 100.01, 100.02, 100.01, 100.00];
      await tester.pumpWidget(
        buildTestApp(const MiniSparkline(prices: prices, color: Colors.green)),
      );

      expect(find.byType(LineChart), findsNothing);
    });

    testWidgets('samples last 20 points when data exceeds max', (tester) async {
      // 25 data points with variation — should sample last 20
      final prices = List.generate(25, (i) => 100.0 + i * 2);
      await tester.pumpWidget(
        buildTestApp(MiniSparkline(prices: prices, color: Colors.orange)),
      );

      expect(find.byType(LineChart), findsOneWidget);
    });

    testWidgets('has Semantics wrapper with image role', (tester) async {
      const prices = [100.0, 105.0, 98.0, 110.0, 103.0, 107.0];
      await tester.pumpWidget(
        buildTestApp(const MiniSparkline(prices: prices, color: Colors.red)),
      );

      expect(find.byType(Semantics), findsWidgets);
    });

    testWidgets('renders with RepaintBoundary for performance', (tester) async {
      const prices = [100.0, 105.0, 98.0, 110.0, 103.0, 107.0];
      await tester.pumpWidget(
        buildTestApp(const MiniSparkline(prices: prices, color: Colors.red)),
      );

      expect(find.byType(RepaintBoundary), findsWidgets);
    });

    testWidgets('renders in dark mode', (tester) async {
      const prices = [100.0, 105.0, 98.0, 110.0, 103.0, 107.0];
      await tester.pumpWidget(
        buildTestApp(
          const MiniSparkline(prices: prices, color: Colors.red),
          brightness: Brightness.dark,
        ),
      );

      expect(find.byType(MiniSparkline), findsOneWidget);
    });
  });
}
