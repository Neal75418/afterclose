import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/domain/models/market_overview_models.dart';
import 'package:afterclose/domain/services/market_sentiment_service.dart';

void main() {
  group('MarketSentimentService.calculate', () {
    // 固定輸入：5 項子指標皆可計算，且各自分數不同以便辨識權重變動。
    //
    // - advanceRatio: ratio 0.5 → _linearMap(0.5, 0.2, 0.8) = 50.0
    // - institutional: 常數序列 std=0、last>0 → 75.0
    // - volumeMomentum: today/avg = 1.0 → _linearMap(1.0, 0.5, 2.0) = 33.333…
    // - marginChange: 無變動 changePct=0 → _linearMap(0, -0.05, 0.05) = 50.0
    // - industryBreadth: 2 產業 1 上漲 → 50.0
    MarketSentiment computeFixedInput() {
      return MarketSentimentService.calculate(
        advanceDecline: const AdvanceDecline(advance: 500, decline: 500),
        institutionalNetHistory: const [100, 100, 100, 100, 100],
        turnoverHistory: const [100, 100, 100, 100, 100, 100],
        marginBalanceHistory: const [100, 100, 100, 100, 100],
        industries: const [
          IndustrySummary(
            industry: 'A',
            stockCount: 1,
            avgChangePct: 1.0,
            advance: 1,
            decline: 0,
          ),
          IndustrySummary(
            industry: 'B',
            stockCount: 1,
            avgChangePct: -1.0,
            advance: 0,
            decline: 1,
          ),
        ],
      );
    }

    test('composite 恰好包含 5 項子指標（漲停比已移除）', () {
      final result = computeFixedInput();

      expect(result.subScores.length, 5);
      expect(
        result.subScores.keys,
        containsAll(<String>[
          'advanceRatio',
          'institutional',
          'volumeMomentum',
          'marginChange',
          'industryBreadth',
        ]),
      );
      // 漲停比已自情緒綜合移除
      expect(result.subScores.containsKey('limitRatio'), isFalse);
    });

    test('權重總和為 1.0（5 項全到齊時 totalWeight 正規化不縮放）', () {
      final result = computeFixedInput();

      // 5 項全到齊 ⇒ totalWeight=1.0 ⇒ 綜合分數 == 加權平均（無正規化放大）。
      // 以已知子分數手算加權平均驗證權重總和為 1.0：
      // 0.35*50 + 0.25*75 + 0.15*(100/3) + 0.15*50 + 0.10*50
      const expected =
          0.35 * 50.0 +
          0.25 * 75.0 +
          0.15 * (100.0 / 3.0) +
          0.15 * 50.0 +
          0.10 * 50.0;

      expect(result.score, closeTo(expected, 1e-9));
    });

    test('固定輸入回歸：綜合分數 = 53.75', () {
      final result = computeFixedInput();

      // 權重重新分配後（advanceRatio 0.25→0.35、移除 limitRatio 0.10）的定錨值
      expect(result.score, closeTo(53.75, 1e-9));
      expect(result.level, SentimentLevel.neutral);
    });

    test('子指標缺漏時有效權重自動正規化', () {
      // 僅提供漲跌比與法人，缺量能/融資/產業
      final result = MarketSentimentService.calculate(
        advanceDecline: const AdvanceDecline(advance: 800, decline: 200),
        institutionalNetHistory: const [100, 100, 100, 100, 100],
        turnoverHistory: const [],
        marginBalanceHistory: const [],
      );

      // advanceRatio ratio=0.8 → 100.0；institutional → 75.0
      // 有效權重 = 0.35 + 0.25 = 0.60
      // (0.35*100 + 0.25*75) / 0.60 = (35 + 18.75) / 0.60 = 89.5833…
      expect(result.subScores.length, 2);
      expect(result.score, closeTo((0.35 * 100 + 0.25 * 75) / 0.60, 1e-9));
    });
  });
}
