import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/domain/models/market_overview_models.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/industry_performance_row.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 4000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  // 已按 avgChangePct DESC 排序：S01 最高 … Sn 最低
  List<IndustrySummary> makeIndustries(int n) => List.generate(
    n,
    (i) => IndustrySummary(
      industry: 'S${(i + 1).toString().padLeft(2, '0')}',
      stockCount: 10,
      avgChangePct: (n - i).toDouble(),
      advance: 5,
      decline: 5,
    ),
  );

  testWidgets('桌面：>8 產業顯示前 4 + 後 4 = 8（對齊「前後各4名」標籤）', (tester) async {
    widenViewport(tester);
    await tester.pumpWidget(
      buildTestApp(
        IndustryPerformanceRow(industries: makeIndustries(12)),
        brightness: Brightness.light,
      ),
    );

    // 前 4 + 後 4 = 8 應顯示
    for (final s in ['S01', 'S02', 'S03', 'S04', 'S09', 'S10', 'S11', 'S12']) {
      expect(find.text(s), findsOneWidget, reason: '$s 應在前 4 或後 4');
    }
    // 中段 4 個不顯示（總共恰好 8 個、非 9）
    for (final s in ['S05', 'S06', 'S07', 'S08']) {
      expect(find.text(s), findsNothing, reason: '中段 $s 不應顯示');
    }
  });
}
