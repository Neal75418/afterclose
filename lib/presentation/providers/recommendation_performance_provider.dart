import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/domain/services/rule_accuracy_service.dart';
import 'package:afterclose/presentation/providers/providers.dart';

// ==================================================
// State
// ==================================================

class RecommendationPerformanceState {
  const RecommendationPerformanceState({
    this.selectedPeriod = 'ALL',
    this.stockRecords = const [],
    this.overallStats,
    this.isLoading = false,
    this.isBackfilling = false,
    this.backfillProgress = 0.0,
    this.backfillCurrent = 0,
    this.backfillTotal = 0,
    this.error,
  });

  final String selectedPeriod;
  final List<StockValidationRecord> stockRecords;
  final OverallPerformanceStats? overallStats;
  final bool isLoading;
  final bool isBackfilling;
  final double backfillProgress;
  final int backfillCurrent;
  final int backfillTotal;
  final String? error;

  RecommendationPerformanceState copyWith({
    String? selectedPeriod,
    List<StockValidationRecord>? stockRecords,
    OverallPerformanceStats? overallStats,
    bool? isLoading,
    bool? isBackfilling,
    double? backfillProgress,
    int? backfillCurrent,
    int? backfillTotal,
    String? error,
    bool clearError = false,
  }) {
    return RecommendationPerformanceState(
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      stockRecords: stockRecords ?? this.stockRecords,
      overallStats: overallStats ?? this.overallStats,
      isLoading: isLoading ?? this.isLoading,
      isBackfilling: isBackfilling ?? this.isBackfilling,
      backfillProgress: backfillProgress ?? this.backfillProgress,
      backfillCurrent: backfillCurrent ?? this.backfillCurrent,
      backfillTotal: backfillTotal ?? this.backfillTotal,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ==================================================
// Notifier
// ==================================================

class RecommendationPerformanceNotifier
    extends Notifier<RecommendationPerformanceState> {
  var _active = true;

  @override
  RecommendationPerformanceState build() {
    _active = true;
    ref.onDispose(() => _active = false);

    // 初始載入
    Future.microtask(() => loadData());

    return const RecommendationPerformanceState();
  }

  RuleAccuracyService get _service => ref.read(ruleAccuracyServiceProvider);

  // ==================================================
  // 資料載入
  // ==================================================

  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final period = state.selectedPeriod;
      final (records, stats) = await (
        _service.getStockValidationRecords(period: period),
        _service.getOverallPerformanceStats(period: period),
      ).wait;

      if (_active) {
        state = state.copyWith(
          stockRecords: records,
          overallStats: stats,
          isLoading: false,
        );
      }
    } catch (e, stack) {
      AppLogger.error('RecPerf', '載入績效資料失敗', e, stack);
      if (_active) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }
  }

  // ==================================================
  // 切換持有天數
  // ==================================================

  Future<void> selectPeriod(String period) async {
    if (state.selectedPeriod == period) return;
    // 清空舊資料，讓 loading spinner 正確顯示
    state = state.copyWith(selectedPeriod: period, stockRecords: const []);
    await loadData();
  }

  // ==================================================
  // 批次回填
  // ==================================================

  Future<void> runBackfill() async {
    if (state.isBackfilling) return;

    state = state.copyWith(
      isBackfilling: true,
      backfillProgress: 0.0,
      backfillCurrent: 0,
      backfillTotal: 0,
      clearError: true,
    );

    try {
      await _service.backfillAllHistoricalRecommendations(
        onProgress: (current, total) {
          if (_active) {
            state = state.copyWith(
              backfillProgress: total > 0 ? current / total : 0,
              backfillCurrent: current,
              backfillTotal: total,
            );
          }
        },
        isCancelled: () => !_active,
      );

      if (_active) {
        state = state.copyWith(isBackfilling: false, backfillProgress: 1.0);
        // 回填完成後重新載入資料
        await loadData();
      }
    } catch (e, stack) {
      AppLogger.error('RecPerf', '批次回填失敗', e, stack);
      if (_active) {
        state = state.copyWith(isBackfilling: false, error: e.toString());
      }
    }
  }
}

// ==================================================
// Provider
// ==================================================

final recommendationPerformanceProvider =
    NotifierProvider<
      RecommendationPerformanceNotifier,
      RecommendationPerformanceState
    >(RecommendationPerformanceNotifier.new);
