// ScoreTierBadge widget 測試 — 分級徽章 + 小字數字（評分改進 #5，
// 使用者選定「徽章為主視覺、確切分數退為小字」）
//
// 測試環境不載實際翻譯（setupTestLocalization 慣例）→ .tr() 回傳 key，
// 斷言以 i18n key 為準；實際字面（強/中/弱/觀察）由 zh-TW.json 保證。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/widgets/score_tier_badge.dart';

import '../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(buildTestApp(child, brightness: Brightness.light));
  }

  group('ScoreTierBadge — 單分數', () {
    testWidgets('強級分數：顯示「強」徽章 + 小字數字', (tester) async {
      await pump(tester, const ScoreTierBadge(score: 52));
      expect(find.text('score.tier.strong'), findsOneWidget);
      expect(find.text('52'), findsOneWidget);
    });

    testWidgets('弱級分數：顯示「弱」徽章', (tester) async {
      await pump(tester, const ScoreTierBadge(score: 14));
      expect(find.text('score.tier.weak'), findsOneWidget);
      expect(find.text('14'), findsOneWidget);
    });

    testWidgets('觀察區分數（< 12）：顯示「觀察」', (tester) async {
      await pump(tester, const ScoreTierBadge(score: 9));
      expect(find.text('score.tier.observation'), findsOneWidget);
    });
  });

  group('ScoreTierBadge — 雙 horizon', () {
    testWidgets('雙分數不同：徽章取較高分的級別、兩個小字數字都顯示', (tester) async {
      // short 20（弱）、long 48（強）→ 徽章「強」（任一 horizon 語意）
      await pump(
        tester,
        const ScoreTierBadge.dual(shortScore: 20, longScore: 48),
      );
      expect(find.text('score.tier.strong'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
      expect(find.text('48'), findsOneWidget);
      // horizon 標籤保留
      expect(find.text('5D'), findsOneWidget);
      expect(find.text('60D'), findsOneWidget);
    });

    testWidgets('雙分數相同：collapse 成單一數字、無 horizon 標籤', (tester) async {
      await pump(
        tester,
        const ScoreTierBadge.dual(shortScore: 30, longScore: 30),
      );
      expect(find.text('score.tier.medium'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
      expect(find.text('5D'), findsNothing);
    });
  });
}
