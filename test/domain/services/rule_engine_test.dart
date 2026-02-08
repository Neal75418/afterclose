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

    test('should cap score at 100', () {
      // Simulate reasons that sum > 100
      final reasons = List.generate(
        5,
        (i) => const TriggeredReason(
          type: ReasonType.reversalW2S,
          score: 35,
          description: 'High Score',
        ),
      );

      final score = ruleEngine.calculateScore(reasons);
      expect(score, 100);
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
}
