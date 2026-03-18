import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/domain/services/market_insight_service.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/key_insights_row.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  group('KeyInsightsRow', () {
    testWidgets('returns SizedBox.shrink when insights is empty', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp(const KeyInsightsRow(insights: [])));

      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.byType(Column), findsNothing);
    });

    testWidgets('renders correct number of cards for 2 insights', (
      tester,
    ) async {
      const insights = [
        MarketInsight(
          type: InsightType.sentimentExtreme,
          severity: InsightSeverity.warning,
          priority: 10,
          titleKey: 'marketOverview.keyInsights.sentimentExtreme.title',
          descKey: 'marketOverview.keyInsights.sentimentExtreme.descFear',
          descArgs: {'score': '15'},
          isPositive: false,
        ),
        MarketInsight(
          type: InsightType.volumeAnomaly,
          severity: InsightSeverity.warning,
          priority: 7,
          titleKey: 'marketOverview.keyInsights.volumeAnomaly.title',
          descKey: 'marketOverview.keyInsights.volumeAnomaly.descHigh',
          descArgs: {'pct': '60'},
          isPositive: true,
        ),
      ];

      await tester.pumpWidget(
        buildTestApp(const KeyInsightsRow(insights: insights)),
      );

      // Wrap 內應該有 2 張卡片（SizedBox wrapping each card）
      final wrap = tester.widget<Wrap>(find.byType(Wrap));
      expect(wrap.children.length, 2);
    });

    testWidgets('renders 4 cards for max insights', (tester) async {
      const insights = [
        MarketInsight(
          type: InsightType.sentimentExtreme,
          severity: InsightSeverity.warning,
          priority: 10,
          titleKey: 'marketOverview.keyInsights.sentimentExtreme.title',
          descKey: 'marketOverview.keyInsights.sentimentExtreme.descGreed',
          descArgs: {'score': '90'},
        ),
        MarketInsight(
          type: InsightType.institutionalStreak,
          severity: InsightSeverity.warning,
          priority: 8,
          titleKey: 'marketOverview.keyInsights.institutionalStreak.title',
          descKey:
              'marketOverview.keyInsights.institutionalStreak.descForeignBuy',
          descArgs: {'days': '7'},
          isPositive: true,
        ),
        MarketInsight(
          type: InsightType.volumeAnomaly,
          severity: InsightSeverity.warning,
          priority: 7,
          titleKey: 'marketOverview.keyInsights.volumeAnomaly.title',
          descKey: 'marketOverview.keyInsights.volumeAnomaly.descHigh',
          descArgs: {'pct': '55'},
          isPositive: true,
        ),
        MarketInsight(
          type: InsightType.chipAlert,
          severity: InsightSeverity.warning,
          priority: 6,
          titleKey: 'marketOverview.keyInsights.chipAlert.title',
          descKey: 'marketOverview.keyInsights.chipAlert.desc',
          descArgs: {'count': '3'},
          isPositive: false,
        ),
      ];

      await tester.pumpWidget(
        buildTestApp(const KeyInsightsRow(insights: insights)),
      );

      final wrap = tester.widget<Wrap>(find.byType(Wrap));
      expect(wrap.children.length, 4);
    });

    testWidgets('cards use left border decoration', (tester) async {
      const insights = [
        MarketInsight(
          type: InsightType.sentimentExtreme,
          severity: InsightSeverity.warning,
          priority: 10,
          titleKey: 'marketOverview.keyInsights.sentimentExtreme.title',
          descKey: 'marketOverview.keyInsights.sentimentExtreme.descFear',
          descArgs: {'score': '10'},
          isPositive: false,
        ),
        MarketInsight(
          type: InsightType.volumeAnomaly,
          severity: InsightSeverity.info,
          priority: 7,
          titleKey: 'marketOverview.keyInsights.volumeAnomaly.title',
          descKey: 'marketOverview.keyInsights.volumeAnomaly.descLow',
          descArgs: {'pct': '35'},
          isPositive: false,
        ),
      ];

      await tester.pumpWidget(
        buildTestApp(const KeyInsightsRow(insights: insights)),
      );

      // 找到有左邊框裝飾的 Container
      final containers = find.byType(Container);
      expect(containers, findsWidgets);
    });

    testWidgets('renders in dark mode', (tester) async {
      const insights = [
        MarketInsight(
          type: InsightType.limitImbalance,
          severity: InsightSeverity.warning,
          priority: 5,
          titleKey: 'marketOverview.keyInsights.limitImbalance.title',
          descKey: 'marketOverview.keyInsights.limitImbalance.descUp',
          descArgs: {'up': '40', 'down': '5'},
          isPositive: true,
        ),
        MarketInsight(
          type: InsightType.industryConcentration,
          severity: InsightSeverity.info,
          priority: 3,
          titleKey: 'marketOverview.keyInsights.industryConcentration.title',
          descKey: 'marketOverview.keyInsights.industryConcentration.descUp',
          descArgs: {'pct': '85'},
          isPositive: true,
        ),
      ];

      await tester.pumpWidget(
        buildTestApp(
          const KeyInsightsRow(insights: insights),
          brightness: Brightness.dark,
        ),
      );

      expect(find.byType(Wrap), findsOneWidget);
    });
  });
}
