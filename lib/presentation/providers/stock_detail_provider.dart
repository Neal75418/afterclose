import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/price_calculator.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/domain/models/chip_strength.dart';
import 'package:afterclose/domain/services/chip_analysis_service.dart';
import 'package:afterclose/domain/services/data_sync_service.dart';
import 'package:afterclose/domain/models/stock_summary.dart';
import 'package:afterclose/domain/services/analysis_summary_service.dart';
import 'package:afterclose/presentation/mappers/summary_localizer.dart';
import 'package:afterclose/domain/services/personalization_service.dart';
import 'package:afterclose/domain/services/rule_accuracy_service.dart';
import 'package:afterclose/presentation/providers/providers.dart';
import 'package:afterclose/presentation/providers/watchlist_provider.dart';

// ==================================================
// Sub-State Classes
// ==================================================

/// Price-related state: stock info, prices, history, analysis
class StockPriceState {
  const StockPriceState({
    this.stock,
    this.latestPrice,
    this.previousPrice,
    this.priceHistory = const [],
    this.analysis,
  });

  final StockMasterEntry? stock;
  final DailyPriceEntry? latestPrice;
  final DailyPriceEntry? previousPrice;
  final List<DailyPriceEntry> priceHistory;
  final DailyAnalysisEntry? analysis;

  /// Price change percentage
  ///
  /// 委託給 PriceCalculator，優先使用 API 漲跌價差，回退到歷史收盤價
  double? get priceChange {
    return PriceCalculator.calculatePriceChange(priceHistory, latestPrice);
  }

  StockPriceState copyWith({
    StockMasterEntry? stock,
    DailyPriceEntry? latestPrice,
    DailyPriceEntry? previousPrice,
    List<DailyPriceEntry>? priceHistory,
    DailyAnalysisEntry? analysis,
  }) {
    return StockPriceState(
      stock: stock ?? this.stock,
      latestPrice: latestPrice ?? this.latestPrice,
      previousPrice: previousPrice ?? this.previousPrice,
      priceHistory: priceHistory ?? this.priceHistory,
      analysis: analysis ?? this.analysis,
    );
  }
}

/// Fundamentals state: revenue, dividends, PER, EPS, quarter metrics
class FundamentalsState {
  const FundamentalsState({
    this.revenueHistory = const [],
    this.dividendHistory = const [],
    this.latestPER,
    this.latestQuarterMetrics = const {},
    this.epsHistory = const [],
  });

  final List<FinMindRevenue> revenueHistory;
  final List<FinMindDividend> dividendHistory;
  final FinMindPER? latestPER;
  final Map<String, double> latestQuarterMetrics;
  final List<FinancialDataEntry> epsHistory;

  FundamentalsState copyWith({
    List<FinMindRevenue>? revenueHistory,
    List<FinMindDividend>? dividendHistory,
    FinMindPER? latestPER,
    Map<String, double>? latestQuarterMetrics,
    List<FinancialDataEntry>? epsHistory,
  }) {
    return FundamentalsState(
      revenueHistory: revenueHistory ?? this.revenueHistory,
      dividendHistory: dividendHistory ?? this.dividendHistory,
      latestPER: latestPER ?? this.latestPER,
      latestQuarterMetrics: latestQuarterMetrics ?? this.latestQuarterMetrics,
      epsHistory: epsHistory ?? this.epsHistory,
    );
  }
}

/// Chip analysis state: institutional, margin, day trading, shareholding, etc.
class ChipAnalysisState {
  const ChipAnalysisState({
    this.institutionalHistory = const [],
    this.marginHistory = const [],
    this.marginTradingHistory = const [],
    this.dayTradingHistory = const [],
    this.shareholdingHistory = const [],
    this.holdingDistribution = const [],
    this.insiderHistory = const [],
    this.chipStrength,
    this.hasInstitutionalError = false,
  });

  final List<DailyInstitutionalEntry> institutionalHistory;
  final List<FinMindMarginData> marginHistory;
  final List<MarginTradingEntry> marginTradingHistory;
  final List<DayTradingEntry> dayTradingHistory;
  final List<ShareholdingEntry> shareholdingHistory;
  final List<HoldingDistributionEntry> holdingDistribution;
  final List<InsiderHoldingEntry> insiderHistory;
  final ChipStrengthResult? chipStrength;

  /// 法人資料載入時是否發生錯誤（部分錯誤，不影響主要資料）
  final bool hasInstitutionalError;

  ChipAnalysisState copyWith({
    List<DailyInstitutionalEntry>? institutionalHistory,
    List<FinMindMarginData>? marginHistory,
    List<MarginTradingEntry>? marginTradingHistory,
    List<DayTradingEntry>? dayTradingHistory,
    List<ShareholdingEntry>? shareholdingHistory,
    List<HoldingDistributionEntry>? holdingDistribution,
    List<InsiderHoldingEntry>? insiderHistory,
    ChipStrengthResult? chipStrength,
    bool? hasInstitutionalError,
  }) {
    return ChipAnalysisState(
      institutionalHistory: institutionalHistory ?? this.institutionalHistory,
      marginHistory: marginHistory ?? this.marginHistory,
      marginTradingHistory: marginTradingHistory ?? this.marginTradingHistory,
      dayTradingHistory: dayTradingHistory ?? this.dayTradingHistory,
      shareholdingHistory: shareholdingHistory ?? this.shareholdingHistory,
      holdingDistribution: holdingDistribution ?? this.holdingDistribution,
      insiderHistory: insiderHistory ?? this.insiderHistory,
      chipStrength: chipStrength ?? this.chipStrength,
      hasInstitutionalError:
          hasInstitutionalError ?? this.hasInstitutionalError,
    );
  }
}

/// Loading state flags for different data sections
class LoadingState {
  const LoadingState({
    this.isLoading = false,
    this.isLoadingMargin = false,
    this.isLoadingFundamentals = false,
    this.isLoadingInsider = false,
    this.isLoadingChip = false,
  });

  final bool isLoading;
  final bool isLoadingMargin;
  final bool isLoadingFundamentals;
  final bool isLoadingInsider;
  final bool isLoadingChip;

  LoadingState copyWith({
    bool? isLoading,
    bool? isLoadingMargin,
    bool? isLoadingFundamentals,
    bool? isLoadingInsider,
    bool? isLoadingChip,
  }) {
    return LoadingState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMargin: isLoadingMargin ?? this.isLoadingMargin,
      isLoadingFundamentals:
          isLoadingFundamentals ?? this.isLoadingFundamentals,
      isLoadingInsider: isLoadingInsider ?? this.isLoadingInsider,
      isLoadingChip: isLoadingChip ?? this.isLoadingChip,
    );
  }
}

// ==================================================
// Stock Detail State
// ==================================================

/// State for stock detail screen
class StockDetailState {
  static const _sentinel = Object();
  const StockDetailState({
    this.price = const StockPriceState(),
    this.fundamentals = const FundamentalsState(),
    this.chip = const ChipAnalysisState(),
    this.loading = const LoadingState(),
    this.isInWatchlist = false,
    this.error,
    this.dataDate,
    this.hasDataMismatch = false,
    this.reasons = const [],
    this.aiSummary,
    this.recentNews = const [],
  });

  final StockPriceState price;
  final FundamentalsState fundamentals;
  final ChipAnalysisState chip;
  final LoadingState loading;

  // Remaining direct fields
  final bool isInWatchlist;
  final String? error;

  /// The synchronized data date - all displayed data should be from this date
  final DateTime? dataDate;

  /// True if price and institutional data dates don't match
  final bool hasDataMismatch;

  final List<DailyReasonEntry> reasons;
  final StockSummary? aiSummary;
  final List<NewsItemEntry> recentNews;

  /// Convenience: Price change percentage (delegates to price sub-state)
  double? get priceChange => price.priceChange;

  /// Trend state label
  String get trendLabel {
    return switch (price.analysis?.trendState) {
      'UP' => '上升趨勢',
      'DOWN' => '下跌趨勢',
      _ => '盤整區間',
    };
  }

  /// Reversal state label
  String? get reversalLabel {
    return switch (price.analysis?.reversalState) {
      'W2S' => '弱轉強',
      'S2W' => '強轉弱',
      _ => null,
    };
  }

  StockDetailState copyWith({
    // Price fields
    StockMasterEntry? stock,
    DailyPriceEntry? latestPrice,
    DailyPriceEntry? previousPrice,
    List<DailyPriceEntry>? priceHistory,
    DailyAnalysisEntry? analysis,
    // Fundamentals fields
    List<FinMindRevenue>? revenueHistory,
    List<FinMindDividend>? dividendHistory,
    FinMindPER? latestPER,
    Map<String, double>? latestQuarterMetrics,
    List<FinancialDataEntry>? epsHistory,
    // Chip fields
    List<DailyInstitutionalEntry>? institutionalHistory,
    List<FinMindMarginData>? marginHistory,
    List<MarginTradingEntry>? marginTradingHistory,
    List<DayTradingEntry>? dayTradingHistory,
    List<ShareholdingEntry>? shareholdingHistory,
    List<HoldingDistributionEntry>? holdingDistribution,
    List<InsiderHoldingEntry>? insiderHistory,
    ChipStrengthResult? chipStrength,
    bool? hasInstitutionalError,
    // Loading fields
    bool? isLoading,
    bool? isLoadingMargin,
    bool? isLoadingFundamentals,
    bool? isLoadingInsider,
    bool? isLoadingChip,
    // Direct fields
    bool? isInWatchlist,
    Object? error = _sentinel,
    DateTime? dataDate,
    bool? hasDataMismatch,
    List<DailyReasonEntry>? reasons,
    StockSummary? aiSummary,
    List<NewsItemEntry>? recentNews,
  }) {
    // Only create new sub-state objects when their fields are being updated
    final needsPriceUpdate =
        stock != null ||
        latestPrice != null ||
        previousPrice != null ||
        priceHistory != null ||
        analysis != null;

    final needsFundamentalsUpdate =
        revenueHistory != null ||
        dividendHistory != null ||
        latestPER != null ||
        latestQuarterMetrics != null ||
        epsHistory != null;

    final needsChipUpdate =
        institutionalHistory != null ||
        marginHistory != null ||
        marginTradingHistory != null ||
        dayTradingHistory != null ||
        shareholdingHistory != null ||
        holdingDistribution != null ||
        insiderHistory != null ||
        chipStrength != null ||
        hasInstitutionalError != null;

    final needsLoadingUpdate =
        isLoading != null ||
        isLoadingMargin != null ||
        isLoadingFundamentals != null ||
        isLoadingInsider != null ||
        isLoadingChip != null;

    return StockDetailState(
      price: needsPriceUpdate
          ? price.copyWith(
              stock: stock,
              latestPrice: latestPrice,
              previousPrice: previousPrice,
              priceHistory: priceHistory,
              analysis: analysis,
            )
          : price,
      fundamentals: needsFundamentalsUpdate
          ? fundamentals.copyWith(
              revenueHistory: revenueHistory,
              dividendHistory: dividendHistory,
              latestPER: latestPER,
              latestQuarterMetrics: latestQuarterMetrics,
              epsHistory: epsHistory,
            )
          : fundamentals,
      chip: needsChipUpdate
          ? chip.copyWith(
              institutionalHistory: institutionalHistory,
              marginHistory: marginHistory,
              marginTradingHistory: marginTradingHistory,
              dayTradingHistory: dayTradingHistory,
              shareholdingHistory: shareholdingHistory,
              holdingDistribution: holdingDistribution,
              insiderHistory: insiderHistory,
              chipStrength: chipStrength,
              hasInstitutionalError: hasInstitutionalError,
            )
          : chip,
      loading: needsLoadingUpdate
          ? loading.copyWith(
              isLoading: isLoading,
              isLoadingMargin: isLoadingMargin,
              isLoadingFundamentals: isLoadingFundamentals,
              isLoadingInsider: isLoadingInsider,
              isLoadingChip: isLoadingChip,
            )
          : loading,
      isInWatchlist: isInWatchlist ?? this.isInWatchlist,
      error: error == _sentinel ? this.error : error as String?,
      dataDate: dataDate ?? this.dataDate,
      hasDataMismatch: hasDataMismatch ?? this.hasDataMismatch,
      reasons: reasons ?? this.reasons,
      aiSummary: aiSummary ?? this.aiSummary,
      recentNews: recentNews ?? this.recentNews,
    );
  }
}

// ==================================================
// Stock Detail Notifier
// ==================================================

class StockDetailNotifier extends StateNotifier<StockDetailState> {
  StockDetailNotifier(this._ref, this._symbol)
    : super(const StockDetailState());

  final Ref _ref;
  final String _symbol;

  AppDatabase get _db => _ref.read(databaseProvider);
  FinMindClient get _finMind => _ref.read(finMindClientProvider);
  DataSyncService get _dataSyncService => _ref.read(dataSyncServiceProvider);

  /// 將資料庫營收資料轉換為 FinMindRevenue 格式
  List<FinMindRevenue> _convertDbRevenuesToFinMind(
    List<MonthlyRevenueEntry> dbRevenues,
  ) {
    return dbRevenues.map((r) {
      return FinMindRevenue(
        stockId: r.symbol,
        date: DateContext.formatYmd(r.date),
        revenueYear: r.revenueYear,
        revenueMonth: r.revenueMonth,
        revenue: r.revenue,
        momGrowth: r.momGrowth ?? 0,
        yoyGrowth: r.yoyGrowth ?? 0,
      );
    }).toList();
  }

  /// Load stock detail data
  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final dateCtx = DateContext.withLookback(RuleParams.lookbackPrice);
      final normalizedToday = dateCtx.today;
      final startDate = dateCtx.historyStart;

      // 決定分析資料的查詢日期
      // 使用資料庫最新價格日期，確保盤前/非交易日也能顯示上次分析結果
      final latestDataDate = await _db.getLatestDataDate();
      final analysisDate = latestDataDate != null
          ? DateContext.normalize(latestDataDate)
          : normalizedToday;

      // Load all data in parallel
      final stockFuture = _db.getStock(_symbol);
      final priceFuture = _db.getPriceHistory(
        _symbol,
        startDate: startDate,
        endDate: normalizedToday,
      );
      // 使用 getRecentPrices 獲取最近兩筆價格，用於計算漲跌幅
      final recentPricesFuture = _db.getRecentPrices(_symbol, count: 2);
      final analysisFuture = _db.getAnalysis(_symbol, analysisDate);
      final reasonsFuture = _db.getReasons(_symbol, analysisDate);
      final instFuture = _db.getInstitutionalHistory(
        _symbol,
        startDate: normalizedToday.subtract(const Duration(days: 10)),
        endDate: normalizedToday,
      );
      final watchlistFuture = _db.isInWatchlist(_symbol);

      final results = await Future.wait([
        stockFuture,
        priceFuture,
        recentPricesFuture,
        analysisFuture,
        reasonsFuture,
        instFuture,
        watchlistFuture,
      ]);

      // 型別轉換
      // 注意：Dart 泛型在運行時會被擦除，`is List<T>` 實際等同於 `is List`。
      // 因此使用 try-catch 包裝，確保即使資料庫層返回格式異常也不會崩潰。
      StockMasterEntry? stock;
      List<DailyPriceEntry> priceHistory = [];
      List<DailyPriceEntry> recentPrices = [];
      DailyAnalysisEntry? analysis;
      List<DailyReasonEntry> reasons = [];
      List<DailyInstitutionalEntry> instHistory = [];
      bool isInWatchlist = false;

      try {
        stock = results[0] as StockMasterEntry?;
        priceHistory = results[1] as List<DailyPriceEntry>;
        recentPrices = results[2] as List<DailyPriceEntry>;
        analysis = results[3] as DailyAnalysisEntry?;
        reasons = results[4] as List<DailyReasonEntry>;
        instHistory = results[5] as List<DailyInstitutionalEntry>;
        isInWatchlist = results[6] as bool;
      } catch (e) {
        // 若型別轉換失敗，記錄錯誤但繼續執行（使用預設空值）
        AppLogger.warning('StockDetail', '資料型別轉換失敗: $_symbol', e);
      }

      // 從最近價格提取最新與前一日（recentPrices 依日期降序排列）
      final latestPrice = recentPrices.isNotEmpty ? recentPrices.first : null;
      final previousPrice = recentPrices.length >= 2 ? recentPrices[1] : null;

      // DEBUG: 除錯漲跌幅計算
      AppLogger.debug(
        'StockDetail',
        'recentPrices count=${recentPrices.length}, '
            'latest=${latestPrice?.close} (${latestPrice?.date}), '
            'prev=${previousPrice?.close} (${previousPrice?.date})',
      );

      // If no institutional data in DB, fetch from API
      // 追蹤 API 是否失敗，以便 UI 顯示部分錯誤提示
      var hasInstitutionalError = false;
      if (instHistory.isEmpty) {
        final apiResult = await _fetchInstitutionalFromApi();
        instHistory = apiResult.data;
        hasInstitutionalError = apiResult.hasError;
      }

      // Synchronize data dates - find common latest date
      final syncResult = _dataSyncService.synchronizeDataDates(
        priceHistory,
        instHistory,
      );
      final syncedInstHistory = syncResult.institutionalHistory;
      final dataDate = syncResult.dataDate;
      final hasDataMismatch = syncResult.hasDataMismatch;

      // 生成 AI 智慧分析摘要
      final summaryData = const AnalysisSummaryService().generate(
        analysis: analysis,
        reasons: reasons,
        latestPrice: latestPrice,
        priceChange: PriceCalculator.calculatePriceChange(
          priceHistory,
          latestPrice,
        ),
        institutionalHistory: syncedInstHistory,
        revenueHistory: state.fundamentals.revenueHistory,
        latestPER: state.fundamentals.latestPER,
      );
      final summary = const SummaryLocalizer().localize(summaryData);

      state = state.copyWith(
        stock: stock,
        latestPrice: latestPrice,
        previousPrice: previousPrice,
        priceHistory: priceHistory,
        analysis: analysis,
        reasons: reasons,
        institutionalHistory: syncedInstHistory,
        aiSummary: summary,
        isInWatchlist: isInWatchlist,
        isLoading: false,
        hasInstitutionalError: hasInstitutionalError,
        dataDate: dataDate,
        hasDataMismatch: hasDataMismatch,
      );

      // 記錄瀏覽行為（Sprint 11 - 個人化推薦）
      unawaited(
        _ref
            .read(personalizationServiceProvider)
            .trackInteraction(
              type: InteractionType.view,
              symbol: _symbol,
              sourcePage: 'stock_detail',
            ),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Fetch institutional data directly from FinMind API
  ///
  /// 返回 record 包含資料與錯誤狀態，讓呼叫端能區分「API 失敗」與「真的沒資料」。
  Future<({List<DailyInstitutionalEntry> data, bool hasError})>
  _fetchInstitutionalFromApi() async {
    try {
      final today = DateTime.now();
      final startDate = today.subtract(const Duration(days: 20));

      final data = await _finMind.getInstitutionalData(
        stockId: _symbol,
        startDate: DateContext.formatYmd(startDate),
        endDate: DateContext.formatYmd(today),
      );

      // Convert to DailyInstitutionalEntry format
      final entries = data.map((item) {
        return DailyInstitutionalEntry(
          symbol: item.stockId,
          date: DateTime.parse(item.date),
          foreignNet: item.foreignNet,
          investmentTrustNet: item.investmentTrustNet,
          dealerNet: item.dealerNet,
        );
      }).toList();

      return (data: entries, hasError: false);
    } catch (e) {
      AppLogger.warning('StockDetail', '取得法人資料失敗: $_symbol', e);
      return (data: <DailyInstitutionalEntry>[], hasError: true);
    }
  }

  /// Toggle watchlist - also syncs with global watchlistProvider
  Future<void> toggleWatchlist() async {
    final watchlistNotifier = _ref.read(watchlistProvider.notifier);
    final wasInWatchlist = state.isInWatchlist;

    if (wasInWatchlist) {
      await watchlistNotifier.removeStock(_symbol);
    } else {
      await watchlistNotifier.addStock(_symbol);
    }

    // Update local state
    state = state.copyWith(isInWatchlist: !wasInWatchlist);

    // 記錄自選股變更行為（Sprint 11 - 個人化推薦）
    unawaited(
      _ref
          .read(personalizationServiceProvider)
          .trackInteraction(
            type: wasInWatchlist
                ? InteractionType.removeWatchlist
                : InteractionType.addWatchlist,
            symbol: _symbol,
            sourcePage: 'stock_detail',
          ),
    );
  }

  /// Load margin trading data (融資融券) from FinMind API
  Future<void> loadMarginData() async {
    // Skip if already loading or already loaded
    if (state.loading.isLoadingMargin || state.chip.marginHistory.isNotEmpty) {
      return;
    }

    state = state.copyWith(isLoadingMargin: true);

    try {
      // Load margin data for the past 20 days
      final today = DateTime.now();
      final startDate = today.subtract(const Duration(days: 20));

      final marginData = await _finMind.getMarginData(
        stockId: _symbol,
        startDate: DateContext.formatYmd(startDate),
        endDate: DateContext.formatYmd(today),
      );

      state = state.copyWith(marginHistory: marginData, isLoadingMargin: false);
    } catch (e) {
      if (e.toString().contains('402')) {
        AppLogger.info('StockDetail', '融資融券 API 不可用 (402)，跳過');
      } else {
        AppLogger.warning('StockDetail', '載入融資融券資料失敗: $_symbol', e);
      }
      state = state.copyWith(isLoadingMargin: false, marginHistory: []);
    }
  }

  /// Load fundamentals data (營收/股利/本益比)
  ///
  /// 估值資料（PER/PBR/殖利率）優先從資料庫（TWSE）取得，
  /// 確保與規則評估使用相同資料來源。
  /// 營收和股利歷史從 FinMind API 取得。
  Future<void> loadFundamentals() async {
    // Skip if already loading or already loaded
    if (state.loading.isLoadingFundamentals ||
        state.fundamentals.revenueHistory.isNotEmpty ||
        state.fundamentals.dividendHistory.isNotEmpty) {
      return;
    }

    state = state.copyWith(isLoadingFundamentals: true);

    try {
      final today = DateTime.now();
      final revenueStartDate = DateTime(today.year - 2, today.month, 1);

      // 1. 優先從資料庫取得估值資料（TWSE 來源，與規則評估一致）
      var latestPER = await _loadValuationData(today);

      // 2. 營收資料：優先從 DB，不足則 fallback FinMind API
      final revenueData = await _loadMonthlyRevenue(
        today: today,
        revenueStartDate: revenueStartDate,
      );

      // 3. 股利歷史：優先從 DB 取得，無資料則從 API 取得並存入 DB
      final dividendData = await _loadDividendHistory();

      // 4. EPS 歷史與季度財務指標（含 ROE 計算）
      final (:epsData, :quarterMetrics) = await _loadFinancialStatements();

      // 5. 若資料庫無估值資料，才用 FinMind API
      latestPER ??= await _loadValuationFromApi(today);

      // 更新 state
      state = state.copyWith(
        revenueHistory: revenueData,
        dividendHistory: dividendData,
        latestPER: latestPER,
        epsHistory: epsData,
        latestQuarterMetrics: quarterMetrics,
        isLoadingFundamentals: false,
      );

      // 基本面載入後重新生成 AI 摘要（含營收/估值資料）
      _regenerateAiSummary(revenueData: revenueData, latestPER: latestPER);
    } catch (e) {
      AppLogger.warning('StockDetail', '載入基本面資料失敗: $_symbol', e);
      state = state.copyWith(isLoadingFundamentals: false);
    }
  }

  /// 從資料庫取得估值資料（PER/PBR/殖利率）
  ///
  /// 優先使用 TWSE 來源的資料，確保與規則評估一致。
  /// 若資料庫無資料則回傳 null，後續由 [_loadValuationFromApi] 補充。
  Future<FinMindPER?> _loadValuationData(DateTime today) async {
    try {
      final perStartDate = today.subtract(const Duration(days: 30));
      final dbValuations = await _db.getValuationHistory(
        _symbol,
        startDate: perStartDate,
      );

      if (dbValuations.isNotEmpty) {
        final latest = dbValuations.last;
        final per = FinMindPER(
          stockId: latest.symbol,
          date: DateContext.formatYmd(latest.date),
          per: latest.per ?? 0,
          pbr: latest.pbr ?? 0,
          dividendYield: latest.dividendYield ?? 0,
        );
        AppLogger.debug(
          'StockDetail',
          '$_symbol: 使用 DB 估值 (殖利率=${per.dividendYield.toStringAsFixed(2)}%)',
        );
        return per;
      }
    } catch (e) {
      AppLogger.warning('StockDetail', '$_symbol: 取得 DB 估值失敗', e);
    }
    return null;
  }

  /// 載入月營收資料
  ///
  /// 優先從資料庫取得（已由 TWSE 同步）。
  /// 若 DB 資料少於 6 個月，改用 FinMind API 取得完整歷史。
  /// API 失敗時 fallback 至 DB 部分資料。
  Future<List<FinMindRevenue>> _loadMonthlyRevenue({
    required DateTime today,
    required DateTime revenueStartDate,
  }) async {
    try {
      final dbRevenues = await _db.getMonthlyRevenueHistory(
        _symbol,
        startDate: revenueStartDate,
      );

      // 若 DB 有足夠資料（>=6 個月），使用 DB；否則用 FinMind API
      const minMonthsForDbUsage = 6;
      if (dbRevenues.length >= minMonthsForDbUsage) {
        final data = _convertDbRevenuesToFinMind(dbRevenues);
        AppLogger.debug('StockDetail', '$_symbol: 使用 DB 營收 (${data.length} 筆)');
        return data;
      }

      // DB 資料不足時用 FinMind API（可取得歷史資料）
      try {
        var revenueData = await _finMind.getMonthlyRevenue(
          stockId: _symbol,
          startDate: DateContext.formatYmd(revenueStartDate),
          endDate: DateContext.formatYmd(today),
        );
        if (revenueData.isNotEmpty) {
          revenueData = FinMindRevenue.calculateGrowthRates(revenueData);
        }
        AppLogger.debug(
          'StockDetail',
          '$_symbol: 使用 FinMind 營收 (${revenueData.length} 筆，DB 僅 ${dbRevenues.length} 筆)',
        );
        return revenueData;
      } catch (apiError) {
        // API 失敗時，若 DB 有部分資料則使用之
        if (dbRevenues.isNotEmpty) {
          final data = _convertDbRevenuesToFinMind(dbRevenues);
          AppLogger.debug(
            'StockDetail',
            '$_symbol: FinMind 失敗，fallback 使用 DB 營收 (${data.length} 筆)',
          );
          return data;
        }
        AppLogger.warning('StockDetail', '取得營收資料失敗: $_symbol', apiError);
      }
    } catch (e) {
      AppLogger.warning('StockDetail', '$_symbol: 載入營收資料失敗', e);
    }
    return [];
  }

  /// 載入股利歷史
  ///
  /// 優先從 DB 取得，無資料則從 FinMind API 取得並背景寫入 DB。
  Future<List<FinMindDividend>> _loadDividendHistory() async {
    try {
      final dbDividends = await _db.getDividendHistory(_symbol);
      if (dbDividends.isNotEmpty) {
        AppLogger.debug(
          'StockDetail',
          '$_symbol: 使用 DB 股利歷史 (${dbDividends.length} 筆)',
        );
        return dbDividends
            .map(
              (d) => FinMindDividend(
                stockId: d.symbol,
                year: d.year,
                cashDividend: d.cashDividend,
                stockDividend: d.stockDividend,
                exDividendDate: d.exDividendDate,
                exRightsDate: d.exRightsDate,
              ),
            )
            .toList();
      }

      // DB 無資料，從 API 取得並存入 DB
      final apiData = await _finMind.getDividends(stockId: _symbol);
      if (apiData.isNotEmpty) {
        // 背景寫入 DB（不阻塞 UI）
        unawaited(
          _db
              .insertDividendData(
                apiData
                    .map(
                      (d) => DividendHistoryCompanion.insert(
                        symbol: _symbol,
                        year: d.year,
                        cashDividend: Value(d.cashDividend),
                        stockDividend: Value(d.stockDividend),
                        exDividendDate: Value(d.exDividendDate),
                        exRightsDate: Value(d.exRightsDate),
                      ),
                    )
                    .toList(),
              )
              .catchError((e) {
                AppLogger.warning('StockDetail', '$_symbol: 背景寫入股利失敗', e);
              }),
        );
        AppLogger.debug(
          'StockDetail',
          '$_symbol: 從 API 取得股利歷史 (${apiData.length} 筆) 並存入 DB',
        );
        return apiData;
      }
    } catch (e) {
      AppLogger.debug('StockDetail', '$_symbol: 取得股利歷史失敗');
    }
    return [];
  }

  /// 載入 EPS 歷史與季度財務指標（含 ROE 計算）
  ///
  /// 從 DB 取得 EPS 資料與最新季度指標，
  /// 若有 NetIncome 但缺 ROE，則計算年化 ROE。
  Future<
    ({List<FinancialDataEntry> epsData, Map<String, double> quarterMetrics})
  >
  _loadFinancialStatements() async {
    List<FinancialDataEntry> epsData = [];
    Map<String, double> quarterMetrics = {};
    try {
      epsData = await _db.getEPSHistory(_symbol);
      if (epsData.isNotEmpty) {
        quarterMetrics = await _db.getLatestQuarterMetrics(_symbol);
      }
      // 計算 ROE：從 Equity 歷史 join NetIncome（需同季日期對齊）
      if (quarterMetrics.containsKey('NetIncome') &&
          !quarterMetrics.containsKey('ROE') &&
          epsData.isNotEmpty) {
        final latestIncomeDate = epsData.first.date;
        final equityEntries = await _db.getEquityHistory(_symbol);
        // 找到與最新 INCOME 同季的 Equity
        for (final eq in equityEntries) {
          if (eq.date == latestIncomeDate &&
              eq.value != null &&
              eq.value! > 0) {
            // 年化 ROE：季度 NetIncome × 4 / Equity × 100
            quarterMetrics['ROE'] =
                quarterMetrics['NetIncome']! * 4 / eq.value! * 100;
            break;
          }
        }
      }
    } catch (e) {
      AppLogger.debug('StockDetail', '$_symbol: 取得 EPS 歷史失敗');
    }
    return (epsData: epsData, quarterMetrics: quarterMetrics);
  }

  /// 從 FinMind API 取得估值資料（PER/PBR/殖利率）
  ///
  /// 僅在 DB 無估值資料時呼叫，作為 fallback。
  Future<FinMindPER?> _loadValuationFromApi(DateTime today) async {
    try {
      final perApiStart = today.subtract(const Duration(days: 5));
      final perData = await _finMind.getPERData(
        stockId: _symbol,
        startDate: DateContext.formatYmd(perApiStart),
        endDate: DateContext.formatYmd(today),
      );

      if (perData.isNotEmpty) {
        perData.sort((a, b) => b.date.compareTo(a.date));
        final per = perData.first;
        AppLogger.debug(
          'StockDetail',
          '$_symbol: 使用 FinMind 估值 (殖利率=${per.dividendYield.toStringAsFixed(2)}%)',
        );
        return per;
      }
    } catch (e) {
      AppLogger.warning('StockDetail', '取得估值資料失敗: $_symbol', e);
    }
    return null;
  }

  /// 重新生成 AI 智慧分析摘要（含營收/估值資料）
  void _regenerateAiSummary({
    required List<FinMindRevenue> revenueData,
    required FinMindPER? latestPER,
  }) {
    final summaryData = const AnalysisSummaryService().generate(
      analysis: state.price.analysis,
      reasons: state.reasons,
      latestPrice: state.price.latestPrice,
      priceChange: state.priceChange,
      institutionalHistory: state.chip.institutionalHistory,
      revenueHistory: revenueData,
      latestPER: latestPER,
    );
    state = state.copyWith(
      aiSummary: const SummaryLocalizer().localize(summaryData),
    );
  }

  /// Load insider holdings data (董監持股)
  ///
  /// 從資料庫取得董監持股歷史資料，用於顯示在股票詳情頁的董監持股頁籤。
  Future<void> loadInsiderData() async {
    // Skip if already loading or already loaded
    if (state.loading.isLoadingInsider ||
        state.chip.insiderHistory.isNotEmpty) {
      return;
    }

    state = state.copyWith(isLoadingInsider: true);

    try {
      final insiderRepo = _ref.read(insiderRepositoryProvider);

      // Load insider holding history for the past 12 months
      final insiderHistory = await insiderRepo.getInsiderHoldingHistory(
        _symbol,
        months: 12,
      );

      // Sort by date descending (newest first)
      insiderHistory.sort((a, b) => b.date.compareTo(a.date));

      state = state.copyWith(
        insiderHistory: insiderHistory,
        isLoadingInsider: false,
      );
    } catch (e) {
      AppLogger.warning('StockDetail', '載入董監持股資料失敗: $_symbol', e);
      state = state.copyWith(isLoadingInsider: false, insiderHistory: []);
    }
  }

  /// Load comprehensive chip analysis data.
  ///
  /// Loads day trading, shareholding, margin trading (from DB),
  /// holding distribution, and insider data, then computes chip strength.
  Future<void> loadChipData() async {
    if (state.loading.isLoadingChip || state.chip.chipStrength != null) return;

    state = state.copyWith(isLoadingChip: true);

    try {
      final today = DateTime.now();
      final startDate10d = today.subtract(const Duration(days: 15));
      final startDate60d = today.subtract(const Duration(days: 90));

      final results = await Future.wait([
        _db.getDayTradingHistory(_symbol, startDate: startDate10d),
        _db.getShareholdingHistory(_symbol, startDate: startDate60d),
        _db.getMarginTradingHistory(_symbol, startDate: startDate10d),
        _db.getLatestHoldingDistribution(_symbol),
        state.chip.insiderHistory.isNotEmpty
            ? Future.value(state.chip.insiderHistory)
            : _db.getRecentInsiderHoldings(_symbol, months: 6),
      ]);

      List<DayTradingEntry> dayTrading = [];
      List<ShareholdingEntry> shareholding = [];
      List<MarginTradingEntry> marginTrading = [];
      List<HoldingDistributionEntry> holdingDist = [];
      List<InsiderHoldingEntry> insider = [];

      try {
        dayTrading = results[0] as List<DayTradingEntry>;
        shareholding = results[1] as List<ShareholdingEntry>;
        marginTrading = results[2] as List<MarginTradingEntry>;
        holdingDist = results[3] as List<HoldingDistributionEntry>;
        insider = results[4] as List<InsiderHoldingEntry>;
      } catch (e) {
        AppLogger.warning('StockDetail', '籌碼資料型別轉換失敗: $_symbol', e);
      }

      // Compute chip strength
      const service = ChipAnalysisService();
      final strength = service.compute(
        institutionalHistory: state.chip.institutionalHistory,
        shareholdingHistory: shareholding,
        marginHistory: marginTrading,
        dayTradingHistory: dayTrading,
        holdingDistribution: holdingDist,
        insiderHistory: insider,
      );

      state = state.copyWith(
        dayTradingHistory: dayTrading,
        shareholdingHistory: shareholding,
        marginTradingHistory: marginTrading,
        holdingDistribution: holdingDist,
        insiderHistory: insider.isNotEmpty ? insider : null,
        chipStrength: strength,
        isLoadingChip: false,
      );
    } catch (e) {
      AppLogger.warning('StockDetail', '載入籌碼分析資料失敗: $_symbol', e);
      state = state.copyWith(isLoadingChip: false);
    }
  }
}

/// Provider family for stock detail
/// 使用 autoDispose + keepAlive 組合：
/// - autoDispose: 無訂閱者時觸發清理
/// - keepAlive: 保留 5 分鐘快取，改善列表↔詳情切換體驗
final stockDetailProvider = StateNotifierProvider.family
    .autoDispose<StockDetailNotifier, StockDetailState, String>((ref, symbol) {
      // 保活機制：5 分鐘內返回同一頁面時使用快取
      final link = ref.keepAlive();

      // 3 分鐘後自動釋放
      final timer = Timer(const Duration(minutes: 3), () {
        try {
          link.close();
        } catch (_) {
          // Timer 可能在 dispose 邊界觸發，忽略已關閉的 link
        }
      });

      // 清理：當 Provider 真正被釋放時取消 Timer
      ref.onDispose(() {
        timer.cancel();
      });

      return StockDetailNotifier(ref, symbol);
    });

/// 規則準確度 Provider（Sprint 10）
///
/// 透過 ruleId 查詢該規則的歷史命中率和平均報酬率。
/// 若該規則觸發次數少於 5 次，返回 null（資料不足）。
final ruleAccuracyProvider = FutureProvider.family
    .autoDispose<RuleStats?, String>((ref, ruleId) async {
      final service = ref.watch(ruleAccuracyServiceProvider);
      return service.getRuleStats(ruleId);
    });

/// 主要規則準確度摘要文字 Provider
///
/// 取得股票的主要觸發規則，並返回其準確度摘要文字。
/// 例如：「命中率 65%，平均 5 日報酬 +2.3%」
final primaryRuleAccuracySummaryProvider = FutureProvider.family
    .autoDispose<String?, String>((ref, symbol) async {
      final state = ref.watch(stockDetailProvider(symbol));
      if (state.reasons.isEmpty) return null;

      // 取得主要規則（rank = 1）
      final primaryReason = state.reasons.firstWhere(
        (r) => r.rank == 1,
        orElse: () => state.reasons.first,
      );

      final service = ref.watch(ruleAccuracyServiceProvider);
      return service.getRuleSummaryText(primaryReason.reasonType);
    });
