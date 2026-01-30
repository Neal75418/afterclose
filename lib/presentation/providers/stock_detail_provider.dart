import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/price_calculator.dart';
import 'package:afterclose/core/utils/taiwan_calendar.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/domain/services/data_sync_service.dart';
import 'package:afterclose/presentation/providers/providers.dart';
import 'package:afterclose/presentation/providers/watchlist_provider.dart';

// ==================================================
// Stock Detail State
// ==================================================

/// State for stock detail screen
class StockDetailState {
  const StockDetailState({
    this.stock,
    this.latestPrice,
    this.previousPrice,
    this.priceHistory = const [],
    this.analysis,
    this.reasons = const [],
    this.institutionalHistory = const [],
    this.marginHistory = const [],
    this.revenueHistory = const [],
    this.dividendHistory = const [],
    this.insiderHistory = const [],
    this.latestPER,
    this.recentNews = const [],
    this.epsHistory = const [],
    this.latestQuarterMetrics = const {},
    this.isInWatchlist = false,
    this.isLoading = false,
    this.isLoadingMargin = false,
    this.isLoadingFundamentals = false,
    this.isLoadingInsider = false,
    this.error,
    this.hasInstitutionalError = false,
    this.dataDate,
    this.hasDataMismatch = false,
  });

  final StockMasterEntry? stock;
  final DailyPriceEntry? latestPrice;
  final DailyPriceEntry? previousPrice;
  final List<DailyPriceEntry> priceHistory;
  final DailyAnalysisEntry? analysis;
  final List<DailyReasonEntry> reasons;
  final List<DailyInstitutionalEntry> institutionalHistory;
  final List<FinMindMarginData> marginHistory;
  final List<FinMindRevenue> revenueHistory;
  final List<FinMindDividend> dividendHistory;
  final List<InsiderHoldingEntry> insiderHistory;
  final FinMindPER? latestPER;
  final List<NewsItemEntry> recentNews;
  final List<FinancialDataEntry> epsHistory;
  final Map<String, double> latestQuarterMetrics;
  final bool isInWatchlist;
  final bool isLoading;
  final bool isLoadingMargin;
  final bool isLoadingFundamentals;
  final bool isLoadingInsider;
  final String? error;

  /// 法人資料載入時是否發生錯誤（部分錯誤，不影響主要資料）
  final bool hasInstitutionalError;

  /// The synchronized data date - all displayed data should be from this date
  final DateTime? dataDate;

  /// True if price and institutional data dates don't match
  final bool hasDataMismatch;

  StockDetailState copyWith({
    StockMasterEntry? stock,
    DailyPriceEntry? latestPrice,
    DailyPriceEntry? previousPrice,
    List<DailyPriceEntry>? priceHistory,
    DailyAnalysisEntry? analysis,
    List<DailyReasonEntry>? reasons,
    List<DailyInstitutionalEntry>? institutionalHistory,
    List<FinMindMarginData>? marginHistory,
    List<FinMindRevenue>? revenueHistory,
    List<FinMindDividend>? dividendHistory,
    List<InsiderHoldingEntry>? insiderHistory,
    FinMindPER? latestPER,
    List<NewsItemEntry>? recentNews,
    List<FinancialDataEntry>? epsHistory,
    Map<String, double>? latestQuarterMetrics,
    bool? isInWatchlist,
    bool? isLoading,
    bool? isLoadingMargin,
    bool? isLoadingFundamentals,
    bool? isLoadingInsider,
    String? error,
    bool? hasInstitutionalError,
    DateTime? dataDate,
    bool? hasDataMismatch,
  }) {
    return StockDetailState(
      stock: stock ?? this.stock,
      latestPrice: latestPrice ?? this.latestPrice,
      previousPrice: previousPrice ?? this.previousPrice,
      priceHistory: priceHistory ?? this.priceHistory,
      analysis: analysis ?? this.analysis,
      reasons: reasons ?? this.reasons,
      institutionalHistory: institutionalHistory ?? this.institutionalHistory,
      marginHistory: marginHistory ?? this.marginHistory,
      revenueHistory: revenueHistory ?? this.revenueHistory,
      dividendHistory: dividendHistory ?? this.dividendHistory,
      insiderHistory: insiderHistory ?? this.insiderHistory,
      latestPER: latestPER ?? this.latestPER,
      recentNews: recentNews ?? this.recentNews,
      epsHistory: epsHistory ?? this.epsHistory,
      latestQuarterMetrics: latestQuarterMetrics ?? this.latestQuarterMetrics,
      isInWatchlist: isInWatchlist ?? this.isInWatchlist,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMargin: isLoadingMargin ?? this.isLoadingMargin,
      isLoadingFundamentals:
          isLoadingFundamentals ?? this.isLoadingFundamentals,
      isLoadingInsider: isLoadingInsider ?? this.isLoadingInsider,
      error: error,
      hasInstitutionalError:
          hasInstitutionalError ?? this.hasInstitutionalError,
      dataDate: dataDate ?? this.dataDate,
      hasDataMismatch: hasDataMismatch ?? this.hasDataMismatch,
    );
  }

  /// Price change percentage
  ///
  /// 使用 PriceCalculator 直接由最新與前一日價格計算
  double? get priceChange {
    return PriceCalculator.calculatePriceChangeFromPrices(
      latestPrice?.close,
      previousPrice?.close,
    );
  }

  /// Trend state label
  String get trendLabel {
    return switch (analysis?.trendState) {
      'UP' => '上升趨勢',
      'DOWN' => '下跌趨勢',
      _ => '盤整區間',
    };
  }

  /// Reversal state label
  String? get reversalLabel {
    return switch (analysis?.reversalState) {
      'W2S' => '弱轉強',
      'S2W' => '強轉弱',
      _ => null,
    };
  }

  /// Get reason labels
  List<String> get reasonLabels {
    return reasons.map((r) {
      return ReasonType.values
              .where((rt) => rt.code == r.reasonType)
              .firstOrNull
              ?.label ??
          r.reasonType;
    }).toList();
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
      // 若今日非交易日（週末/假日），使用前一個交易日
      final analysisDate = TaiwanCalendar.isTradingDay(normalizedToday)
          ? normalizedToday
          : TaiwanCalendar.getPreviousTradingDay(normalizedToday);

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

      state = state.copyWith(
        stock: stock,
        latestPrice: latestPrice,
        previousPrice: previousPrice,
        priceHistory: priceHistory,
        analysis: analysis,
        reasons: reasons,
        institutionalHistory: syncedInstHistory,
        isInWatchlist: isInWatchlist,
        isLoading: false,
        hasInstitutionalError: hasInstitutionalError,
        dataDate: dataDate,
        hasDataMismatch: hasDataMismatch,
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

    if (state.isInWatchlist) {
      await watchlistNotifier.removeStock(_symbol);
    } else {
      await watchlistNotifier.addStock(_symbol);
    }

    // Update local state
    state = state.copyWith(isInWatchlist: !state.isInWatchlist);
  }

  /// Load margin trading data (融資融券) from FinMind API
  Future<void> loadMarginData() async {
    // Skip if already loading or already loaded
    if (state.isLoadingMargin || state.marginHistory.isNotEmpty) return;

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
    if (state.isLoadingFundamentals ||
        state.revenueHistory.isNotEmpty ||
        state.dividendHistory.isNotEmpty) {
      return;
    }

    state = state.copyWith(isLoadingFundamentals: true);

    try {
      final today = DateTime.now();

      // Load revenue for past 24 months (need 2 years for YoY calculation)
      final revenueStartDate = DateTime(today.year - 2, today.month, 1);

      // 1. 優先從資料庫取得估值資料（TWSE 來源，與規則評估一致）
      final perStartDate = today.subtract(const Duration(days: 30));
      final dbValuations = await _db.getValuationHistory(
        _symbol,
        startDate: perStartDate,
      );

      FinMindPER? latestPER;
      if (dbValuations.isNotEmpty) {
        // 使用資料庫資料（來自 TWSE）
        final latest = dbValuations.last;
        latestPER = FinMindPER(
          stockId: latest.symbol,
          date: DateContext.formatYmd(latest.date),
          per: latest.per ?? 0,
          pbr: latest.pbr ?? 0,
          dividendYield: latest.dividendYield ?? 0,
        );
        AppLogger.debug(
          'StockDetail',
          '$_symbol: 使用 DB 估值 (殖利率=${latestPER.dividendYield.toStringAsFixed(2)}%)',
        );
      }

      // 2. 營收資料：優先從資料庫取得（已由 TWSE 同步）
      // 注意：TWSE OpenData 只提供最新月份，DB 資料可能不足
      // 若 DB 資料少於 6 個月，改用 FinMind API 取得完整歷史
      List<FinMindRevenue> revenueData = [];
      final dbRevenues = await _db.getMonthlyRevenueHistory(
        _symbol,
        startDate: revenueStartDate,
      );

      // 若 DB 有足夠資料（>=6 個月），使用 DB；否則用 FinMind API
      const minMonthsForDbUsage = 6;
      if (dbRevenues.length >= minMonthsForDbUsage) {
        // 使用資料庫資料（來自 TWSE 同步）
        revenueData = _convertDbRevenuesToFinMind(dbRevenues);
        AppLogger.debug(
          'StockDetail',
          '$_symbol: 使用 DB 營收 (${revenueData.length} 筆)',
        );
      } else {
        // DB 資料不足時用 FinMind API（可取得歷史資料）
        try {
          revenueData = await _finMind.getMonthlyRevenue(
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
        } catch (apiError) {
          // API 失敗時，若 DB 有部分資料則使用之
          if (dbRevenues.isNotEmpty) {
            revenueData = _convertDbRevenuesToFinMind(dbRevenues);
            AppLogger.debug(
              'StockDetail',
              '$_symbol: FinMind 失敗，fallback 使用 DB 營收 (${revenueData.length} 筆)',
            );
          } else {
            AppLogger.warning('StockDetail', '取得營收資料失敗: $_symbol', apiError);
          }
        }
      }

      // 3. 股利歷史：優先從 DB 取得，無資料則從 API 取得並存入 DB
      List<FinMindDividend> dividendData = [];
      try {
        final dbDividends = await _db.getDividendHistory(_symbol);
        if (dbDividends.isNotEmpty) {
          dividendData = dbDividends
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
          AppLogger.debug(
            'StockDetail',
            '$_symbol: 使用 DB 股利歷史 (${dbDividends.length} 筆)',
          );
        } else {
          // DB 無資料，從 API 取得並存入 DB
          final apiData = await _finMind.getDividends(stockId: _symbol);
          if (apiData.isNotEmpty) {
            dividendData = apiData;
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
          }
        }
      } catch (dividendError) {
        AppLogger.debug('StockDetail', '$_symbol: 取得股利歷史失敗');
      }

      // 4. EPS 歷史：從 DB 取得
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

      // 5. 若資料庫無估值資料，才用 FinMind API
      if (latestPER == null) {
        try {
          final perApiStart = today.subtract(const Duration(days: 5));
          final perData = await _finMind.getPERData(
            stockId: _symbol,
            startDate: DateContext.formatYmd(perApiStart),
            endDate: DateContext.formatYmd(today),
          );

          if (perData.isNotEmpty) {
            perData.sort((a, b) => b.date.compareTo(a.date));
            latestPER = perData.first;
            AppLogger.debug(
              'StockDetail',
              '$_symbol: 使用 FinMind 估值 (殖利率=${latestPER.dividendYield.toStringAsFixed(2)}%)',
            );
          }
        } catch (perError) {
          AppLogger.warning('StockDetail', '取得估值資料失敗: $_symbol', perError);
        }
      }

      state = state.copyWith(
        revenueHistory: revenueData,
        dividendHistory: dividendData,
        latestPER: latestPER,
        epsHistory: epsData,
        latestQuarterMetrics: quarterMetrics,
        isLoadingFundamentals: false,
      );
    } catch (e) {
      AppLogger.warning('StockDetail', '載入基本面資料失敗: $_symbol', e);
      state = state.copyWith(isLoadingFundamentals: false);
    }
  }

  /// Load insider holdings data (董監持股)
  ///
  /// 從資料庫取得董監持股歷史資料，用於顯示在股票詳情頁的董監持股頁籤。
  Future<void> loadInsiderData() async {
    // Skip if already loading or already loaded
    if (state.isLoadingInsider || state.insiderHistory.isNotEmpty) return;

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
        link.close();
      });

      // 清理：當 Provider 真正被釋放時取消 Timer
      ref.onDispose(() {
        timer.cancel();
      });

      return StockDetailNotifier(ref, symbol);
    });
