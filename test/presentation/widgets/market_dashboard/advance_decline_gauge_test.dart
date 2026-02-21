import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/providers/market_overview_provider.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/advance_decline_gauge.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  group('AdvanceDeclineGauge', () {
    testWidgets('returns empty when total is 0', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const AdvanceDeclineGauge(data: AdvanceDecline())),
      );

      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.byType(Column), findsNothing);
    });

    testWidgets('displays advance, unchanged, decline values', (tester) async {
      const data = AdvanceDecline(advance: 500, unchanged: 100, decline: 400);
      await tester.pumpWidget(
        buildTestApp(const AdvanceDeclineGauge(data: data)),
      );

      // 數字值顯示
      expect(find.text('500'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('400'), findsOneWidget);
    });

    testWidgets('displays percentage labels', (tester) async {
      const data = AdvanceDecline(advance: 500, unchanged: 100, decline: 400);
      await tester.pumpWidget(
        buildTestApp(const AdvanceDeclineGauge(data: data)),
      );

      // 百分比: 500/1000=50%, 100/1000=10%, 400/1000=40%
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('10%'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
    });

    testWidgets('renders segmented bar with Flexible widgets', (tester) async {
      const data = AdvanceDecline(advance: 600, unchanged: 0, decline: 400);
      await tester.pumpWidget(
        buildTestApp(const AdvanceDeclineGauge(data: data)),
      );

      // With unchanged=0, only 2 Flexible segments
      final flexibles = find.byType(Flexible);
      expect(flexibles, findsNWidgets(2));
    });

    testWidgets('renders in dark mode', (tester) async {
      const data = AdvanceDecline(advance: 300, decline: 200, unchanged: 50);
      await tester.pumpWidget(
        buildTestApp(
          const AdvanceDeclineGauge(data: data),
          brightness: Brightness.dark,
        ),
      );

      expect(find.byType(AdvanceDeclineGauge), findsOneWidget);
    });
  });
}
