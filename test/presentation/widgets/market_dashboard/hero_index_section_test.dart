import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/hero_index_section.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  TwseMarketIndex createIndex({
    double close = 22000.50,
    double change = 150.25,
    double changePercent = 0.69,
  }) {
    return TwseMarketIndex(
      date: DateTime(2026, 2, 15),
      name: '發行量加權股價指數',
      close: close,
      change: change,
      changePercent: changePercent,
    );
  }

  group('HeroIndexSection', () {
    testWidgets('displays formatted close price', (tester) async {
      await tester.pumpWidget(
        buildTestApp(HeroIndexSection(index: createIndex())),
      );

      // 22,000.50 should be displayed
      expect(find.text('22,000.50'), findsOneWidget);
    });

    testWidgets('shows positive sign for up market', (tester) async {
      await tester.pumpWidget(
        buildTestApp(HeroIndexSection(index: createIndex(change: 150.25))),
      );

      // +150.25 formatted
      expect(find.text('+150.25'), findsOneWidget);
    });

    testWidgets('shows no sign for down market', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          HeroIndexSection(
            index: createIndex(change: -80.10, changePercent: -0.36),
          ),
        ),
      );

      expect(find.text('-80.10'), findsOneWidget);
    });

    group('market stage row', () {
      // 持續上升 80 點 → 多頭排列（close > MA20 > MA60）
      final bullishHistory = List.generate(80, (i) => 22000.0 + i.toDouble());

      testWidgets('renders stage chip with sufficient stage history', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestApp(
            HeroIndexSection(
              index: createIndex(),
              historyData: bullishHistory,
              stageHistory: bullishHistory,
            ),
          ),
        );

        // 位階 chip + 距 20MA / 距 60MA 乖離率（無載入翻譯時 .tr() 回傳 key）
        expect(find.text('marketOverview.stage.bullish'), findsOneWidget);
        expect(find.textContaining('marketOverview.biasMa20'), findsOneWidget);
      });

      testWidgets('shows insufficient muted text when stage history is short', (
        tester,
      ) async {
        // 少於 MA60 所需筆數（<60）→ 位階資料不足
        final shortHistory = List.generate(30, (i) => 22000.0 + i.toDouble());

        await tester.pumpWidget(
          buildTestApp(
            HeroIndexSection(
              index: createIndex(),
              historyData: shortHistory,
              stageHistory: shortHistory,
            ),
          ),
        );

        expect(find.text('marketOverview.stage.insufficient'), findsOneWidget);
        // 資料不足時不顯示位階 chip
        expect(find.text('marketOverview.stage.bullish'), findsNothing);
      });

      testWidgets('omits stage row entirely when no stage history', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestApp(HeroIndexSection(index: createIndex())),
        );

        expect(find.text('marketOverview.stage.insufficient'), findsNothing);
        expect(find.text('marketOverview.stage.bullish'), findsNothing);
      });
    });
  });
}
