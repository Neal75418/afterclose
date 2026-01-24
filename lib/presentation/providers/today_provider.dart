import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/price_calculator.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/database/cached_accessor.dart';
import 'package:afterclose/domain/services/update_service.dart';
import 'package:afterclose/presentation/providers/notification_provider.dart';
import 'package:afterclose/presentation/providers/price_alert_provider.dart';
import 'package:afterclose/presentation/providers/providers.dart';

/// 每日更新作業的最大執行時間
const _updateTimeout = Duration(minutes: 60);

// ==================================================
// Today Screen State
// ==================================================

/// 今日推薦與市場總覽的 State
class TodayState {
  const TodayState({
    this.recommendations = const [],
    this.watchlistStatus = const {},
    this.lastUpdate,
    this.dataDate,
    this.isLoading = false,
    this.isUpdating = false,
    this.updateProgress,
    this.error,
  });

  final List<RecommendationWithDetails> recommendations;
  final Map<String, WatchlistStockStatus> watchlistStatus;
  final DateTime? lastUpdate;

  /// 目前顯示資料的實際日期
  final DateTime? dataDate;
  final bool isLoading;
  final bool isUpdating;
  final UpdateProgress? updateProgress;
  final String? error;

  TodayState copyWith({
    List<RecommendationWithDetails>? recommendations,
    Map<String, WatchlistStockStatus>? watchlistStatus,
    DateTime? lastUpdate,
    DateTime? dataDate,
    bool? isLoading,
    bool? isUpdating,
    UpdateProgress? updateProgress,
    String? error,
  }) {
    return TodayState(
      recommendations: recommendations ?? this.recommendations,
      watchlistStatus: watchlistStatus ?? this.watchlistStatus,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      dataDate: dataDate ?? this.dataDate,
      isLoading: isLoading ?? this.isLoading,
      isUpdating: isUpdating ?? this.isUpdating,
      updateProgress: updateProgress,
      error: error,
    );
  }
}

/// 包含股票詳情與推薦原因的推薦項目
class RecommendationWithDetails {
  const RecommendationWithDetails({
    required this.symbol,
    required this.score,
    required this.rank,
    this.stockName,
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
  final double? latestClose;
  final double? priceChange;
  final List<DailyReasonEntry> reasons;
  final String? trendState;
  final List<double>? recentPrices;
}

/// 自選股票狀態
class WatchlistStockStatus {
  const WatchlistStockStatus({
    required this.symbol,
    this.stockName,
    this.latestClose,
    this.priceChange,
    this.hasSignal = false,
    this.signalType,
  });

  final String symbol;
  final String? stockName;
  final double? latestClose;
  final double? priceChange;
  final bool hasSignal;
  final String? signalType;

  /// 取得狀態圖示
  String get statusIcon {
    if (hasSignal) return '🔥';
    if (priceChange != null && priceChange!.abs() >= 3) return '👀';
    return '😴';
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

class TodayNotifier extends StateNotifier<TodayState> {
  TodayNotifier(this._ref) : super(const TodayState());

  final Ref _ref;

  AppDatabase get _db => _ref.read(databaseProvider);
  CachedDatabaseAccessor get _cachedDb => _ref.read(cachedDbProvider);
  UpdateService get _updateService => _ref.read(updateServiceProvider);

  /// 載入今日資料
  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // 取得最後更新執行記錄
      final lastRun = await _db.getLatestUpdateRun();

      // 使用今日日期進行查詢（update_service 使用此日期儲存）
      final dateCtx = DateContext.now();

      // 取得今日推薦（使用 repo 的智慧回退機制處理週末）
      final repo = _ref.read(analysisRepositoryProvider);
      final recommendations = await repo.getTodayRecommendations();

      // 取得實際資料日期供顯示用（非查詢用途）
      final latestPriceDate = await _db.getLatestDataDate();
      final latestInstDate = await _db.getLatestInstitutionalDate();

      // 計算顯示用的資料日期，取兩者較早者
      final dataDate = DateContext.earlierOf(latestPriceDate, latestInstDate);

      // 決定用於分析查詢的實際日期
      // 若有推薦資料，使用該資料的日期；否則使用最新資料日期
      final analysisDate = recommendations.isNotEmpty
          ? DateContext.normalize(recommendations.first.date)
          : (dataDate ?? dateCtx.today);

      // 取得自選清單
      final watchlist = await _db.getWatchlist();

      // 收集所有需要載入的股票代碼
      final recSymbols = recommendations.map((r) => r.symbol).toList();
      final watchlistSymbols = watchlist.map((w) => w.symbol).toList();
      final allSymbols = {...recSymbols, ...watchlistSymbols}.toList();

      // 使用 Dart 3 Records 進行型別安全的批次載入（無需手動轉型）
      // 使用實際資料日期查詢分析資料，確保非交易日也能正確顯示趨勢
      final data = await _cachedDb.loadStockListData(
        symbols: allSymbols,
        analysisDate: analysisDate,
        historyStart: dateCtx.historyStart,
      );

      // 解構 Record 欄位，享有編譯期型別安全
      final stocksMap = data.stocks;
      final latestPricesMap = data.latestPrices;
      final analysesMap = data.analyses;
      final reasonsMap = data.reasons;
      final priceHistoriesMap = data.priceHistories;

      // 使用工具方法計算價格變化
      final priceChanges = PriceCalculator.calculatePriceChangesBatch(
        priceHistoriesMap,
        latestPricesMap,
      );

      // 建立推薦詳情
      final recWithDetails = recommendations.map((rec) {
        final priceHistory = priceHistoriesMap[rec.symbol];
        // 擷取收盤價供迷你走勢圖使用（限制 30 天以提升效能）
        final recentPrices = priceHistory
            ?.take(30)
            .map((p) => p.close)
            .whereType<double>()
            .toList();
        return RecommendationWithDetails(
          symbol: rec.symbol,
          score: rec.score,
          rank: rec.rank,
          stockName: stocksMap[rec.symbol]?.name,
          latestClose: latestPricesMap[rec.symbol]?.close,
          priceChange: priceChanges[rec.symbol],
          reasons: reasonsMap[rec.symbol] ?? [],
          trendState: analysesMap[rec.symbol]?.trendState,
          recentPrices: recentPrices,
        );
      }).toList();

      // 建立自選清單狀態
      final watchlistStatus = <String, WatchlistStockStatus>{};
      for (final item in watchlist) {
        final reasons = reasonsMap[item.symbol] ?? [];
        watchlistStatus[item.symbol] = WatchlistStockStatus(
          symbol: item.symbol,
          stockName: stocksMap[item.symbol]?.name,
          latestClose: latestPricesMap[item.symbol]?.close,
          priceChange: priceChanges[item.symbol],
          hasSignal: reasons.isNotEmpty,
          signalType: analysesMap[item.symbol]?.trendState,
        );
      }

      state = state.copyWith(
        recommendations: recWithDetails,
        watchlistStatus: watchlistStatus,
        lastUpdate: lastRun?.finishedAt ?? lastRun?.startedAt,
        dataDate: dataDate,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 執行每日更新，具備逾時保護機制
  ///
  /// 若更新時間超過 [_updateTimeout] 將拋出 [TimeoutException]
  Future<UpdateResult> runUpdate({bool forceFetch = false}) async {
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
            forceFetch: forceFetch,
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
        final notificationNotifier = _ref.read(notificationProvider.notifier);
        await notificationNotifier.showUpdateCompleteNotification(
          recommendationCount: result.recommendationsGenerated,
          alertsTriggered: alertsTriggered,
        );
      }

      // 更新後重新載入資料
      await loadData();

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
        error: e.toString(),
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
      final notificationState = _ref.read(notificationProvider);
      if (!notificationState.isInitialized) {
        await _ref.read(notificationProvider.notifier).initialize();
      }

      final alertNotifier = _ref.read(priceAlertProvider.notifier);
      final notificationNotifier = _ref.read(notificationProvider.notifier);

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
      AppLogger.warning('TodayNotifier', 'Price alert check failed', e);
      return 0;
    }
  }
}

/// 今日畫面 State 的 Provider
final todayProvider = StateNotifierProvider<TodayNotifier, TodayState>((ref) {
  return TodayNotifier(ref);
});
