import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/stock_summary.dart';
import 'package:afterclose/presentation/providers/stock_detail_state.dart';

void main() {
  final defaultDate = DateTime(2026, 2, 13);

  // ==================================================
  // StockPriceState
  // ==================================================

  group('StockPriceState', () {
    test('default values', () {
      const state = StockPriceState();
      expect(state.stock, isNull);
      expect(state.latestPrice, isNull);
      expect(state.previousPrice, isNull);
      expect(state.priceHistory, isEmpty);
      expect(state.analysis, isNull);
    });

    test('priceChange returns null when latestPrice is null', () {
      const state = StockPriceState();
      expect(state.priceChange, isNull);
    });

    test('priceChange delegates to PriceCalculator', () {
      final yesterday = DailyPriceEntry(
        symbol: '2330',
        date: defaultDate.subtract(const Duration(days: 1)),
        close: 500.0,
        volume: 10000,
      );
      final today = DailyPriceEntry(
        symbol: '2330',
        date: defaultDate,
        close: 550.0,
        volume: 20000,
      );
      final state = StockPriceState(
        latestPrice: today,
        priceHistory: [yesterday, today],
      );
      // (550-500)/500 * 100 = 10.0
      expect(state.priceChange, closeTo(10.0, 0.01));
    });

    test('copyWith updates stock', () {
      const state = StockPriceState();
      final stock = StockMasterEntry(
        symbol: '2330',
        name: '台積電',
        market: 'TWSE',
        isActive: true,
        updatedAt: defaultDate,
      );
      final updated = state.copyWith(stock: stock);
      expect(updated.stock?.symbol, '2330');
      expect(updated.latestPrice, isNull);
    });

    test('copyWith updates latestPrice', () {
      const state = StockPriceState();
      final price = DailyPriceEntry(
        symbol: '2330',
        date: defaultDate,
        close: 600.0,
        volume: 50000,
      );
      final updated = state.copyWith(latestPrice: price);
      expect(updated.latestPrice?.close, 600.0);
    });

    test('copyWith updates previousPrice', () {
      const state = StockPriceState();
      final price = DailyPriceEntry(
        symbol: '2330',
        date: defaultDate,
        close: 580.0,
        volume: 40000,
      );
      final updated = state.copyWith(previousPrice: price);
      expect(updated.previousPrice?.close, 580.0);
    });

    test('copyWith updates priceHistory', () {
      const state = StockPriceState();
      final history = [
        DailyPriceEntry(
          symbol: '2330',
          date: defaultDate,
          close: 600.0,
          volume: 50000,
        ),
      ];
      final updated = state.copyWith(priceHistory: history);
      expect(updated.priceHistory, hasLength(1));
    });

    test('copyWith updates analysis', () {
      const state = StockPriceState();
      final analysis = DailyAnalysisEntry(
        symbol: '2330',
        date: defaultDate,
        score: 80.0,
        trendState: 'UP',
        reversalState: '',
        computedAt: defaultDate,
      );
      final updated = state.copyWith(analysis: analysis);
      expect(updated.analysis?.score, 80.0);
    });

    test('copyWith preserves unmodified fields', () {
      final stock = StockMasterEntry(
        symbol: '2330',
        name: '台積電',
        market: 'TWSE',
        isActive: true,
        updatedAt: defaultDate,
      );
      final state = StockPriceState(stock: stock);
      final analysis = DailyAnalysisEntry(
        symbol: '2330',
        date: defaultDate,
        score: 90.0,
        trendState: 'UP',
        reversalState: '',
        computedAt: defaultDate,
      );
      final updated = state.copyWith(analysis: analysis);
      expect(updated.stock?.symbol, '2330');
      expect(updated.analysis?.score, 90.0);
    });
  });

  // ==================================================
  // FundamentalsState
  // ==================================================

  group('FundamentalsState', () {
    test('default values', () {
      const state = FundamentalsState();
      expect(state.revenueHistory, isEmpty);
      expect(state.dividendHistory, isEmpty);
      expect(state.latestPER, isNull);
      expect(state.latestQuarterMetrics, isEmpty);
      expect(state.epsHistory, isEmpty);
    });

    test('copyWith updates revenueHistory', () {
      const state = FundamentalsState();
      final updated = state.copyWith(revenueHistory: []);
      expect(updated.revenueHistory, isEmpty);
    });

    test('copyWith updates latestQuarterMetrics', () {
      const state = FundamentalsState();
      final updated = state.copyWith(
        latestQuarterMetrics: {'ROE': 25.0, 'ROA': 12.0},
      );
      expect(updated.latestQuarterMetrics, hasLength(2));
      expect(updated.latestQuarterMetrics['ROE'], 25.0);
    });

    test('copyWith preserves unmodified fields', () {
      final state = const FundamentalsState().copyWith(
        latestQuarterMetrics: {'ROE': 25.0},
      );
      final updated = state.copyWith(epsHistory: []);
      expect(updated.latestQuarterMetrics['ROE'], 25.0);
      expect(updated.epsHistory, isEmpty);
    });
  });

  // ==================================================
  // ChipAnalysisState
  // ==================================================

  group('ChipAnalysisState', () {
    test('default values', () {
      const state = ChipAnalysisState();
      expect(state.institutionalHistory, isEmpty);
      expect(state.marginHistory, isEmpty);
      expect(state.marginTradingHistory, isEmpty);
      expect(state.dayTradingHistory, isEmpty);
      expect(state.shareholdingHistory, isEmpty);
      expect(state.holdingDistribution, isEmpty);
      expect(state.insiderHistory, isEmpty);
      expect(state.chipStrength, isNull);
      expect(state.hasInstitutionalError, isFalse);
    });

    test('copyWith updates hasInstitutionalError', () {
      const state = ChipAnalysisState();
      final updated = state.copyWith(hasInstitutionalError: true);
      expect(updated.hasInstitutionalError, isTrue);
    });

    test('copyWith updates insiderHistory', () {
      const state = ChipAnalysisState();
      final updated = state.copyWith(insiderHistory: []);
      expect(updated.insiderHistory, isEmpty);
    });

    test('copyWith preserves unmodified fields', () {
      final state = const ChipAnalysisState().copyWith(
        hasInstitutionalError: true,
      );
      final updated = state.copyWith(insiderHistory: []);
      expect(updated.hasInstitutionalError, isTrue);
      expect(updated.insiderHistory, isEmpty);
    });
  });

  // ==================================================
  // LoadingState
  // ==================================================

  group('LoadingState', () {
    test('default values — all false', () {
      const state = LoadingState();
      expect(state.isLoading, isFalse);
      expect(state.isLoadingMargin, isFalse);
      expect(state.isLoadingFundamentals, isFalse);
      expect(state.isLoadingInsider, isFalse);
      expect(state.isLoadingChip, isFalse);
    });

    test('copyWith updates isLoading', () {
      const state = LoadingState();
      final updated = state.copyWith(isLoading: true);
      expect(updated.isLoading, isTrue);
      expect(updated.isLoadingMargin, isFalse);
    });

    test('copyWith updates isLoadingMargin', () {
      const state = LoadingState();
      final updated = state.copyWith(isLoadingMargin: true);
      expect(updated.isLoadingMargin, isTrue);
    });

    test('copyWith updates isLoadingFundamentals', () {
      const state = LoadingState();
      final updated = state.copyWith(isLoadingFundamentals: true);
      expect(updated.isLoadingFundamentals, isTrue);
    });

    test('copyWith updates isLoadingInsider', () {
      const state = LoadingState();
      final updated = state.copyWith(isLoadingInsider: true);
      expect(updated.isLoadingInsider, isTrue);
    });

    test('copyWith updates isLoadingChip', () {
      const state = LoadingState();
      final updated = state.copyWith(isLoadingChip: true);
      expect(updated.isLoadingChip, isTrue);
    });

    test('copyWith preserves unmodified fields', () {
      final state = const LoadingState().copyWith(
        isLoading: true,
        isLoadingMargin: true,
      );
      final updated = state.copyWith(isLoadingChip: true);
      expect(updated.isLoading, isTrue);
      expect(updated.isLoadingMargin, isTrue);
      expect(updated.isLoadingChip, isTrue);
      expect(updated.isLoadingFundamentals, isFalse);
    });
  });

  // ==================================================
  // StockDetailState
  // ==================================================

  group('StockDetailState', () {
    test('default values', () {
      const state = StockDetailState();
      expect(state.isInWatchlist, isFalse);
      expect(state.error, isNull);
      expect(state.dataDate, isNull);
      expect(state.hasDataMismatch, isFalse);
      expect(state.reasons, isEmpty);
      expect(state.aiSummary, isNull);
      expect(state.recentNews, isEmpty);
    });

    // Convenience getters
    test('priceChange delegates to price sub-state', () {
      const state = StockDetailState();
      expect(state.priceChange, isNull);
    });

    test('stockName returns stock name', () {
      final stock = StockMasterEntry(
        symbol: '2330',
        name: '台積電',
        market: 'TWSE',
        isActive: true,
        updatedAt: defaultDate,
      );
      final state = const StockDetailState().copyWith(stock: stock);
      expect(state.stockName, '台積電');
    });

    test('stockName returns null when stock is null', () {
      const state = StockDetailState();
      expect(state.stockName, isNull);
    });

    test('stockMarket returns market', () {
      final stock = StockMasterEntry(
        symbol: '2330',
        name: '台積電',
        market: 'TWSE',
        isActive: true,
        updatedAt: defaultDate,
      );
      final state = const StockDetailState().copyWith(stock: stock);
      expect(state.stockMarket, 'TWSE');
    });

    test('stockIndustry returns industry', () {
      final stock = StockMasterEntry(
        symbol: '2330',
        name: '台積電',
        market: 'TWSE',
        isActive: true,
        updatedAt: defaultDate,
        industry: '半導體業',
      );
      final state = const StockDetailState().copyWith(stock: stock);
      expect(state.stockIndustry, '半導體業');
    });

    test('latestClose returns close price', () {
      final price = DailyPriceEntry(
        symbol: '2330',
        date: defaultDate,
        close: 600.0,
        volume: 50000,
      );
      final state = const StockDetailState().copyWith(latestPrice: price);
      expect(state.latestClose, 600.0);
    });

    test('latestClose returns null when no latestPrice', () {
      const state = StockDetailState();
      expect(state.latestClose, isNull);
    });

    test('trendLabel returns label for UP', () {
      final analysis = DailyAnalysisEntry(
        symbol: '2330',
        date: defaultDate,
        score: 80.0,
        trendState: 'UP',
        reversalState: '',
        computedAt: defaultDate,
      );
      final state = const StockDetailState().copyWith(analysis: analysis);
      expect(state.trendLabel, isNotEmpty);
    });

    test('trendLabel returns sideways for null', () {
      const state = StockDetailState();
      expect(state.trendLabel, isNotEmpty);
    });

    test('reversalLabel returns null for empty reversalState', () {
      final analysis = DailyAnalysisEntry(
        symbol: '2330',
        date: defaultDate,
        score: 80.0,
        trendState: 'UP',
        reversalState: '',
        computedAt: defaultDate,
      );
      final state = const StockDetailState().copyWith(analysis: analysis);
      expect(state.reversalLabel, isNull);
    });

    test('reversalLabel returns label for W2S', () {
      final analysis = DailyAnalysisEntry(
        symbol: '2330',
        date: defaultDate,
        score: 80.0,
        trendState: 'UP',
        reversalState: 'W2S',
        computedAt: defaultDate,
      );
      final state = const StockDetailState().copyWith(analysis: analysis);
      expect(state.reversalLabel, isNotNull);
    });

    // copyWith — price sub-state
    test('copyWith updates stock through price sub-state', () {
      final stock = StockMasterEntry(
        symbol: '2330',
        name: '台積電',
        market: 'TWSE',
        isActive: true,
        updatedAt: defaultDate,
      );
      final state = const StockDetailState().copyWith(stock: stock);
      expect(state.price.stock?.symbol, '2330');
    });

    test('copyWith updates latestPrice through price sub-state', () {
      final price = DailyPriceEntry(
        symbol: '2330',
        date: defaultDate,
        close: 600.0,
        volume: 50000,
      );
      final state = const StockDetailState().copyWith(latestPrice: price);
      expect(state.price.latestPrice?.close, 600.0);
    });

    // copyWith — fundamentals sub-state
    test('copyWith updates latestQuarterMetrics', () {
      final state = const StockDetailState().copyWith(
        latestQuarterMetrics: {'ROE': 25.0},
      );
      expect(state.fundamentals.latestQuarterMetrics['ROE'], 25.0);
    });

    // copyWith — chip sub-state
    test('copyWith updates hasInstitutionalError', () {
      final state = const StockDetailState().copyWith(
        hasInstitutionalError: true,
      );
      expect(state.chip.hasInstitutionalError, isTrue);
    });

    // copyWith — loading sub-state
    test('copyWith updates isLoading', () {
      final state = const StockDetailState().copyWith(isLoading: true);
      expect(state.loading.isLoading, isTrue);
    });

    test('copyWith updates isLoadingMargin', () {
      final state = const StockDetailState().copyWith(isLoadingMargin: true);
      expect(state.loading.isLoadingMargin, isTrue);
    });

    test('copyWith updates isLoadingFundamentals', () {
      final state = const StockDetailState().copyWith(
        isLoadingFundamentals: true,
      );
      expect(state.loading.isLoadingFundamentals, isTrue);
    });

    test('copyWith updates isLoadingInsider', () {
      final state = const StockDetailState().copyWith(isLoadingInsider: true);
      expect(state.loading.isLoadingInsider, isTrue);
    });

    test('copyWith updates isLoadingChip', () {
      final state = const StockDetailState().copyWith(isLoadingChip: true);
      expect(state.loading.isLoadingChip, isTrue);
    });

    // copyWith — direct fields
    test('copyWith updates isInWatchlist', () {
      final state = const StockDetailState().copyWith(isInWatchlist: true);
      expect(state.isInWatchlist, isTrue);
    });

    test('copyWith updates error', () {
      final state = const StockDetailState().copyWith(error: 'Network error');
      expect(state.error, 'Network error');
    });

    test('copyWith clears error with null', () {
      final state = const StockDetailState().copyWith(error: 'Some error');
      final cleared = state.copyWith(error: null);
      expect(cleared.error, isNull);
    });

    test('copyWith preserves error when not passed (sentinel)', () {
      final state = const StockDetailState().copyWith(error: 'Existing error');
      final updated = state.copyWith(isInWatchlist: true);
      expect(updated.error, 'Existing error');
    });

    test('copyWith updates dataDate', () {
      final state = const StockDetailState().copyWith(dataDate: defaultDate);
      expect(state.dataDate, defaultDate);
    });

    test('copyWith updates hasDataMismatch', () {
      final state = const StockDetailState().copyWith(hasDataMismatch: true);
      expect(state.hasDataMismatch, isTrue);
    });

    test('copyWith updates reasons', () {
      final reasons = [
        DailyReasonEntry(
          symbol: '2330',
          date: defaultDate,
          rank: 1,
          reasonType: 'BREAKOUT',
          evidenceJson: '{}',
          ruleScore: 10.0,
        ),
      ];
      final state = const StockDetailState().copyWith(reasons: reasons);
      expect(state.reasons, hasLength(1));
    });

    test('copyWith updates aiSummary', () {
      const summary = StockSummary(
        overallAssessment: 'Bullish',
        sentiment: SummarySentiment.bullish,
      );
      final state = const StockDetailState().copyWith(aiSummary: summary);
      expect(state.aiSummary?.sentiment, SummarySentiment.bullish);
    });

    test('copyWith updates recentNews', () {
      final state = const StockDetailState().copyWith(recentNews: []);
      expect(state.recentNews, isEmpty);
    });

    // copyWith — sub-state skipping optimization
    test('copyWith skips price rebuild when no price fields changed', () {
      final stock = StockMasterEntry(
        symbol: '2330',
        name: '台積電',
        market: 'TWSE',
        isActive: true,
        updatedAt: defaultDate,
      );
      final state = const StockDetailState().copyWith(stock: stock);
      // Update only a direct field — price sub-state should be same reference
      final updated = state.copyWith(isInWatchlist: true);
      expect(identical(state.price, updated.price), isTrue);
    });

    test(
      'copyWith skips fundamentals rebuild when no fundamentals fields changed',
      () {
        final state = const StockDetailState().copyWith(
          latestQuarterMetrics: {'ROE': 25.0},
        );
        final updated = state.copyWith(isInWatchlist: true);
        expect(identical(state.fundamentals, updated.fundamentals), isTrue);
      },
    );

    test('copyWith skips chip rebuild when no chip fields changed', () {
      final state = const StockDetailState().copyWith(
        hasInstitutionalError: true,
      );
      final updated = state.copyWith(isInWatchlist: true);
      expect(identical(state.chip, updated.chip), isTrue);
    });

    test('copyWith skips loading rebuild when no loading fields changed', () {
      final state = const StockDetailState().copyWith(isLoading: true);
      final updated = state.copyWith(isInWatchlist: true);
      expect(identical(state.loading, updated.loading), isTrue);
    });

    // Combined update across multiple sub-states
    test('copyWith updates multiple sub-states at once', () {
      final stock = StockMasterEntry(
        symbol: '2330',
        name: '台積電',
        market: 'TWSE',
        isActive: true,
        updatedAt: defaultDate,
      );
      final state = const StockDetailState().copyWith(
        stock: stock,
        latestQuarterMetrics: {'ROE': 25.0},
        hasInstitutionalError: true,
        isLoading: true,
        isInWatchlist: true,
        error: 'test',
      );
      expect(state.price.stock?.symbol, '2330');
      expect(state.fundamentals.latestQuarterMetrics['ROE'], 25.0);
      expect(state.chip.hasInstitutionalError, isTrue);
      expect(state.loading.isLoading, isTrue);
      expect(state.isInWatchlist, isTrue);
      expect(state.error, 'test');
    });
  });
}
