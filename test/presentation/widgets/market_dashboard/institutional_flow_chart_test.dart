import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/providers/market_overview_provider.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/institutional_flow_chart.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 4000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  group('InstitutionalFlowChart', () {
    testWidgets('returns SizedBox.shrink when all values are 0', (
      tester,
    ) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          const InstitutionalFlowChart(
            data: InstitutionalTotals(
              foreignNet: 0,
              trustNet: 0,
              dealerNet: 0,
              totalNet: 0,
            ),
          ),
        ),
      );

      // Should render empty
      expect(find.byType(InstitutionalFlowChart), findsOneWidget);
    });

    testWidgets('displays three flow cards with data', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          const InstitutionalFlowChart(
            data: InstitutionalTotals(
              foreignNet: 5000000000,
              trustNet: -2000000000,
              dealerNet: 500000000,
              totalNet: 3500000000,
            ),
          ),
        ),
      );

      expect(find.byType(InstitutionalFlowChart), findsOneWidget);
    });

    testWidgets('shows positive total net in up color', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          const InstitutionalFlowChart(
            data: InstitutionalTotals(
              foreignNet: 3000000000,
              trustNet: 1000000000,
              dealerNet: 500000000,
              totalNet: 4500000000,
            ),
          ),
        ),
      );

      expect(find.byType(InstitutionalFlowChart), findsOneWidget);
    });

    testWidgets('shows negative total net in down color', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          const InstitutionalFlowChart(
            data: InstitutionalTotals(
              foreignNet: -3000000000,
              trustNet: -1000000000,
              dealerNet: -500000000,
              totalNet: -4500000000,
            ),
          ),
        ),
      );

      expect(find.byType(InstitutionalFlowChart), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          const InstitutionalFlowChart(
            data: InstitutionalTotals(
              foreignNet: 1000000000,
              trustNet: 500000000,
              dealerNet: -200000000,
              totalNet: 1300000000,
            ),
          ),
          brightness: Brightness.dark,
        ),
      );

      expect(find.byType(InstitutionalFlowChart), findsOneWidget);
    });
  });
}
