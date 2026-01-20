import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/utils/price_calculator.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/update_service.dart';
import 'package:afterclose/presentation/providers/providers.dart';

// ==================================================
// Today Screen State
// ==================================================

/// State for today's recommendations and market overview
class TodayState {
  const TodayState({
    this.recommendations = const [],
    this.watchlistStatus = const {},
    this.lastUpdate,
    this.isLoading = false,
    this.isUpdating = false,
    this.updateProgress,
    this.error,
  });

  final List<RecommendationWithDetails> recommendations;
  final Map<String, WatchlistStockStatus> watchlistStatus;
  final DateTime? lastUpdate;
  final bool isLoading;
  final bool isUpdating;
  final UpdateProgress? updateProgress;
  final String? error;

  TodayState copyWith({
    List<RecommendationWithDetails>? recommendations,
    Map<String, WatchlistStockStatus>? watchlistStatus,
    DateTime? lastUpdate,
    bool? isLoading,
    bool? isUpdating,
    UpdateProgress? updateProgress,
    String? error,
  }) {
    return TodayState(
      recommendations: recommendations ?? this.recommendations,
      watchlistStatus: watchlistStatus ?? this.watchlistStatus,
      lastUpdate: lastUpdate ?? this.lastUpdate,
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
  UpdateService get _updateService => _ref.read(updateServiceProvider);

  /// Load today's data
  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Get last update run
      final lastRun = await _db.getLatestUpdateRun();
      final today = DateTime.now();
      final normalizedToday = DateTime.utc(today.year, today.month, today.day);
      final historyStart = normalizedToday.subtract(const Duration(days: 5));

      // Get today's recommendations
      final recommendations = await _db.getRecommendations(normalizedToday);

      // Get watchlist
      final watchlist = await _db.getWatchlist();

      // Collect all symbols we need to load
      final recSymbols = recommendations.map((r) => r.symbol).toList();
      final watchlistSymbols = watchlist.map((w) => w.symbol).toList();
      final allSymbols = {...recSymbols, ...watchlistSymbols}.toList();

      // Batch load all data in parallel
      final results = await Future.wait([
        _db.getStocksBatch(allSymbols),
        _db.getLatestPricesBatch(allSymbols),
        _db.getAnalysesBatch(allSymbols, normalizedToday),
        _db.getReasonsBatch(allSymbols, normalizedToday),
        _db.getPriceHistoryBatch(
          allSymbols,
          startDate: historyStart,
          endDate: normalizedToday,
        ),
      ]);

      final stocksMap = results[0] as Map<String, StockMasterEntry>;
      final latestPricesMap = results[1] as Map<String, DailyPriceEntry>;
      final analysesMap = results[2] as Map<String, DailyAnalysisEntry>;
      final reasonsMap = results[3] as Map<String, List<DailyReasonEntry>>;
      final priceHistoriesMap = results[4] as Map<String, List<DailyPriceEntry>>;

      // Calculate price changes using utility
      final priceChanges = PriceCalculator.calculatePriceChangesBatch(
        priceHistoriesMap,
        latestPricesMap,
      );

      // Build recommendation details
      final recWithDetails = recommendations.map((rec) {
        final priceHistory = priceHistoriesMap[rec.symbol];
        // Extract close prices for sparkline
        final recentPrices = priceHistory
            ?.map((p) => p.close)
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
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Run daily update
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
      final result = await _updateService.runDailyUpdate(
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
      );

      state = state.copyWith(isUpdating: false, updateProgress: null);

      // Reload data after update
      await loadData();

      return result;
    } catch (e) {
      state = state.copyWith(
        isUpdating: false,
        updateProgress: null,
        error: e.toString(),
      );
      rethrow;
    }
  }
}

/// Provider for today screen state
final todayProvider = StateNotifierProvider<TodayNotifier, TodayState>((ref) {
  return TodayNotifier(ref);
});
