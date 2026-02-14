import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart'
    show StateNotifier, StateNotifierProvider;

import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/database/cached_accessor.dart';
import 'package:afterclose/data/repositories/analysis_repository.dart';
import 'package:afterclose/domain/models/scan_models.dart';
import 'package:afterclose/domain/services/data_sync_service.dart';
import 'package:afterclose/domain/services/scan_filter_service.dart';
import 'package:afterclose/core/constants/pagination.dart';
import 'package:afterclose/presentation/providers/providers.dart';

// Re-export scan models for backward compatibility
export 'package:afterclose/domain/models/scan_models.dart';

// ==================================================
// Scan Screen State
// ==================================================

/// State for scan screen
class ScanState {
  const ScanState({
    this.allStocks = const [], // Original unfiltered data
    this.stocks = const [], // Filtered/sorted view
    this.filter = ScanFilter.all,
    this.sort = ScanSort.scoreDesc,
    this.industryFilter,
    this.industries = const [],
    this.dataDate,
    this.isLoading = false,
    this.isFiltering = false,
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

  /// 目前選擇的產業篩選（null 表示不限產業）
  final String? industryFilter;

  /// 所有可選產業列表
  final List<String> industries;

  /// The actual date of the data being displayed
  final DateTime? dataDate;

  /// 首次載入或 pull-to-refresh
  final bool isLoading;

  /// 篩選器/排序切換中（輕量 loading，不顯示全骨架）
  final bool isFiltering;

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
    String? industryFilter,
    bool clearIndustryFilter = false,
    List<String>? industries,
    DateTime? dataDate,
    bool? isLoading,
    bool? isFiltering,
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
      industryFilter: clearIndustryFilter
          ? null
          : (industryFilter ?? this.industryFilter),
      industries: industries ?? this.industries,
      dataDate: dataDate ?? this.dataDate,
      isLoading: isLoading ?? this.isLoading,
      isFiltering: isFiltering ?? this.isFiltering,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      totalCount: totalCount ?? this.totalCount,
      totalAnalyzedCount: totalAnalyzedCount ?? this.totalAnalyzedCount,
      error: error,
    );
  }
}

/// Stock item in scan list

// ==================================================
// Scan Notifier
// ==================================================

class ScanNotifier extends StateNotifier<ScanState> {
  ScanNotifier(this._ref) : super(const ScanState());

  final Ref _ref;

  AppDatabase get _db => _ref.read(databaseProvider);
  CachedDatabaseAccessor get _cachedDb => _ref.read(cachedDbProvider);
  DataSyncService get _dataSyncService => _ref.read(dataSyncServiceProvider);
  AnalysisRepository get _analysisRepo => _ref.read(analysisRepositoryProvider);

  static const _service = ScanFilterService();

  // Cached data for pagination
  List<DailyAnalysisEntry> _allAnalyses = [];
  List<DailyAnalysisEntry> _filteredAnalyses = [];
  Map<String, List<DailyReasonEntry>> _allReasons = {};
  Set<String> _watchlistSymbols = {};
  Set<String>? _industrySymbols; // 產業篩選用
  int _industryFilterSeq = 0; // 防護 race condition
  List<String>? _cachedIndustries; // 產業列表快取
  DateContext? _dateCtx;

  /// Load scan data (first page)
  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, error: null, hasMore: true);

    try {
      // 智慧回退：找到最近有資料的日期（統一由 Repository 處理日期正規化）
      final result = await _analysisRepo.findLatestAnalyses();
      final targetDate = result.targetDate;
      final analyses = result.analyses;

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

      // 載入產業列表（使用快取）
      final industries = _cachedIndustries ?? await _db.getDistinctIndustries();
      _cachedIndustries = industries;

      // 保留使用者的產業篩選（pull-to-refresh 不應清除）
      if (state.industryFilter != null) {
        _industrySymbols = await _db.getSymbolsByIndustry(
          state.industryFilter!,
        );
      } else {
        _industrySymbols = null;
      }

      // 套用現有篩選條件（保留 filter + industry）
      _applyGlobalFilter(state.filter);

      if (_filteredAnalyses.isEmpty) {
        state = state.copyWith(
          allStocks: [],
          stocks: [],
          industries: industries,
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
        _filteredAnalyses.take(kPageSize).toList(),
      );

      state = state.copyWith(
        allStocks: [], // No longer used for filtering
        stocks: firstPageItems,
        industries: industries,
        dataDate: dataDate,
        isLoading: false,
        hasMore: _filteredAnalyses.length > kPageSize,
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
          .take(kPageSize)
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

    // 篩選切換使用 isFiltering（輕量 indicator），不替換為全骨架
    state = state.copyWith(filter: filter, isFiltering: true, stocks: []);
    _reloadFirstPage();
  }

  /// 設定產業篩選
  Future<void> setIndustryFilter(String? industry) async {
    if (industry == state.industryFilter) return;

    final seq = ++_industryFilterSeq;

    // 先更新 UI 狀態，避免連點時重複觸發
    state = state.copyWith(
      industryFilter: industry,
      clearIndustryFilter: industry == null,
      isFiltering: true,
      stocks: [],
    );

    if (industry != null) {
      final symbols = await _db.getSymbolsByIndustry(industry);
      // 防護 race condition：async 完成後確認序號未變
      if (seq != _industryFilterSeq) return;
      _industrySymbols = symbols;
    } else {
      _industrySymbols = null;
    }

    // 重新套用目前的 filter（含產業）
    _applyGlobalFilter(state.filter);
    _reloadFirstPage();
  }

  /// Helper to reload first page after filter/sort change
  Future<void> _reloadFirstPage() async {
    try {
      final firstPageItems = await _loadItemsForAnalyses(
        _filteredAnalyses.take(kPageSize).toList(),
      );

      state = state.copyWith(
        stocks: firstPageItems,
        isLoading: false,
        isFiltering: false,
        hasMore: _filteredAnalyses.length > kPageSize,
        totalCount: _filteredAnalyses.length,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isFiltering: false,
        error: e.toString(),
      );
    }
  }

  /// Apply global filter to _allAnalyses -> _filteredAnalyses
  void _applyGlobalFilter(ScanFilter filter) {
    _filteredAnalyses = _service.applyFilter(
      allAnalyses: _allAnalyses,
      filter: filter,
      allReasons: _allReasons,
      industrySymbols: _industrySymbols,
    );
  }

  /// Load detailed stock data for a batch of analyses
  Future<List<ScanStockItem>> _loadItemsForAnalyses(
    List<DailyAnalysisEntry> analyses,
  ) async {
    final dateCtx = _dateCtx;
    if (analyses.isEmpty || dateCtx == null) return [];

    return _service.buildStockItems(
      analyses: analyses,
      dateCtx: dateCtx,
      cachedDb: _cachedDb,
      watchlistSymbols: _watchlistSymbols,
    );
  }

  /// Set sort
  void setSort(ScanSort sort) {
    if (sort == state.sort) return;

    // Apply global sort
    _applyGlobalSort(sort);

    // 排序切換使用 isFiltering（輕量 indicator）
    state = state.copyWith(sort: sort, isFiltering: true, stocks: []);
    _reloadFirstPage();
  }

  /// Apply global sort to _filteredAnalyses
  void _applyGlobalSort(ScanSort sort) {
    _service.applySort(_filteredAnalyses, sort);
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
