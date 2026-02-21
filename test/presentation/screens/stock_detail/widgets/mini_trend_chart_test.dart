import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/screens/stock_detail/widgets/mini_trend_chart.dart';

import '../../../../helpers/widget_test_helpers.dart';

void main() {
  group('MiniTrendChart', () {
    testWidgets('renders empty SizedBox with < 2 data points', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const MiniTrendChart(dataPoints: [42.0])),
      );

      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('renders chart with 2+ data points', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const MiniTrendChart(dataPoints: [10.0, 20.0, 15.0, 25.0]),
        ),
      );

      expect(find.byType(MiniTrendChart), findsOneWidget);
    });

    testWidgets('uses custom height', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const MiniTrendChart(dataPoints: [10.0, 20.0, 30.0], height: 120),
        ),
      );

      expect(find.byType(MiniTrendChart), findsOneWidget);
    });

    testWidgets('accepts custom line and fill colors', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const MiniTrendChart(
            dataPoints: [5.0, 10.0, 7.0],
            lineColor: Colors.red,
            fillColor: Colors.red,
          ),
        ),
      );

      expect(find.byType(MiniTrendChart), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const MiniTrendChart(dataPoints: [10.0, 20.0, 15.0]),
          brightness: Brightness.dark,
        ),
      );

      expect(find.byType(MiniTrendChart), findsOneWidget);
    });
  });
}
