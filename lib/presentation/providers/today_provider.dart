import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  });

  final String symbol;
  final double score;
  final int rank;
  final String? stockName;
  final double? latestClose;
  final double? priceChange;
  final List<DailyReasonEntry> reasons;
  final String? trendState;
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

      // Get today's recommendations
      final recommendations = await _db.getRecommendations(normalizedToday);

      // Build recommendation details
      final recWithDetails = <RecommendationWithDetails>[];
      for (var i = 0; i < recommendations.length; i++) {
        final rec = recommendations[i];
        final stock = await _db.getStock(rec.symbol);
        final latestPrice = await _db.getLatestPrice(rec.symbol);
        final reasons = await _db.getReasons(rec.symbol, normalizedToday);
        final analysis = await _db.getAnalysis(rec.symbol, normalizedToday);

        // Calculate price change
        double? priceChange;
        if (latestPrice?.close != null) {
          final history = await _db.getPriceHistory(
            rec.symbol,
            startDate: normalizedToday.subtract(const Duration(days: 5)),
            endDate: normalizedToday,
          );
          if (history.length >= 2) {
            final prevClose = history[history.length - 2].close;
            if (prevClose != null && prevClose > 0) {
              priceChange =
                  ((latestPrice!.close! - prevClose) / prevClose) * 100;
            }
          }
        }

        recWithDetails.add(
          RecommendationWithDetails(
            symbol: rec.symbol,
            score: rec.score,
            rank: rec.rank,
            stockName: stock?.name,
            latestClose: latestPrice?.close,
            priceChange: priceChange,
            reasons: reasons,
            trendState: analysis?.trendState,
          ),
        );
      }

      // Get watchlist status
      final watchlist = await _db.getWatchlist();
      final watchlistStatus = <String, WatchlistStockStatus>{};

      for (final item in watchlist) {
        final stock = await _db.getStock(item.symbol);
        final latestPrice = await _db.getLatestPrice(item.symbol);
        final analysis = await _db.getAnalysis(item.symbol, normalizedToday);
        final reasons = await _db.getReasons(item.symbol, normalizedToday);

        // Calculate price change
        double? priceChange;
        if (latestPrice?.close != null) {
          final history = await _db.getPriceHistory(
            item.symbol,
            startDate: normalizedToday.subtract(const Duration(days: 5)),
            endDate: normalizedToday,
          );
          if (history.length >= 2) {
            final prevClose = history[history.length - 2].close;
            if (prevClose != null && prevClose > 0) {
              priceChange =
                  ((latestPrice!.close! - prevClose) / prevClose) * 100;
            }
          }
        }

        watchlistStatus[item.symbol] = WatchlistStockStatus(
          symbol: item.symbol,
          stockName: stock?.name,
          latestClose: latestPrice?.close,
          priceChange: priceChange,
          hasSignal: reasons.isNotEmpty,
          signalType: analysis?.trendState,
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
