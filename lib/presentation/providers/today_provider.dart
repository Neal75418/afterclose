import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/constants/api_config.dart';
import 'package:afterclose/core/constants/data_freshness.dart';
import 'package:afterclose/core/utils/error_display.dart';
import 'package:afterclose/core/utils/sentinel.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/taiwan_calendar.dart';
import 'package:afterclose/data/database/cached_accessor.dart';
import 'package:afterclose/data/repositories/market_data_repository.dart';
import 'package:afterclose/domain/services/data_sync_service.dart';
import 'package:afterclose/domain/services/update_service.dart';
import 'package:afterclose/presentation/providers/data_update_epoch_provider.dart';
import 'package:afterclose/presentation/providers/market_overview_provider.dart';
import 'package:afterclose/presentation/providers/notification_provider.dart';
import 'package:afterclose/presentation/providers/price_alert_provider.dart';
import 'package:afterclose/presentation/providers/providers.dart';

/// 每日更新作業的最大執行時間
const _updateTimeout = Duration(minutes: ApiConfig.updateTimeoutMin);

// ==================================================
// Today Screen State
// ==================================================

/// 今日推薦與市場總覽的 State
class TodayState {
  const TodayState({
    this.lastUpdate,
    this.dataDate,
    this.isLoading = false,
    this.isUpdating = false,
    this.updateProgress,
    this.error,
  });

  final DateTime? lastUpdate;

  /// 目前顯示資料的實際日期
  final DateTime? dataDate;
  final bool isLoading;
  final bool isUpdating;
  final UpdateProgress? updateProgress;
  final String? error;

  TodayState copyWith({
    DateTime? lastUpdate,
    DateTime? dataDate,
    bool? isLoading,
    bool? isUpdating,
    Object? updateProgress = sentinel,
    Object? error = sentinel,
  }) {
    return TodayState(
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
    return const TodayState();
  }

  CachedDatabaseAccessor get _cachedDb => ref.read(cachedDbProvider);
  UpdateService get _updateService => ref.read(updateServiceProvider);
  DataSyncService get _dataSyncService => ref.read(dataSyncServiceProvider);
  MarketDataRepository get _marketRepo =>
      ref.read(marketDataRepositoryProvider);

  /// 載入今日畫面的「更新編排」狀態（最後更新時間 / 資料日期）+ 觸發冷啟自動更新
  ///
  /// **2026-06-21 退役舊推薦系統 Step 3**：推薦清單已改由
  /// [modeRecommendationsProvider] 獨立載入（3-mode tab）。此處不再載入舊
  /// daily_recommendation 清單，只負責 today 畫面共用的編排狀態
  /// （lastUpdate / dataDate / isLoading / 冷啟更新）。
  Future<void> loadData() async {
    final generation = ++_loadGeneration;
    state = state.copyWith(isLoading: true, error: null);

    try {
      // 取得最後更新執行記錄
      final lastRun = await _marketRepo.getLatestUpdateRun();

      // B-lite cold-start auto-update（2026-06-18）：macOS 無 workmanager、
      // CLI 卡 Flutter binding，妥協做法是「user 一開 app 就背景跑」。
      // 6h gate + 交易日 + 不阻塞 UI（fire-and-forget）。
      _maybeTriggerColdStartUpdate(lastRun?.finishedAt ?? lastRun?.startedAt);

      // 取得實際資料日期供顯示用（非查詢用途）
      final latestPriceDate = await _marketRepo.getLatestDataDate();
      final latestInstDate = await _marketRepo.getLatestInstitutionalDate();
      final dataDate = _dataSyncService.getDisplayDataDate(
        latestPriceDate,
        latestInstDate,
      );

      // 防禦性 guard：寫入前驗證 generation 沒被並發 reload 取代
      if (!_active || _loadGeneration != generation) return;

      state = state.copyWith(
        lastUpdate: lastRun?.finishedAt ?? lastRun?.startedAt,
        dataDate: dataDate,
        isLoading: false,
      );
    } catch (e) {
      AppLogger.warning('TodayNotifier', '載入今日資料失敗', e);
      // race fix：runUpdate 完成後 await loadData() 跟 pull-to-refresh 並發時，
      // generation guard 確保只有最後一次能寫入 error state。
      if (!_active || _loadGeneration != generation) return;
      state = state.copyWith(isLoading: false, error: ErrorDisplay.message(e));
    }
  }

  /// B-lite cold-start auto-update 全域開關
  ///
  /// **Production**：`main.dart` 在 startup 設為 true（個人 dev 機默認
  /// 行為，避免漏交易日）。
  /// **Tests**：預設 false 避免單元測試意外觸發 [runUpdate] → 未 stub
  /// 的 `_updateService.runDailyUpdate()` 鏈拋型別例外。需要驗證
  /// cold-start 行為的 test 自己改 true。
  /// **Workmanager 背景 isolate**：不需要設（路徑不經 TodayNotifier）。
  static bool autoColdStartUpdateEnabled = false;

  /// B-lite cold-start auto-update（2026-06-18）
  ///
  /// 四個 short-circuit（任一不通就 skip）：
  /// 1. [autoColdStartUpdateEnabled]=false → 整層關閉（主要給測試 / 未來
  ///    feature flag 用）
  /// 2. 已有 update 在進行 → [runUpdate] 自己會擋，提前 skip 省 log noise
  /// 3. 上次 update 距現在 < [DataFreshness.coldStartAutoUpdateGateHours]
  ///    → fresh enough，跳過避免同日多次重跑 syncer（每個 syncer 內
  ///    有 freshness check，但繞掉整次省 ~10s 開銷）
  /// 4. 非交易日（週末 / 國定假日）→ 沒新資料可抓
  ///
  /// 通過則 fire-and-forget — UI 用 [TodayState.isUpdating] / updateProgress
  /// 顯示進度，user 可以繼續操作；完成後 [dataUpdateEpochProvider] 自然
  /// 觸發各 consumer reload。
  ///
  /// **注意**：catch 全部 error 進 log，因為這層是「**幫使用者順手做的**
  /// 背景行為」，失敗不該影響主要 [loadData] 流程。實際失敗會被 runUpdate
  /// 內部包成 UpdateResult.errors，後續 UI 會反映。
  void _maybeTriggerColdStartUpdate(DateTime? lastUpdatedAt) {
    if (!autoColdStartUpdateEnabled) return;
    if (state.isUpdating) return;
    if (!TaiwanCalendar.isTradingDay(DateTime.now())) return;
    if (lastUpdatedAt != null) {
      final elapsed = DateTime.now().difference(lastUpdatedAt);
      if (elapsed.inHours < DataFreshness.coldStartAutoUpdateGateHours) {
        return;
      }
    }
    AppLogger.info(
      'TodayNotifier',
      'B-lite cold-start auto-update：上次 update ${lastUpdatedAt ?? "從未"}，'
          '距今 ≥${DataFreshness.coldStartAutoUpdateGateHours}h，背景觸發',
    );
    // unawaited — 不阻塞 loadData 主流程
    unawaited(
      runUpdate().catchError((Object e, StackTrace s) {
        AppLogger.warning('TodayNotifier', 'cold-start auto-update 失敗', e, s);
        return UpdateResult(date: DateTime.now())..message = '$e';
      }),
    );
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
          alertsTriggered: alertsTriggered,
        );
      }

      // 通知其他依賴 daily_* 表的 provider（scan / watchlist / performance
      // 等）資料已寫入新一輪，讓它們透過 ref.listen(dataUpdateEpochProvider)
      // 自行 reload。在 await loadData 前 bump 確保 listener 邏輯與 today
      // 本地 reload 並行。
      ref.read(dataUpdateEpochProvider.notifier).bump();

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
