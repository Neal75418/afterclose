import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/price_calculator.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/database/cached_accessor.dart';
import 'package:afterclose/presentation/providers/providers.dart';

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
  institutionalShift(
    'scan.filterInstitutionalShift',
    'INSTITUTIONAL_SHIFT',
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

  // Cached data for pagination
  List<DailyAnalysisEntry> _allAnalyses = [];
  Set<String> _watchlistSymbols = {};
  DateContext? _dateCtx;

  /// Load scan data (first page)
  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, error: null, hasMore: true);

    try {
      // Use today's date for querying (update_service stores with this date)
      _dateCtx = DateContext.now();

      // Get all analyses for today (with score > 0) - lightweight metadata only
      final analyses = await _db.getAnalysisForDate(_dateCtx!.today);
      _allAnalyses = analyses.where((a) => a.score > 0).toList();

      // Get actual data dates for display purposes (not for querying)
      final latestPriceDate = await _db.getLatestDataDate();
      final latestInstDate = await _db.getLatestInstitutionalDate();

      // Calculate dataDate for display - use the earlier of the two dates
      final dataDate = DateContext.earlierOf(latestPriceDate, latestInstDate);

      if (_allAnalyses.isEmpty) {
        state = state.copyWith(
          allStocks: [],
          stocks: [],
          dataDate: dataDate,
          isLoading: false,
          hasMore: false,
          totalCount: 0,
        );
        return;
      }

      // Get watchlist for checking
      final watchlist = await _db.getWatchlist();
      _watchlistSymbols = watchlist.map((w) => w.symbol).toSet();

      // Load first page of detailed data
      final firstPageItems = await _loadItemsForAnalyses(
        _allAnalyses.take(_kPageSize).toList(),
      );

      state = state.copyWith(
        allStocks: firstPageItems,
        stocks: _applySort(
          _applyFilter(firstPageItems, state.filter),
          state.sort,
        ),
        dataDate: dataDate,
        isLoading: false,
        hasMore: _allAnalyses.length > _kPageSize,
        totalCount: _allAnalyses.length,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Load more items (for infinite scroll)
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || _dateCtx == null) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final currentCount = state.allStocks.length;
      final remainingAnalyses = _allAnalyses
          .skip(currentCount)
          .take(_kPageSize)
          .toList();

      if (remainingAnalyses.isEmpty) {
        state = state.copyWith(isLoadingMore: false, hasMore: false);
        return;
      }

      final newItems = await _loadItemsForAnalyses(remainingAnalyses);
      final updatedAll = [...state.allStocks, ...newItems];

      // Reapply filter and sort
      final filtered = _applyFilter(updatedAll, state.filter);
      final sorted = _applySort(filtered, state.sort);

      state = state.copyWith(
        allStocks: updatedAll,
        stocks: sorted,
        isLoadingMore: false,
        hasMore: updatedAll.length < _allAnalyses.length,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  /// Load detailed stock data for a batch of analyses
  Future<List<ScanStockItem>> _loadItemsForAnalyses(
    List<DailyAnalysisEntry> analyses,
  ) async {
    if (analyses.isEmpty || _dateCtx == null) return [];

    final symbols = analyses.map((a) => a.symbol).toList();

    // Type-safe batch load using Dart 3 Records
    final data = await _cachedDb.loadScanData(
      symbols: symbols,
      analysisDate: _dateCtx!.today,
      historyStart: _dateCtx!.historyStart,
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
      // Extract close prices for sparkline (limit to 30 days for performance)
      final recentPrices = priceHistory
          ?.take(30)
          .map((p) => p.close)
          .whereType<double>()
          .toList();
      return ScanStockItem(
        symbol: analysis.symbol,
        score: analysis.score,
        stockName: stocksMap[analysis.symbol]?.name,
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

  /// Set filter - filters from original data, not already-filtered data
  void setFilter(ScanFilter filter) {
    if (filter == state.filter) return;

    // Filter from original unfiltered data
    final filtered = _applyFilter(state.allStocks, filter);
    final sorted = _applySort(filtered, state.sort);

    state = state.copyWith(filter: filter, stocks: sorted);
  }

  /// Set sort
  void setSort(ScanSort sort) {
    if (sort == state.sort) return;

    // Re-filter then sort to ensure consistent state
    final filtered = _applyFilter(state.allStocks, state.filter);
    final sorted = _applySort(filtered, sort);

    state = state.copyWith(sort: sort, stocks: sorted);
  }

  /// Apply filter to stocks
  List<ScanStockItem> _applyFilter(
    List<ScanStockItem> stocks,
    ScanFilter filter,
  ) {
    if (filter == ScanFilter.all || filter.reasonCode == null) {
      return List.from(stocks);
    }

    return stocks
        .where((s) => s.reasons.any((r) => r.reasonType == filter.reasonCode))
        .toList();
  }

  /// Apply sort to stocks
  List<ScanStockItem> _applySort(List<ScanStockItem> stocks, ScanSort sort) {
    final sorted = List<ScanStockItem>.from(stocks);

    switch (sort) {
      case ScanSort.scoreDesc:
        sorted.sort((a, b) => b.score.compareTo(a.score));
      case ScanSort.scoreAsc:
        sorted.sort((a, b) => a.score.compareTo(b.score));
      case ScanSort.priceChangeDesc:
        sorted.sort((a, b) {
          final aChange = a.priceChange ?? double.negativeInfinity;
          final bChange = b.priceChange ?? double.negativeInfinity;
          return bChange.compareTo(aChange);
        });
      case ScanSort.priceChangeAsc:
        sorted.sort((a, b) {
          final aChange = a.priceChange ?? double.infinity;
          final bChange = b.priceChange ?? double.infinity;
          return aChange.compareTo(bChange);
        });
    }

    return sorted;
  }

  /// Toggle watchlist for a stock
  Future<void> toggleWatchlist(String symbol) async {
    final isInWatchlist = await _db.isInWatchlist(symbol);

    if (isInWatchlist) {
      await _db.removeFromWatchlist(symbol);
    } else {
      await _db.addToWatchlist(symbol);
    }

    // Update both allStocks and stocks using copyWith
    final updatedAll = state.allStocks.map((s) {
      if (s.symbol == symbol) return s.copyWith(isInWatchlist: !isInWatchlist);
      return s;
    }).toList();

    final updatedFiltered = state.stocks.map((s) {
      if (s.symbol == symbol) return s.copyWith(isInWatchlist: !isInWatchlist);
      return s;
    }).toList();

    state = state.copyWith(allStocks: updatedAll, stocks: updatedFiltered);
  }
}

/// Provider for scan screen state
final scanProvider = StateNotifierProvider<ScanNotifier, ScanState>((ref) {
  return ScanNotifier(ref);
});
