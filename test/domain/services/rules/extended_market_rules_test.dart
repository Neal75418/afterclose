import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/domain/models/models.dart';
import 'package:afterclose/domain/services/rules/extended_market_rules.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/price_data_generators.dart';

void main() {
  // ==========================================
  // ForeignShareholdingIncreasingRule
  // ==========================================
  group('ForeignShareholdingIncreasingRule', () {
    const rule = ForeignShareholdingIncreasingRule();

    test('triggers when foreign shareholding increases >= threshold', () {
      final context = AnalysisContext(
        evaluationTime: DateTime(2025, 6, 1),
        trendState: TrendState.range,
        marketData: MarketDataContext(
          foreignSharesRatio: 30.0,
          foreignSharesRatioChange: 0.8, // >= 0.5
        ),
      );
      const data = StockData(symbol: 'TEST', prices: []);

      final result = rule.evaluate(context, data);

      expect(result, isNotNull);
      expect(result!.type, equals(ReasonType.foreignShareholdingIncreasing));
      expect(result.score, equals(RuleScores.foreignShareholdingIncreasing));
    });

    test('does not trigger when change is below threshold', () {
      final context = AnalysisContext(
        evaluationTime: DateTime(2025, 6, 1),
        trendState: TrendState.range,
        marketData: MarketDataContext(
          foreignSharesRatio: 30.0,
          foreignSharesRatioChange: 0.3, // < 0.5
        ),
      );
      const data = StockData(symbol: 'TEST', prices: []);

      expect(rule.evaluate(context, data), isNull);
    });

    test('does not trigger when marketData is null', () {
      final context = AnalysisContext(
        evaluationTime: DateTime(2025, 6, 1),
        trendState: TrendState.range,
      );
      const data = StockData(symbol: 'TEST', prices: []);

      expect(rule.evaluate(context, data), isNull);
    });
  });

  // ==========================================
  // ForeignShareholdingDecreasingRule
  // ==========================================
  group('ForeignShareholdingDecreasingRule', () {
    const rule = ForeignShareholdingDecreasingRule();

    test('triggers when foreign shareholding decreases >= threshold', () {
      final context = AnalysisContext(
        evaluationTime: DateTime(2025, 6, 1),
        trendState: TrendState.range,
        marketData: MarketDataContext(
          foreignSharesRatio: 25.0,
          foreignSharesRatioChange: -0.7, // <= -0.5
        ),
      );
      const data = StockData(symbol: 'TEST', prices: []);

      final result = rule.evaluate(context, data);

      expect(result, isNotNull);
      expect(result!.type, equals(ReasonType.foreignShareholdingDecreasing));
      expect(result.score, equals(RuleScores.foreignShareholdingDecreasing));
    });

    test('does not trigger when decrease is below threshold', () {
      final context = AnalysisContext(
        evaluationTime: DateTime(2025, 6, 1),
        trendState: TrendState.range,
        marketData: MarketDataContext(
          foreignSharesRatio: 25.0,
          foreignSharesRatioChange: -0.2, // > -0.5
        ),
      );
      const data = StockData(symbol: 'TEST', prices: []);

      expect(rule.evaluate(context, data), isNull);
    });

    test('does not trigger when change is null', () {
      final context = AnalysisContext(
        evaluationTime: DateTime(2025, 6, 1),
        trendState: TrendState.range,
        marketData: MarketDataContext(foreignSharesRatio: 25.0),
      );
      const data = StockData(symbol: 'TEST', prices: []);

      expect(rule.evaluate(context, data), isNull);
    });
  });

  // ==========================================
  // DayTradingHighRule
  // ==========================================
  group('DayTradingHighRule', () {
    const rule = DayTradingHighRule();

    test('triggers when day trading ratio is in high range', () {
      final context = AnalysisContext(
        evaluationTime: DateTime(2025, 6, 1),
        trendState: TrendState.range,
        marketData: MarketDataContext(dayTradingRatio: 60.0), // 50-70 range
      );
      final data = StockData(
        symbol: 'TEST',
        prices: [
          createTestPrice(
            date: DateTime.now(),
            close: 100.0,
            volume: 15000000, // > 10,000,000 (萬張)
          ),
        ],
      );

      final result = rule.evaluate(context, data);

      expect(result, isNotNull);
      expect(result!.type, equals(ReasonType.dayTradingHigh));
      expect(result.score, equals(RuleScores.dayTradingHigh));
    });

    test('does not trigger when ratio is below high threshold', () {
      final context = AnalysisContext(
        evaluationTime: DateTime(2025, 6, 1),
        trendState: TrendState.range,
        marketData: MarketDataContext(dayTradingRatio: 45.0), // < 50
      );
      final data = StockData(
        symbol: 'TEST',
        prices: [
          createTestPrice(date: DateTime.now(), close: 100.0, volume: 15000000),
        ],
      );

      expect(rule.evaluate(context, data), isNull);
    });

    test('does not trigger when ratio is at extreme level', () {
      final context = AnalysisContext(
        evaluationTime: DateTime(2025, 6, 1),
        trendState: TrendState.range,
        marketData: MarketDataContext(dayTradingRatio: 75.0), // >= 70
      );
      final data = StockData(
        symbol: 'TEST',
        prices: [
          createTestPrice(date: DateTime.now(), close: 100.0, volume: 15000000),
        ],
      );

      // DayTradingHighRule only triggers for [50, 70), extreme is handled by DayTradingExtremeRule
      expect(rule.evaluate(context, data), isNull);
    });

    test('does not trigger when volume is too low', () {
      final context = AnalysisContext(
        evaluationTime: DateTime(2025, 6, 1),
        trendState: TrendState.range,
        marketData: MarketDataContext(dayTradingRatio: 60.0),
      );
      final data = StockData(
        symbol: 'TEST',
        prices: [
          createTestPrice(
            date: DateTime.now(),
            close: 100.0,
            volume: 5000000, // < 10,000,000 (萬張)
          ),
        ],
      );

      expect(rule.evaluate(context, data), isNull);
    });
  });

  // ==========================================
  // DayTradingExtremeRule
  // ==========================================
  group('DayTradingExtremeRule', () {
    const rule = DayTradingExtremeRule();

    test('triggers when day trading ratio is extreme', () {
      final context = AnalysisContext(
        evaluationTime: DateTime(2025, 6, 1),
        trendState: TrendState.range,
        marketData: MarketDataContext(dayTradingRatio: 75.0), // >= 70
      );
      final data = StockData(
        symbol: 'TEST',
        prices: [
          createTestPrice(
            date: DateTime.now(),
            close: 100.0,
            volume: 35000000, // > 30,000,000 (3 萬張)
          ),
        ],
      );

      final result = rule.evaluate(context, data);

      expect(result, isNotNull);
      expect(result!.type, equals(ReasonType.dayTradingExtreme));
      expect(result.score, equals(RuleScores.dayTradingExtreme));
    });

    test('does not trigger below extreme threshold', () {
      final context = AnalysisContext(
        evaluationTime: DateTime(2025, 6, 1),
        trendState: TrendState.range,
        marketData: MarketDataContext(dayTradingRatio: 65.0), // < 70
      );
      final data = StockData(
        symbol: 'TEST',
        prices: [
          createTestPrice(date: DateTime.now(), close: 100.0, volume: 35000000),
        ],
      );

      expect(rule.evaluate(context, data), isNull);
    });

    test('does not trigger when volume is too low', () {
      final context = AnalysisContext(
        evaluationTime: DateTime(2025, 6, 1),
        trendState: TrendState.range,
        marketData: MarketDataContext(dayTradingRatio: 75.0), // >= 70
      );
      final data = StockData(
        symbol: 'TEST',
        prices: [
          createTestPrice(
            date: DateTime.now(),
            close: 100.0,
            volume: 20000000, // < 30,000,000 (3 萬張)
          ),
        ],
      );

      expect(rule.evaluate(context, data), isNull);
    });
  });

  // ==========================================
  // ConcentrationHighRule
  // ==========================================
  group('ConcentrationHighRule', () {
    const rule = ConcentrationHighRule();

    test('triggers when concentration ratio >= threshold', () {
      final context = AnalysisContext(
        evaluationTime: DateTime(2025, 6, 1),
        trendState: TrendState.range,
        marketData: MarketDataContext(concentrationRatio: 75.0), // >= 60
      );
      const data = StockData(symbol: 'TEST', prices: []);

      final result = rule.evaluate(context, data);

      expect(result, isNotNull);
      expect(result!.type, equals(ReasonType.concentrationHigh));
      expect(result.score, equals(RuleScores.concentrationHigh));
    });

    test('does not trigger below threshold', () {
      final context = AnalysisContext(
        evaluationTime: DateTime(2025, 6, 1),
        trendState: TrendState.range,
        marketData: MarketDataContext(concentrationRatio: 55.0), // < 60
      );
      const data = StockData(symbol: 'TEST', prices: []);

      expect(rule.evaluate(context, data), isNull);
    });

    test('does not trigger when concentration ratio is null', () {
      final context = AnalysisContext(
        evaluationTime: DateTime(2025, 6, 1),
        trendState: TrendState.range,
        marketData: MarketDataContext(),
      );
      const data = StockData(symbol: 'TEST', prices: []);

      expect(rule.evaluate(context, data), isNull);
    });

    test('triggers at exact threshold (60%)', () {
      final context = AnalysisContext(
        evaluationTime: DateTime(2025, 6, 1),
        trendState: TrendState.range,
        marketData: MarketDataContext(
          concentrationRatio:
              InstitutionalParams.concentrationHighThreshold, // 60.0
        ),
      );
      const data = StockData(symbol: 'TEST', prices: []);

      final result = rule.evaluate(context, data);

      expect(result, isNotNull);
      expect(result!.type, equals(ReasonType.concentrationHigh));
    });
  });

  // ==========================================
  // 邊界/null 測試補充
  // ==========================================

  group('DayTradingHighRule Edge Cases', () {
    const rule = DayTradingHighRule();

    test('returns null when dayTradingRatio is null', () {
      final context = AnalysisContext(
        evaluationTime: DateTime(2025, 6, 1),
        trendState: TrendState.range,
        marketData: MarketDataContext(dayTradingRatio: null),
      );
      final data = StockData(
        symbol: 'TEST',
        prices: [
          createTestPrice(date: DateTime.now(), close: 100.0, volume: 15000000),
        ],
      );

      expect(rule.evaluate(context, data), isNull);
    });

    test('returns null when prices are empty', () {
      final context = AnalysisContext(
        evaluationTime: DateTime(2025, 6, 1),
        trendState: TrendState.range,
        marketData: MarketDataContext(dayTradingRatio: 60.0),
      );
      const data = StockData(symbol: 'TEST', prices: []);

      expect(rule.evaluate(context, data), isNull);
    });

    test('triggers at exact 50% threshold', () {
      final context = AnalysisContext(
        evaluationTime: DateTime(2025, 6, 1),
        trendState: TrendState.range,
        marketData: MarketDataContext(
          dayTradingRatio: InstitutionalParams.dayTradingHighThreshold, // 50.0
        ),
      );
      final data = StockData(
        symbol: 'TEST',
        prices: [
          createTestPrice(date: DateTime.now(), close: 100.0, volume: 15000000),
        ],
      );

      final result = rule.evaluate(context, data);

      expect(result, isNotNull);
      expect(result!.type, equals(ReasonType.dayTradingHigh));
    });

    test('returns null when volume is null', () {
      final context = AnalysisContext(
        evaluationTime: DateTime(2025, 6, 1),
        trendState: TrendState.range,
        marketData: MarketDataContext(dayTradingRatio: 60.0),
      );
      final data = StockData(
        symbol: 'TEST',
        prices: [
          createTestPrice(date: DateTime.now(), close: 100.0, volume: null),
        ],
      );

      expect(rule.evaluate(context, data), isNull);
    });
  });

  group('DayTradingExtremeRule Edge Cases', () {
    const rule = DayTradingExtremeRule();

    test('returns null when dayTradingRatio is null', () {
      final context = AnalysisContext(
        evaluationTime: DateTime(2025, 6, 1),
        trendState: TrendState.range,
        marketData: MarketDataContext(dayTradingRatio: null),
      );
      final data = StockData(
        symbol: 'TEST',
        prices: [
          createTestPrice(date: DateTime.now(), close: 100.0, volume: 35000000),
        ],
      );

      expect(rule.evaluate(context, data), isNull);
    });

    test('triggers at exact 70% threshold', () {
      final context = AnalysisContext(
        evaluationTime: DateTime(2025, 6, 1),
        trendState: TrendState.range,
        marketData: MarketDataContext(
          dayTradingRatio:
              InstitutionalParams.dayTradingExtremeThreshold, // 70.0
        ),
      );
      final data = StockData(
        symbol: 'TEST',
        prices: [
          createTestPrice(date: DateTime.now(), close: 100.0, volume: 35000000),
        ],
      );

      final result = rule.evaluate(context, data);

      expect(result, isNotNull);
      expect(result!.type, equals(ReasonType.dayTradingExtreme));
    });
  });
}
