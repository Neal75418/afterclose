import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/constants/market_codes.dart';
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
