import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/domain/models/models.dart';
import 'package:afterclose/domain/services/rule_engine.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';
import 'package:afterclose/domain/services/rules/volume_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/price_data_generators.dart';

void main() {
  late RuleEngine ruleEngine;

  setUp(() {
    ruleEngine = RuleEngine();
  });

  group('StockData Helpers', () {
    test('latestPrice returns last entry', () {
      final prices = [
        createTestPrice(date: DateTime.now(), close: 100.0),
        createTestPrice(date: DateTime.now(), close: 105.0),
      ];
      final data = StockData(symbol: 'TEST', prices: prices);

      expect(data.latestPrice, equals(prices.last));
      expect(data.latestClose, equals(105.0));
    });

    test('previousPrice returns second to last entry', () {
      final prices = [
        createTestPrice(date: DateTime.now(), close: 100.0),
        createTestPrice(date: DateTime.now(), close: 105.0),
      ];
      final data = StockData(symbol: 'TEST', prices: prices);

      expect(data.previousPrice, equals(prices.first));
      expect(data.previousClose, equals(100.0));
    });

    test('returns null when prices are empty', () {
      const data = StockData(symbol: 'TEST', prices: []);

      expect(data.latestPrice, isNull);
      expect(data.latestClose, isNull);
      expect(data.previousPrice, isNull);
      expect(data.previousClose, isNull);
    });
  });

  // ==========================================
  // getTopReasons / calculateScore / evaluateStock
  // ==========================================

  group('getTopReasons', () {
    test('return all reasons when descriptions are unique', () {
      final reasons = [
        const TriggeredReason(
          type: ReasonType.techBreakout,
          score: 25,
          description: 'Breakout above resistance',
        ),
        const TriggeredReason(
          type: ReasonType.volumeSpike,
          score: 22,
          description: 'Volume spike 4x avg',
        ),
        const TriggeredReason(
          type: ReasonType.reversalW2S,
          score: 35,
          description: 'Weak to strong reversal',
        ),
      ];

      final result = ruleEngine.getTopReasons(reasons);
      expect(result.length, 3);
    });

    test('dedup reasons with same description', () {
      final reasons = [
        const TriggeredReason(
          type: ReasonType.techBreakout,
          score: 25,
          description: 'Same description',
        ),
        const TriggeredReason(
          type: ReasonType.volumeSpike,
          score: 22,
          description: 'Same description',
        ),
      ];

      final result = ruleEngine.getTopReasons(reasons);
      expect(result.length, 1);
      expect(result.first.type, ReasonType.techBreakout);
    });

    test('return empty list for empty reasons', () {
      final result = ruleEngine.getTopReasons([]);
      expect(result, isEmpty);
    });

    test('keep first occurrence when duplicates exist', () {
      final reasons = [
        const TriggeredReason(
          type: ReasonType.techBreakout,
          score: 25,
          description: 'Dup',
        ),
        const TriggeredReason(
          type: ReasonType.volumeSpike,
          score: 22,
          description: 'Unique',
        ),
        const TriggeredReason(
          type: ReasonType.reversalW2S,
          score: 35,
          description: 'Dup',
        ),
      ];

      final result = ruleEngine.getTopReasons(reasons);
      expect(result.length, 2);
      // 第一個 Dup 保留（techBreakout），第二個 Dup 去除
      expect(result[0].type, ReasonType.techBreakout);
      expect(result[1].type, ReasonType.volumeSpike);
    });
  });

  group('calculateScore Institutional Combo Bonus', () {
    test(
      'apply institutional combo bonus for institutional + breakout (+15)',
      () {
        final reasons = [
          const TriggeredReason(
            type: ReasonType.institutionalBuy,
            score: 18,
            description: 'Inst buy',
          ),
          const TriggeredReason(
            type: ReasonType.techBreakout,
            score: 25,
            description: 'Breakout',
          ),
        ];

        // Base: 18 + 25 = 43
        // Bonus: +15 (institutional + breakout)
        // Total: 58
        final score = ruleEngine.calculateScore(reasons);
        expect(score, 58);
      },
    );

    test(
      'apply institutional combo bonus for institutional + reversal (+15)',
      () {
        final reasons = [
          const TriggeredReason(
            type: ReasonType.institutionalBuy,
            score: 18,
            description: 'Inst buy',
          ),
          const TriggeredReason(
            type: ReasonType.reversalW2S,
            score: 35,
            description: 'Reversal',
          ),
        ];

        // Base: 18 + 35 = 53
        // Bonus: +15 (institutional + reversal)
        // Total: 68
        final score = ruleEngine.calculateScore(reasons);
        expect(score, 68);
      },
    );

    test(
      'apply all applicable bonuses simultaneously (capped at maxScore)',
      () {
        final reasons = [
          const TriggeredReason(
            type: ReasonType.institutionalBuy,
            score: 18,
            description: 'Inst',
          ),
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

        // Base: 18 + 35 + 22 = 75
        // Bonuses: +10 (reversal+volume) + 15 (institutional+reversal) = +25
        // Raw: 100 → capped at maxScore (80)
        final score = ruleEngine.calculateScore(reasons);
        expect(score, RuleScores.maxScore);
      },
    );
  });

  group('Rule Exception Handling', () {
    test('catch and skip rule exceptions without crashing', () {
      final engine = RuleEngine(customRules: [const _ThrowingRule()]);
      final prices = generateConstantPrices(days: 5, basePrice: 100.0);
      const context = AnalysisContext(trendState: TrendState.range);

      final reasons = engine.evaluateStock(
        context,
        StockData(symbol: 'UNKNOWN', prices: prices),
      );

      // 拋出例外的規則被跳過，不影響結果
      expect(reasons, isEmpty);
    });

    test('return results from remaining rules when one rule throws', () {
      final engine = RuleEngine(
        customRules: [const _ThrowingRule(), const VolumeSpikeRule()],
      );
      final prices = generatePricesWithVolumeSpike(
        days: 30,
        normalVolume: 1000,
        spikeVolume: 5000,
      );
      const context = AnalysisContext(trendState: TrendState.range);

      final reasons = engine.evaluateStock(
        context,
        StockData(symbol: 'UNKNOWN', prices: prices),
      );

      // _ThrowingRule 拋例外被跳過，VolumeSpikeRule 正常觸發
      expect(reasons, isNotEmpty);
      expect(reasons.any((r) => r.type == ReasonType.volumeSpike), isTrue);
    });
  });

  group('calculateScore Edge Cases', () {
    test('return 0 for empty reasons list', () {
      final score = ruleEngine.calculateScore([]);
      expect(score, 0);
    });

    test('apply cooldown penalty correctly', () {
      final reasons = [
        const TriggeredReason(
          type: ReasonType.reversalW2S,
          score: 35,
          description: 'Reversal',
        ),
      ];

      // Base: 35
      // Cooldown: -15
      // Total: 20
      final score = ruleEngine.calculateScore(
        reasons,
        wasRecentlyRecommended: true,
      );
      expect(score, 20);
    });

    test('not go below 0 with cooldown penalty', () {
      final reasons = [
        const TriggeredReason(
          type: ReasonType.newsRelated,
          score: 8,
          description: 'News',
        ),
      ];

      // Base: 8
      // Cooldown: -15
      // Raw: -7 → clamped to 0
      final score = ruleEngine.calculateScore(
        reasons,
        wasRecentlyRecommended: true,
      );
      expect(score, 0);
    });

    test('handle mixed positive and negative scores', () {
      final reasons = [
        const TriggeredReason(
          type: ReasonType.techBreakout,
          score: 25,
          description: 'Breakout',
        ),
        const TriggeredReason(
          type: ReasonType.techBreakdown,
          score: -20,
          description: 'Breakdown',
        ),
      ];

      // 25 + (-20) = 5
      final score = ruleEngine.calculateScore(reasons);
      expect(score, 5);
    });
  });

  group('evaluateStock Edge Cases', () {
    test('return empty list for empty price history', () {
      final reasons = ruleEngine.evaluateStock(
        const AnalysisContext(trendState: TrendState.range),
        const StockData(symbol: 'UNKNOWN', prices: []),
      );
      expect(reasons, isEmpty);
    });

    test('sort returned reasons by score descending', () {
      // 使用自訂規則確保產生多個已知分數的結果
      final engine = RuleEngine(
        customRules: [
          const _FixedScoreRule(
            ruleId: 'low',
            score: 10,
            reasonType: ReasonType.newsRelated,
          ),
          const _FixedScoreRule(
            ruleId: 'high',
            score: 30,
            reasonType: ReasonType.techBreakout,
          ),
          const _FixedScoreRule(
            ruleId: 'mid',
            score: 20,
            reasonType: ReasonType.volumeSpike,
          ),
        ],
      );
      final prices = generateConstantPrices(days: 5, basePrice: 100.0);
      const context = AnalysisContext(trendState: TrendState.range);

      final reasons = engine.evaluateStock(
        context,
        StockData(symbol: 'UNKNOWN', prices: prices),
      );

      expect(reasons.length, 3);
      expect(reasons[0].score, 30);
      expect(reasons[1].score, 20);
      expect(reasons[2].score, 10);
    });
  });
}

// ==========================================
// 測試用內聯規則
// ==========================================

/// 永遠拋出例外的規則（用於測試例外處理）
class _ThrowingRule extends StockRule {
  const _ThrowingRule();

  @override
  String get id => 'throwing_rule';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    throw Exception('Test exception from ThrowingRule');
  }
}

/// 永遠回傳固定分數的規則（用於測試排序）
class _FixedScoreRule extends StockRule {
  const _FixedScoreRule({
    required this.ruleId,
    required this.score,
    required this.reasonType,
  });

  final String ruleId;
  final int score;
  final ReasonType reasonType;

  @override
  String get id => ruleId;

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    return TriggeredReason(
      type: reasonType,
      score: score,
      description: 'Fixed score $score from $ruleId',
    );
  }
}
