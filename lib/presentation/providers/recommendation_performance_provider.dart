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
    this.ruleStats = const [],
    this.isLoading = false,
    this.isBackfilling = false,
    this.backfillProgress = 0.0,
    this.backfillCurrent = 0,
    this.backfillTotal = 0,
    this.error,
  });

  final String selectedPeriod;
  final List<RuleStats> ruleStats;
  final bool isLoading;
  final bool isBackfilling;
  final double backfillProgress;
  final int backfillCurrent;
  final int backfillTotal;
  final String? error;

  /// 總驗證筆數
  int get totalValidated => ruleStats.fold(0, (sum, r) => sum + r.triggerCount);

  /// 加權勝率
  double get overallWinRate {
    final total = totalValidated;
    if (total == 0) return 0;
    final weighted = ruleStats.fold(
      0.0,
      (sum, r) => sum + r.hitRate * r.triggerCount,
    );
    return weighted / total;
  }

  /// 加權平均報酬
  double get overallAvgReturn {
    final total = totalValidated;
    if (total == 0) return 0;
    final weighted = ruleStats.fold(
      0.0,
      (sum, r) => sum + r.avgReturn * r.triggerCount,
    );
    return weighted / total;
  }

  RecommendationPerformanceState copyWith({
    String? selectedPeriod,
    List<RuleStats>? ruleStats,
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
      ruleStats: ruleStats ?? this.ruleStats,
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
      final stats = await _service.getAllRuleStats(
        period: state.selectedPeriod,
      );
      if (_active) {
        state = state.copyWith(ruleStats: stats, isLoading: false);
      }
    } catch (e, stack) {
      AppLogger.error('RecPerf', '載入規則統計失敗', e, stack);
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
    state = state.copyWith(selectedPeriod: period);
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
        // 回填完成後重新載入統計
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
