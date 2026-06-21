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

  const totals = InstitutionalTotals(
    foreignNet: 43400000000, // +434 億
    trustNet: 5000000000, // +50 億
    dealerNet: 2000000000, // +20 億
    totalNet: 50400000000,
  );

  group('InstitutionalFlowChart dealer hedge annotation', () {
    testWidgets('dealer row shows hedge tooltip; foreign/trust do not', (
      tester,
    ) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(const InstitutionalFlowChart(data: totals)),
      );

      // 自營含避險提示：恰好一個 Tooltip（僅自營列）
      final hedgeTooltip = find.byWidgetPredicate(
        (w) => w is Tooltip && w.message == 'marketOverview.dealerHedgeNote',
      );
      expect(hedgeTooltip, findsOneWidget);

      // ⓘ icon 只出現在自營列（外資/投信列無此標註）
      expect(find.byIcon(Icons.info_outline), findsOneWidget);

      // 三法人名稱都在（確認標註未影響其他列渲染）
      expect(find.text('marketOverview.foreign'), findsOneWidget);
      expect(find.text('marketOverview.trust'), findsOneWidget);
      expect(find.text('marketOverview.dealer'), findsOneWidget);
    });
  });
}
