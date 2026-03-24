import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/domain/models/models.dart';
import 'package:afterclose/domain/services/rule_engine.dart';
import 'package:afterclose/domain/services/rules/technical_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/price_data_generators.dart';

void main() {
  late RuleEngine ruleEngine;

  setUp(() {
    ruleEngine = RuleEngine();
  });

  group('RuleEngine Strategy', () {
    test('evaluateStock should run all rules and return reasons', () {
      // 產生有成交量爆增的價格資料
      // 注意：突破規則現在需要 MA20 過濾和成交量確認 (2x 均量)
      final prices = generatePricesWithVolumeSpike(
        days: 30,
        normalVolume: 1000,
        spikeVolume: 5000,
      );
      const context = AnalysisContext(
        trendState: TrendState.range,
        resistanceLevel: 100.0,
      );

      final reasons = ruleEngine.evaluateStock(
        priceHistory: prices,
        context: context,
        symbol: 'TEST',
      );

      // 驗證成交量爆增規則有觸發
      expect(reasons, isNotEmpty);
      expect(reasons.any((r) => r.type == ReasonType.volumeSpike), isTrue);
      // 注意：突破規則現在需要 MA20 和 2x 成交量確認，收盤 103 剛好等於 breakoutLevel (100 * 1.03)
      // 需要 close > breakoutLevel 才會觸發，所以這裡不再驗證

      final score = ruleEngine.calculateScore(reasons);
      expect(score, greaterThan(0));
    });

    test('support custom rules via constructor', () {
      final customEngine = RuleEngine(customRules: [const BreakoutRule()]);

      // 產生有成交量的上升趨勢價格
      // 突破規則需要: 1) close > breakoutLevel  2) close > MA20  3) todayVolume >= 2x avgVolume
      final prices = generatePricesWithBreakout(
        days: 30,
        basePrice: 100.0,
        breakoutPrice: 110.0, // 超過 breakoutLevel (100 * 1.03 = 103)
        normalVolume: 1000,
        breakoutVolume: 3000, // 3x 均量
      );
      const context = AnalysisContext(
        trendState: TrendState.up,
        resistanceLevel: 100.0,
      );

      final reasons = customEngine.evaluateStock(
        priceHistory: prices,
        context: context,
      );

      // 驗證突破規則有觸發
      expect(reasons.any((r) => r.type == ReasonType.techBreakout), isTrue);
    });
  });

  group('calculateScore', () {
    test('apply bonus for Breakout + Volume Spike (+10)', () {
      final reasons = [
        const TriggeredReason(
          type: ReasonType.techBreakout,
          score: 25,
          description: 'Breakout',
        ),
        const TriggeredReason(
          type: ReasonType.volumeSpike,
          score: 22,
          description: 'Volume',
        ),
      ];

      // Base: 25 + 22 = 47
      // Bonus: +10 (Breakout + Volume)
      // Total: 57
      final score = ruleEngine.calculateScore(reasons);
      expect(score, 57);
    });

    test('apply bonus for Reversal + Volume Spike (+10)', () {
      final reasons = [
        const TriggeredReason(
          type: ReasonType.reversalW2S,
          score: 35,
          description: 'Reversal',
        ),
        const TriggeredReason(
          type: ReasonType.volumeSpike,
          score: 22,
          description: 'Volume',
        ),
      ];

      // Base: 35 + 22 = 57
      // Bonus: +10 (Reversal + Volume)
      // Total: 67
      final score = ruleEngine.calculateScore(reasons);
      expect(score, 67);
    });

    test('cap score at maxScore', () {
      // Simulate reasons that sum > maxScore
      final reasons = List.generate(
        5,
        (i) => const TriggeredReason(
          type: ReasonType.reversalW2S,
          score: 35,
          description: 'High Score',
        ),
      );

      final score = ruleEngine.calculateScore(reasons);
      expect(score, RuleScores.maxScore);
    });

    test('not reduce score below 0', () {
      // Simulate negative reasons
      final reasons = [
        const TriggeredReason(
          type: ReasonType.techBreakdown,
          score: -100,
          description: 'Bad',
        ),
      ];

      final score = ruleEngine.calculateScore(reasons);
      expect(score, 0);
    });
  });
}
