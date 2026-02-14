import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart'
    show StateNotifier, StateNotifierProvider;

import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/backtest_models.dart';
import 'package:afterclose/domain/models/screening_condition.dart';
import 'package:afterclose/domain/services/backtest_service.dart';
import 'package:afterclose/data/repositories/screening_repository.dart';
import 'package:afterclose/domain/services/screening_service.dart';
import 'package:afterclose/presentation/providers/providers.dart';

// ==================================================
// State
// ==================================================

class BacktestState {
  const BacktestState({
    this.config = const BacktestConfig(
      periodMonths: 3,
      holdingDays: 5,
      samplingInterval: 1,
    ),
    this.result,
    this.isExecuting = false,
    this.progress = 0.0,
    this.progressTotal = 0,
    this.progressCurrent = 0,
    this.error,
  });

  final BacktestConfig config;
  final BacktestResult? result;
  final bool isExecuting;
  final double progress;
  final int progressTotal;
  final int progressCurrent;
  final String? error;

  BacktestState copyWith({
    BacktestConfig? config,
    BacktestResult? result,
    bool clearResult = false,
    bool? isExecuting,
    double? progress,
    int? progressTotal,
    int? progressCurrent,
    String? error,
    bool clearError = false,
  }) {
    return BacktestState(
      config: config ?? this.config,
      result: clearResult ? null : (result ?? this.result),
      isExecuting: isExecuting ?? this.isExecuting,
      progress: progress ?? this.progress,
      progressTotal: progressTotal ?? this.progressTotal,
      progressCurrent: progressCurrent ?? this.progressCurrent,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ==================================================
// Notifier
// ==================================================

class BacktestNotifier extends StateNotifier<BacktestState> {
  BacktestNotifier(this._ref) : super(const BacktestState());

  final Ref _ref;

  AppDatabase get _db => _ref.read(databaseProvider);

  // ==========================================
  // 設定管理
  // ==========================================

  void updatePeriod(int months) {
    state = state.copyWith(
      config: BacktestConfig(
        periodMonths: months,
        holdingDays: state.config.holdingDays,
        samplingInterval: state.config.samplingInterval,
      ),
      clearResult: true,
    );
  }

  void updateHoldingDays(int days) {
    state = state.copyWith(
      config: BacktestConfig(
        periodMonths: state.config.periodMonths,
        holdingDays: days,
        samplingInterval: state.config.samplingInterval,
      ),
      clearResult: true,
    );
  }

  void updateSamplingInterval(int interval) {
    state = state.copyWith(
      config: BacktestConfig(
        periodMonths: state.config.periodMonths,
        holdingDays: state.config.holdingDays,
        samplingInterval: interval,
      ),
      clearResult: true,
    );
  }

  // ==========================================
  // 回測執行
  // ==========================================

  Future<void> executeBacktest(List<ScreeningCondition> conditions) async {
    if (conditions.isEmpty) return;

    state = state.copyWith(
      isExecuting: true,
      progress: 0.0,
      progressCurrent: 0,
      progressTotal: 0,
      clearError: true,
      clearResult: true,
    );

    try {
      final service = BacktestService(
        database: _db,
        screeningService: ScreeningService(
          repository: ScreeningRepository(database: _db),
        ),
      );

      final result = await service.execute(
        conditions: conditions,
        config: state.config,
        onProgress: (current, total) {
          if (mounted) {
            state = state.copyWith(
              progress: total > 0 ? current / total : 0,
              progressCurrent: current,
              progressTotal: total,
            );
          }
        },
        isCancelled: () => !mounted,
      );

      if (mounted) {
        state = state.copyWith(
          result: result,
          isExecuting: false,
          progress: 1.0,
        );
      }
    } catch (e) {
      AppLogger.error('Backtest', '回測執行失敗', e);
      if (mounted) {
        state = state.copyWith(isExecuting: false, error: e.toString());
      }
    }
  }

  void clearResults() {
    state = state.copyWith(clearResult: true, clearError: true, progress: 0.0);
  }
}

// ==================================================
// Provider
// ==================================================

final backtestProvider = StateNotifierProvider<BacktestNotifier, BacktestState>(
  (ref) {
    return BacktestNotifier(ref);
  },
);
