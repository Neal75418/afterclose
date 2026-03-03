import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/models.dart';
import 'package:afterclose/domain/services/rule_engine.dart';
import 'package:afterclose/domain/services/rules/fundamental_rules.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';
import 'package:afterclose/domain/services/rules/technical_rules.dart';
import 'package:afterclose/domain/services/rules/volume_rules.dart';
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

    test('should support custom rules via constructor', () {
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

    test('registerRule and unregisterRule should work', () {
      final engine = RuleEngine(customRules: []);
      expect(
        engine.evaluateStock(
          priceHistory: generateConstantPrices(days: 30, basePrice: 100.0),
          context: const AnalysisContext(trendState: TrendState.up),
        ),
        isEmpty,
      );

      engine.registerRule(const BreakoutRule());

      // 產生滿足突破條件的價格資料
      final prices = generatePricesWithBreakout(
        days: 30,
        basePrice: 100.0,
        breakoutPrice: 110.0,
        normalVolume: 1000,
        breakoutVolume: 3000,
      );
      final reasons = engine.evaluateStock(
        priceHistory: prices,
        context: const AnalysisContext(
          trendState: TrendState.up,
          resistanceLevel: 100.0,
        ),
      );
      expect(reasons, isNotEmpty);

      engine.unregisterRule('tech_breakout');
      final afterUnregister = engine.evaluateStock(
        priceHistory: prices,
        context: const AnalysisContext(
          trendState: TrendState.up,
          resistanceLevel: 100.0,
        ),
      );
      expect(afterUnregister, isEmpty);
    });
  });

  group('calculateScore', () {
    test('should apply bonus for Breakout + Volume Spike (+10)', () {
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

    test('should apply bonus for Reversal + Volume Spike (+10)', () {
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

    test('should cap score at maxScore', () {
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

    test('should not reduce score below 0', () {
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

  group('Individual Rules', () {
    group('WeakToStrongRule', () {
      const rule = WeakToStrongRule();

      test('should trigger on breakout above range top', () {
        final prices = generateDowntrendPrices(days: 60);
        final pricesWithBreakout = [
          ...prices.take(prices.length - 1),
          createTestPrice(date: DateTime.now(), close: 102.0),
        ];

        const context = AnalysisContext(
          trendState: TrendState.down,
          reversalState: ReversalState.weakToStrong,
          rangeTop: 100.0,
        );

        final data = StockData(symbol: 'TEST', prices: pricesWithBreakout);
        final result = rule.evaluate(context, data);

        expect(result, isNotNull);
        expect(result!.type, ReasonType.reversalW2S);
      });

      test('should NOT trigger when trend is already up', () {
        final prices = generateUptrendPrices(days: 30);
        const context = AnalysisContext(
          trendState: TrendState.up,
          rangeTop: 100.0,
        );

        final data = StockData(symbol: 'TEST', prices: prices);
        final result = rule.evaluate(context, data);

        expect(result, isNull);
      });
    });

    group('StrongToWeakRule', () {
      const rule = StrongToWeakRule();

      test('should trigger on breakdown below support', () {
        final prices = generateUptrendPrices(days: 30);
        final pricesWithBreakdown = [
          ...prices.take(prices.length - 1),
          createTestPrice(date: DateTime.now(), close: 98.0),
        ];

        const context = AnalysisContext(
          trendState: TrendState.up,
          reversalState: ReversalState.strongToWeak,
          supportLevel: 100.0,
        );

        final data = StockData(symbol: 'TEST', prices: pricesWithBreakdown);
        final result = rule.evaluate(context, data);

        expect(result, isNotNull);
        expect(result!.type, ReasonType.reversalS2W);
      });

      test('should NOT trigger when trend is already down', () {
        final prices = generateDowntrendPrices(days: 30);
        const context = AnalysisContext(
          trendState: TrendState.down,
          supportLevel: 100.0,
        );

        final data = StockData(symbol: 'TEST', prices: prices);
        final result = rule.evaluate(context, data);

        expect(result, isNull);
      });
    });

    group('BreakoutRule', () {
      const rule = BreakoutRule();

      test('should trigger when close exceeds resistance with volume', () {
        // 突破規則需要: close > breakoutLevel, close > MA20, volume >= 2x avg
        // breakoutLevel = 100 * 1.03 = 103, 所以需要 close > 103
        final prices = generatePricesWithBreakout(
          days: 25,
          basePrice: 100.0,
          breakoutPrice: 110.0, // > 103 (breakoutLevel) 且 > 100 (MA20)
          normalVolume: 1000,
          breakoutVolume: 3000, // 3x 均量
        );
        const context = AnalysisContext(
          trendState: TrendState.range,
          resistanceLevel: 100.0,
        );

        final data = StockData(symbol: 'TEST', prices: prices);
        final result = rule.evaluate(context, data);

        expect(result, isNotNull);
        expect(result!.type, ReasonType.techBreakout);
      });

      test('should NOT trigger when close is below resistance', () {
        final prices = generateConstantPrices(
          days: 25,
          basePrice: 99.0,
          volume: 1000,
        );
        const context = AnalysisContext(
          trendState: TrendState.range,
          resistanceLevel: 100.0,
        );

        final data = StockData(symbol: 'TEST', prices: prices);
        final result = rule.evaluate(context, data);

        expect(result, isNull);
      });
    });

    group('BreakdownRule', () {
      const rule = BreakdownRule();

      test('should trigger when close falls below support with volume', () {
        // 跌破規則需要: close < breakdownLevel, close < MA20, volume >= 2x avg
        // breakdownLevel = 100 * (1 - 0.03) = 97, 所以需要 close < 97
        final prices = generatePricesWithBreakdown(
          days: 25,
          basePrice: 100.0,
          breakdownPrice: 90.0, // < 97 (breakdownLevel) 且 < 100 (MA20)
          normalVolume: 1000,
          breakdownVolume: 3000, // 3x 均量
        );
        const context = AnalysisContext(
          trendState: TrendState.range,
          supportLevel: 100.0,
        );

        final data = StockData(symbol: 'TEST', prices: prices);
        final result = rule.evaluate(context, data);

        expect(result, isNotNull);
        expect(result!.type, ReasonType.techBreakdown);
      });

      test('should NOT trigger when close is above support', () {
        final prices = generateConstantPrices(
          days: 25,
          basePrice: 101.0,
          volume: 1000,
        );
        const context = AnalysisContext(
          trendState: TrendState.range,
          supportLevel: 100.0,
        );

        final data = StockData(symbol: 'TEST', prices: prices);
        final result = rule.evaluate(context, data);

        expect(result, isNull);
      });
    });

    group('VolumeSpikeRule', () {
      const rule = VolumeSpikeRule();

      test('should trigger when volume is 4x average with price move', () {
        final prices = generatePricesWithVolumeSpike(
          days: 30,
          normalVolume: 1000,
          spikeVolume: 5000,
        );
        const context = AnalysisContext(trendState: TrendState.range);
        final data = StockData(symbol: 'TEST', prices: prices);

        final result = rule.evaluate(context, data);

        expect(result, isNotNull);
        expect(result!.type, ReasonType.volumeSpike);
      });

      test('should NOT trigger with low volume', () {
        final prices = generateUptrendPrices(days: 30);
        const context = AnalysisContext(trendState: TrendState.range);
        final data = StockData(symbol: 'TEST', prices: prices);

        final result = rule.evaluate(context, data);

        expect(result, isNull);
      });
    });

    group('PriceSpikeRule', () {
      const rule = PriceSpikeRule();

      test('should trigger when price moves 5%+ with volume confirmation', () {
        // v0.1.3: 需要 21 天資料計算均量，且成交量需達 1.5 倍
        final now = DateTime.now();
        const baseVolume = 1000.0;
        final prices = List.generate(21, (i) {
          if (i < 20) {
            // 前 20 天：平穩價格，正常成交量
            return createTestPrice(
              date: now.subtract(Duration(days: 20 - i)),
              close: 100.0,
              volume: baseVolume,
            );
          } else {
            // 今天：漲 8%，成交量 2 倍（大於 1.5 倍門檻）
            return createTestPrice(
              date: now,
              close: 108.0,
              volume: baseVolume * 2,
            );
          }
        });
        const context = AnalysisContext(trendState: TrendState.range);
        final data = StockData(symbol: 'TEST', prices: prices);

        final result = rule.evaluate(context, data);

        expect(result, isNotNull);
        expect(result!.type, ReasonType.priceSpike);
        expect(result.evidence?['volumeMultiple'], greaterThanOrEqualTo(1.5));
      });

      test('should NOT trigger with small price change', () {
        // 4% 漲幅不觸發（門檻 5%）
        final now = DateTime.now();
        final prices = List.generate(21, (i) {
          if (i < 20) {
            return createTestPrice(
              date: now.subtract(Duration(days: 20 - i)),
              close: 100.0,
              volume: 1000.0,
            );
          } else {
            return createTestPrice(
              date: now,
              close: 104.0, // 只漲 4%
              volume: 2000.0,
            );
          }
        });
        const context = AnalysisContext(trendState: TrendState.range);
        final data = StockData(symbol: 'TEST', prices: prices);

        final result = rule.evaluate(context, data);

        expect(result, isNull);
      });

      test('should NOT trigger without volume confirmation', () {
        // 價格漲 8%，但成交量不足 1.5 倍
        final now = DateTime.now();
        final prices = List.generate(21, (i) {
          if (i < 20) {
            return createTestPrice(
              date: now.subtract(Duration(days: 20 - i)),
              close: 100.0,
              volume: 1000.0,
            );
          } else {
            return createTestPrice(
              date: now,
              close: 108.0,
              volume: 1200.0, // 只有 1.2 倍，低於 1.5 倍門檻
            );
          }
        });
        const context = AnalysisContext(trendState: TrendState.range);
        final data = StockData(symbol: 'TEST', prices: prices);

        final result = rule.evaluate(context, data);

        expect(result, isNull);
      });
    });

    group('InstitutionalShiftRule', () {
      const rule = InstitutionalShiftRule();

      test('should trigger when foreign investors switch to buy', () {
        // Rule Case 5 (Significant Buy) requires:
        // 1. todayVolume >= 1,000,000 shares (1000 sheets * 1000)
        // 2. todayNet > 2,500,000 (2500 sheets * 1000)
        // 3. todayNet.abs() / todayVolume >= 0.25 (25% ratio)
        //
        // Using: todayDirection = 3,000,000, volume = 10,000,000
        // ratio = 3M / 10M = 0.3 > 0.25 ✓
        final history = generateInstitutionalHistory(
          days: 15,
          prevDirection: -600000,
          todayDirection: 4000000, // 4M net buy (= 4000 sheets, 40% ratio)
        );
        final prices = [
          ...generateConstantPrices(
            days: 14,
            basePrice: 100.0,
            volume: 10000000,
          ),
          createTestPrice(
            date: DateTime.now(),
            close: 102.0, // 2% rise > 1.5% threshold
            volume: 10000000,
          ),
        ];
        const context = AnalysisContext(trendState: TrendState.range);
        final data = StockData(
          symbol: 'TEST',
          prices: prices,
          institutional: history,
        );

        final result = rule.evaluate(context, data);

        expect(result, isNotNull);
        expect(result!.type, ReasonType.institutionalBuy);
      });

      test('should NOT trigger with insufficient history', () {
        final history = generateInstitutionalHistory(
          days: 3,
          prevDirection: -500,
          todayDirection: 500,
        );
        const context = AnalysisContext(trendState: TrendState.range);
        final data = StockData(
          symbol: 'TEST',
          prices: [],
          institutional: history,
        );

        final result = rule.evaluate(context, data);

        expect(result, isNull);
      });

      // ============================================================
      // Phase 3a: InstitutionalShiftRule 補測
      // ============================================================

      test('Scenario 1: should trigger sell-to-buy reversal', () {
        // prevAvg < -100K, todayNet > 500K, price up, ratio > 35%
        final now = DateTime.now();
        final history = List.generate(5, (i) {
          return DailyInstitutionalEntry(
            symbol: 'TEST',
            date: now.subtract(Duration(days: 4 - i)),
            foreignNet: i < 4 ? -150000.0 : 2000000.0,
            investmentTrustNet: 0,
            dealerNet: 0,
          );
        });
        final prices = [
          ...generateConstantPrices(
            days: 14,
            basePrice: 100.0,
            volume: 4000000,
          ),
          createTestPrice(
            date: now,
            close: 102.0, // +2% > 1.5%
            volume: 4000000, // >= 2M
          ),
        ];
        const context = AnalysisContext(trendState: TrendState.range);
        final data = StockData(
          symbol: 'TEST',
          prices: prices,
          institutional: history,
        );

        final result = rule.evaluate(context, data);

        expect(result, isNotNull);
        expect(result!.type, ReasonType.institutionalBuy);
        expect(result.description, contains('由賣轉買'));
      });

      test('Scenario 2: should trigger buy-to-sell reversal', () {
        // prevAvg > 100K, todayNet < -500K, price down, ratio > 35%
        final now = DateTime.now();
        final history = List.generate(5, (i) {
          return DailyInstitutionalEntry(
            symbol: 'TEST',
            date: now.subtract(Duration(days: 4 - i)),
            foreignNet: i < 4 ? 150000.0 : -2000000.0,
            investmentTrustNet: 0,
            dealerNet: 0,
          );
        });
        final prices = [
          ...generateConstantPrices(
            days: 14,
            basePrice: 100.0,
            volume: 4000000,
          ),
          createTestPrice(
            date: now,
            close: 98.0, // -2% < -1.5%
            volume: 4000000,
          ),
        ];
        const context = AnalysisContext(trendState: TrendState.range);
        final data = StockData(
          symbol: 'TEST',
          prices: prices,
          institutional: history,
        );

        final result = rule.evaluate(context, data);

        expect(result, isNotNull);
        expect(result!.type, ReasonType.institutionalSell);
        expect(result.score, RuleScores.institutionalShiftSell);
        expect(result.description, contains('由買轉賣'));
      });

      test('Scenario 3: should trigger buy acceleration', () {
        // prevAvg > 100K, todayNet > prevAvg * 2, > 1M, ratio > 50%
        final now = DateTime.now();
        final history = List.generate(5, (i) {
          return DailyInstitutionalEntry(
            symbol: 'TEST',
            date: now.subtract(Duration(days: 4 - i)),
            foreignNet: i < 4 ? 300000.0 : 3000000.0,
            investmentTrustNet: 0,
            dealerNet: 0,
          );
        });
        final prices = [
          ...generateConstantPrices(
            days: 14,
            basePrice: 100.0,
            volume: 5000000,
          ),
          createTestPrice(date: now, close: 101.0, volume: 5000000),
        ];
        const context = AnalysisContext(trendState: TrendState.range);
        final data = StockData(
          symbol: 'TEST',
          prices: prices,
          institutional: history,
        );

        final result = rule.evaluate(context, data);

        expect(result, isNotNull);
        expect(result!.type, ReasonType.institutionalBuy);
        expect(result.description, contains('買超擴大'));
      });

      test('Scenario 4: should trigger sell acceleration', () {
        // prevAvg < -100K, todayNet < prevAvg * 2, < -1M, ratio > 50%
        final now = DateTime.now();
        final history = List.generate(5, (i) {
          return DailyInstitutionalEntry(
            symbol: 'TEST',
            date: now.subtract(Duration(days: 4 - i)),
            foreignNet: i < 4 ? -300000.0 : -3000000.0,
            investmentTrustNet: 0,
            dealerNet: 0,
          );
        });
        final prices = [
          ...generateConstantPrices(
            days: 14,
            basePrice: 100.0,
            volume: 5000000,
          ),
          createTestPrice(date: now, close: 99.0, volume: 5000000),
        ];
        const context = AnalysisContext(trendState: TrendState.range);
        final data = StockData(
          symbol: 'TEST',
          prices: prices,
          institutional: history,
        );

        final result = rule.evaluate(context, data);

        expect(result, isNotNull);
        expect(result!.type, ReasonType.institutionalSell);
        expect(result.description, contains('賣超擴大'));
      });

      test('Scenario 6: should trigger significant sell (generic catch)', () {
        // todayNet < -5M, ratio > 35%, priceChangePercent < -1%
        final now = DateTime.now();
        final history = [
          DailyInstitutionalEntry(
            symbol: 'TEST',
            date: now.subtract(const Duration(days: 1)),
            foreignNet: 0,
            investmentTrustNet: 0,
            dealerNet: 0,
          ),
          DailyInstitutionalEntry(
            symbol: 'TEST',
            date: now,
            foreignNet: -6000000.0,
            investmentTrustNet: 0,
            dealerNet: 0,
          ),
        ];
        final prices = [
          ...generateConstantPrices(
            days: 14,
            basePrice: 100.0,
            volume: 10000000,
          ),
          createTestPrice(
            date: now,
            close: 98.0, // -2% < -1%
            volume: 10000000,
          ),
        ];
        const context = AnalysisContext(trendState: TrendState.range);
        final data = StockData(
          symbol: 'TEST',
          prices: prices,
          institutional: history,
        );

        final result = rule.evaluate(context, data);

        expect(result, isNotNull);
        expect(result!.type, ReasonType.institutionalSell);
        expect(result.description, contains('顯著賣超'));
      });

      test('should return null when todayNet.abs() < minVolumeShares', () {
        final now = DateTime.now();
        final history = [
          DailyInstitutionalEntry(
            symbol: 'TEST',
            date: now,
            foreignNet: 500000.0, // < 1,000,000
            investmentTrustNet: 0,
            dealerNet: 0,
          ),
        ];
        final prices = generateConstantPrices(
          days: 5,
          basePrice: 100.0,
          volume: 5000000,
        );
        const context = AnalysisContext(trendState: TrendState.range);
        final data = StockData(
          symbol: 'TEST',
          prices: prices,
          institutional: history,
        );

        expect(rule.evaluate(context, data), isNull);
      });

      test('should return null when volume < validVolumeShares', () {
        final now = DateTime.now();
        final history = [
          DailyInstitutionalEntry(
            symbol: 'TEST',
            date: now,
            foreignNet: 2000000.0,
            investmentTrustNet: 0,
            dealerNet: 0,
          ),
        ];
        final prices = [
          createTestPrice(
            date: now,
            close: 100.0,
            volume: 1000000, // < 2,000,000
          ),
        ];
        const context = AnalysisContext(trendState: TrendState.range);
        final data = StockData(
          symbol: 'TEST',
          prices: prices,
          institutional: history,
        );

        expect(rule.evaluate(context, data), isNull);
      });

      test('should have hasHistory = true when exactly 4 entries', () {
        // 4 筆法人資料 → hasHistory = true (history.length >= 4)
        final now = DateTime.now();
        final history = List.generate(4, (i) {
          return DailyInstitutionalEntry(
            symbol: 'TEST',
            date: now.subtract(Duration(days: 3 - i)),
            foreignNet: i < 3 ? -150000.0 : 2000000.0,
            investmentTrustNet: 0,
            dealerNet: 0,
          );
        });
        final prices = [
          ...generateConstantPrices(
            days: 14,
            basePrice: 100.0,
            volume: 4000000,
          ),
          createTestPrice(date: now, close: 102.0, volume: 4000000),
        ];
        const context = AnalysisContext(trendState: TrendState.range);
        final data = StockData(
          symbol: 'TEST',
          prices: prices,
          institutional: history,
        );

        final result = rule.evaluate(context, data);

        // hasHistory = true, 應該能觸發歷史邏輯（Scenario 1: 賣轉買）
        expect(result, isNotNull);
        expect(result!.type, ReasonType.institutionalBuy);
      });

      test('should skip history logic when only 3 entries', () {
        // 3 筆法人資料 → hasHistory = false, 只用通用邏輯
        final now = DateTime.now();
        final history = List.generate(3, (i) {
          return DailyInstitutionalEntry(
            symbol: 'TEST',
            date: now.subtract(Duration(days: 2 - i)),
            foreignNet: i < 2 ? -150000.0 : 6000000.0,
            investmentTrustNet: 0,
            dealerNet: 0,
          );
        });
        final prices = [
          ...generateConstantPrices(
            days: 14,
            basePrice: 100.0,
            volume: 10000000,
          ),
          createTestPrice(
            date: now,
            close: 102.0, // +2% > 1%
            volume: 10000000,
          ),
        ];
        const context = AnalysisContext(trendState: TrendState.range);
        final data = StockData(
          symbol: 'TEST',
          prices: prices,
          institutional: history,
        );

        final result = rule.evaluate(context, data);

        // hasHistory = false, 觸發 Scenario 5（顯著買超）
        expect(result, isNotNull);
        expect(result!.type, ReasonType.institutionalBuy);
        expect(result.description, contains('顯著買超'));
      });
    });

    group('NewsRule', () {
      const rule = NewsRule();

      test('should trigger on positive news', () {
        final news = [
          NewsItemEntry(
            id: 'test-1',
            title: '營收創新高！公司表現優異',
            source: 'MoneyDJ',
            url: 'https://example.com/news/1',
            publishedAt: DateTime.now(),
            fetchedAt: DateTime.now(),
            category: 'EARNINGS',
          ),
        ];
        const context = AnalysisContext(trendState: TrendState.range);
        final data = StockData(symbol: 'TEST', prices: [], news: news);

        final result = rule.evaluate(context, data);

        expect(result, isNotNull);
        expect(result!.type, ReasonType.newsRelated);
        expect(result.description, contains('利多'));
      });

      test('should trigger on negative news', () {
        final news = [
          NewsItemEntry(
            id: 'test-2',
            title: '虧損擴大，業績不佳',
            source: 'MoneyDJ',
            url: 'https://example.com/news/2',
            publishedAt: DateTime.now(),
            fetchedAt: DateTime.now(),
            category: 'EARNINGS',
          ),
        ];
        const context = AnalysisContext(trendState: TrendState.range);
        final data = StockData(symbol: 'TEST', prices: [], news: news);

        final result = rule.evaluate(context, data);

        expect(result, isNotNull);
        expect(result!.type, ReasonType.newsRelated);
        expect(result.description, contains('利空'));
      });

      test('should NOT trigger on old news (>120h / 5 days)', () {
        // Rule filters news older than 120 hours (5 days)
        final news = [
          NewsItemEntry(
            id: 'test-3',
            title: '營收創新高！',
            source: 'MoneyDJ',
            url: 'https://example.com/news/3',
            publishedAt: DateTime.now().subtract(const Duration(hours: 150)),
            fetchedAt: DateTime.now().subtract(const Duration(hours: 150)),
            category: 'EARNINGS',
          ),
        ];
        const context = AnalysisContext(trendState: TrendState.range);
        final data = StockData(symbol: 'TEST', prices: [], news: news);

        final result = rule.evaluate(context, data);

        expect(result, isNull);
      });
    });
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

  // ============================================================
  // Phase 2: getTopReasons / calculateScore / evaluateStock 補測
  // ============================================================

  group('getTopReasons', () {
    test('should return all reasons when descriptions are unique', () {
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

    test('should dedup reasons with same description', () {
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

    test('should return empty list for empty reasons', () {
      final result = ruleEngine.getTopReasons([]);
      expect(result, isEmpty);
    });

    test('should keep first occurrence when duplicates exist', () {
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
      'should apply institutional combo bonus for institutional + breakout (+15)',
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
      'should apply institutional combo bonus for institutional + reversal (+15)',
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
      'should apply all applicable bonuses simultaneously (capped at maxScore)',
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
    test('should catch and skip rule exceptions without crashing', () {
      final engine = RuleEngine(customRules: [const _ThrowingRule()]);
      final prices = generateConstantPrices(days: 5, basePrice: 100.0);
      const context = AnalysisContext(trendState: TrendState.range);

      final reasons = engine.evaluateStock(
        priceHistory: prices,
        context: context,
      );

      // 拋出例外的規則被跳過，不影響結果
      expect(reasons, isEmpty);
    });

    test('should return results from remaining rules when one rule throws', () {
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
        priceHistory: prices,
        context: context,
      );

      // _ThrowingRule 拋例外被跳過，VolumeSpikeRule 正常觸發
      expect(reasons, isNotEmpty);
      expect(reasons.any((r) => r.type == ReasonType.volumeSpike), isTrue);
    });
  });

  group('calculateScore Edge Cases', () {
    test('should return 0 for empty reasons list', () {
      final score = ruleEngine.calculateScore([]);
      expect(score, 0);
    });

    test('should apply cooldown penalty correctly', () {
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

    test('should not go below 0 with cooldown penalty', () {
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

    test('should handle mixed positive and negative scores', () {
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
    test('should return empty list for empty price history', () {
      final reasons = ruleEngine.evaluateStock(
        priceHistory: [],
        context: const AnalysisContext(trendState: TrendState.range),
      );
      expect(reasons, isEmpty);
    });

    test('should sort returned reasons by score descending', () {
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
        priceHistory: prices,
        context: context,
      );

      expect(reasons.length, 3);
      expect(reasons[0].score, 30);
      expect(reasons[1].score, 20);
      expect(reasons[2].score, 10);
    });
  });
}

// ============================================================
// 測試用內聯規則
// ============================================================

/// 永遠拋出例外的規則（用於測試例外處理）
class _ThrowingRule extends StockRule {
  const _ThrowingRule();

  @override
  String get id => 'throwing_rule';

  @override
  String get name => 'Throwing Rule';

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
  String get name => 'Fixed Score Rule ($ruleId)';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    return TriggeredReason(
      type: reasonType,
      score: score,
      description: 'Fixed score $score from $ruleId',
    );
  }
}
