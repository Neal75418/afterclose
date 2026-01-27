import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/price_calculator.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/database/cached_accessor.dart';
import 'package:afterclose/domain/services/data_sync_service.dart';
import 'package:afterclose/presentation/providers/providers.dart';
import 'package:afterclose/core/utils/taiwan_calendar.dart';

// ==================================================
// Scan Screen State
// ==================================================

/// Filter options for scan screen
enum ScanFilter {
  // All
  all('scan.filterAll', null, ScanFilterGroup.all),

  // Reversal signals
  reversalW2S(
    'scan.filterReversalW2S',
    'REVERSAL_W2S',
    ScanFilterGroup.reversal,
  ),
  reversalS2W(
    'scan.filterReversalS2W',
    'REVERSAL_S2W',
    ScanFilterGroup.reversal,
  ),

  // Technical breakout/breakdown
  breakout('scan.filterBreakout', 'TECH_BREAKOUT', ScanFilterGroup.technical),
  breakdown(
    'scan.filterBreakdown',
    'TECH_BREAKDOWN',
    ScanFilterGroup.technical,
  ),

  // Volume signals
  volumeSpike('scan.filterVolumeSpike', 'VOLUME_SPIKE', ScanFilterGroup.volume),

  // Price signals
  priceSpike('scan.filterPriceSpike', 'PRICE_SPIKE', ScanFilterGroup.price),

  // KD signals
  kdGoldenCross(
    'scan.filterKdGoldenCross',
    'KD_GOLDEN_CROSS',
    ScanFilterGroup.indicator,
  ),
  kdDeathCross(
    'scan.filterKdDeathCross',
    'KD_DEATH_CROSS',
    ScanFilterGroup.indicator,
  ),

  // RSI signals
  rsiOverbought(
    'scan.filterRsiOverbought',
    'RSI_EXTREME_OVERBOUGHT',
    ScanFilterGroup.indicator,
  ),
  rsiOversold(
    'scan.filterRsiOversold',
    'RSI_EXTREME_OVERSOLD',
    ScanFilterGroup.indicator,
  ),

  // Institutional signals
  institutionalBuy(
    'scan.filterInstitutionalBuy',
    'INSTITUTIONAL_BUY',
    ScanFilterGroup.institutional,
  ),
  institutionalSell(
    'scan.filterInstitutionalSell',
    'INSTITUTIONAL_SELL',
    ScanFilterGroup.institutional,
  ),
  institutionalBuyStreak(
    'scan.filterInstitutionalBuyStreak',
    'INSTITUTIONAL_BUY_STREAK',
    ScanFilterGroup.institutional,
  ),
  institutionalSellStreak(
    'scan.filterInstitutionalSellStreak',
    'INSTITUTIONAL_SELL_STREAK',
    ScanFilterGroup.institutional,
  ),

  // Extended market data signals (Phase 4)
  dayTradingHigh(
    'scan.filterDayTradingHigh',
    'DAY_TRADING_HIGH',
    ScanFilterGroup.extendedMarket,
  ),
  dayTradingExtreme(
    'scan.filterDayTradingExtreme',
    'DAY_TRADING_EXTREME',
    ScanFilterGroup.extendedMarket,
  ),
  // NOTE: concentrationHigh removed - requires paid API (股權分散表)

  // News signals
  newsRelated('scan.filterNewsRelated', 'NEWS_RELATED', ScanFilterGroup.news),

  // 52-week signals
  week52High('scan.filterWeek52High', 'WEEK_52_HIGH', ScanFilterGroup.week52),
  week52Low('scan.filterWeek52Low', 'WEEK_52_LOW', ScanFilterGroup.week52),

  // MA alignment signals
  maAlignmentBullish(
    'scan.filterMaAlignmentBullish',
    'MA_ALIGNMENT_BULLISH',
    ScanFilterGroup.maAlignment,
  ),
  maAlignmentBearish(
    'scan.filterMaAlignmentBearish',
    'MA_ALIGNMENT_BEARISH',
    ScanFilterGroup.maAlignment,
  ),

  // Candlestick patterns - neutral
  patternDoji(
    'scan.filterPatternDoji',
    'PATTERN_DOJI',
    ScanFilterGroup.pattern,
  ),

  // Candlestick patterns - bullish
  patternBullishEngulfing(
    'scan.filterPatternBullishEngulfing',
    'PATTERN_BULLISH_ENGULFING',
    ScanFilterGroup.pattern,
  ),
  patternHammer(
    'scan.filterPatternHammer',
    'PATTERN_HAMMER',
    ScanFilterGroup.pattern,
  ),
  patternMorningStar(
    'scan.filterPatternMorningStar',
    'PATTERN_MORNING_STAR',
    ScanFilterGroup.pattern,
  ),
  patternThreeWhiteSoldiers(
    'scan.filterPatternThreeWhiteSoldiers',
    'PATTERN_THREE_WHITE_SOLDIERS',
    ScanFilterGroup.pattern,
  ),
  patternGapUp(
    'scan.filterPatternGapUp',
    'PATTERN_GAP_UP',
    ScanFilterGroup.pattern,
  ),

  // Candlestick patterns - bearish
  patternBearishEngulfing(
    'scan.filterPatternBearishEngulfing',
    'PATTERN_BEARISH_ENGULFING',
    ScanFilterGroup.pattern,
  ),
  patternHangingMan(
    'scan.filterPatternHangingMan',
    'PATTERN_HANGING_MAN',
    ScanFilterGroup.pattern,
  ),
  patternEveningStar(
    'scan.filterPatternEveningStar',
    'PATTERN_EVENING_STAR',
    ScanFilterGroup.pattern,
  ),
  patternThreeBlackCrows(
    'scan.filterPatternThreeBlackCrows',
    'PATTERN_THREE_BLACK_CROWS',
    ScanFilterGroup.pattern,
  ),
  patternGapDown(
    'scan.filterPatternGapDown',
    'PATTERN_GAP_DOWN',
    ScanFilterGroup.pattern,
  ),

  // Price-volume divergence signals
  priceVolumeBullishDivergence(
    'scan.filterPriceVolumeBullishDivergence',
    'PRICE_VOLUME_BULLISH_DIVERGENCE',
    ScanFilterGroup.priceVolume,
  ),
  priceVolumeBearishDivergence(
    'scan.filterPriceVolumeBearishDivergence',
    'PRICE_VOLUME_BEARISH_DIVERGENCE',
    ScanFilterGroup.priceVolume,
  ),
  highVolumeBreakout(
    'scan.filterHighVolumeBreakout',
    'HIGH_VOLUME_BREAKOUT',
    ScanFilterGroup.priceVolume,
  ),
  lowVolumeAccumulation(
    'scan.filterLowVolumeAccumulation',
    'LOW_VOLUME_ACCUMULATION',
    ScanFilterGroup.priceVolume,
  ),

  // Fundamental analysis signals (基本面訊號)
  revenueYoySurge(
    'scan.filterRevenueYoySurge',
    'REVENUE_YOY_SURGE',
    ScanFilterGroup.fundamental,
  ),
  revenueYoyDecline(
    'scan.filterRevenueYoyDecline',
    'REVENUE_YOY_DECLINE',
    ScanFilterGroup.fundamental,
  ),
  revenueMomGrowth(
    'scan.filterRevenueMomGrowth',
    'REVENUE_MOM_GROWTH',
    ScanFilterGroup.fundamental,
  ),
  highDividendYield(
    'scan.filterHighDividendYield',
    'HIGH_DIVIDEND_YIELD',
    ScanFilterGroup.fundamental,
  ),
  peUndervalued(
    'scan.filterPeUndervalued',
    'PE_UNDERVALUED',
    ScanFilterGroup.fundamental,
  ),
  peOvervalued(
    'scan.filterPeOvervalued',
    'PE_OVERVALUED',
    ScanFilterGroup.fundamental,
  ),
  pbrUndervalued(
    'scan.filterPbrUndervalued',
    'PBR_UNDERVALUED',
    ScanFilterGroup.fundamental,
  );

  const ScanFilter(this.labelKey, this.reasonCode, this.group);

  /// i18n key for label - use .tr() to get translated string
  final String labelKey;
  final String? reasonCode;
  final ScanFilterGroup group;
}

/// Group for organizing scan filters in UI
enum ScanFilterGroup {
  all('scan.groupAll'),
  reversal('scan.groupReversal'),
  technical('scan.groupTechnical'),
  volume('scan.groupVolume'),
  price('scan.groupPrice'),
  indicator('scan.groupIndicator'),
  institutional('scan.groupInstitutional'),
  extendedMarket('scan.groupExtendedMarket'),
  news('scan.groupNews'),
  week52('scan.groupWeek52'),
  maAlignment('scan.groupMaAlignment'),
  pattern('scan.groupPattern'),
  priceVolume('scan.groupPriceVolume'),
  fundamental('scan.groupFundamental');

  const ScanFilterGroup(this.labelKey);

  /// i18n key for label - use .tr() to get translated string
  final String labelKey;

  /// Get all filters in this group
  List<ScanFilter> get filters =>
      ScanFilter.values.where((f) => f.group == this).toList();
}

/// Sort options for scan screen
enum ScanSort {
  scoreDesc('scan.sortScoreDesc'),
  scoreAsc('scan.sortScoreAsc'),
  priceChangeDesc('scan.sortPriceChangeDesc'),
  priceChangeAsc('scan.sortPriceChangeAsc');

  const ScanSort(this.labelKey);

  /// i18n key for label - use .tr() to get translated string
  final String labelKey;
}

/// Page size for scan screen pagination
const _kPageSize = 50;

/// State for scan screen
class ScanState {
  const ScanState({
    this.allStocks = const [], // Original unfiltered data
    this.stocks = const [], // Filtered/sorted view
    this.filter = ScanFilter.all,
    this.sort = ScanSort.scoreDesc,
    this.dataDate,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.totalCount = 0,
    this.totalAnalyzedCount = 0,
    this.error,
  });

  final List<ScanStockItem> allStocks;
  final List<ScanStockItem> stocks;
  final ScanFilter filter;
  final ScanSort sort;

  /// The actual date of the data being displayed
  final DateTime? dataDate;
  final bool isLoading;

  /// Whether more items are being loaded (infinite scroll)
  final bool isLoadingMore;

  /// Whether there are more items to load
  final bool hasMore;

  /// Total count of items matching current filter
  final int totalCount;

  /// Total count of items scanned (analyzed) today
  final int totalAnalyzedCount;

  final String? error;

  ScanState copyWith({
    List<ScanStockItem>? allStocks,
    List<ScanStockItem>? stocks,
    ScanFilter? filter,
    ScanSort? sort,
    DateTime? dataDate,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? totalCount,
    int? totalAnalyzedCount,
    String? error,
  }) {
    return ScanState(
      allStocks: allStocks ?? this.allStocks,
      stocks: stocks ?? this.stocks,
      filter: filter ?? this.filter,
      sort: sort ?? this.sort,
      dataDate: dataDate ?? this.dataDate,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      totalCount: totalCount ?? this.totalCount,
      totalAnalyzedCount: totalAnalyzedCount ?? this.totalAnalyzedCount,
      error: error,
    );
  }
}

/// Stock item in scan list
class ScanStockItem {
  const ScanStockItem({
    required this.symbol,
    required this.score,
    this.stockName,
    this.market,
    this.latestClose,
    this.priceChange,
    this.volume,
    this.trendState,
    this.reasons = const [],
    this.isInWatchlist = false,
    this.recentPrices,
  });

  final String symbol;
  final double score;
  final String? stockName;

  /// 市場：'TWSE'（上市）或 'TPEx'（上櫃）
  final String? market;
  final double? latestClose;
  final double? priceChange;
  final double? volume;
  final String? trendState;
  final List<DailyReasonEntry> reasons;
  final bool isInWatchlist;
  final List<double>? recentPrices;

  /// Get main reason label
  String? get mainReasonLabel {
    if (reasons.isEmpty) return null;
    return ReasonType.values
        .where((r) => r.code == reasons.first.reasonType)
        .firstOrNull
        ?.label;
  }

  /// Get trend icon
  String get trendIcon {
    return switch (trendState) {
      'UP' => '📈',
      'DOWN' => '📉',
      _ => '➡️',
    };
  }

  /// Create a copy with modified fields
  ScanStockItem copyWith({bool? isInWatchlist}) {
    return ScanStockItem(
      symbol: symbol,
      score: score,
      stockName: stockName,
      market: market,
      latestClose: latestClose,
      priceChange: priceChange,
      volume: volume,
      trendState: trendState,
      reasons: reasons,
      isInWatchlist: isInWatchlist ?? this.isInWatchlist,
      recentPrices: recentPrices,
    );
  }
}

// ==================================================
// Scan Notifier
// ==================================================

class ScanNotifier extends StateNotifier<ScanState> {
  ScanNotifier(this._ref) : super(const ScanState());

  final Ref _ref;

  AppDatabase get _db => _ref.read(databaseProvider);
  CachedDatabaseAccessor get _cachedDb => _ref.read(cachedDbProvider);
  DataSyncService get _dataSyncService => _ref.read(dataSyncServiceProvider);

  // Cached data for pagination
  // Cached data for pagination
  List<DailyAnalysisEntry> _allAnalyses = [];
  List<DailyAnalysisEntry> _filteredAnalyses = [];
  Map<String, List<DailyReasonEntry>> _allReasons = {};
  Set<String> _watchlistSymbols = {};
  DateContext? _dateCtx;

  /// Load scan data (first page)
  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, error: null, hasMore: true);

    try {
      // 智慧回退邏輯：依序嘗試最近 3 天的資料
      // 這處理以下情況：
      // - 週末/假日：顯示最近交易日資料
      // - 盤前：資料可能來自前一日
      // - API 日期延遲：TWSE/TPEX 資料日期可能落後
      final now = DateTime.now();
      var targetDate = DateTime(now.year, now.month, now.day);
      var analyses = <DailyAnalysisEntry>[];

      // 依序嘗試今天、昨天、前天的資料
      for (var daysAgo = 0; daysAgo <= 2; daysAgo++) {
        final date = now.subtract(Duration(days: daysAgo));
        final normalizedDate = DateTime(date.year, date.month, date.day);
        analyses = await _db.getAnalysisForDate(normalizedDate);
        if (analyses.isNotEmpty) {
          targetDate = normalizedDate;
          break;
        }
      }

      // 若最近 3 天都無資料，嘗試前一交易日（處理連續假期）
      if (analyses.isEmpty) {
        final prevTradingDay = TaiwanCalendar.getPreviousTradingDay(
          now.subtract(const Duration(days: 3)),
        );
        AppLogger.info('ScanProvider', '最近 3 天無資料，備援至前一交易日 $prevTradingDay');
        targetDate = prevTradingDay;
        analyses = await _db.getAnalysisForDate(targetDate);
      }

      // Update DateContext to reflect the actual data date
      final dateCtx = DateContext.forDate(targetDate);
      _dateCtx = dateCtx;
      _allAnalyses = analyses
          .where((a) => a.score > 0)
          .toList(); // Pre-fetch all reasons for filtering logic
      if (_allAnalyses.isNotEmpty) {
        final allSymbols = _allAnalyses.map((a) => a.symbol).toList();
        _allReasons = await _db.getReasonsBatch(allSymbols, dateCtx.today);
      } else {
        _allReasons = {};
      }

      // Get actual data dates for display purposes
      final latestPriceDate = await _db.getLatestDataDate();
      final latestInstDate = await _db.getLatestInstitutionalDate();
      final dataDate = _dataSyncService.getDisplayDataDate(
        latestPriceDate,
        latestInstDate,
      );

      // Apply initial filter (All)
      _applyGlobalFilter(ScanFilter.all);

      if (_filteredAnalyses.isEmpty) {
        state = state.copyWith(
          allStocks: [],
          stocks: [],
          dataDate: dataDate,
          isLoading: false,
          hasMore: false,
          totalCount: 0,
          totalAnalyzedCount: _allAnalyses.length,
        );
        return;
      }

      // Get watchlist for checking
      final watchlist = await _db.getWatchlist();
      _watchlistSymbols = watchlist.map((w) => w.symbol).toSet();

      // Load first page
      final firstPageItems = await _loadItemsForAnalyses(
        _filteredAnalyses.take(_kPageSize).toList(),
      );

      state = state.copyWith(
        allStocks: [], // No longer used for filtering
        stocks: firstPageItems,
        dataDate: dataDate,
        isLoading: false,
        hasMore: _filteredAnalyses.length > _kPageSize,
        totalCount: _filteredAnalyses.length,
        totalAnalyzedCount: _allAnalyses.length,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      AppLogger.error('ScanProvider', '載入資料失敗', e);
    }
  }

  /// Load more items (for infinite scroll)
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || _dateCtx == null) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final currentLen = state.stocks.length;
      final nextPageAnalyses = _filteredAnalyses
          .skip(currentLen)
          .take(_kPageSize)
          .toList();

      if (nextPageAnalyses.isEmpty) {
        state = state.copyWith(isLoadingMore: false, hasMore: false);
        return;
      }

      final newItems = await _loadItemsForAnalyses(nextPageAnalyses);

      state = state.copyWith(
        stocks: [...state.stocks, ...newItems],
        isLoadingMore: false,
        hasMore: (currentLen + newItems.length) < _filteredAnalyses.length,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  /// Set filter
  void setFilter(ScanFilter filter) {
    if (filter == state.filter) return;

    // Apply global filter
    _applyGlobalFilter(filter);

    // Reset pagination and reload first page
    state = state.copyWith(filter: filter, isLoading: true, stocks: []);
    _reloadFirstPage();
  }

  /// Helper to reload first page after filter/sort change
  Future<void> _reloadFirstPage() async {
    try {
      final firstPageItems = await _loadItemsForAnalyses(
        _filteredAnalyses.take(_kPageSize).toList(),
      );

      state = state.copyWith(
        stocks: firstPageItems,
        isLoading: false,
        hasMore: _filteredAnalyses.length > _kPageSize,
        totalCount: _filteredAnalyses.length,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Apply global filter to _allAnalyses -> _filteredAnalyses
  void _applyGlobalFilter(ScanFilter filter) {
    if (filter == ScanFilter.all) {
      _filteredAnalyses = List.from(_allAnalyses);
      return;
    }

    _filteredAnalyses = _allAnalyses.where((analysis) {
      // Must have detailed reasons loaded
      final reasons = _allReasons[analysis.symbol];
      if (reasons == null || reasons.isEmpty) return false;

      // Check if any reason matches filter code
      // Note: filter.reasonCode is a STRING code from ReasonType.
      // DailyReasonEntry.reasonType is also a STRING code.
      // They should match directly.
      if (filter.reasonCode == null) return true;

      return reasons.any((r) => r.reasonType == filter.reasonCode);
    }).toList();
  }

  /// Load detailed stock data for a batch of analyses
  Future<List<ScanStockItem>> _loadItemsForAnalyses(
    List<DailyAnalysisEntry> analyses,
  ) async {
    final dateCtx = _dateCtx;
    if (analyses.isEmpty || dateCtx == null) return [];

    final symbols = analyses.map((a) => a.symbol).toList();

    // Type-safe batch load using Dart 3 Records
    final data = await _cachedDb.loadScanData(
      symbols: symbols,
      analysisDate: dateCtx.today,
      historyStart: dateCtx.historyStart,
    );

    // Destructure Record fields
    final stocksMap = data.stocks;
    final latestPricesMap = data.latestPrices;
    final reasonsMap = data.reasons;
    final priceHistoriesMap = data.priceHistories;

    // Calculate price changes using utility
    final priceChanges = PriceCalculator.calculatePriceChangesBatch(
      priceHistoriesMap,
      latestPricesMap,
    );

    // Build stock items
    return analyses.map((analysis) {
      final latestPrice = latestPricesMap[analysis.symbol];
      final priceHistory = priceHistoriesMap[analysis.symbol];
      // 擷取最近 30 天收盤價供迷你走勢圖使用
      // priceHistory 按日期升序排列，需取最後 30 筆才是最近的資料
      List<double>? recentPrices;
      if (priceHistory != null && priceHistory.isNotEmpty) {
        final startIdx = priceHistory.length > 30
            ? priceHistory.length - 30
            : 0;
        recentPrices = priceHistory
            .sublist(startIdx)
            .map((p) => p.close)
            .whereType<double>()
            .toList();
      }
      return ScanStockItem(
        symbol: analysis.symbol,
        score: analysis.score,
        stockName: stocksMap[analysis.symbol]?.name,
        market: stocksMap[analysis.symbol]?.market,
        latestClose: latestPrice?.close,
        priceChange: priceChanges[analysis.symbol],
        volume: latestPrice?.volume,
        trendState: analysis.trendState,
        reasons: reasonsMap[analysis.symbol] ?? [],
        isInWatchlist: _watchlistSymbols.contains(analysis.symbol),
        recentPrices: recentPrices,
      );
    }).toList();
  }

  /// Set sort
  void setSort(ScanSort sort) {
    if (sort == state.sort) return;

    // Apply global sort
    _applyGlobalSort(sort);

    // Reset pagination and reload first page
    state = state.copyWith(sort: sort, isLoading: true, stocks: []);
    _reloadFirstPage();
  }

  /// Apply global sort to _filteredAnalyses
  void _applyGlobalSort(ScanSort sort) {
    // Note: DailyAnalysisEntry only has score.
    // Price change sort requires loading detailed data which we don't do globally yet.
    // For now, we fallback to score sort (or keep current order if price change requested).
    if (sort == ScanSort.scoreAsc) {
      _filteredAnalyses.sort((a, b) => a.score.compareTo(b.score));
    } else {
      // Default: Score Desc
      _filteredAnalyses.sort((b, a) => a.score.compareTo(b.score));
    }
  }

  /// Toggle watchlist for a stock
  Future<void> toggleWatchlist(String symbol) async {
    final isInWatchlist = await _db.isInWatchlist(symbol);

    if (isInWatchlist) {
      await _db.removeFromWatchlist(symbol);
    } else {
      await _db.addToWatchlist(symbol);
    }

    // Update stocks using copyWith (allStocks is unused)
    final updatedFiltered = state.stocks.map((s) {
      if (s.symbol == symbol) return s.copyWith(isInWatchlist: !isInWatchlist);
      return s;
    }).toList();

    state = state.copyWith(stocks: updatedFiltered);
  }
}

/// Provider for scan screen state
final scanProvider = StateNotifierProvider<ScanNotifier, ScanState>((ref) {
  return ScanNotifier(ref);
});
