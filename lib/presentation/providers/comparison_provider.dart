import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/constants/calibrated_scores/horizon.dart';
import 'package:afterclose/core/constants/data_freshness.dart';
import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/error_display.dart';
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
import 'package:afterclose/presentation/providers/selected_horizon_provider.dart';

// ==================================================
// 比較狀態
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
// 比較 Notifier
// ==================================================

class ComparisonNotifier extends Notifier<ComparisonState> {
  var _active = true;

  /// Generation token：每次啟動 _loadAllData 遞增，
  /// 載入完成時若 generation 已過期（有更新的載入），放棄寫入。
  int _loadGeneration = 0;

  @override
  ComparisonState build() {
    _active = true;
    _loadGeneration = 0;
    ref.onDispose(() => _active = false);

    // Stage 5c dual-horizon：切換 horizon 時重新生成所有 summary，保留
    // 其他已載入資料（stocksMap / priceHistoriesMap / institutionalMap...）
    // 不動。Command-based reload 模式，避免整個 notifier rebuild 把大量
    // batch-loaded data 清空。
    ref.listen<Horizon>(selectedHorizonProvider, (prev, next) {
      if (prev == next) return;
      if (!_active) return;
      if (state.symbols.isEmpty) return;
      _regenerateAllSummaries();
    });

    return const ComparisonState();
  }

  AppDatabase get _db => ref.read(databaseProvider);
  CachedDatabaseAccessor get _cachedDb => ref.read(cachedDbProvider);

  /// 新增股票並重新載入所有比較資料。
  ///
  /// 失敗時回滾新增的 symbol，避免佔用名額且無資料。
  Future<void> addStock(String symbol) async {
    if (state.symbols.contains(symbol) || !state.canAddMore) return;

    final oldSymbols = state.symbols;
    final newSymbols = [...oldSymbols, symbol];
    state = state.copyWith(symbols: newSymbols, isLoading: true, error: null);
    await _loadAllData(newSymbols);

    // _loadAllData 失敗時會設定 error，回滾新增的 symbol
    if (state.error != null) {
      state = state.copyWith(symbols: oldSymbols);
    }
  }

  /// 一次新增多檔股票（用於初始載入，避免 race condition）。
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

  /// 移除股票並重新載入資料。
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

  /// 清除目前的錯誤狀態。
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// 錯誤後重新載入目前所有股票的資料。
  Future<void> reload() async {
    if (state.symbols.isEmpty) return;
    state = state.copyWith(isLoading: true, error: null);
    await _loadAllData(state.symbols);
  }

  /// 載入指定股票的所有比較資料。
  ///
  /// 使用 generation token 防止舊載入覆蓋新狀態：
  /// 若載入期間有更新的 _loadAllData 被啟動，本次結果會被丟棄。
  Future<void> _loadAllData(List<String> symbols) async {
    final generation = ++_loadGeneration;

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
      final instStartDate = dateCtx.today.subtract(
        const Duration(days: InstitutionalParams.institutionalLookbackDays),
      );
      final (valuations, institutional, eps, revenue) = await (
        _db.getLatestValuationsBatch(symbols),
        _db.getInstitutionalHistoryBatch(symbols, startDate: instStartDate),
        _db.getEPSHistoryBatch(symbols),
        _db.getRecentMonthlyRevenueBatch(
          symbols,
          months: DataFreshness.revenueDisplayMonths,
        ),
      ).wait;

      if (!_active || _loadGeneration != generation) return;

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
          horizon: ref.read(selectedHorizonProvider),
        );
        summaries[symbol] = localizer.localize(summaryData);
      }

      // generation 過期：有更新的載入已啟動，丟棄本次結果
      if (_loadGeneration != generation) return;

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
      // generation 過期時不覆蓋新載入的錯誤狀態
      if (_loadGeneration != generation) return;
      AppLogger.warning('ComparisonNotifier', '載入比較資料失敗', e);
      state = state.copyWith(isLoading: false, error: ErrorDisplay.message(e));
    }
  }

  /// 以當前 horizon 重新生成所有股票的 AI 摘要（Stage 5c）
  ///
  /// 不重新向 DB / API 取資料 — 只重跑 `summaryService.generate` 跟
  /// `localizer.localize` 這段純運算。觸發來源是 [selectedHorizonProvider]
  /// 的 listen callback。
  void _regenerateAllSummaries() {
    if (state.symbols.isEmpty) return;
    const summaryService = AnalysisSummaryService();
    const localizer = SummaryLocalizer();
    final horizon = ref.read(selectedHorizonProvider);
    final summaries = <String, StockSummary>{};

    for (final symbol in state.symbols) {
      final analysis = state.analysesMap[symbol];
      final reasons = state.reasonsMap[symbol] ?? [];
      final latestPrice = state.latestPricesMap[symbol];
      final priceHistory = state.priceHistoriesMap[symbol] ?? [];

      final finMindRevenues = FinMindModelMapper.toFinMindRevenues(
        state.revenueMap[symbol] ?? [],
      );
      final finMindPER = FinMindModelMapper.toFinMindPER(
        state.valuationsMap[symbol],
      );

      final summaryData = summaryService.generate(
        analysis: analysis,
        reasons: reasons,
        latestPrice: latestPrice,
        priceChange: PriceCalculator.calculatePriceChange(
          priceHistory,
          latestPrice,
        ),
        institutionalHistory: state.institutionalMap[symbol] ?? [],
        revenueHistory: finMindRevenues,
        latestPER: finMindPER,
        horizon: horizon,
      );
      summaries[symbol] = localizer.localize(summaryData);
    }

    state = state.copyWith(summariesMap: summaries);
  }
}

// ==================================================
// Provider
// ==================================================

final comparisonProvider =
    NotifierProvider.autoDispose<ComparisonNotifier, ComparisonState>(
      ComparisonNotifier.new,
    );
