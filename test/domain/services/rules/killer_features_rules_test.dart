import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/domain/models/models.dart';
import 'package:afterclose/domain/services/rules/insider_rules.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';
import 'package:afterclose/domain/services/rules/warning_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/price_data_generators.dart';

void main() {
  group('Insider Rules', () {
    group('InsiderSellingStreakRule', () {
      const rule = InsiderSellingStreakRule();

      test('triggers when selling streak >= 3 months', () {
        const context = AnalysisContext(
          trendState: TrendState.range,
          marketData: MarketDataContext(
            insiderData: InsiderDataContext(
              hasSellingStreak: true,
              sellingStreakMonths: 3,
              insiderRatio: 25.0,
            ),
          ),
        );

        final prices = generateFlatPrices(days: 20, basePrice: 100.0);
        final data = StockData(symbol: 'TEST', prices: prices);

        final result = rule.evaluate(context, data);

        expect(result, isNotNull);
        expect(result!.type, equals(ReasonType.insiderSellingStreak));
        expect(result.score, equals(RuleScores.insiderSellingStreak));
      });

      test('does not trigger when selling streak < 3 months', () {
        const context = AnalysisContext(
          trendState: TrendState.range,
          marketData: MarketDataContext(
            insiderData: InsiderDataContext(
              hasSellingStreak: true,
              sellingStreakMonths: 2,
              insiderRatio: 25.0,
            ),
          ),
        );

        final prices = generateFlatPrices(days: 20, basePrice: 100.0);
        final data = StockData(symbol: 'TEST', prices: prices);

        final result = rule.evaluate(context, data);

        expect(result, isNull);
      });

      test('does not trigger when no selling streak', () {
        const context = AnalysisContext(
          trendState: TrendState.range,
          marketData: MarketDataContext(
            insiderData: InsiderDataContext(
              hasSellingStreak: false,
              sellingStreakMonths: 0,
              insiderRatio: 25.0,
            ),
          ),
        );

        final prices = generateFlatPrices(days: 20, basePrice: 100.0);
        final data = StockData(symbol: 'TEST', prices: prices);

        final result = rule.evaluate(context, data);

        expect(result, isNull);
      });
    });

    group('InsiderSignificantBuyingRule', () {
      const rule = InsiderSignificantBuyingRule();

      test('triggers when buying change >= 5%', () {
        const context = AnalysisContext(
          trendState: TrendState.range,
          marketData: MarketDataContext(
            insiderData: InsiderDataContext(
              hasSignificantBuying: true,
              buyingChange: 6.0,
              insiderRatio: 30.0,
            ),
          ),
        );

        final prices = generateFlatPrices(days: 20, basePrice: 100.0);
        final data = StockData(symbol: 'TEST', prices: prices);

        final result = rule.evaluate(context, data);

        expect(result, isNotNull);
        expect(result!.type, equals(ReasonType.insiderSignificantBuying));
        expect(result.score, equals(RuleScores.insiderSignificantBuying));
      });

      test('does not trigger when buying change < 5%', () {
        const context = AnalysisContext(
          trendState: TrendState.range,
          marketData: MarketDataContext(
            insiderData: InsiderDataContext(
              hasSignificantBuying: true,
              buyingChange: 3.0,
              insiderRatio: 23.0,
            ),
          ),
        );

        final prices = generateFlatPrices(days: 20, basePrice: 100.0);
        final data = StockData(symbol: 'TEST', prices: prices);

        final result = rule.evaluate(context, data);

        expect(result, isNull);
      });

      test('does not trigger when buyingChange is null', () {
        const context = AnalysisContext(
          trendState: TrendState.range,
          marketData: MarketDataContext(
            insiderData: InsiderDataContext(
              hasSignificantBuying: true,
              buyingChange: null,
              insiderRatio: 25.0,
            ),
          ),
        );

        final prices = generateFlatPrices(days: 20, basePrice: 100.0);
        final data = StockData(symbol: 'TEST', prices: prices);

        final result = rule.evaluate(context, data);

        expect(result, isNull);
      });
    });

    group('HighPledgeRatioRule', () {
      const rule = HighPledgeRatioRule();

      test('triggers when pledge ratio >= 50%', () {
        const context = AnalysisContext(
          trendState: TrendState.range,
          marketData: MarketDataContext(
            insiderData: InsiderDataContext(
              pledgeRatio: 55.0,
              insiderRatio: 20.0,
            ),
          ),
        );

        final prices = generateFlatPrices(days: 20, basePrice: 100.0);
        final data = StockData(symbol: 'TEST', prices: prices);

        final result = rule.evaluate(context, data);

        expect(result, isNotNull);
        expect(result!.type, equals(ReasonType.highPledgeRatio));
        expect(result.score, equals(RuleScores.highPledgeRatio));
      });

      test('does not trigger when pledge ratio < 50%', () {
        const context = AnalysisContext(
          trendState: TrendState.range,
          marketData: MarketDataContext(
            insiderData: InsiderDataContext(
              pledgeRatio: 40.0,
              insiderRatio: 25.0,
            ),
          ),
        );

        final prices = generateFlatPrices(days: 20, basePrice: 100.0);
        final data = StockData(symbol: 'TEST', prices: prices);

        final result = rule.evaluate(context, data);

        expect(result, isNull);
      });

      test('does not trigger when pledgeRatio is null', () {
        const context = AnalysisContext(
          trendState: TrendState.range,
          marketData: MarketDataContext(
            insiderData: InsiderDataContext(
              pledgeRatio: null,
              insiderRatio: 25.0,
            ),
          ),
        );

        final prices = generateFlatPrices(days: 20, basePrice: 100.0);
        final data = StockData(symbol: 'TEST', prices: prices);

        final result = rule.evaluate(context, data);

        expect(result, isNull);
      });
    });
  });

  group('Warning Rules', () {
    group('TradingWarningAttentionRule', () {
      const rule = TradingWarningAttentionRule();

      test('triggers when isAttention is true', () {
        const context = AnalysisContext(
          trendState: TrendState.range,
          marketData: MarketDataContext(
            warningData: WarningDataContext(
              isAttention: true,
              isDisposal: false,
              reasonDescription: '成交量異常',
            ),
          ),
        );

        final prices = generateFlatPrices(days: 20, basePrice: 100.0);
        final data = StockData(symbol: 'TEST', prices: prices);

        final result = rule.evaluate(context, data);

        expect(result, isNotNull);
        expect(result!.type, equals(ReasonType.tradingWarningAttention));
        expect(result.score, equals(RuleScores.tradingWarningAttention));
      });

      test('does not trigger when isDisposal is true', () {
        // DISPOSAL 優先於 ATTENTION
        const context = AnalysisContext(
          trendState: TrendState.range,
          marketData: MarketDataContext(
            warningData: WarningDataContext(
              isAttention: true,
              isDisposal: true,
              reasonDescription: '處置股票',
            ),
          ),
        );

        final prices = generateFlatPrices(days: 20, basePrice: 100.0);
        final data = StockData(symbol: 'TEST', prices: prices);

        final result = rule.evaluate(context, data);

        expect(result, isNull);
      });
    });

    group('TradingWarningDisposalRule', () {
      const rule = TradingWarningDisposalRule();

      test('triggers when isDisposal is true', () {
        const context = AnalysisContext(
          trendState: TrendState.range,
          marketData: MarketDataContext(
            warningData: WarningDataContext(
              isAttention: false,
              isDisposal: true,
              disposalMeasures: '分盤交易',
            ),
          ),
        );

        final prices = generateFlatPrices(days: 20, basePrice: 100.0);
        final data = StockData(symbol: 'TEST', prices: prices);

        final result = rule.evaluate(context, data);

        expect(result, isNotNull);
        expect(result!.type, equals(ReasonType.tradingWarningDisposal));
        expect(result.score, equals(RuleScores.tradingWarningDisposal));
      });

      test('does not trigger when isDisposal is false', () {
        const context = AnalysisContext(
          trendState: TrendState.range,
          marketData: MarketDataContext(
            warningData: WarningDataContext(
              isAttention: true,
              isDisposal: false,
            ),
          ),
        );

        final prices = generateFlatPrices(days: 20, basePrice: 100.0);
        final data = StockData(symbol: 'TEST', prices: prices);

        final result = rule.evaluate(context, data);

        expect(result, isNull);
      });
    });
  });

  group('Foreign Rules', () {
    group('ForeignConcentrationWarningRule', () {
      const rule = ForeignConcentrationWarningRule();

      test('triggers when foreign ratio >= 60%', () {
        const context = AnalysisContext(
          trendState: TrendState.range,
          marketData: MarketDataContext(foreignSharesRatio: 65.0),
        );

        final prices = generateFlatPrices(days: 20, basePrice: 100.0);
        final data = StockData(symbol: 'TEST', prices: prices);

        final result = rule.evaluate(context, data);

        expect(result, isNotNull);
        expect(result!.type, equals(ReasonType.foreignConcentrationWarning));
      });

      test('does not trigger when foreign ratio < 60%', () {
        const context = AnalysisContext(
          trendState: TrendState.range,
          marketData: MarketDataContext(foreignSharesRatio: 50.0),
        );

        final prices = generateFlatPrices(days: 20, basePrice: 100.0);
        final data = StockData(symbol: 'TEST', prices: prices);

        final result = rule.evaluate(context, data);

        expect(result, isNull);
      });
    });

    group('ForeignExodusRule', () {
      const rule = ForeignExodusRule();

      test('triggers when foreign ratio change <= -2%', () {
        const context = AnalysisContext(
          trendState: TrendState.range,
          marketData: MarketDataContext(
            foreignSharesRatio: 40.0,
            foreignSharesRatioChange: -2.5,
          ),
        );

        final prices = generateFlatPrices(days: 20, basePrice: 100.0);
        final data = StockData(symbol: 'TEST', prices: prices);

        final result = rule.evaluate(context, data);

        expect(result, isNotNull);
        expect(result!.type, equals(ReasonType.foreignExodus));
        expect(result.score, equals(RuleScores.foreignExodus));
      });

      test('does not trigger when foreign ratio change > -2%', () {
        const context = AnalysisContext(
          trendState: TrendState.range,
          marketData: MarketDataContext(
            foreignSharesRatio: 40.0,
            foreignSharesRatioChange: -1.0,
          ),
        );

        final prices = generateFlatPrices(days: 20, basePrice: 100.0);
        final data = StockData(symbol: 'TEST', prices: prices);

        final result = rule.evaluate(context, data);

        expect(result, isNull);
      });
    });
  });
}
