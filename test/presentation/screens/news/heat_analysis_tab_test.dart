import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/constants/scoring_mode.dart';
import 'package:afterclose/domain/services/news/heat_calculator.dart';
import 'package:afterclose/presentation/providers/news_heat_provider.dart';
import 'package:afterclose/presentation/screens/news/heat_analysis_tab.dart';

import '../../../helpers/provider_test_helpers.dart';
import '../../../helpers/widget_test_helpers.dart';

// 註：本專案 widget 測試慣例（見 price_alert_dialog_test.dart、
// settings_screen_test.dart）在 buildTestApp/buildProviderTestApp 下不接
// EasyLocalization widget，`.tr()` 因此解析不到真實翻譯、fallback 回傳
// 原始 key 字串本身。故本檔斷言比對「i18n key 原始字串」而非翻譯後文字，
// 與專案既有測試慣例一致（非本檔行為變更）。

NewsHeatAnalysis analysis() => NewsHeatAnalysis(
  themes: const [
    ThemeHeat(
      theme: '記憶體',
      articles7d: 23,
      articlesPrev21d: 6,
      isSurging: true,
      topStocks: ['2408', '2344'],
    ),
  ],
  stocks: const [
    StockHeat(
      symbol: '2408',
      mentions7d: 9,
      mentionsPrev21d: 2,
      isSurging: true,
    ),
    StockHeat(
      symbol: '2330',
      mentions7d: 30,
      mentionsPrev21d: 40,
      isSurging: false,
    ),
  ],
  stockNames: const {'2408': '南亞科', '2344': '華邦電', '2330': '台積電'},
  modeBySymbol: const {'2408': ScoringMode.weaknessObserve},
);

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 8000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  Widget build(NewsHeatAnalysis data) => buildProviderTestApp(
    const HeatAnalysisTab(),
    overrides: [newsHeatProvider.overrideWith((ref) async => data)],
  );

  testWidgets('顯示主流族群卡片與成分股', (tester) async {
    widenViewport(tester);
    await tester.pumpWidget(build(analysis()));
    await tester.pumpAndSettle();

    expect(find.text('記憶體'), findsOneWidget);
    expect(find.text('南亞科'), findsWidgets);
  });

  testWidgets('焦點股列表含爆量徽章與回檔標注', (tester) async {
    widenViewport(tester);
    await tester.pumpWidget(build(analysis()));
    await tester.pumpAndSettle();

    expect(find.text('台積電'), findsOneWidget);
    // 爆量徽章（2408）至少一個 — 'news.surgeBadge' i18n key
    expect(find.text('news.surgeBadge'), findsWidgets);
    // 回檔標注（2408 屬 weaknessObserve）— ScoringMode.displayKey i18n key
    expect(find.text('scoringMode.weaknessObserve'), findsWidgets);
  });

  testWidgets('只看回檔中過濾', (tester) async {
    widenViewport(tester);
    await tester.pumpWidget(build(analysis()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('news.pullbackOnly'));
    await tester.pumpAndSettle();

    expect(find.text('南亞科'), findsWidgets);
    expect(find.text('台積電'), findsNothing);
  });

  testWidgets('空資料顯示空狀態', (tester) async {
    widenViewport(tester);
    await tester.pumpWidget(
      build(
        const NewsHeatAnalysis(
          themes: [],
          stocks: [],
          stockNames: {},
          modeBySymbol: {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('news.heatEmpty'), findsOneWidget);
  });
}
