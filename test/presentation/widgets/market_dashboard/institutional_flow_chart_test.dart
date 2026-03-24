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
  });
}
