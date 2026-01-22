import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/analysis_service.dart';
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
      final prices = generatePricesWithVolumeSpike(
        days: 30,
        normalVolume: 1000,
        spikeVolume: 5000,
      );
      final context = AnalysisContext(
        trendState: TrendState.range,
        resistanceLevel: 100.0,
      );

      final reasons = ruleEngine.evaluateStock(
        priceHistory: prices,
        context: context,
        symbol: 'TEST',
      );

      expect(reasons, isNotEmpty);
      expect(reasons.any((r) => r.type == ReasonType.volumeSpike), isTrue);
      expect(reasons.any((r) => r.type == ReasonType.techBreakout), isTrue);

      final score = ruleEngine.calculateScore(reasons);
      expect(score, greaterThan(50));
    });

    test('should support custom rules via constructor', () {
      final customEngine = RuleEngine(customRules: [const BreakoutRule()]);

      final prices = generateUptrendPrices(days: 30);
      final context = AnalysisContext(
        trendState: TrendState.up,
        resistanceLevel: 100.0,
      );

      final reasons = customEngine.evaluateStock(
        priceHistory: prices,
        context: context,
      );

      // Only BreakoutRule should be evaluated
      expect(reasons.every((r) => r.type == ReasonType.techBreakout), isTrue);
    });

    test('registerRule and unregisterRule should work', () {
      final engine = RuleEngine(customRules: []);
      expect(
        engine.evaluateStock(
          priceHistory: generateUptrendPrices(days: 30),
          context: AnalysisContext(trendState: TrendState.up),
        ),
        isEmpty,
      );

      engine.registerRule(const BreakoutRule());
      final reasons = engine.evaluateStock(
        priceHistory: generateUptrendPrices(days: 30),
        context: AnalysisContext(
          trendState: TrendState.up,
          resistanceLevel: 100.0,
        ),
      );
      expect(reasons, isNotEmpty);

      engine.unregisterRule('tech_breakout');
      final afterUnregister = engine.evaluateStock(
        priceHistory: generateUptrendPrices(days: 30),
        context: AnalysisContext(
          trendState: TrendState.up,
          resistanceLevel: 100.0,
        ),
      );
      expect(afterUnregister, isEmpty);
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

        final context = AnalysisContext(
          trendState: TrendState.down,
          rangeTop: 100.0,
        );

        final data = StockData(symbol: 'TEST', prices: pricesWithBreakout);
        final result = rule.evaluate(context, data);

        expect(result, isNotNull);
        expect(result!.type, ReasonType.reversalW2S);
      });

      test('should NOT trigger when trend is already up', () {
        final prices = generateUptrendPrices(days: 30);
        final context = AnalysisContext(
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

        final context = AnalysisContext(
          trendState: TrendState.up,
          supportLevel: 100.0,
        );

        final data = StockData(symbol: 'TEST', prices: pricesWithBreakdown);
        final result = rule.evaluate(context, data);

        expect(result, isNotNull);
        expect(result!.type, ReasonType.reversalS2W);
      });

      test('should NOT trigger when trend is already down', () {
        final prices = generateDowntrendPrices(days: 30);
        final context = AnalysisContext(
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

      test('should trigger when close exceeds resistance', () {
        final prices = [createTestPrice(date: DateTime.now(), close: 105.0)];
        final context = AnalysisContext(
          trendState: TrendState.range,
          resistanceLevel: 100.0,
        );

        final data = StockData(symbol: 'TEST', prices: prices);
        final result = rule.evaluate(context, data);

        expect(result, isNotNull);
        expect(result!.type, ReasonType.techBreakout);
      });

      test('should NOT trigger when close is below resistance', () {
        final prices = [createTestPrice(date: DateTime.now(), close: 99.0)];
        final context = AnalysisContext(
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

      test('should trigger when close falls below support', () {
        final prices = [createTestPrice(date: DateTime.now(), close: 98.0)];
        final context = AnalysisContext(
          trendState: TrendState.range,
          supportLevel: 100.0,
        );

        final data = StockData(symbol: 'TEST', prices: prices);
        final result = rule.evaluate(context, data);

        expect(result, isNotNull);
        expect(result!.type, ReasonType.techBreakdown);
      });

      test('should NOT trigger when close is above support', () {
        final prices = [createTestPrice(date: DateTime.now(), close: 101.0)];
        final context = AnalysisContext(
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
        final context = AnalysisContext(trendState: TrendState.range);
        final data = StockData(symbol: 'TEST', prices: prices);

        final result = rule.evaluate(context, data);

        expect(result, isNotNull);
        expect(result!.type, ReasonType.volumeSpike);
      });

      test('should NOT trigger with low volume', () {
        final prices = generateUptrendPrices(days: 30);
        final context = AnalysisContext(trendState: TrendState.range);
        final data = StockData(symbol: 'TEST', prices: prices);

        final result = rule.evaluate(context, data);

        expect(result, isNull);
      });
    });

    group('PriceSpikeRule', () {
      const rule = PriceSpikeRule();

      test('should trigger when price moves 6%+', () {
        final prices = [
          createTestPrice(
            date: DateTime.now().subtract(const Duration(days: 1)),
            close: 100.0,
          ),
          createTestPrice(date: DateTime.now(), close: 107.0),
        ];
        final context = AnalysisContext(trendState: TrendState.range);
        final data = StockData(symbol: 'TEST', prices: prices);

        final result = rule.evaluate(context, data);

        expect(result, isNotNull);
        expect(result!.type, ReasonType.priceSpike);
      });

      test('should NOT trigger with small price change', () {
        final prices = [
          createTestPrice(
            date: DateTime.now().subtract(const Duration(days: 1)),
            close: 100.0,
          ),
          createTestPrice(date: DateTime.now(), close: 101.0),
        ];
        final context = AnalysisContext(trendState: TrendState.range);
        final data = StockData(symbol: 'TEST', prices: prices);

        final result = rule.evaluate(context, data);

        expect(result, isNull);
      });
    });

    group('InstitutionalShiftRule', () {
      const rule = InstitutionalShiftRule();

      test('should trigger when foreign investors switch to buy', () {
        final history = generateInstitutionalHistory(
          days: 15,
          prevDirection: -1000,
          todayDirection: 1000,
        );
        final context = AnalysisContext(trendState: TrendState.range);
        final data = StockData(
          symbol: 'TEST',
          prices: [],
          institutional: history,
        );

        final result = rule.evaluate(context, data);

        expect(result, isNotNull);
        expect(result!.type, ReasonType.institutionalShift);
      });

      test('should NOT trigger with insufficient history', () {
        final history = generateInstitutionalHistory(
          days: 3,
          prevDirection: -500,
          todayDirection: 500,
        );
        final context = AnalysisContext(trendState: TrendState.range);
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
        final context = AnalysisContext(trendState: TrendState.range);
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
        final context = AnalysisContext(trendState: TrendState.range);
        final data = StockData(symbol: 'TEST', prices: [], news: news);

        final result = rule.evaluate(context, data);

        expect(result, isNotNull);
        expect(result!.type, ReasonType.newsRelated);
        expect(result.description, contains('利空'));
      });

      test('should NOT trigger on old news (>24h)', () {
        final news = [
          NewsItemEntry(
            id: 'test-3',
            title: '營收創新高！',
            source: 'MoneyDJ',
            url: 'https://example.com/news/3',
            publishedAt: DateTime.now().subtract(const Duration(hours: 48)),
            fetchedAt: DateTime.now().subtract(const Duration(hours: 48)),
            category: 'EARNINGS',
          ),
        ];
        final context = AnalysisContext(trendState: TrendState.range);
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
      final data = StockData(symbol: 'TEST', prices: []);

      expect(data.latestPrice, isNull);
      expect(data.latestClose, isNull);
      expect(data.previousPrice, isNull);
      expect(data.previousClose, isNull);
    });
  });
}
