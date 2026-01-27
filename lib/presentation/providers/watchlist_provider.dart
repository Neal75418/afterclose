import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/price_calculator.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/database/cached_accessor.dart';
import 'package:afterclose/data/repositories/warning_repository.dart';
import 'package:afterclose/data/repositories/insider_repository.dart';
import 'package:afterclose/presentation/providers/providers.dart';
import 'package:afterclose/presentation/widgets/warning_badge.dart';

// ==================================================
// Watchlist Sort Options
// ==================================================

/// Sort options for watchlist
enum WatchlistSort {
  addedDesc('加入時間（新→舊）'),
  addedAsc('加入時間（舊→新）'),
  scoreDesc('分數（高→低）'),
  scoreAsc('分數（低→高）'),
  priceChangeDesc('漲跌幅（高→低）'),
  priceChangeAsc('漲跌幅（低→高）'),
  nameAsc('名稱（A→Z）');

  const WatchlistSort(this.label);
  final String label;
}

// ==================================================
// Watchlist Group Options
// ==================================================

/// Group options for watchlist
enum WatchlistGroup {
  none('不分組'),
  status('依狀態'),
  trend('依趨勢');

  const WatchlistGroup(this.label);
  final String label;
}

/// Status category for grouping
enum WatchlistStatus {
  signal('🔥', '有訊號'),
  volatile('👀', '波動中'),
  quiet('😴', '平靜');

  const WatchlistStatus(this.icon, this.label);
  final String icon;
  final String label;
}

/// Trend category for grouping
enum WatchlistTrend {
  up('📈', '上升趨勢'),
  down('📉', '下降趨勢'),
  sideways('➡️', '盤整');

  const WatchlistTrend(this.icon, this.label);
  final String icon;
  final String label;
}

// ==================================================
// Watchlist Screen State
// ==================================================

/// State for watchlist screen
///
/// 使用快取策略：[filteredItems]、[groupedByStatus]、[groupedByTrend]
/// 僅在建構時計算一次，避免每次 build 時重複計算。
class WatchlistState {
  WatchlistState({
    this.items = const [],
    this.isLoading = false,
    this.error,
    this.sort = WatchlistSort.addedDesc,
    this.group = WatchlistGroup.none,
    this.searchQuery = '',
  }) : _filteredItems = _computeFilteredItems(items, searchQuery),
       _groupedByStatus = null,
       _groupedByTrend = null;

  /// Private constructor for copyWith to preserve cached values when appropriate
  WatchlistState._internal({
    required this.items,
    required this.isLoading,
    required this.error,
    required this.sort,
    required this.group,
    required this.searchQuery,
    required List<WatchlistItemData> filteredItems,
  }) : _filteredItems = filteredItems,
       _groupedByStatus = null,
       _groupedByTrend = null;

  final List<WatchlistItemData> items;
  final bool isLoading;
  final String? error;
  final WatchlistSort sort;
  final WatchlistGroup group;
  final String searchQuery;

  // 快取的過濾結果
  final List<WatchlistItemData> _filteredItems;
  // 延遲初始化的分組快取
  Map<WatchlistStatus, List<WatchlistItemData>>? _groupedByStatus;
  Map<WatchlistTrend, List<WatchlistItemData>>? _groupedByTrend;

  /// Filtered items based on search query (cached)
  List<WatchlistItemData> get filteredItems => _filteredItems;

  /// Grouped items by status (lazy cached)
  Map<WatchlistStatus, List<WatchlistItemData>> get groupedByStatus {
    return _groupedByStatus ??= _computeGroupedByStatus(_filteredItems);
  }

  /// Grouped items by trend (lazy cached)
  Map<WatchlistTrend, List<WatchlistItemData>> get groupedByTrend {
    return _groupedByTrend ??= _computeGroupedByTrend(_filteredItems);
  }

  /// Compute filtered items based on search query
  static List<WatchlistItemData> _computeFilteredItems(
    List<WatchlistItemData> items,
    String searchQuery,
  ) {
    if (searchQuery.isEmpty) return items;
    final query = searchQuery.toLowerCase();
    return items.where((item) {
      return item.symbol.toLowerCase().contains(query) ||
          (item.stockName?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  /// Compute grouped by status
  static Map<WatchlistStatus, List<WatchlistItemData>> _computeGroupedByStatus(
    List<WatchlistItemData> items,
  ) {
    final result = <WatchlistStatus, List<WatchlistItemData>>{};
    for (final status in WatchlistStatus.values) {
      result[status] = [];
    }
    for (final item in items) {
      result[item.status]!.add(item);
    }
    return result;
  }

  /// Compute grouped by trend
  static Map<WatchlistTrend, List<WatchlistItemData>> _computeGroupedByTrend(
    List<WatchlistItemData> items,
  ) {
    final result = <WatchlistTrend, List<WatchlistItemData>>{};
    for (final trend in WatchlistTrend.values) {
      result[trend] = [];
    }
    for (final item in items) {
      result[item.trend]!.add(item);
    }
    return result;
  }

  WatchlistState copyWith({
    List<WatchlistItemData>? items,
    bool? isLoading,
    String? error,
    WatchlistSort? sort,
    WatchlistGroup? group,
    String? searchQuery,
  }) {
    final newItems = items ?? this.items;
    final newSearchQuery = searchQuery ?? this.searchQuery;

    // 若 items 或 searchQuery 變更，需重新計算 filteredItems
    final needsRecompute =
        items != null ||
        (searchQuery != null && searchQuery != this.searchQuery);

    if (needsRecompute) {
      return WatchlistState(
        items: newItems,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        sort: sort ?? this.sort,
        group: group ?? this.group,
        searchQuery: newSearchQuery,
      );
    }

    // 若只是 isLoading/error/sort/group 變更，保留現有快取
    return WatchlistState._internal(
      items: newItems,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      sort: sort ?? this.sort,
      group: group ?? this.group,
      searchQuery: newSearchQuery,
      filteredItems: _filteredItems,
    );
  }
}

/// Data class for watchlist item
class WatchlistItemData {
  const WatchlistItemData({
    required this.symbol,
    this.stockName,
    this.market,
    this.latestClose,
    this.priceChange,
    this.trendState,
    this.score,
    this.hasSignal = false,
    this.addedAt,
    this.recentPrices = const [],
    this.reasons = const [],
    this.warningType,
  });

  final String symbol;
  final String? stockName;

  /// 市場：'TWSE'（上市）或 'TPEx'（上櫃）
  final String? market;
  final double? latestClose;
  final double? priceChange;
  final String? trendState;
  final double? score;
  final bool hasSignal;
  final DateTime? addedAt;
  final List<double> recentPrices;
  final List<String> reasons;

  /// 警示類型（處置 > 注意 > 高質押），用於顯示警示標記
  final WarningBadgeType? warningType;

  /// Get status category
  WatchlistStatus get status {
    if (hasSignal) return WatchlistStatus.signal;
    if ((priceChange?.abs() ?? 0) >= 3) {
      return WatchlistStatus.volatile;
    }
    return WatchlistStatus.quiet;
  }

  /// Get trend category
  WatchlistTrend get trend {
    return switch (trendState) {
      'UP' => WatchlistTrend.up,
      'DOWN' => WatchlistTrend.down,
      _ => WatchlistTrend.sideways,
    };
  }

  String get statusIcon => status.icon;
}

// ==================================================
// Watchlist Notifier
// ==================================================

class WatchlistNotifier extends StateNotifier<WatchlistState> {
  WatchlistNotifier(this._ref) : super(WatchlistState());

  final Ref _ref;

  AppDatabase get _db => _ref.read(databaseProvider);
  CachedDatabaseAccessor get _cachedDb => _ref.read(cachedDbProvider);
  WarningRepository get _warningRepo => _ref.read(warningRepositoryProvider);
  InsiderRepository get _insiderRepo => _ref.read(insiderRepositoryProvider);

  /// Load watchlist data
  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final dateCtx = DateContext.now();

      final watchlist = await _db.getWatchlist();
      if (watchlist.isEmpty) {
        state = state.copyWith(items: [], isLoading: false);
        return;
      }

      // Collect all symbols for batch queries
      final symbols = watchlist.map((w) => w.symbol).toList();

      // 取得實際資料日期，確保非交易日也能正確顯示趨勢
      final latestDataDate = await _db.getLatestDataDate();
      final analysisDate = latestDataDate != null
          ? DateContext.normalize(latestDataDate)
          : dateCtx.today;

      // Type-safe batch load using Dart 3 Records (no manual casting needed)
      final data = await _cachedDb.loadStockListData(
        symbols: symbols,
        analysisDate: analysisDate,
        historyStart: dateCtx.historyStart,
      );

      // Destructure Record fields - compile-time type safety!
      final stocksMap = data.stocks;
      final latestPricesMap = data.latestPrices;
      final analysesMap = data.analyses;
      final reasonsMap = data.reasons;
      final priceHistoriesMap = data.priceHistories;

      // Calculate price changes using utility
      final priceChanges = PriceCalculator.calculatePriceChangesBatch(
        priceHistoriesMap,
        latestPricesMap,
      );

      // Fetch warning data for watchlist (Killer Features)
      final warningsMap = await _warningRepo.getWatchlistWarnings(symbols);
      final highPledgeMap = await _insiderRepo.getWatchlistHighPledgeStocks(
        symbols,
        threshold: RuleParams.highPledgeRatioThreshold,
      );

      // Build items from batch results
      final items = watchlist.map((item) {
        final stock = stocksMap[item.symbol];
        final latestPrice = latestPricesMap[item.symbol];
        final analysis = analysesMap[item.symbol];
        final reasons = reasonsMap[item.symbol] ?? [];
        final priceHistory = priceHistoriesMap[item.symbol] ?? [];

        // Extract recent prices for sparkline (last 20 days)
        final recentPrices = PriceCalculator.extractSparklinePrices(
          priceHistory,
        );

        // Determine warning type (priority: disposal > attention > highPledge)
        final warningType = _determineWarningType(
          symbol: item.symbol,
          warningsMap: warningsMap,
          highPledgeMap: highPledgeMap,
        );

        return WatchlistItemData(
          symbol: item.symbol,
          stockName: stock?.name,
          market: stock?.market,
          latestClose: latestPrice?.close,
          priceChange: priceChanges[item.symbol],
          trendState: analysis?.trendState,
          score: analysis?.score,
          hasSignal: reasons.isNotEmpty,
          addedAt: item.createdAt,
          recentPrices: recentPrices,
          reasons: reasons.map((r) => r.reasonType).toList(),
          warningType: warningType,
        );
      }).toList();

      // Sort items
      final sortedItems = _sortItems(items, state.sort);

      state = state.copyWith(items: sortedItems, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Sort items based on specified sort option
  List<WatchlistItemData> _sortItems(
    List<WatchlistItemData> items,
    WatchlistSort sort,
  ) {
    final sorted = List<WatchlistItemData>.from(items);
    switch (sort) {
      case WatchlistSort.addedDesc:
        sorted.sort((a, b) => _compareDatesNullLast(b.addedAt, a.addedAt));
      case WatchlistSort.addedAsc:
        sorted.sort((a, b) => _compareDatesNullLast(a.addedAt, b.addedAt));
      case WatchlistSort.scoreDesc:
        sorted.sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));
      case WatchlistSort.scoreAsc:
        sorted.sort((a, b) => (a.score ?? 0).compareTo(b.score ?? 0));
      case WatchlistSort.priceChangeDesc:
        sorted.sort(
          (a, b) => (b.priceChange ?? 0).compareTo(a.priceChange ?? 0),
        );
      case WatchlistSort.priceChangeAsc:
        sorted.sort(
          (a, b) => (a.priceChange ?? 0).compareTo(b.priceChange ?? 0),
        );
      case WatchlistSort.nameAsc:
        sorted.sort((a, b) => a.symbol.compareTo(b.symbol));
    }
    return sorted;
  }

  /// 比較日期，null 值排在最後
  int _compareDatesNullLast(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1; // a 是 null，排在後面
    if (b == null) return -1; // b 是 null，排在後面
    return a.compareTo(b);
  }

  /// 判斷警示類型（優先級：處置 > 注意 > 高質押）
  WarningBadgeType? _determineWarningType({
    required String symbol,
    required Map<String, TradingWarningEntry> warningsMap,
    required Map<String, InsiderHoldingEntry> highPledgeMap,
  }) {
    final warning = warningsMap[symbol];
    if (warning != null) {
      if (warning.warningType == 'DISPOSAL') {
        return WarningBadgeType.disposal;
      }
      return WarningBadgeType.attention;
    }
    if (highPledgeMap.containsKey(symbol)) {
      return WarningBadgeType.highPledge;
    }
    return null;
  }

  /// Set sort option
  void setSort(WatchlistSort sort) {
    if (state.sort == sort) return;
    final sortedItems = _sortItems(state.items, sort);
    state = state.copyWith(sort: sort, items: sortedItems);
  }

  /// Set group option
  void setGroup(WatchlistGroup group) {
    state = state.copyWith(group: group);
  }

  /// Set search query
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Add stock to watchlist
  Future<bool> addStock(String symbol) async {
    // Check if stock exists
    final stock = await _db.getStock(symbol);
    if (stock == null) {
      return false;
    }

    // Check if already in watchlist
    final existingSymbols = state.items.map((i) => i.symbol).toSet();
    if (existingSymbols.contains(symbol)) {
      return true;
    }

    try {
      // Persist to database
      await _db.addToWatchlist(symbol);

      // 從資料庫讀取實際的 createdAt，確保與 loadData 一致
      final watchlistEntry = await _db.getWatchlistEntry(symbol);
      final actualAddedAt = watchlistEntry?.createdAt ?? DateTime.now();

      // Incremental update: load data only for this stock
      final itemData = await _loadSingleStockData(
        symbol,
        stock.name,
        stock.market,
        addedAt: actualAddedAt,
      );
      final newItems = [...state.items, itemData];
      state = state.copyWith(items: _sortItems(newItems, state.sort));

      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Remove stock from watchlist
  ///
  /// 使用樂觀更新策略：先更新 UI，若資料庫操作失敗則回滾至先前狀態。
  /// 保存完整的狀態快照以確保回滾時排序與分組設定一致。
  Future<void> removeStock(String symbol) async {
    // 保存完整狀態快照以便回滾（包含排序、分組等設定）
    final previousState = state;

    // 樂觀更新：立即從狀態中移除
    state = state.copyWith(
      items: state.items.where((item) => item.symbol != symbol).toList(),
    );

    try {
      await _db.removeFromWatchlist(symbol);
    } catch (e) {
      // 回滾至完整的先前狀態，確保排序順序一致
      state = previousState.copyWith(error: e.toString());
    }
  }

  /// Restore a removed stock
  Future<void> restoreStock(String symbol) async {
    try {
      await _db.addToWatchlist(symbol);

      // 從資料庫讀取實際的 createdAt，確保與 loadData 一致
      final watchlistEntry = await _db.getWatchlistEntry(symbol);
      final actualAddedAt = watchlistEntry?.createdAt ?? DateTime.now();

      // Incremental update: load data only for this stock
      final stock = await _db.getStock(symbol);
      final itemData = await _loadSingleStockData(
        symbol,
        stock?.name,
        stock?.market,
        addedAt: actualAddedAt,
      );
      final newItems = [...state.items, itemData];
      state = state.copyWith(items: _sortItems(newItems, state.sort));
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Load data for a single stock (used for incremental updates)
  ///
  /// [addedAt] 應從資料庫的 watchlist entry 取得，以確保與 loadData 一致。
  /// 若未提供則使用當前時間作為 fallback。
  Future<WatchlistItemData> _loadSingleStockData(
    String symbol,
    String? stockName,
    String? market, {
    DateTime? addedAt,
  }) async {
    final dateCtx = DateContext.now();

    // 取得實際資料日期，確保非交易日也能正確顯示趨勢
    final latestDataDate = await _db.getLatestDataDate();
    final analysisDate = latestDataDate != null
        ? DateContext.normalize(latestDataDate)
        : dateCtx.today;

    // Batch load data for this single stock
    final results = await Future.wait([
      _db.getLatestPrice(symbol),
      _db.getAnalysis(symbol, analysisDate),
      _db.getReasons(symbol, analysisDate),
      _db.getPriceHistory(
        symbol,
        startDate: dateCtx.historyStart,
        endDate: dateCtx.today,
      ),
    ]);

    final latestPrice = results[0] as DailyPriceEntry?;
    final analysis = results[1] as DailyAnalysisEntry?;
    final reasons = results[2] as List<DailyReasonEntry>;
    final priceHistory = results[3] as List<DailyPriceEntry>;

    // Calculate price change
    double? priceChange;
    final latestClose = latestPrice?.close;
    if (latestClose != null && priceHistory.length >= 2) {
      final previousPrice = priceHistory
          .where((p) => p.date.isBefore(latestPrice!.date))
          .toList();
      if (previousPrice.isNotEmpty) {
        final prevClose = previousPrice.first.close;
        if (prevClose != null && prevClose > 0) {
          priceChange = ((latestClose - prevClose) / prevClose) * 100;
        }
      }
    }

    // Extract recent prices for sparkline
    final recentPrices = PriceCalculator.extractSparklinePrices(priceHistory);

    // Fetch warning data for this stock (Killer Features)
    final warningsMap = await _warningRepo.getWatchlistWarnings([symbol]);
    final highPledgeMap = await _insiderRepo.getWatchlistHighPledgeStocks([
      symbol,
    ], threshold: RuleParams.highPledgeRatioThreshold);
    final warningType = _determineWarningType(
      symbol: symbol,
      warningsMap: warningsMap,
      highPledgeMap: highPledgeMap,
    );

    return WatchlistItemData(
      symbol: symbol,
      stockName: stockName,
      market: market,
      latestClose: latestPrice?.close,
      priceChange: priceChange,
      trendState: analysis?.trendState,
      score: analysis?.score,
      hasSignal: reasons.isNotEmpty,
      addedAt: addedAt ?? DateTime.now(),
      recentPrices: recentPrices,
      reasons: reasons.map((r) => r.reasonType).toList(),
      warningType: warningType,
    );
  }
}

/// Provider for watchlist screen state
final watchlistProvider =
    StateNotifierProvider<WatchlistNotifier, WatchlistState>((ref) {
      return WatchlistNotifier(ref);
    });
