import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
        buildTestApp(SentimentGaugeSection(sentiment: createSentiment())),
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
        buildTestApp(SentimentGaugeSection(sentiment: createSentiment())),
      );

      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.expand_less), findsOneWidget);
      expect(find.text('59'), findsOneWidget); // advanceRatio
      expect(find.text('68'), findsOneWidget); // industryBreadth
    });
  });
}
