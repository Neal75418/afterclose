import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/constants/api_config.dart';
import 'package:afterclose/core/constants/calibrated_scores/horizon.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/error_display.dart';
import 'package:afterclose/core/utils/sentinel.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/price_calculator.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/database/cached_accessor.dart';
import 'package:afterclose/domain/services/data_sync_service.dart';
import 'package:afterclose/domain/services/update_service.dart';
import 'package:afterclose/presentation/providers/market_overview_provider.dart';
import 'package:afterclose/presentation/providers/notification_provider.dart';
import 'package:afterclose/presentation/providers/price_alert_provider.dart';
import 'package:afterclose/presentation/providers/providers.dart';
import 'package:afterclose/presentation/providers/selected_horizon_provider.dart';

/// 每日更新作業的最大執行時間
const _updateTimeout = Duration(minutes: ApiConfig.updateTimeoutMin);

// ==================================================
// Today Screen State
// ==================================================

/// 今日推薦與市場總覽的 State
class TodayState {
  const TodayState({
    this.recommendations = const [],
    this.lastUpdate,
    this.dataDate,
    this.isLoading = false,
    this.isUpdating = false,
    this.updateProgress,
    this.error,
  });

  final List<RecommendationWithDetails> recommendations;
  final DateTime? lastUpdate;

  /// 目前顯示資料的實際日期
  final DateTime? dataDate;
  final bool isLoading;
  final bool isUpdating;
  final UpdateProgress? updateProgress;
  final String? error;

  TodayState copyWith({
    List<RecommendationWithDetails>? recommendations,
    DateTime? lastUpdate,
    DateTime? dataDate,
    bool? isLoading,
    bool? isUpdating,
    Object? updateProgress = sentinel,
    Object? error = sentinel,
  }) {
    return TodayState(
      recommendations: recommendations ?? this.recommendations,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      dataDate: dataDate ?? this.dataDate,
      isLoading: isLoading ?? this.isLoading,
      isUpdating: isUpdating ?? this.isUpdating,
      updateProgress: updateProgress == sentinel
          ? this.updateProgress
          : updateProgress as UpdateProgress?,
      error: error == sentinel ? this.error : error as String?,
    );
  }
}

/// 包含股票詳情與推薦原因的推薦項目
class RecommendationWithDetails {
  RecommendationWithDetails({
    required this.symbol,
    required this.score,
    required this.rank,
    this.stockName,
    this.market,
    this.latestClose,
    this.priceChange,
    this.reasons = const [],
    this.trendState,
    this.recentPrices,
  });

  final String symbol;
  final double score;
  final int rank;
  final String? stockName;

  /// 市場：'TWSE'（上市）或 'TPEx'（上櫃）
  final String? market;
  final double? latestClose;
  final double? priceChange;
  final List<DailyReasonEntry> reasons;
  final String? trendState;
  final List<double>? recentPrices;

  /// 預計算的 reasonType 列表（避免在 Widget build 中重複轉換）
  late final List<String> reasonTypes = reasons
      .map((r) => r.reasonType)
      .toList();
}

/// 更新進度資訊
class UpdateProgress {
  const UpdateProgress({
    required this.currentStep,
    required this.totalSteps,
    required this.message,
  });

  final int currentStep;
  final int totalSteps;
  final String message;

  double get progress => totalSteps > 0 ? currentStep / totalSteps : 0;
}

// ==================================================
// Today Notifier
// ==================================================

class TodayNotifier extends Notifier<TodayState> {
  var _active = true;
  int _loadGeneration = 0;

  @override
  TodayState build() {
    _active = true;
    _loadGeneration = 0;
    ref.onDispose(() => _active = false);

    // Stage 5c dual-horizon：切換 horizon 時只重新載入 recommendations 列表
    // 跟相關 details，保留 lastUpdate / dataDate / updateProgress 等
    // non-horizon-specific 狀態。Command-based reload 模式優於 ref.watch
    // 整體 rebuild — 否則 update 進行中的 progress banner 會閃掉。
    ref.listen<Horizon>(selectedHorizonProvider, (prev, next) {
      if (prev == next) return;
      if (!_active) return;
      _reloadForHorizon(next);
    });

    return const TodayState();
  }

  AppDatabase get _db => ref.read(databaseProvider);
  CachedDatabaseAccessor get _cachedDb => ref.read(cachedDbProvider);
  UpdateService get _updateService => ref.read(updateServiceProvider);
  DataSyncService get _dataSyncService => ref.read(dataSyncServiceProvider);

  /// 載入今日資料
  Future<void> loadData() async {
    final generation = ++_loadGeneration;
    state = state.copyWith(isLoading: true, error: null);

    try {
      // 取得最後更新執行記錄
      final lastRun = await _db.getLatestUpdateRun();

      final loadHorizon = ref.read(selectedHorizonProvider);
      final loaded = await _loadRecommendationsAndDetails(
        horizon: loadHorizon,
        generation: generation,
      );
      if (loaded == null) return; // generation 過期或 inactive

      // 防禦性 guard：在最後寫入前再次驗證 generation 沒被更新的 reload
      // 取代。helper 內部的 check 已經涵蓋每個 await 點，這裡只是保險。
      if (!_active || _loadGeneration != generation) return;

      state = state.copyWith(
        recommendations: loaded.recWithDetails,
        lastUpdate: lastRun?.finishedAt ?? lastRun?.startedAt,
        dataDate: loaded.dataDate,
        isLoading: false,
      );

      // Stage 5c: 在 loadData 進行中若使用者切換 horizon，listener 仍會
      // 觸發 _reloadForHorizon（不會被擋住，因為 _active 為 true），會
      // 自然取代上面的寫入。這邊只是 belt-and-braces：載入完成後若發現
      // horizon 已不一致，補一次 reload。
      if (_active && ref.read(selectedHorizonProvider) != loadHorizon) {
        await _reloadForHorizon(ref.read(selectedHorizonProvider));
      }
    } catch (e) {
      AppLogger.warning('TodayNotifier', '載入今日資料失敗', e);
      state = state.copyWith(isLoading: false, error: ErrorDisplay.message(e));
    }
  }

  /// Stage 5c：horizon 切換時的 reload command
  ///
  /// 只重查 recommendations + 重建 recWithDetails，保留 [TodayState.lastUpdate]
  /// / [TodayState.dataDate] / [TodayState.updateProgress] 等狀態不動。
  /// 跟 [loadData] 共用 [_loadRecommendationsAndDetails] helper。
  ///
  /// 在成功 / catch / 早退路徑都確保 `isLoading` 被清除 — 若 [loadData]
  /// 中途被本 reload supersede，它的 `isLoading: true` 會卡住 shimmer，
  /// 必須由最後倖存的 reload 負責清掉。透過 `_loadGeneration == generation`
  /// 確保只有最新的一次 reload 寫入 state，避免被更新的 reload 蓋寫。
  Future<void> _reloadForHorizon(Horizon horizon) async {
    final generation = ++_loadGeneration;
    try {
      final loaded = await _loadRecommendationsAndDetails(
        horizon: horizon,
        generation: generation,
      );
      if (loaded == null) return;

      // 防禦性 guard：跟 loadData 對齊
      if (!_active || _loadGeneration != generation) return;

      state = state.copyWith(
        recommendations: loaded.recWithDetails,
        isLoading: false,
      );
    } catch (e) {
      AppLogger.warning('TodayNotifier', 'horizon 切換重載失敗', e);
      // 不覆蓋現有 recommendations，僅清 isLoading — 切換失敗的 fallback
      // 是繼續顯示舊 list，但不能卡在 shimmer。
      if (_active && _loadGeneration == generation) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  /// 載入指定 horizon 的 recommendations 並組裝為 [RecommendationWithDetails]
  ///
  /// 為 [loadData] 與 [_reloadForHorizon] 共用。回傳 null 代表 generation
  /// 已過期或 notifier 已 dispose，呼叫端應直接放棄寫入 state。
  Future<
    ({List<RecommendationWithDetails> recWithDetails, DateTime? dataDate})?
  >
  _loadRecommendationsAndDetails({
    required Horizon horizon,
    required int generation,
  }) async {
    // 使用今日日期進行查詢（update_service 使用此日期儲存）
    final dateCtx = DateContext.now();

    // 取得今日推薦（使用 repo 的智慧回退機制處理週末）
    final repo = ref.read(analysisRepositoryProvider);
    final recommendations = await repo.getTodayRecommendations(
      horizon: horizon,
    );
    if (!_active || _loadGeneration != generation) return null;

    // 取得實際資料日期供顯示用（非查詢用途）
    final latestPriceDate = await _db.getLatestDataDate();
    final latestInstDate = await _db.getLatestInstitutionalDate();

    final dataDate = _dataSyncService.getDisplayDataDate(
      latestPriceDate,
      latestInstDate,
    );

    // 決定用於分析查詢的實際日期
    final analysisDate = recommendations.isNotEmpty
        ? DateContext.normalize(recommendations.first.date)
        : (dataDate ?? dateCtx.today);

    // 取得自選清單
    final watchlist = await _db.getWatchlist();

    // 收集所有需要載入的股票代碼
    final recSymbols = recommendations.map((r) => r.symbol).toList();
    final watchlistSymbols = watchlist.map((w) => w.symbol).toList();
    final allSymbols = {...recSymbols, ...watchlistSymbols}.toList();

    // historyStart 以 analysisDate 為基準，避免長假時 historyStart > analysisDate
    final historyCtx = DateContext.forDate(analysisDate);
    final data = await _cachedDb.loadStockListData(
      symbols: allSymbols,
      analysisDate: analysisDate,
      historyStart: historyCtx.historyStart,
    );
    if (!_active || _loadGeneration != generation) return null;

    final stocksMap = data.stocks;
    final latestPricesMap = data.latestPrices;
    final analysesMap = data.analyses;
    final reasonsMap = data.reasons;
    final priceHistoriesMap = data.priceHistories;

    final priceChanges = PriceCalculator.calculatePriceChangesBatch(
      priceHistoriesMap,
      latestPricesMap,
    );

    final recWithDetails = recommendations.map((rec) {
      final priceHistory = priceHistoriesMap[rec.symbol];
      // 擷取最近 30 天收盤價供迷你走勢圖使用
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
      return RecommendationWithDetails(
        symbol: rec.symbol,
        score: rec.score,
        rank: rec.rank,
        stockName: stocksMap[rec.symbol]?.name,
        market: stocksMap[rec.symbol]?.market,
        latestClose: latestPricesMap[rec.symbol]?.close,
        priceChange: priceChanges[rec.symbol],
        reasons: reasonsMap[rec.symbol] ?? [],
        trendState: analysesMap[rec.symbol]?.trendState,
        recentPrices: recentPrices,
      );
    }).toList();

    return (recWithDetails: recWithDetails, dataDate: dataDate);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  /// 執行每日更新，具備逾時保護機制
  ///
  /// 若更新時間超過 [_updateTimeout] 將拋出 [TimeoutException]
  /// 若已有更新在進行中，直接返回以避免並發 DB 寫入衝突。
  Future<UpdateResult> runUpdate({bool force = false}) async {
    if (state.isUpdating) {
      return UpdateResult(date: DateTime.now())
        ..skipped = true
        ..message = '更新已在進行中，請稍候';
    }

    state = state.copyWith(
      isUpdating: true,
      updateProgress: const UpdateProgress(
        currentStep: 0,
        totalSteps: 10,
        message: '開始更新...',
      ),
    );

    try {
      final result = await _updateService
          .runDailyUpdate(
            force: force,
            onProgress: (current, total, message) {
              state = state.copyWith(
                updateProgress: UpdateProgress(
                  currentStep: current,
                  totalSteps: total,
                  message: message,
                ),
              );
            },
          )
          .timeout(
            _updateTimeout,
            onTimeout: () {
              throw TimeoutException('更新作業超時，請檢查網路連線後重試', _updateTimeout);
            },
          );

      state = state.copyWith(isUpdating: false, updateProgress: null);

      // 更新後使快取失效（資料已變更）
      _cachedDb.invalidateCache();

      // 檢查價格警示並觸發通知
      final alertsTriggered = await _checkPriceAlerts(
        result.currentPrices,
        result.priceChanges,
      );

      // 若有警示被觸發，顯示更新完成通知
      if (alertsTriggered > 0) {
        final notificationNotifier = ref.read(notificationProvider.notifier);
        await notificationNotifier.showUpdateCompleteNotification(
          recommendationCount: result.recommendationsGenerated,
          alertsTriggered: alertsTriggered,
        );
      }

      // 更新後重新載入資料（含大盤總覽 Dashboard）
      await Future.wait([
        loadData(),
        ref.read(marketOverviewProvider.notifier).loadData(),
      ]);

      // loadData() / marketOverview.loadData() 內部 catch 不會 rethrow，
      // 但會設定各自的 state.error。若重新載入失敗，加入 errors 讓
      // summary 顯示警告而非純成功
      if (state.error != null) {
        result.errors.add(state.error!);
      }
      final marketError = ref.read(marketOverviewProvider).error;
      if (marketError != null) {
        result.errors.add(marketError);
      }

      return result;
    } on TimeoutException catch (e) {
      state = state.copyWith(
        isUpdating: false,
        updateProgress: null,
        error: e.message ?? '更新超時',
      );
      rethrow;
    } catch (e) {
      state = state.copyWith(
        isUpdating: false,
        updateProgress: null,
        error: ErrorDisplay.message(e),
      );
      rethrow;
    }
  }

  /// 檢查目前價格是否觸發價格警示並發送通知
  ///
  /// 回傳已觸發的警示數量
  Future<int> _checkPriceAlerts(
    Map<String, double> currentPrices,
    Map<String, double> priceChanges,
  ) async {
    if (currentPrices.isEmpty) return 0;

    try {
      // 確保通知服務已初始化
      final notificationState = ref.read(notificationProvider);
      if (!notificationState.isInitialized) {
        await ref.read(notificationProvider.notifier).initialize();
      }

      final alertNotifier = ref.read(priceAlertProvider.notifier);
      final notificationNotifier = ref.read(notificationProvider.notifier);

      // 檢查並觸發警示
      final triggered = await alertNotifier.checkAndTriggerAlerts(
        currentPrices,
        priceChanges,
      );

      // 為每個被觸發的警示發送通知
      for (final alert in triggered) {
        await notificationNotifier.showPriceAlertNotification(
          alert,
          currentPrice: currentPrices[alert.symbol],
        );
      }

      return triggered.length;
    } catch (e) {
      // 非關鍵錯誤：警示檢查失敗不應導致更新失敗
      AppLogger.warning('TodayNotifier', '價格警示檢查失敗', e);
      return 0;
    }
  }
}

/// 今日畫面 State 的 Provider
final todayProvider = NotifierProvider<TodayNotifier, TodayState>(
  TodayNotifier.new,
);
