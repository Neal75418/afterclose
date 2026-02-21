import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/screens/custom_screening/backtest/widgets/return_distribution_chart.dart';

import '../../../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(3000, 2400);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  Map<String, int> createDistribution({
    int lessThanNeg10 = 2,
    int neg10to5 = 5,
    int neg5to0 = 15,
    int zero5 = 30,
    int five10 = 10,
    int moreThan10 = 3,
  }) {
    return {
      '< -10%': lessThanNeg10,
      '-10~-5%': neg10to5,
      '-5~0%': neg5to0,
      '0~5%': zero5,
      '5~10%': five10,
      '> 10%': moreThan10,
    };
  }

  group('ReturnDistributionChart', () {
    testWidgets('renders with typical distribution', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          ReturnDistributionChart(distribution: createDistribution()),
        ),
      );

      expect(find.byType(ReturnDistributionChart), findsOneWidget);
    });

    testWidgets('renders with all-zero distribution', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          ReturnDistributionChart(
            distribution: createDistribution(
              lessThanNeg10: 0,
              neg10to5: 0,
              neg5to0: 0,
              zero5: 0,
              five10: 0,
              moreThan10: 0,
            ),
          ),
        ),
      );

      expect(find.byType(ReturnDistributionChart), findsOneWidget);
    });

    testWidgets('renders with concentrated distribution', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          ReturnDistributionChart(
            distribution: createDistribution(
              lessThanNeg10: 0,
              neg10to5: 0,
              neg5to0: 0,
              zero5: 100,
              five10: 0,
              moreThan10: 0,
            ),
          ),
        ),
      );

      expect(find.byType(ReturnDistributionChart), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          ReturnDistributionChart(distribution: createDistribution()),
          brightness: Brightness.dark,
        ),
      );

      expect(find.byType(ReturnDistributionChart), findsOneWidget);
    });
  });
}
