import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:daredevil/domain/services/alert/alert_target_calculator.dart';
import 'package:daredevil/presentation/screens/stock_detail/widgets/alert_quick_set.dart';

import '../../../../helpers/widget_test_helpers.dart';

/// 快捷提醒鈕(2026-08-07)。
///
/// 存在理由:使用者要「觸價後開始觀察」而非每次手打價位。app **只算不
/// 決定**——把 5MA/10MA/月線/20 日高/守門價算好放著,點哪個由使用者。
void main() {
  setUpAll(() async => setupTestLocalization());

  List<Ohlc> bars(int n) => [
    for (var i = 0; i < n; i++)
      Ohlc(high: 100 + i + 2, low: 100 + i - 2, close: 100 + i.toDouble()),
  ];

  void widen(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 4000);
    addTearDown(tester.view.resetPhysicalSize);
  }

  testWidgets('資料足夠時列出全部五種快捷鈕,各自帶算好的價位', (tester) async {
    widen(tester);
    await tester.pumpWidget(
      buildTestApp(AlertQuickSet(bars: bars(30), onSelected: (_, __) {})),
    );
    // 五種:跌破5MA/跌破10MA/跌破月線/突破月線/突破20日高 + 守門價 = 6
    expect(find.byType(ActionChip), findsNWidgets(6));
    // 價位有顯示(5MA=127.0)
    expect(find.textContaining('127.0'), findsOneWidget);
  });

  testWidgets('🚨 點擊回傳種類與價位——app 不自己建立,由呼叫端決定', (tester) async {
    widen(tester);
    AlertKind? kind;
    double? price;
    await tester.pumpWidget(
      buildTestApp(
        AlertQuickSet(
          bars: bars(30),
          onSelected: (k, t) {
            kind = k;
            price = t.price;
          },
        ),
      ),
    );
    await tester.tap(find.byType(ActionChip).first);
    await tester.pump();
    expect(kind, isNotNull);
    expect(price, isNotNull);
  });

  testWidgets('資料不足 → 只顯示算得出來的,不硬湊', (tester) async {
    widen(tester);
    await tester.pumpWidget(
      buildTestApp(AlertQuickSet(bars: bars(8), onSelected: (_, __) {})),
    );
    expect(find.byType(ActionChip), findsOneWidget); // 只有 5MA
  });

  testWidgets('完全無資料 → 整個區塊收起,不留空殼', (tester) async {
    widen(tester);
    await tester.pumpWidget(
      buildTestApp(AlertQuickSet(bars: const [], onSelected: (_, __) {})),
    );
    expect(find.byType(ActionChip), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
