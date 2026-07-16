import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/theme/app_theme.dart';
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
        IndustryPerformanceRow(
          industries: makeIndustries(12),
          indexChangePercent: null,
        ),
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

  testWidgets('桌面榜單門檻：未達 kIndustryBoardMinStockCount(5) 的產業排除在外，即使排名極端', (
    tester,
  ) async {
    widenViewport(tester);

    // MINI_TOP / MINI_BOTTOM 僅 2 檔（未達榜單門檻 5），數值卻極端 → 若無門檻會霸榜
    // Q01..Q11 各 6 檔（達門檻），已按 avgChangePct DESC 排序
    final industries = [
      const IndustrySummary(
        industry: 'MINI_TOP',
        stockCount: 2,
        avgChangePct: 999,
        advance: 2,
        decline: 0,
      ),
      ...List.generate(
        11,
        (i) => IndustrySummary(
          industry: 'Q${(i + 1).toString().padLeft(2, '0')}',
          stockCount: 6,
          avgChangePct: (11 - i).toDouble(),
          advance: 3,
          decline: 3,
        ),
      ),
      const IndustrySummary(
        industry: 'MINI_BOTTOM',
        stockCount: 2,
        avgChangePct: -999,
        advance: 0,
        decline: 2,
      ),
    ];

    await tester.pumpWidget(
      buildTestApp(
        IndustryPerformanceRow(
          industries: industries,
          indexChangePercent: null,
        ),
      ),
    );

    // 前 4 + 後 4（從達門檻的 11 檔 Q01..Q11 中選取）
    for (final s in ['Q01', 'Q02', 'Q03', 'Q04', 'Q08', 'Q09', 'Q10', 'Q11']) {
      expect(find.text(s), findsOneWidget, reason: '$s 應在達門檻榜單的前 4 或後 4');
    }
    // 中段達門檻但排名居中 → 不上榜
    for (final s in ['Q05', 'Q06', 'Q07']) {
      expect(find.text(s), findsNothing, reason: '中段 $s 不應顯示');
    }
    // 未達門檻（僅 2 檔）即使數值極端也應被排除
    expect(
      find.text('MINI_TOP'),
      findsNothing,
      reason: '2 檔迷你產業應被榜單門檻排除，即使數值最高',
    );
    expect(
      find.text('MINI_BOTTOM'),
      findsNothing,
      reason: '2 檔迷你產業應被榜單門檻排除，即使數值最低',
    );
  });

  testWidgets('卡片顯示家數徽章（延伸 ▲N▼M 區域）', (tester) async {
    widenViewport(tester);
    final industries = [
      const IndustrySummary(
        industry: 'C01',
        stockCount: 7,
        avgChangePct: 1.5,
        advance: 5,
        decline: 2,
      ),
    ];

    await tester.pumpWidget(
      buildTestApp(
        IndustryPerformanceRow(
          industries: industries,
          indexChangePercent: null,
        ),
      ),
    );

    // 未載入實際翻譯資源的測試環境下 .tr() 回傳原始 key；
    // 存在即代表家數徽章已接上卡片版面（數值代入以 i18n namedArgs 測試涵蓋範圍外）。
    expect(find.textContaining('industryStockCount'), findsOneWidget);
  });

  testWidgets('大盤錨點：indexChangePercent 有值時顯示對應符號與 2 位小數；null 時不顯示', (
    tester,
  ) async {
    widenViewport(tester);

    await tester.pumpWidget(
      buildTestApp(
        IndustryPerformanceRow(
          industries: makeIndustries(3),
          indexChangePercent: 2.1,
        ),
      ),
    );
    expect(find.text('+2.10%'), findsOneWidget);

    await tester.pumpWidget(
      buildTestApp(
        IndustryPerformanceRow(
          industries: makeIndustries(3),
          indexChangePercent: null,
        ),
      ),
    );
    expect(find.text('+2.10%'), findsNothing, reason: 'null 時不應顯示大盤錨點');
  });

  testWidgets('5 日動能：momentum5d 有值時顯示、null 時隱藏（逐卡片獨立）', (tester) async {
    widenViewport(tester);
    final industries = [
      const IndustrySummary(
        industry: 'M01',
        stockCount: 10,
        avgChangePct: 5,
        advance: 5,
        decline: 0,
        momentum5d: 3.2,
      ),
      const IndustrySummary(
        industry: 'M02',
        stockCount: 10,
        avgChangePct: -5,
        advance: 0,
        decline: 5,
      ),
    ];

    await tester.pumpWidget(
      buildTestApp(
        IndustryPerformanceRow(
          industries: industries,
          indexChangePercent: null,
        ),
      ),
    );

    // M01 有 momentum5d=3.2 → 顯示「+3.2%」；M02 momentum5d 為 null → 全域僅一處動能文字
    expect(find.textContaining('+3.2%'), findsOneWidget);
    expect(find.textContaining('industryMomentum5d'), findsOneWidget);
  });

  testWidgets('5 日動能微負值不顯示「-0.0%」負零（捨入後歸零去符號）', (tester) async {
    widenViewport(tester);
    final industries = [
      const IndustrySummary(
        industry: 'M01',
        stockCount: 10,
        avgChangePct: 1,
        advance: 5,
        decline: 0,
        momentum5d: -0.04, // toStringAsFixed(1) 會變 "-0.0"
      ),
    ];

    await tester.pumpWidget(
      buildTestApp(
        IndustryPerformanceRow(
          industries: industries,
          indexChangePercent: null,
        ),
      ),
    );

    expect(find.textContaining('-0.0%'), findsNothing);
    expect(find.textContaining('0.0%'), findsOneWidget);
    // 顏色也須用捨入後的值：顯示 0.0% 就該是中性色，不得帶漲跌方向色
    final text = tester.widget<Text>(find.textContaining('0.0%'));
    expect(text.style?.color, AppTheme.neutralColor, reason: '顯示為零的動能不應著漲跌色');
  });

  testWidgets('等權口徑：顯示等權 caption', (tester) async {
    widenViewport(tester);

    await tester.pumpWidget(
      buildTestApp(
        IndustryPerformanceRow(
          industries: makeIndustries(3),
          indexChangePercent: null,
        ),
      ),
    );

    expect(find.textContaining('industryEqualWeighted'), findsOneWidget);
  });
}
