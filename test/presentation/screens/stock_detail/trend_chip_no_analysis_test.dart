// 沒被評分的股票，頁首照樣宣稱「盤整」
//
// stock_detail_header.dart:483
//   label: 'trend.${trendState?.trendKey ?? 'sideways'}'.tr(),
// `trendState` 為 null（＝這檔今天沒有 daily_analysis）時被 `?? 'sideways'`
// 收斂成 `trend.sideways` =「盤整」——一個明確的趨勢宣稱。
//
// 實機 2026-07-27（資料日 07-24）台積電 2330：畫面顯示「→ 盤整」，但
//   daily_analysis 最新一筆是 **2026-07-21**（且該筆是 DOWN、有支撐 2197.5
//   ／壓力 2345.0），07-22 起沒有任何分析列；
//   provider 走 `_db.getAnalysis(_symbol, analysisDate)` 精確日期查詢、
//   無 fallback（stock_detail_provider.dart:133），所以 analysis 為 null。
// 支撐壓力徽章因為是 `if (data.support case final x?)` 而正確地沒出現，
// 只有趨勢徽章硬渲染了預設值——同一個 Wrap 裡兩種做法。
//
// 規模：2026-07-24 有價格的 2,127 檔中只有 154 檔被評分（每日候選池是刻意
// 篩選的子集，這部分正常），其餘 **1,973 檔（93%）**打開都會看到「盤整」，
// 與它們的實際走勢無關。台積電當日 -2.29%、前一個分析日是 DOWN。
//
// 這與先前修掉的「零訊號股票顯示佐證中等」是同一個病：**預設值洩漏成
// 使用者可見的結論**。修法沿用同一個 Wrap 裡支撐壓力的既有做法——沒有
// 資料就不渲染，而不是發明第四種 trend 狀態。
//
// 注意 RANGE 是合法值：有分析且為 RANGE 時仍須顯示「盤整」，兩者不可混為一談。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/screens/stock_detail/widgets/stock_detail_header.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  Widget headerWith({String? trendState}) => StockDetailHeader(
    symbol: '2330',
    data: StockHeaderData(
      stockName: '台積電',
      stockMarket: 'TWSE',
      latestClose: 2350,
      priceChange: -2.29,
      trendState: trendState,
      dataDate: DateTime(2026, 7, 24),
    ),
  );

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(5000, 4000);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(buildTestApp(child, brightness: Brightness.dark));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('🚨 沒有當日分析時不得顯示趨勢徽章（預設值不是結論）', (tester) async {
    await pump(tester, headerWith());

    expect(
      find.text('trend.sideways'),
      findsNothing,
      reason:
          '台積電 2026-07-24 沒被評分，畫面卻宣稱「盤整」。'
          '同一個 Wrap 裡的支撐壓力徽章在 null 時就正確地不渲染',
    );
    expect(find.text('trend.up'), findsNothing);
    expect(find.text('trend.down'), findsNothing);
  });

  testWidgets('對照組：RANGE 是合法分析結果，仍須顯示「盤整」', (tester) async {
    await pump(tester, headerWith(trendState: 'RANGE'));

    expect(
      find.text('trend.sideways'),
      findsOneWidget,
      reason: '有分析且判定為橫盤 ≠ 沒有分析，不可因為上一條而一併隱藏',
    );
  });

  testWidgets('對照組：UP / DOWN 照常顯示', (tester) async {
    await pump(tester, headerWith(trendState: 'UP'));
    expect(find.text('trend.up'), findsOneWidget);

    await pump(tester, headerWith(trendState: 'DOWN'));
    expect(find.text('trend.down'), findsOneWidget);
  });
}
