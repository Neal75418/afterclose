import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/sentinel.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/price_calculator.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/database/cached_accessor.dart';
import 'package:afterclose/domain/models/stock_summary.dart';
import 'package:afterclose/domain/services/analysis_summary_service.dart';
import 'package:afterclose/presentation/mappers/finmind_model_mapper.dart';
import 'package:afterclose/presentation/mappers/summary_localizer.dart';
import 'package:afterclose/presentation/providers/providers.dart';

// ==================================================
// Comparison State
// ==================================================

class ComparisonState {
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
    Object? error = sentinel,
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
      error: error == sentinel ? this.error : error as String?,
    );
  }
}

// ==================================================
// Comparison Notifier
// ==================================================

class ComparisonNotifier extends Notifier<ComparisonState> {
  var _active = true;

  @override
  ComparisonState build() {
    _active = true;
    ref.onDispose(() => _active = false);
    return const ComparisonState();
  }

  AppDatabase get _db => ref.read(databaseProvider);
  CachedDatabaseAccessor get _cachedDb => ref.read(cachedDbProvider);

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

    // 移除該股票的比較資料
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
      final (valuations, institutional, eps, revenue) = await (
        _db.getLatestValuationsBatch(symbols),
        _db.getInstitutionalHistoryBatch(symbols, startDate: instStartDate),
        _db.getEPSHistoryBatch(symbols),
        _db.getRecentMonthlyRevenueBatch(symbols, months: 6),
      ).wait;

      if (!_active) return;

      // 3. Generate AI summaries per stock
      const summaryService = AnalysisSummaryService();
      const localizer = SummaryLocalizer();
      final summaries = <String, StockSummary>{};
      for (final symbol in symbols) {
        final analysis = coreData.analyses[symbol];
        final reasons = coreData.reasons[symbol] ?? [];
        final latestPrice = coreData.latestPrices[symbol];
        final priceHistory = coreData.priceHistories[symbol] ?? [];

        // 將 DB Model 轉換為 API Model 供摘要服務使用
        final finMindRevenues = FinMindModelMapper.toFinMindRevenues(
          revenue[symbol] ?? [],
        );
        final finMindPER = FinMindModelMapper.toFinMindPER(valuations[symbol]);

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
    NotifierProvider.autoDispose<ComparisonNotifier, ComparisonState>(
      ComparisonNotifier.new,
    );
