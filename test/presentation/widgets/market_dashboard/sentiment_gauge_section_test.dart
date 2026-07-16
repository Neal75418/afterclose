import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/constants/market_codes.dart';
import 'package:afterclose/core/constants/ui_constants.dart';
import 'package:afterclose/domain/services/market_sentiment_service.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/sentiment_gauge_section.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  MarketSentiment createSentiment() {
    return const MarketSentiment(
      score: 57,
      level: SentimentLevel.neutral,
      subScores: {
        'advanceRatio': 59.0,
        'institutional': 62.0,
        'volumeMomentum': 42.0,
        'marginChange': 47.0,
        'industryBreadth': 68.0,
      },
    );
  }

  group('SentimentGaugeSection 子指標收摺', () {
    testWidgets('預設收摺：顯示總分、子指標細項不在 tree', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          SentimentGaugeSection(
            sentiment: createSentiment(),
            market: MarketCode.twse,
          ),
        ),
      );

      // 總分仍顯示
      expect(find.text('57'), findsOneWidget);
      // 收摺狀態的 chevron 朝下
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsNothing);
      // 子指標分數（advanceRatio=59）預設不渲染
      expect(find.text('59'), findsNothing);
    });

    testWidgets('點細項展開：子指標分數出現、chevron 反轉', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          SentimentGaugeSection(
            sentiment: createSentiment(),
            market: MarketCode.twse,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.expand_less), findsOneWidget);
      expect(find.text('59'), findsOneWidget); // advanceRatio
      expect(find.text('68'), findsOneWidget); // industryBreadth
    });
  });

  group('SentimentGaugeSection 渲染高度（回歸：情緒配對列殘留高度）', () {
    // 移除趨勢 sparkline 前的 UiConstants.sentimentDividerHeight 舊值（見該
    // 常數的變更前註解）。兩測試皆須遠低於此值，證明「殘留高度」迴歸已修正。
    const oldSentimentDividerHeight = 260.0;

    /// 量測「內容實際需要的高度」，非填滿可用空間的高度。
    ///
    /// [SentimentGaugeSection] 頂層為 `Column`（預設 `mainAxisSize.max`），
    /// 若直接塞進 `buildTestApp` 的 `Scaffold(body: ...)`，會在有限高度環境
    /// 下被撐滿至整個 body（量到的是「可用空間」而非「內容所需空間」）。
    /// `SingleChildScrollView` 給子孫 unbounded 高度，複現
    /// `MarketDashboard._buildParallelView` 實際所在的 CustomScrollView
    /// 情境——此時 `Column` 的 `mainAxisSize.max` 在 unbounded 環境下會回退
    /// 為子孫實際大小總和，量到的才是真正的內容高度。
    Future<double> measureHeight(
      WidgetTester tester,
      MarketSentiment sentiment,
    ) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          SingleChildScrollView(
            child: SentimentGaugeSection(
              sentiment: sentiment,
              market: MarketCode.twse,
            ),
          ),
        ),
      );
      return tester.getSize(find.byType(SentimentGaugeSection)).height;
    }

    testWidgets('子指標收摺（預設狀態）：高度遠小於已移除趨勢 sparkline 前的舊值', (tester) async {
      final height = await measureHeight(tester, createSentiment());

      expect(height, lessThan(oldSentimentDividerHeight));
      // 不得超過現行 sentimentDividerHeight，否則分隔線會明顯短於卡片本身
      // （見 UiConstants.sentimentDividerHeight 註解）。
      expect(height, lessThanOrEqualTo(UiConstants.sentimentDividerHeight));
    });

    testWidgets('子指標展開（5 項全部命中，最高狀態）：高度遠小於舊值，且不超過分隔線常數', (tester) async {
      // 子指標全部 5 項命中展開是目前最高的內容狀態（趨勢 sparkline 移除後
      // 已無更高狀態），故用此狀態驗證 UiConstants.sentimentDividerHeight
      // 是否仍涵蓋實際最高內容高度。
      await measureHeight(tester, createSentiment());
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();
      final height = tester.getSize(find.byType(SentimentGaugeSection)).height;

      expect(height, lessThan(oldSentimentDividerHeight));
      expect(height, lessThanOrEqualTo(UiConstants.sentimentDividerHeight));
    });
  });

  group('SentimentGaugeSection 趨勢 sparkline 已移除', () {
    testWidgets('即使提供 5 筆以上歷史分數，也不再渲染趨勢 sparkline row', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          SentimentGaugeSection(
            sentiment: createSentiment(),
            market: MarketCode.twse,
            sentimentHistory: const [40, 45, 50, 55, 57],
          ),
        ),
      );

      expect(find.text('marketOverview.sentiment.trend'), findsNothing);
    });
  });

  group('SentimentGaugeSection 市場標示', () {
    testWidgets('上市／上櫃各自標題內含對應市場標示，兩者文字不同', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestApp(
          Column(
            children: [
              SentimentGaugeSection(
                sentiment: createSentiment(),
                market: MarketCode.twse,
              ),
              SentimentGaugeSection(
                sentiment: createSentiment(),
                market: MarketCode.tpex,
              ),
            ],
          ),
        ),
      );

      final gauges = find.byType(SentimentGaugeSection);
      final twseGauge = gauges.at(0);
      final tpexGauge = gauges.at(1);

      // 各自標題含對應市場標示（測試環境無 EasyLocalization context，
      // .tr() 回傳原始 key，故比對 key 而非實際翻譯後中文字串）。
      expect(
        find.descendant(
          of: twseGauge,
          matching: find.textContaining('marketOverview.twse'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tpexGauge,
          matching: find.textContaining('marketOverview.tpex'),
        ),
        findsOneWidget,
      );

      // 交叉檢查：TWSE 側不得混入 TPEx 標示，反之亦然 — 證明兩者標題
      // 真正不同（而非兩側剛好都含相同字串)。
      expect(
        find.descendant(
          of: twseGauge,
          matching: find.textContaining('marketOverview.tpex'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: tpexGauge,
          matching: find.textContaining('marketOverview.twse'),
        ),
        findsNothing,
      );
    });
  });
}
