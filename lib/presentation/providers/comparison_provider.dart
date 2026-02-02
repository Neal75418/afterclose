import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/price_calculator.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/database/cached_accessor.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/domain/models/stock_summary.dart';
import 'package:afterclose/domain/services/analysis_summary_service.dart';
import 'package:afterclose/presentation/mappers/summary_localizer.dart';
import 'package:afterclose/presentation/providers/providers.dart';

// ==================================================
// Comparison State
// ==================================================

class ComparisonState {
  static const _sentinel = Object();
  const ComparisonState({
    this.symbols = const [],
    this.stocksMap = const {},
    this.latestPricesMap = const {},
    this.priceHistoriesMap = const {},
    this.analysesMap = const {},
    this.reasonsMap = const {},
    this.valuationsMap = const {},
    this.institutionalMap = const {},
    this.epsMap = const {},
    this.revenueMap = const {},
    this.summariesMap = const {},
    this.isLoading = false,
    this.error,
  });

  final List<String> symbols;
  final Map<String, StockMasterEntry> stocksMap;
  final Map<String, DailyPriceEntry> latestPricesMap;
  final Map<String, List<DailyPriceEntry>> priceHistoriesMap;
  final Map<String, DailyAnalysisEntry> analysesMap;
  final Map<String, List<DailyReasonEntry>> reasonsMap;
  final Map<String, StockValuationEntry> valuationsMap;
  final Map<String, List<DailyInstitutionalEntry>> institutionalMap;
  final Map<String, List<FinancialDataEntry>> epsMap;
  final Map<String, List<MonthlyRevenueEntry>> revenueMap;
  final Map<String, StockSummary> summariesMap;
  final bool isLoading;
  final String? error;

  int get stockCount => symbols.length;
  bool get canAddMore => symbols.length < 4;
  bool get hasEnoughToCompare => symbols.length >= 2;

  ComparisonState copyWith({
    List<String>? symbols,
    Map<String, StockMasterEntry>? stocksMap,
    Map<String, DailyPriceEntry>? latestPricesMap,
    Map<String, List<DailyPriceEntry>>? priceHistoriesMap,
    Map<String, DailyAnalysisEntry>? analysesMap,
    Map<String, List<DailyReasonEntry>>? reasonsMap,
    Map<String, StockValuationEntry>? valuationsMap,
    Map<String, List<DailyInstitutionalEntry>>? institutionalMap,
    Map<String, List<FinancialDataEntry>>? epsMap,
    Map<String, List<MonthlyRevenueEntry>>? revenueMap,
    Map<String, StockSummary>? summariesMap,
    bool? isLoading,
    Object? error = _sentinel,
  }) {
    return ComparisonState(
      symbols: symbols ?? this.symbols,
      stocksMap: stocksMap ?? this.stocksMap,
      latestPricesMap: latestPricesMap ?? this.latestPricesMap,
      priceHistoriesMap: priceHistoriesMap ?? this.priceHistoriesMap,
      analysesMap: analysesMap ?? this.analysesMap,
      reasonsMap: reasonsMap ?? this.reasonsMap,
      valuationsMap: valuationsMap ?? this.valuationsMap,
      institutionalMap: institutionalMap ?? this.institutionalMap,
      epsMap: epsMap ?? this.epsMap,
      revenueMap: revenueMap ?? this.revenueMap,
      summariesMap: summariesMap ?? this.summariesMap,
      isLoading: isLoading ?? this.isLoading,
      error: error == _sentinel ? this.error : error as String?,
    );
  }
}

// ==================================================
// Comparison Notifier
// ==================================================

class ComparisonNotifier extends StateNotifier<ComparisonState> {
  ComparisonNotifier(this._ref) : super(const ComparisonState());

  final Ref _ref;

  AppDatabase get _db => _ref.read(databaseProvider);
  CachedDatabaseAccessor get _cachedDb => _ref.read(cachedDbProvider);

  /// Add a stock and reload all comparison data.
  Future<void> addStock(String symbol) async {
    if (state.symbols.contains(symbol) || !state.canAddMore) return;

    final newSymbols = [...state.symbols, symbol];
    state = state.copyWith(symbols: newSymbols, isLoading: true);
    await _loadAllData(newSymbols);
  }

  /// Add multiple stocks at once (used for initial load to avoid race conditions).
  Future<void> addStocks(List<String> symbols) async {
    final unique = <String>[];
    for (final s in symbols) {
      if (!unique.contains(s) && unique.length < 4) {
        unique.add(s);
      }
    }
    if (unique.isEmpty) return;

    state = state.copyWith(symbols: unique, isLoading: true);
    await _loadAllData(unique);
  }

  /// Remove a stock and reload data.
  void removeStock(String symbol) {
    final newSymbols = state.symbols.where((s) => s != symbol).toList();

    // Remove data for the removed symbol
    final newStocks = Map<String, StockMasterEntry>.from(state.stocksMap)
      ..remove(symbol);
    final newPrices = Map<String, DailyPriceEntry>.from(state.latestPricesMap)
      ..remove(symbol);
    final newHistories = Map<String, List<DailyPriceEntry>>.from(
      state.priceHistoriesMap,
    )..remove(symbol);
    final newAnalyses = Map<String, DailyAnalysisEntry>.from(state.analysesMap)
      ..remove(symbol);
    final newReasons = Map<String, List<DailyReasonEntry>>.from(
      state.reasonsMap,
    )..remove(symbol);
    final newValuations = Map<String, StockValuationEntry>.from(
      state.valuationsMap,
    )..remove(symbol);
    final newInst = Map<String, List<DailyInstitutionalEntry>>.from(
      state.institutionalMap,
    )..remove(symbol);
    final newEps = Map<String, List<FinancialDataEntry>>.from(state.epsMap)
      ..remove(symbol);
    final newRevenue = Map<String, List<MonthlyRevenueEntry>>.from(
      state.revenueMap,
    )..remove(symbol);
    final newSummaries = Map<String, StockSummary>.from(state.summariesMap)
      ..remove(symbol);

    state = state.copyWith(
      symbols: newSymbols,
      stocksMap: newStocks,
      latestPricesMap: newPrices,
      priceHistoriesMap: newHistories,
      analysesMap: newAnalyses,
      reasonsMap: newReasons,
      valuationsMap: newValuations,
      institutionalMap: newInst,
      epsMap: newEps,
      revenueMap: newRevenue,
      summariesMap: newSummaries,
    );
  }

  /// Load all comparison data for the given symbols.
  Future<void> _loadAllData(List<String> symbols) async {
    try {
      final dateCtx = DateContext.now(historyDays: 90);

      // 使用資料庫最新價格日期，確保盤前/非交易日也能顯示上次分析結果
      final latestDataDate = await _db.getLatestDataDate();
      final analysisDate = latestDataDate != null
          ? DateContext.normalize(latestDataDate)
          : dateCtx.today;

      // 1. Core data via cached batch query
      final coreData = await _cachedDb.loadStockListData(
        symbols: symbols,
        analysisDate: analysisDate,
        historyStart: dateCtx.historyStart,
      );

      // 2. Additional data in parallel
      final instStartDate = dateCtx.today.subtract(const Duration(days: 10));
      final results = await Future.wait([
        _db.getLatestValuationsBatch(symbols),
        _db.getInstitutionalHistoryBatch(symbols, startDate: instStartDate),
        _db.getEPSHistoryBatch(symbols),
        _db.getRecentMonthlyRevenueBatch(symbols, months: 6),
      ]);

      final valuations = results[0] as Map<String, StockValuationEntry>;
      final institutional =
          results[1] as Map<String, List<DailyInstitutionalEntry>>;
      final eps = results[2] as Map<String, List<FinancialDataEntry>>;
      final revenue = results[3] as Map<String, List<MonthlyRevenueEntry>>;

      // 3. Generate AI summaries per stock
      const summaryService = AnalysisSummaryService();
      const localizer = SummaryLocalizer();
      final summaries = <String, StockSummary>{};
      for (final symbol in symbols) {
        final analysis = coreData.analyses[symbol];
        final reasons = coreData.reasons[symbol] ?? [];
        final latestPrice = coreData.latestPrices[symbol];
        final priceHistory = coreData.priceHistories[symbol] ?? [];

        // Convert DB models to API models for summary service
        final revenueEntries = revenue[symbol] ?? [];
        final finMindRevenues = revenueEntries
            .map(
              (r) => FinMindRevenue(
                stockId: r.symbol,
                date: r.date.toIso8601String().substring(0, 10),
                revenue: r.revenue,
                revenueMonth: r.revenueMonth,
                revenueYear: r.revenueYear,
                momGrowth: r.momGrowth,
                yoyGrowth: r.yoyGrowth,
              ),
            )
            .toList();

        final valuation = valuations[symbol];
        final finMindPER = valuation != null
            ? FinMindPER(
                stockId: valuation.symbol,
                date: valuation.date.toIso8601String().substring(0, 10),
                per: valuation.per ?? 0,
                pbr: valuation.pbr ?? 0,
                dividendYield: valuation.dividendYield ?? 0,
              )
            : null;

        final summaryData = summaryService.generate(
          analysis: analysis,
          reasons: reasons,
          latestPrice: latestPrice,
          priceChange: PriceCalculator.calculatePriceChange(
            priceHistory,
            latestPrice,
          ),
          institutionalHistory: institutional[symbol] ?? [],
          revenueHistory: finMindRevenues,
          latestPER: finMindPER,
        );
        summaries[symbol] = localizer.localize(summaryData);
      }

      state = state.copyWith(
        stocksMap: coreData.stocks,
        latestPricesMap: coreData.latestPrices,
        priceHistoriesMap: coreData.priceHistories,
        analysesMap: coreData.analyses,
        reasonsMap: coreData.reasons,
        valuationsMap: valuations,
        institutionalMap: institutional,
        epsMap: eps,
        revenueMap: revenue,
        summariesMap: summaries,
        isLoading: false,
      );
    } catch (e) {
      AppLogger.warning('Comparison', '載入比較資料失敗', e);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

// ==================================================
// Provider
// ==================================================

final comparisonProvider =
    StateNotifierProvider.autoDispose<ComparisonNotifier, ComparisonState>(
      (ref) => ComparisonNotifier(ref),
    );
