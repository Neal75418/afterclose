import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/screens/portfolio/widgets/allocation_pie_chart.dart';

import '../../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(3000, 2400);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  group('AllocationPieChart', () {
    testWidgets('returns SizedBox.shrink when map is empty', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const AllocationPieChart(allocationMap: {})),
      );

      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('renders pie chart with data', (tester) async {
      widenViewport(tester);
      final map = {'2330': 50.0, '2317': 30.0, '0050': 20.0};

      await tester.pumpWidget(
        buildTestApp(AllocationPieChart(allocationMap: map)),
      );

      expect(find.byType(AllocationPieChart), findsOneWidget);
    });

    testWidgets('displays legend entries', (tester) async {
      widenViewport(tester);
      final map = {'2330': 50.0, '2317': 30.0, '0050': 20.0};

      await tester.pumpWidget(
        buildTestApp(AllocationPieChart(allocationMap: map)),
      );

      expect(find.textContaining('2330'), findsOneWidget);
      expect(find.textContaining('2317'), findsOneWidget);
      expect(find.textContaining('0050'), findsOneWidget);
    });

    testWidgets('limits legend to 6 entries', (tester) async {
      widenViewport(tester);
      final map = {
        'A': 20.0,
        'B': 18.0,
        'C': 16.0,
        'D': 14.0,
        'E': 12.0,
        'F': 10.0,
        'G': 5.0,
        'H': 5.0,
      };

      await tester.pumpWidget(
        buildTestApp(AllocationPieChart(allocationMap: map)),
      );

      // G and H should not appear in legend (only first 6)
      expect(find.textContaining('G'), findsNothing);
      expect(find.textContaining('H'), findsNothing);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      final map = {'2330': 60.0, '2317': 40.0};

      await tester.pumpWidget(
        buildTestApp(
          AllocationPieChart(allocationMap: map),
          brightness: Brightness.dark,
        ),
      );

      expect(find.byType(AllocationPieChart), findsOneWidget);
    });
  });
}
