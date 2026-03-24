import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/models.dart';
import 'package:afterclose/domain/services/rules/fundamental_rules.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';
import 'package:afterclose/domain/services/rules/technical_rules.dart';
import 'package:afterclose/domain/services/rules/volume_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/price_data_generators.dart';

void main() {
  group('Individual Rules', () {
    group('WeakToStrongRule', () {
      const rule = WeakToStrongRule();

      test('trigger on breakout above range top', () {
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

      test('NOT trigger when trend is already up', () {
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

      test('trigger on breakdown below support', () {
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

      test('NOT trigger when trend is already down', () {
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

      test('trigger when close exceeds resistance with volume', () {
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

      test('NOT trigger when close is below resistance', () {
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

      test('trigger when close falls below support with volume', () {
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

      test('NOT trigger when close is above support', () {
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

      test('trigger when volume is 4x average with price move', () {
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

      test('NOT trigger with low volume', () {
        final prices = generateUptrendPrices(days: 30);
        const context = AnalysisContext(trendState: TrendState.range);
        final data = StockData(symbol: 'TEST', prices: prices);

        final result = rule.evaluate(context, data);

        expect(result, isNull);
      });
    });

    group('PriceSpikeRule', () {
      const rule = PriceSpikeRule();

      test('trigger when price moves 5%+ with volume confirmation', () {
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

      test('NOT trigger with small price change', () {
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

      test('NOT trigger without volume confirmation', () {
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

      test('trigger when foreign investors switch to buy', () {
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

      test('NOT trigger with insufficient history', () {
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

      // ==========================================
      // InstitutionalShiftRule 補測
      // ==========================================

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

      test('return null when todayNet.abs() < minVolumeShares', () {
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

      test('return null when volume < validVolumeShares', () {
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

      test('have hasHistory = true when exactly 4 entries', () {
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

      test('skip history logic when only 3 entries', () {
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

      test('trigger on positive news', () {
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

      test('trigger on negative news', () {
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

      test('NOT trigger on old news (>120h / 5 days)', () {
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
}
