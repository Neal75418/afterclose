import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/constants/calibrated_scores/horizon.dart';
import 'package:afterclose/core/constants/pagination.dart';
import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/error_display.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/database/cached_accessor.dart';
import 'package:afterclose/data/repositories/analysis_repository.dart';
import 'package:afterclose/data/repositories/market_data_repository.dart';
import 'package:afterclose/domain/models/scan_models.dart';
import 'package:afterclose/domain/services/data_sync_service.dart';
import 'package:afterclose/domain/services/scan_filter_service.dart';
import 'package:afterclose/presentation/providers/data_update_epoch_provider.dart';
import 'package:afterclose/presentation/providers/providers.dart';
import 'package:afterclose/presentation/providers/watchlist_provider.dart';

// Re-export（向後相容）
export 'package:afterclose/domain/models/scan_models.dart';

const _sentinel = Object();

// ==================================================
// 掃描狀態
// ==================================================

/// 掃描畫面狀態
class ScanState {
  const ScanState({
    /// 篩選/排序後的顯示清單
    this.stocks = const [],
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
    this.tradeableUniverseCount = 0,
    this.observations = const [],
    this.observationCount = 0,
    this.error,
  });

  final List<ScanStockItem> stocks;
  final ScanFilter filter;
  final ScanSort sort;

  /// 目前選擇的產業篩選（null 表示不限產業）
  final String? industryFilter;

  /// 所有可選產業列表
  final List<String> industries;

  /// 目前顯示的資料實際日期
  final DateTime? dataDate;

  /// 首次載入或 pull-to-refresh
  final bool isLoading;

  /// 篩選器/排序切換中（輕量 loading，不顯示全骨架）
  final bool isFiltering;

  /// 是否正在載入更多項目（無限捲動）
  final bool isLoadingMore;

  /// 是否還有更多項目可載入
  final bool hasMore;

  /// 符合目前篩選條件的項目總數
  final int totalCount;

  /// 今日已掃描（分析）的項目總數
  final int totalAnalyzedCount;

  /// 今日「可交易池」股數（過流動性門檻）。供覆蓋透明度 funnel：
  /// 「自 [tradeableUniverseCount] 檔可交易股篩出 [totalAnalyzedCount] 檔有訊號」，
  /// 讓使用者知道清單是訊號子集、非全市場。
  final int tradeableUniverseCount;

  /// 「觀察區」（接近觸發、score 落在 [observation, signal) 區間）的前 N 檔。
  final List<ScanStockItem> observations;

  /// 觀察區總檔數（未截斷），供 section 標題顯示「觀察區 (N)」。
  final int observationCount;

  final String? error;

  ScanState copyWith({
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
    int? tradeableUniverseCount,
    List<ScanStockItem>? observations,
    int? observationCount,
    Object? error = _sentinel,
  }) {
    return ScanState(
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
      tradeableUniverseCount:
          tradeableUniverseCount ?? this.tradeableUniverseCount,
      observations: observations ?? this.observations,
      observationCount: observationCount ?? this.observationCount,
      error: error == _sentinel ? this.error : error as String?,
    );
  }
}

// ==================================================
// 掃描 Notifier
// ==================================================

class ScanNotifier extends Notifier<ScanState> {
  var _active = true;

  @override
  ScanState build() {
    _active = true;
    ref.onDispose(() => _active = false);

    // 重設所有可變快取，避免 Riverpod rebuild 時殘留舊資料
    // （_staticCachedIndustries 為 static，跨 instance 保留）
    _allAnalyses = [];
    _observationAnalyses = [];
    _filteredAnalyses = [];
    _allReasons = {};
    _watchlistSymbols = {};
    _industrySymbols = null;
    _industryFilterSeq = 0;
    _reloadSeq = 0;
    _dateCtx = null;

    // 監聽 watchlistProvider 變更，同步自選狀態
    ref.listen(
      watchlistProvider.select((s) => s.items.map((i) => i.symbol).toSet()),
      (prev, next) => _syncWatchlistSymbols(next),
    );

    // M6 fix：runUpdate 完成後會 bump dataUpdateEpoch；scan 畫面開著時
    // 自動 reload 拿到新 analysis / reason，否則使用者需要手動關閉再開
    // 才能看到新資料（背景 BackgroundUpdateService 觸發更新時尤其無感）。
    ref.listen(dataUpdateEpochProvider, (_, _) {
      if (!_active) return;
      loadData();
    });

    return const ScanState();
  }

  AppDatabase get _db => ref.read(databaseProvider);
  CachedDatabaseAccessor get _cachedDb => ref.read(cachedDbProvider);
  DataSyncService get _dataSyncService => ref.read(dataSyncServiceProvider);
  AnalysisRepository get _analysisRepo => ref.read(analysisRepositoryProvider);
  MarketDataRepository get _marketRepo =>
      ref.read(marketDataRepositoryProvider);

  static const _service = ScanFilterService();

  /// 產業列表跨 instance 快取（極少變動，僅 stock_master 更新時改變）。
  ///
  /// ## 已知限制（架構 review LOW state）
  ///
  /// 用 static 跨 ProviderContainer instance 共享，hermetic widget test
  /// 容易看到上次 test 殘留（test 用獨立 container 但 static 不歸零）。
  /// 解法：test 在 `setUp` 呼叫 [resetStaticIndustryCacheForTesting]。
  ///
  /// 對 production 行為無影響，只在 test 並行/順序敏感時需要注意。
  static List<String>? _staticCachedIndustries;
  static DateTime? _industryCacheTime;
  static const _industryCacheTtl = Duration(minutes: 5);

  /// Test helper：重置跨 instance 的產業列表 cache。
  @visibleForTesting
  static void resetStaticIndustryCacheForTesting() {
    _staticCachedIndustries = null;
    _industryCacheTime = null;
  }

  // 分頁快取資料（於 build() 中重設）
  List<DailyAnalysisEntry> _allAnalyses = [];
  List<DailyAnalysisEntry> _observationAnalyses = [];
  List<DailyAnalysisEntry> _filteredAnalyses = [];
  Map<String, List<DailyReasonEntry>> _allReasons = {};
  Set<String> _watchlistSymbols = {};
  Set<String>? _industrySymbols;
  int _industryFilterSeq = 0;
  int _reloadSeq = 0;
  DateContext? _dateCtx;

  /// 掃描頁固定用長線（60D）鏡頭：scoreLong 過濾 / 排序 / 顯示。
  ///
  /// 為什麼定死 long：實證 edge 在 60D（高分→報酬 spread +6.3% 單調），5D 接近
  /// 雜訊（+0.8%）；且設 horizon 的全域開關已於 2026-06-19 被 3-tab Mode UI 取代、
  /// 無 UI 可切 → 掃描頁直接用有 edge 的 60D。
  static const Horizon _horizon = Horizon.long;

  /// 清除錯誤狀態
  void clearError() => state = state.copyWith(error: null);

  /// 載入掃描資料（第一頁）
  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, error: null, hasMore: true);

    try {
      // 智慧回退：找到最近有資料的日期（統一由 Repository 處理日期正規化）
      // scan 預設依 short horizon 排序；UI 切 horizon 時也走同一 reload
      // path（dataUpdateEpoch listener 或 horizon listener 都會重新呼這條）。
      final result = await _analysisRepo.findLatestAnalyses(horizon: _horizon);
      if (!_active) return;
      final targetDate = result.targetDate;
      final analyses = result.analyses;

      // 更新 DateContext 以反映實際資料日期
      final dateCtx = DateContext.forDate(targetDate);
      _dateCtx = dateCtx;
      // 掃描頁固定長線。daily_analysis 持久化門檻已降到 observationScoreThreshold
      // 供「觀察區」用，故 scoreLong>0 不再等於「訊號」。依持久化分層：
      // - 主清單（訊號）：scoreLong>0 且 max(short,long) ≥ minScoreThreshold
      //   （= 門檻調整前的 universe，主清單行為不變）
      // - 觀察區（接近觸發）：scoreLong>0 且 max(short,long) 落在 [observation, signal)
      _allAnalyses = analyses
          .where((a) => a.scoreLong > 0 && isScanSignal(a))
          .toList();
      _observationAnalyses = analyses
          .where((a) => a.scoreLong > 0 && isScanObservation(a))
          .toList();
      _allReasons = {};
      // Lazy load：只在目前 filter 真正需要時才載入（切換 filter 時按需載入）
      if (_allAnalyses.isNotEmpty && state.filter != ScanFilter.all) {
        await _ensureReasonsLoaded();
      }

      // 取得實際資料日期供顯示
      final latestPriceDate = await _marketRepo.getLatestDataDate();
      final latestInstDate = await _marketRepo.getLatestInstitutionalDate();
      final dataDate = _dataSyncService.getDisplayDataDate(
        latestPriceDate,
        latestInstDate,
      );

      // 覆蓋透明度 funnel 的分母：當日「可交易池」股數（過流動性門檻）
      final tradeableUniverse = await _db.getTradeableUniverseCount(targetDate);

      // 載入產業列表（使用 static 快取 + TTL）
      final now = DateTime.now();
      final cacheExpired =
          _industryCacheTime == null ||
          now.difference(_industryCacheTime!) > _industryCacheTtl;
      final industries = (!cacheExpired && _staticCachedIndustries != null)
          ? _staticCachedIndustries!
          : await _db.getDistinctIndustries();
      _staticCachedIndustries = industries;
      _industryCacheTime = now;

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

      // 取得自選股清單供比對（主清單 + 觀察區共用）
      final watchlist = await _db.getWatchlist();
      _watchlistSymbols = watchlist.map((w) => w.symbol).toSet();

      // 觀察區（接近觸發）：取前 N 檔轉 item，不分頁、不受主清單 filter 影響。
      final observationItems = await _loadItemsForAnalyses(
        _observationAnalyses.take(kPageSize).toList(),
      );
      if (!_active) return;

      if (_filteredAnalyses.isEmpty) {
        state = state.copyWith(
          stocks: [],
          industries: industries,
          dataDate: dataDate,
          isLoading: false,
          hasMore: false,
          totalCount: 0,
          totalAnalyzedCount: _allAnalyses.length,
          tradeableUniverseCount: tradeableUniverse,
          observations: observationItems,
          observationCount: _observationAnalyses.length,
        );
        return;
      }

      // 載入第一頁
      final firstPageItems = await _loadItemsForAnalyses(
        _filteredAnalyses.take(kPageSize).toList(),
      );
      if (!_active) return;

      state = state.copyWith(
        stocks: firstPageItems,
        industries: industries,
        dataDate: dataDate,
        isLoading: false,
        hasMore: _filteredAnalyses.length > kPageSize,
        totalCount: _filteredAnalyses.length,
        totalAnalyzedCount: _allAnalyses.length,
        tradeableUniverseCount: tradeableUniverse,
        observations: observationItems,
        observationCount: _observationAnalyses.length,
      );
    } catch (e, s) {
      state = state.copyWith(isLoading: false, error: ErrorDisplay.message(e));
      AppLogger.error('ScanNotifier', '載入資料失敗', e, s);
    }
  }

  /// 載入更多項目（無限捲動）
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
      AppLogger.warning('ScanNotifier', '載入更多失敗', e);
      state = state.copyWith(
        isLoadingMore: false,
        error: ErrorDisplay.message(e),
      );
    }
  }

  /// 設定篩選條件
  Future<void> setFilter(ScanFilter filter) async {
    if (filter == state.filter) return;

    // 切換至訊號 filter 時，按需載入 reasons
    if (filter != ScanFilter.all) {
      await _ensureReasonsLoaded();
    }

    // 套用全域篩選
    _applyGlobalFilter(filter);

    // 篩選切換使用 isFiltering（輕量 indicator），不替換為全骨架
    state = state.copyWith(filter: filter, isFiltering: true, stocks: []);
    _reloadFirstPage(++_reloadSeq);
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

    // 重新套用目前的 filter（含產業），按需載入 reasons
    if (state.filter != ScanFilter.all) {
      await _ensureReasonsLoaded();
    }
    _applyGlobalFilter(state.filter);
    _reloadFirstPage(++_reloadSeq);
  }

  /// 篩選/排序變更後重新載入第一頁的輔助方法
  Future<void> _reloadFirstPage(int seq) async {
    try {
      final firstPageItems = await _loadItemsForAnalyses(
        _filteredAnalyses.take(kPageSize).toList(),
      );

      // 防護 race condition：若期間有新的 reload 觸發，丟棄舊結果
      if (seq != _reloadSeq) return;

      state = state.copyWith(
        stocks: firstPageItems,
        isLoading: false,
        isFiltering: false,
        hasMore: _filteredAnalyses.length > kPageSize,
        totalCount: _filteredAnalyses.length,
      );
    } catch (e) {
      if (seq != _reloadSeq) return;
      AppLogger.warning('ScanNotifier', '重新載入第一頁失敗', e);
      state = state.copyWith(
        isLoading: false,
        isFiltering: false,
        error: ErrorDisplay.message(e),
      );
    }
  }

  /// 按需載入 reasons（首次切換至非 all filter 時執行）
  Future<void> _ensureReasonsLoaded() async {
    if (_allReasons.isNotEmpty || _allAnalyses.isEmpty) return;
    final dateCtx = _dateCtx;
    if (dateCtx == null) return;
    final allSymbols = _allAnalyses.map((a) => a.symbol).toList();
    _allReasons = await _cachedDb.getReasonsBatch(allSymbols, dateCtx.today);
  }

  /// 套用全域篩選（_allAnalyses → _filteredAnalyses）
  void _applyGlobalFilter(ScanFilter filter) {
    _filteredAnalyses = _service.applyFilter(
      allAnalyses: _allAnalyses,
      filter: filter,
      allReasons: _allReasons,
      industrySymbols: _industrySymbols,
    );
  }

  /// 載入一批分析的詳細股票資料
  Future<List<ScanStockItem>> _loadItemsForAnalyses(
    List<DailyAnalysisEntry> analyses,
  ) async {
    final dateCtx = _dateCtx;
    if (analyses.isEmpty || dateCtx == null) return [];

    return _service.buildStockItems(
      analyses: analyses,
      dateCtx: dateCtx,
      cachedDb: _cachedDb,
      watchlistSymbols: Set.unmodifiable(_watchlistSymbols),
      horizon: _horizon,
    );
  }

  /// 設定排序
  void setSort(ScanSort sort) {
    if (sort == state.sort) return;

    // 套用全域排序
    _applyGlobalSort(sort);

    // 排序切換使用 isFiltering（輕量 indicator）
    state = state.copyWith(sort: sort, isFiltering: true, stocks: []);
    _reloadFirstPage(++_reloadSeq);
  }

  /// 套用全域排序至 _filteredAnalyses
  void _applyGlobalSort(ScanSort sort) {
    _service.applySort(_filteredAnalyses, sort, horizon: _horizon);
  }

  /// 從 watchlistProvider 同步自選清單狀態到 scan 畫面
  void _syncWatchlistSymbols(Set<String> symbols) {
    _watchlistSymbols = symbols;
    if (state.stocks.isEmpty) return;

    final updated = state.stocks.map((s) {
      final inWatchlist = symbols.contains(s.symbol);
      if (s.isInWatchlist == inWatchlist) return s;
      return s.copyWith(isInWatchlist: inWatchlist);
    }).toList();

    state = state.copyWith(stocks: updated);
  }

  /// Toggle watchlist for a stock — 透過 watchlistProvider 同步全域狀態
  Future<void> toggleWatchlist(String symbol) async {
    final isInWatchlist = _watchlistSymbols.contains(symbol);
    final watchlistNotifier = ref.read(watchlistProvider.notifier);

    try {
      if (isInWatchlist) {
        final success = await watchlistNotifier.removeStock(symbol);
        if (!success) {
          final msg = ref.read(watchlistProvider).error ?? '移除自選股失敗';
          throw StateError(msg);
        }
        _watchlistSymbols.remove(symbol);
      } else {
        final success = await watchlistNotifier.addStock(symbol);
        if (!success) {
          final msg = ref.read(watchlistProvider).error ?? '加入自選股失敗';
          throw StateError(msg);
        }
        _watchlistSymbols.add(symbol);
      }

      final updatedFiltered = state.stocks.map((s) {
        if (s.symbol == symbol) {
          return s.copyWith(isInWatchlist: !isInWatchlist);
        }
        return s;
      }).toList();

      state = state.copyWith(stocks: updatedFiltered, error: null);
    } catch (e) {
      AppLogger.warning('ScanNotifier', '切換自選股失敗: $symbol', e);
      state = state.copyWith(error: ErrorDisplay.message(e));
    }
  }
}

/// 掃描畫面狀態 Provider
final scanProvider = NotifierProvider<ScanNotifier, ScanState>(
  ScanNotifier.new,
);

/// 成立訊號層：任一 horizon ≥ [RuleParams.minScoreThreshold]（與持久化口徑一致）。
@visibleForTesting
bool isScanSignal(DailyAnalysisEntry a) =>
    a.scoreShort >= RuleParams.minScoreThreshold ||
    a.scoreLong >= RuleParams.minScoreThreshold;

/// 觀察層（接近觸發）：未達訊號、但任一 horizon ≥ [RuleParams.observationScoreThreshold]。
@visibleForTesting
bool isScanObservation(DailyAnalysisEntry a) =>
    !isScanSignal(a) &&
    (a.scoreShort >= RuleParams.observationScoreThreshold ||
        a.scoreLong >= RuleParams.observationScoreThreshold);
