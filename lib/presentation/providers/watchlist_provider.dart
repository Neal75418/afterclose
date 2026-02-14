import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/constants/pagination.dart';
import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/sentinel.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/price_calculator.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/database/cached_accessor.dart';
import 'package:afterclose/data/repositories/warning_repository.dart';
import 'package:afterclose/data/repositories/insider_repository.dart';
import 'package:afterclose/presentation/providers/providers.dart';
import 'package:afterclose/presentation/providers/watchlist_types.dart';
import 'package:afterclose/presentation/widgets/warning_badge.dart';

export 'package:afterclose/presentation/providers/watchlist_types.dart';

// ==================================================
// 自選股頁面狀態
// ==================================================

/// 自選股頁面狀態
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
    this.isLoadingMore = false,
    this.hasMore = true,
    this.displayedCount = kPageSize,
  }) : _filteredItems = _computeFilteredItems(items, searchQuery),
       _groupedByStatus = null,
       _groupedByTrend = null;

  /// 內部建構子：copyWith 時保留快取值
  WatchlistState._internal({
    required this.items,
    required this.isLoading,
    required this.error,
    required this.sort,
    required this.group,
    required this.searchQuery,
    required this.isLoadingMore,
    required this.hasMore,
    required this.displayedCount,
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

  /// 是否正在載入更多（無限滾動）
  final bool isLoadingMore;

  /// 是否還有更多資料可載入
  final bool hasMore;

  /// 目前已顯示的數量
  final int displayedCount;

  // 快取的過濾結果
  final List<WatchlistItemData> _filteredItems;
  // 延遲初始化的分組快取
  Map<WatchlistStatus, List<WatchlistItemData>>? _groupedByStatus;
  Map<WatchlistTrend, List<WatchlistItemData>>? _groupedByTrend;

  /// 搜尋過濾後的項目（已快取）
  List<WatchlistItemData> get filteredItems => _filteredItems;

  /// 目前顯示的項目（分頁後）
  List<WatchlistItemData> get displayedItems {
    return _filteredItems.take(displayedCount).toList();
  }

  /// 依狀態分組（延遲初始化快取）
  Map<WatchlistStatus, List<WatchlistItemData>> get groupedByStatus {
    return _groupedByStatus ??= _computeGroupedByStatus(_filteredItems);
  }

  /// 依趨勢分組（延遲初始化快取）
  Map<WatchlistTrend, List<WatchlistItemData>> get groupedByTrend {
    return _groupedByTrend ??= _computeGroupedByTrend(_filteredItems);
  }

  /// 根據搜尋關鍵字計算過濾結果
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

  /// 計算狀態分組
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

  /// 計算趨勢分組
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
    Object? error = sentinel,
    WatchlistSort? sort,
    WatchlistGroup? group,
    String? searchQuery,
    bool? isLoadingMore,
    bool? hasMore,
    int? displayedCount,
  }) {
    final newItems = items ?? this.items;
    final newSearchQuery = searchQuery ?? this.searchQuery;
    final newError = error == sentinel ? this.error : error as String?;

    // 若 items 或 searchQuery 變更，需重新計算 filteredItems
    final needsRecompute =
        items != null ||
        (searchQuery != null && searchQuery != this.searchQuery);

    if (needsRecompute) {
      return WatchlistState(
        items: newItems,
        isLoading: isLoading ?? this.isLoading,
        error: newError,
        sort: sort ?? this.sort,
        group: group ?? this.group,
        searchQuery: newSearchQuery,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        displayedCount: displayedCount ?? this.displayedCount,
      );
    }

    // 若只是 isLoading/error/sort/group 變更，保留現有快取
    return WatchlistState._internal(
      items: newItems,
      isLoading: isLoading ?? this.isLoading,
      error: newError,
      sort: sort ?? this.sort,
      group: group ?? this.group,
      searchQuery: newSearchQuery,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      displayedCount: displayedCount ?? this.displayedCount,
      filteredItems: _filteredItems,
    );
  }
}

// ==================================================
// 自選股 Notifier
// ==================================================

class WatchlistNotifier extends Notifier<WatchlistState> {
  @override
  WatchlistState build() => WatchlistState();

  AppDatabase get _db => ref.read(databaseProvider);
  CachedDatabaseAccessor get _cachedDb => ref.read(cachedDbProvider);
  WarningRepository get _warningRepo => ref.read(warningRepositoryProvider);
  InsiderRepository get _insiderRepo => ref.read(insiderRepositoryProvider);

  /// 載入自選股資料
  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final dateCtx = DateContext.now();

      final watchlist = await _db.getWatchlist();
      if (watchlist.isEmpty) {
        state = state.copyWith(items: [], isLoading: false);
        return;
      }

      // 收集所有代號進行批次查詢
      final symbols = watchlist.map((w) => w.symbol).toList();

      // 取得實際資料日期，確保非交易日也能正確顯示趨勢
      final latestDataDate = await _db.getLatestDataDate();
      final analysisDate = latestDataDate != null
          ? DateContext.normalize(latestDataDate)
          : dateCtx.today;

      // 使用 Dart 3 Records 進行型別安全的批次載入
      final data = await _cachedDb.loadStockListData(
        symbols: symbols,
        analysisDate: analysisDate,
        historyStart: dateCtx.historyStart,
      );

      // 解構 Record 欄位
      final stocksMap = data.stocks;
      final latestPricesMap = data.latestPrices;
      final analysesMap = data.analyses;
      final reasonsMap = data.reasons;
      final priceHistoriesMap = data.priceHistories;

      // 計算漲跌幅
      final priceChanges = PriceCalculator.calculatePriceChangesBatch(
        priceHistoriesMap,
        latestPricesMap,
      );

      // 取得自選股警示資料
      final warningsMap = await _warningRepo.getWatchlistWarnings(symbols);
      final highPledgeMap = await _insiderRepo.getWatchlistHighPledgeStocks(
        symbols,
        threshold: RuleParams.highPledgeRatioThreshold,
      );

      // 從批次結果建構項目
      final items = watchlist.map((item) {
        final stock = stocksMap[item.symbol];
        final latestPrice = latestPricesMap[item.symbol];
        final analysis = analysesMap[item.symbol];
        final reasons = reasonsMap[item.symbol] ?? [];
        final priceHistory = priceHistoriesMap[item.symbol] ?? [];

        // 提取近期價格用於 sparkline
        final recentPrices = PriceCalculator.extractSparklinePrices(
          priceHistory,
        );

        // 判斷警示類型（優先級：處置 > 注意 > 高質押）
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

      // 排序
      final sortedItems = _sortItems(items, state.sort);

      // 初始化分頁狀態
      final hasMore = sortedItems.length > kPageSize;
      final displayedCount = hasMore ? kPageSize : sortedItems.length;

      state = state.copyWith(
        items: sortedItems,
        isLoading: false,
        hasMore: hasMore,
        displayedCount: displayedCount,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 載入更多自選股（無限滾動）
  Future<void> loadMore() async {
    // 防止重複載入
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      // 計算下一頁的範圍
      final currentCount = state.displayedCount;
      final totalCount = state.filteredItems.length;
      const nextPageSize = kPageSize;
      final newDisplayedCount = (currentCount + nextPageSize).clamp(
        0,
        totalCount,
      );

      // 更新狀態
      state = state.copyWith(
        displayedCount: newDisplayedCount,
        hasMore: newDisplayedCount < totalCount,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// 依指定選項排序
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

  /// 設定排序選項
  void setSort(WatchlistSort sort) {
    if (state.sort == sort) return;
    final sortedItems = _sortItems(state.items, sort);
    state = state.copyWith(sort: sort, items: sortedItems);
  }

  /// 設定分組選項
  void setGroup(WatchlistGroup group) {
    state = state.copyWith(group: group);
  }

  /// 設定搜尋關鍵字
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// 新增股票至自選股
  Future<bool> addStock(String symbol) async {
    // 檢查股票是否存在
    final stock = await _db.getStock(symbol);
    if (stock == null) {
      return false;
    }

    // 檢查是否已在自選股中
    final existingSymbols = state.items.map((i) => i.symbol).toSet();
    if (existingSymbols.contains(symbol)) {
      return true;
    }

    try {
      // 寫入資料庫
      await _db.addToWatchlist(symbol);

      // 從資料庫讀取實際的 createdAt，確保與 loadData 一致
      final watchlistEntry = await _db.getWatchlistEntry(symbol);
      final actualAddedAt = watchlistEntry?.createdAt ?? DateTime.now();

      // 增量更新：僅載入此股票資料
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

  /// 還原已移除的股票
  Future<void> restoreStock(String symbol) async {
    try {
      await _db.addToWatchlist(symbol);

      // 從資料庫讀取實際的 createdAt，確保與 loadData 一致
      final watchlistEntry = await _db.getWatchlistEntry(symbol);
      final actualAddedAt = watchlistEntry?.createdAt ?? DateTime.now();

      // 增量更新：僅載入此股票資料
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

  /// 載入單一股票資料（用於增量更新）
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

    // 批次載入此股票的資料
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

    // Calculate price change（統一使用 PriceCalculator，優先取 API 漲跌價差）
    final priceChange = PriceCalculator.calculatePriceChange(
      priceHistory,
      latestPrice,
    );

    // 提取近期價格用於 sparkline
    final recentPrices = PriceCalculator.extractSparklinePrices(priceHistory);

    // 取得此股票的警示資料
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

/// 自選股頁面狀態 Provider
final watchlistProvider = NotifierProvider<WatchlistNotifier, WatchlistState>(
  WatchlistNotifier.new,
);
