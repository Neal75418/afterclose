import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/domain/models/industry_ranking.dart';
import 'package:afterclose/presentation/providers/industry_ranking_provider.dart';
import 'package:afterclose/presentation/widgets/industry_ranking_section.dart';

import '../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 4000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  Widget buildSection(Map<RankingWindow, List<IndustryRanking>> byWindow) {
    return ProviderScope(
      overrides: [
        industryRankingProvider.overrideWith(
          (ref, window) async => byWindow[window] ?? const [],
        ),
      ],
      child: buildTestApp(
        const SingleChildScrollView(child: IndustryRankingSection()),
      ),
    );
  }

  const semis = IndustryRanking(
    industry: '半導體業',
    momentumPct: 12.3,
    memberCount: 42,
    institutionalNetShares: 5000000, // +5,000 張
    topMembers: [
      IndustryMember(symbol: '2330', name: '台積電', retPct: 15.0),
      IndustryMember(symbol: '2454', name: '聯發科', retPct: 10.0),
    ],
  );
  const textiles = IndustryRanking(
    industry: '紡織業',
    momentumPct: -2.5,
    memberCount: 12,
    institutionalNetShares: -800000,
    topMembers: [],
  );
  const financials = IndustryRanking(
    industry: '金融保險',
    momentumPct: 3.0,
    memberCount: 32,
    institutionalNetShares: 351542596,
    topMembers: [],
  );

  group('IndustryRankingSection', () {
    testWidgets('顯示產業卡：名稱、動能百分比、名次（預設 20日）', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildSection(const {
          RankingWindow.d20: [semis, textiles],
        }),
      );
      await tester.pumpAndSettle(); // SectionHeader 動畫跑完（避免 pending timer）

      expect(find.text('半導體業'), findsOneWidget);
      expect(find.text('+12.3%'), findsOneWidget);
      expect(find.text('紡織業'), findsOneWidget);
      expect(find.text('-2.5%'), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // 名次
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('切到 5日 → 換成 5日視窗的排行', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildSection(const {
          RankingWindow.d20: [financials],
          RankingWindow.d5: [semis],
        }),
      );
      await tester.pumpAndSettle();

      // 預設 20日：金融在榜、半導體不在
      expect(find.text('金融保險'), findsOneWidget);
      expect(find.text('半導體業'), findsNothing);

      await tester.tap(find.text('today.industryWindow5d'));
      await tester.pumpAndSettle();

      // 5日視角：半導體反彈進榜
      expect(find.text('半導體業'), findsOneWidget);
      expect(find.text('金融保險'), findsNothing);
    });

    testWidgets('空排行 → 整段收起', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildSection(const {}));
      await tester.pumpAndSettle();

      expect(find.text('today.industryRanking'), findsNothing);
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('點卡片開領漲成員 sheet', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildSection(const {
          RankingWindow.d20: [semis],
        }),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('半導體業'));
      await tester.pumpAndSettle();

      expect(find.text('台積電'), findsOneWidget);
      expect(find.text('2330'), findsOneWidget);
      expect(find.text('+15.0%'), findsOneWidget);
      expect(find.text('聯發科'), findsOneWidget);
    });
  });
}
