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
  });
}
