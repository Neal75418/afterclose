import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
    this.latestPER,
    this.recentNews = const [],
    this.isInWatchlist = false,
    this.isLoading = false,
    this.isLoadingMargin = false,
    this.isLoadingFundamentals = false,
    this.error,
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
  final FinMindPER? latestPER;
  final List<NewsItemEntry> recentNews;
  final bool isInWatchlist;
  final bool isLoading;
  final bool isLoadingMargin;
  final bool isLoadingFundamentals;
  final String? error;

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
    FinMindPER? latestPER,
    List<NewsItemEntry>? recentNews,
    bool? isInWatchlist,
    bool? isLoading,
    bool? isLoadingMargin,
    bool? isLoadingFundamentals,
    String? error,
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
      latestPER: latestPER ?? this.latestPER,
      recentNews: recentNews ?? this.recentNews,
      isInWatchlist: isInWatchlist ?? this.isInWatchlist,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMargin: isLoadingMargin ?? this.isLoadingMargin,
      isLoadingFundamentals:
          isLoadingFundamentals ?? this.isLoadingFundamentals,
      error: error,
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

  /// 日期格式化器（用於資料轉換）
  static final _dateFormat = DateFormat('yyyy-MM-dd');

  /// 將資料庫營收資料轉換為 FinMindRevenue 格式
  List<FinMindRevenue> _convertDbRevenuesToFinMind(
    List<MonthlyRevenueEntry> dbRevenues,
  ) {
    return dbRevenues.map((r) {
      return FinMindRevenue(
        stockId: r.symbol,
        date: _dateFormat.format(r.date),
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

      final stock = results[0] as StockMasterEntry?;
      final priceHistory = results[1] as List<DailyPriceEntry>;
      final recentPrices = results[2] as List<DailyPriceEntry>;
      final analysis = results[3] as DailyAnalysisEntry?;
      final reasons = results[4] as List<DailyReasonEntry>;
      var instHistory = results[5] as List<DailyInstitutionalEntry>;
      final isInWatchlist = results[6] as bool;

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
      if (instHistory.isEmpty) {
        instHistory = await _fetchInstitutionalFromApi();
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
        dataDate: dataDate,
        hasDataMismatch: hasDataMismatch,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Fetch institutional data directly from FinMind API
  Future<List<DailyInstitutionalEntry>> _fetchInstitutionalFromApi() async {
    try {
      final today = DateTime.now();
      final startDate = today.subtract(const Duration(days: 20));

      final data = await _finMind.getInstitutionalData(
        stockId: _symbol,
        startDate: _dateFormat.format(startDate),
        endDate: _dateFormat.format(today),
      );

      // Convert to DailyInstitutionalEntry format
      return data.map((item) {
        return DailyInstitutionalEntry(
          symbol: item.stockId,
          date: DateTime.parse(item.date),
          foreignNet: item.foreignNet,
          investmentTrustNet: item.investmentTrustNet,
          dealerNet: item.dealerNet,
        );
      }).toList();
    } catch (e) {
      AppLogger.warning('StockDetail', '取得法人資料失敗: $_symbol', e);
      return [];
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
        startDate: _dateFormat.format(startDate),
        endDate: _dateFormat.format(today),
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
          date: _dateFormat.format(latest.date),
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
            startDate: _dateFormat.format(revenueStartDate),
            endDate: _dateFormat.format(today),
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

      // 3. 股利歷史：從 FinMind 取得（DB 未儲存歷史）
      List<FinMindDividend> dividendData = [];
      try {
        dividendData = await _finMind.getDividends(stockId: _symbol);
      } catch (dividendError) {
        AppLogger.debug('StockDetail', '$_symbol: 取得股利歷史失敗');
      }

      // 4. 若資料庫無估值資料，才用 FinMind API
      if (latestPER == null) {
        try {
          final perApiStart = today.subtract(const Duration(days: 5));
          final perData = await _finMind.getPERData(
            stockId: _symbol,
            startDate: _dateFormat.format(perApiStart),
            endDate: _dateFormat.format(today),
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
        isLoadingFundamentals: false,
      );
    } catch (e) {
      AppLogger.warning('StockDetail', '載入基本面資料失敗: $_symbol', e);
      state = state.copyWith(isLoadingFundamentals: false);
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

      // 5 分鐘後自動釋放
      final timer = Timer(const Duration(minutes: 5), () {
        link.close();
      });

      // 清理：當 Provider 真正被釋放時取消 Timer
      ref.onDispose(() {
        timer.cancel();
      });

      return StockDetailNotifier(ref, symbol);
    });
