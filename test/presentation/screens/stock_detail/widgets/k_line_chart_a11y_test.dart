// 平盤 a11y 播報迴歸 —— flat-value sign/color 缺陷類第三輪
//
// K 線圖的無障礙摘要以 `change >= 0` 二分方向，平盤（首尾同價）被播報成
// 「上漲」、微負值（捨入後為 0.00%）被播報成「下跌」，與同時播報的
// 「0.00%」自相矛盾。修正後改走 `S.priceChangeLabel` 三分法 + 顯示精度
// 捨入，平盤與捨入歸零一律播報「持平」。
//
// 兩個測試環境細節：
//
// 1. 本檔獨立於 `k_line_chart_widget_test.dart`——該檔用空翻譯（.tr() 回傳
//    key）驗結構，本檔要驗「播報的字」，必須載入真實翻譯。同檔會互相污染
//    `Localization.instance`；Flutter 每個 test 檔獨立 isolate，分檔即隔離。
//
// 2. 摘要走 namedArgs，key 找不到時 easy_localization 直接回 key、不代入
//    args，播報的字就觀察不到——所以必須真的載入翻譯。但 rootBundle 的非同步
//    載入在 widget test 的 fake async 下不會 resolve（實測 label 恆為空），
//    因此改在 setUpAll 用 dart:io 先把真實 zh-TW.json 讀進記憶體，再用
//    preloaded loader 餵給 EasyLocalization（Future 於 microtask 完成，pump
//    得到）。讀真檔而非寫死字串，翻譯檔若漂移本測試會跟著抓到。

import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/k_line_chart_widget.dart';

/// 供給預先讀好的翻譯 map（避開 rootBundle 在 fake async 下不 resolve）
class _PreloadedAssetLoader extends AssetLoader {
  const _PreloadedAssetLoader(this.data);

  final Map<String, dynamic> data;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => data;
}

void main() {
  late Map<String, dynamic> zhTw;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    zhTw =
        json.decode(await File('assets/translations/zh-TW.json').readAsString())
            as Map<String, dynamic>;
  });

  Widget wrapWithRealTranslations(Widget child) => EasyLocalization(
    supportedLocales: const [Locale('zh', 'TW')],
    path: 'assets/translations',
    fallbackLocale: const Locale('zh', 'TW'),
    startLocale: const Locale('zh', 'TW'),
    assetLoader: _PreloadedAssetLoader(zhTw),
    child: Builder(
      builder: (context) => MaterialApp(
        locale: context.locale,
        supportedLocales: context.supportedLocales,
        localizationsDelegates: context.localizationDelegates,
        theme: AppTheme.lightTheme,
        home: Scaffold(body: child),
      ),
    ),
  );

  final baseDate = DateTime(2026, 2, 13);

  /// 由收盤價序列建出 priceHistory（oldest→newest）
  List<DailyPriceEntry> historyFromCloses(List<double> closes) {
    return List.generate(
      closes.length,
      (i) => DailyPriceEntry(
        symbol: '2330',
        date: baseDate.subtract(Duration(days: closes.length - i)),
        open: closes[i],
        high: closes[i] + 2,
        low: closes[i] - 2,
        close: closes[i],
        volume: 50000 + i * 1000,
      ),
    );
  }

  /// 先漲後跌回到 [end]——首尾同價時 change 恰為 0，但序列不退化為一直線
  List<double> roundTripCloses({double end = 100.0}) => [
    for (var i = 0; i < 15; i++) 100.0 + i,
    for (var i = 14; i >= 1; i--) 100.0 + i,
    end,
  ];

  /// 取出 K 線圖根節點的無障礙摘要文字
  String chartSummaryOf(WidgetTester tester) {
    final semantics = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .firstWhere(
          (w) => w.properties.label?.contains('K線圖') ?? false,
          orElse: () => throw StateError('找不到 K 線圖無障礙摘要'),
        );
    return semantics.properties.label!;
  }

  Future<void> pumpChart(WidgetTester tester, List<double> closes) async {
    tester.view.physicalSize = const Size(5000, 4000);
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      wrapWithRealTranslations(
        KLineChartWidget(priceHistory: historyFromCloses(closes)),
      ),
    );
    // 翻譯 loader 於 microtask 完成，需額外 pump 才會 rebuild 出內容
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  group('KLineChartWidget 無障礙摘要方向播報', () {
    testWidgets('平盤（首尾同價）播報「持平」而非「上漲」', (tester) async {
      await pumpChart(tester, roundTripCloses());

      final summary = chartSummaryOf(tester);
      expect(summary, contains('持平'));
      expect(summary, isNot(contains('上漲')));
      expect(summary, isNot(contains('下跌')));
    });

    testWidgets('微負值（捨入後 0.00%）播報「持平」而非「下跌」', (tester) async {
      // 首 100.0 尾 99.9999 → changePercent ≈ -0.0001%，2 位捨入為 0.00
      await pumpChart(tester, roundTripCloses(end: 99.9999));

      final summary = chartSummaryOf(tester);
      expect(summary, contains('0.00'));
      expect(summary, contains('持平'));
      expect(summary, isNot(contains('下跌')));
    });

    testWidgets('真實上漲仍播報「上漲」（未過度中性化）', (tester) async {
      await pumpChart(tester, [for (var i = 0; i < 30; i++) 100.0 + i]);

      final summary = chartSummaryOf(tester);
      expect(summary, contains('上漲'));
      expect(summary, isNot(contains('持平')));
    });

    testWidgets('真實下跌仍播報「下跌」', (tester) async {
      await pumpChart(tester, [for (var i = 0; i < 30; i++) 130.0 - i]);

      final summary = chartSummaryOf(tester);
      expect(summary, contains('下跌'));
      expect(summary, isNot(contains('持平')));
    });
  });
}
