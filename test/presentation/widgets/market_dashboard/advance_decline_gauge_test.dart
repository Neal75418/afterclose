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

      // With unchanged=0, only 2 Flexible segments inside the segmented bar.
      // 限定在 ClipRRect（分段條容器）內計數，避免把判讀行（P2）的 Flexible 一併計入。
      final barSegments = find.descendant(
        of: find.byType(ClipRRect),
        matching: find.byType(Flexible),
      );
      expect(barSegments, findsNWidgets(2));
    });

    // 判讀層（P2）— 廣度判讀行
    testWidgets('renders breadth interpretation line for valid input', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(3000, 2400);
      addTearDown(() => tester.view.resetPhysicalSize());

      // advance/(adv+dec) = 700/1000 = 0.70 > 0.60 → broadUp
      const data = AdvanceDecline(advance: 700, unchanged: 0, decline: 300);
      await tester.pumpWidget(
        buildTestApp(const AdvanceDeclineGauge(data: data)),
      );

      expect(
        find.text('marketOverview.reading.breadth.broadUp'),
        findsOneWidget,
      );
    });

    testWidgets('no interpretation line when data is absent (total 0)', (
      tester,
    ) async {
      // total == 0 → 整個 widget 收斂為 SizedBox.shrink，不顯示判讀行
      await tester.pumpWidget(
        buildTestApp(const AdvanceDeclineGauge(data: AdvanceDecline())),
      );

      expect(
        find.textContaining('marketOverview.reading.breadth'),
        findsNothing,
      );
    });
  });
}
