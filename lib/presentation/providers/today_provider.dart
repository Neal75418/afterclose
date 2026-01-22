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

/// Maximum duration for daily update operation
const _updateTimeout = Duration(minutes: 5);

// ==================================================
// Today Screen State
// ==================================================

/// State for today's recommendations and market overview
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

  /// The actual date of the data being displayed
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

/// Recommendation with stock details and reasons
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

/// Status of a watchlist stock
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

  /// Get status icon
  String get statusIcon {
    if (hasSignal) return '🔥';
    if (priceChange != null && priceChange!.abs() >= 3) return '👀';
    return '😴';
  }
}

/// Update progress info
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

  /// Load today's data
  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Get last update run
      final lastRun = await _db.getLatestUpdateRun();

      // Use today's date for querying (update_service stores with this date)
      final dateCtx = DateContext.now();

      // Get recommendations for today
      final recommendations = await _db.getRecommendations(dateCtx.today);

      // Get actual data dates for display purposes (not for querying)
      final latestPriceDate = await _db.getLatestDataDate();
      final latestInstDate = await _db.getLatestInstitutionalDate();

      // Calculate dataDate for display - use the earlier of the two dates
      final dataDate = DateContext.earlierOf(latestPriceDate, latestInstDate);

      // Get watchlist
      final watchlist = await _db.getWatchlist();

      // Collect all symbols we need to load
      final recSymbols = recommendations.map((r) => r.symbol).toList();
      final watchlistSymbols = watchlist.map((w) => w.symbol).toList();
      final allSymbols = {...recSymbols, ...watchlistSymbols}.toList();

      // Type-safe batch load using Dart 3 Records (no manual casting needed)
      final data = await _cachedDb.loadStockListData(
        symbols: allSymbols,
        analysisDate: dateCtx.today,
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

      // Build recommendation details
      final recWithDetails = recommendations.map((rec) {
        final priceHistory = priceHistoriesMap[rec.symbol];
        // Extract close prices for sparkline (limit to 30 days for performance)
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

      // Build watchlist status
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

  /// Run daily update with timeout protection
  ///
  /// Throws [TimeoutException] if update takes longer than [_updateTimeout].
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

      // Invalidate cache after update (data has changed)
      _cachedDb.invalidateCache();

      // Check price alerts and trigger notifications
      final alertsTriggered = await _checkPriceAlerts(
        result.currentPrices,
        result.priceChanges,
      );

      // Show update complete notification if alerts were triggered
      if (alertsTriggered > 0) {
        final notificationNotifier = _ref.read(notificationProvider.notifier);
        await notificationNotifier.showUpdateCompleteNotification(
          recommendationCount: result.recommendationsGenerated,
          alertsTriggered: alertsTriggered,
        );
      }

      // Reload data after update
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

  /// Check price alerts against current prices and trigger notifications
  ///
  /// Returns the number of alerts triggered.
  Future<int> _checkPriceAlerts(
    Map<String, double> currentPrices,
    Map<String, double> priceChanges,
  ) async {
    if (currentPrices.isEmpty) return 0;

    try {
      // Ensure notification service is initialized
      final notificationState = _ref.read(notificationProvider);
      if (!notificationState.isInitialized) {
        await _ref.read(notificationProvider.notifier).initialize();
      }

      final alertNotifier = _ref.read(priceAlertProvider.notifier);
      final notificationNotifier = _ref.read(notificationProvider.notifier);

      // Check and trigger alerts
      final triggered = await alertNotifier.checkAndTriggerAlerts(
        currentPrices,
        priceChanges,
      );

      // Send notifications for each triggered alert
      for (final alert in triggered) {
        await notificationNotifier.showPriceAlertNotification(
          alert,
          currentPrice: currentPrices[alert.symbol],
        );
      }

      return triggered.length;
    } catch (e) {
      // Non-critical: alert check failure shouldn't fail the update
      AppLogger.warning('TodayNotifier', 'Price alert check failed', e);
      return 0;
    }
  }
}

/// Provider for today screen state
final todayProvider = StateNotifierProvider<TodayNotifier, TodayState>((ref) {
  return TodayNotifier(ref);
});
