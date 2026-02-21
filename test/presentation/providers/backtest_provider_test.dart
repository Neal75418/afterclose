import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/backtest_models.dart';
import 'package:afterclose/domain/models/screening_condition.dart';
import 'package:afterclose/presentation/providers/providers.dart';
import 'package:afterclose/presentation/providers/backtest_provider.dart';

// =============================================================================
// Mocks
// =============================================================================

class MockAppDatabase extends Mock implements AppDatabase {}

// =============================================================================
// Test Helpers
// =============================================================================

const _testCondition = ScreeningCondition(
  field: ScreeningField.close,
  operator: ScreeningOperator.greaterThan,
  value: 100.0,
);

// =============================================================================
// Tests
// =============================================================================

void main() {
  late MockAppDatabase mockDb;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(DateTime(2026));
  });

  setUp(() {
    mockDb = MockAppDatabase();
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(mockDb)],
    );
  });

  tearDown(() {
    container.dispose();
  });

  // ===========================================================================
  // BacktestState
  // ===========================================================================

  group('BacktestState', () {
    test('has correct default values', () {
      const state = BacktestState();

      expect(state.config.periodMonths, 3);
      expect(state.config.holdingDays, 5);
      expect(state.config.samplingInterval, 1);
      expect(state.result, isNull);
      expect(state.isExecuting, isFalse);
      expect(state.progress, 0.0);
      expect(state.progressTotal, 0);
      expect(state.progressCurrent, 0);
      expect(state.error, isNull);
    });

    test('copyWith preserves unset values', () {
      const state = BacktestState(
        isExecuting: true,
        progress: 0.5,
        progressTotal: 10,
        progressCurrent: 5,
      );

      final copied = state.copyWith();
      expect(copied.isExecuting, isTrue);
      expect(copied.progress, 0.5);
      expect(copied.progressTotal, 10);
      expect(copied.progressCurrent, 5);
    });

    test('copyWith clearResult sets result to null', () {
      final result = BacktestResult(
        config: const BacktestConfig(periodMonths: 3, holdingDays: 5),
        trades: [],
        summary: const BacktestSummary(
          totalTrades: 0,
          winningTrades: 0,
          losingTrades: 0,
          avgReturn: 0,
          medianReturn: 0,
          maxReturn: 0,
          minReturn: 0,
          stdDeviation: 0,
          winRate: 0,
        ),
        executionTime: const Duration(seconds: 1),
        tradingDaysScanned: 60,
      );
      final state = BacktestState(result: result);
      final cleared = state.copyWith(clearResult: true);
      expect(cleared.result, isNull);
    });

    test('copyWith clearError sets error to null', () {
      const state = BacktestState(error: 'some error');
      final cleared = state.copyWith(clearError: true);
      expect(cleared.error, isNull);
    });

    test('copyWith updates individual fields', () {
      const state = BacktestState();
      final updated = state.copyWith(
        isExecuting: true,
        progress: 0.75,
        progressTotal: 20,
        progressCurrent: 15,
      );
      expect(updated.isExecuting, isTrue);
      expect(updated.progress, 0.75);
      expect(updated.progressTotal, 20);
      expect(updated.progressCurrent, 15);
    });
  });

  // ===========================================================================
  // BacktestConfig
  // ===========================================================================

  group('BacktestConfig', () {
    test('has correct totalDaysBack', () {
      const config = BacktestConfig(periodMonths: 3, holdingDays: 5);
      expect(config.totalDaysBack, 93); // 3 * 31
    });

    test('default samplingInterval is 1', () {
      const config = BacktestConfig(periodMonths: 6, holdingDays: 10);
      expect(config.samplingInterval, 1);
    });
  });

  // ===========================================================================
  // BacktestNotifier config management
  // ===========================================================================

  group('BacktestNotifier config management', () {
    test('updatePeriod changes periodMonths and clears result', () {
      final notifier = container.read(backtestProvider.notifier);
      notifier.updatePeriod(6);

      final state = container.read(backtestProvider);
      expect(state.config.periodMonths, 6);
      expect(state.config.holdingDays, 5); // preserved
      expect(state.config.samplingInterval, 1); // preserved
      expect(state.result, isNull);
    });

    test('updateHoldingDays changes holdingDays and clears result', () {
      final notifier = container.read(backtestProvider.notifier);
      notifier.updateHoldingDays(10);

      final state = container.read(backtestProvider);
      expect(state.config.holdingDays, 10);
      expect(state.config.periodMonths, 3); // preserved
    });

    test('updateSamplingInterval changes interval and clears result', () {
      final notifier = container.read(backtestProvider.notifier);
      notifier.updateSamplingInterval(5);

      final state = container.read(backtestProvider);
      expect(state.config.samplingInterval, 5);
      expect(state.config.periodMonths, 3); // preserved
      expect(state.config.holdingDays, 5); // preserved
    });

    test('multiple config updates preserve other settings', () {
      final notifier = container.read(backtestProvider.notifier);
      notifier.updatePeriod(12);
      notifier.updateHoldingDays(20);
      notifier.updateSamplingInterval(3);

      final state = container.read(backtestProvider);
      expect(state.config.periodMonths, 12);
      expect(state.config.holdingDays, 20);
      expect(state.config.samplingInterval, 3);
    });
  });

  // ===========================================================================
  // BacktestNotifier executeBacktest
  // ===========================================================================

  group('BacktestNotifier executeBacktest', () {
    test('returns immediately when conditions are empty', () async {
      final notifier = container.read(backtestProvider.notifier);
      await notifier.executeBacktest([]);

      final state = container.read(backtestProvider);
      expect(state.isExecuting, isFalse);
      expect(state.result, isNull);
    });

    test('handles execution error gracefully', () async {
      when(
        () => mockDb.getAnalysisForDate(any()),
      ).thenThrow(Exception('DB failure'));

      final notifier = container.read(backtestProvider.notifier);
      await notifier.executeBacktest([_testCondition]);

      final state = container.read(backtestProvider);
      expect(state.isExecuting, isFalse);
      expect(state.error, isNotNull);
      expect(state.error, contains('DB failure'));
    });

    test('resets isExecuting on error', () async {
      when(
        () => mockDb.getAnalysisForDate(any()),
      ).thenThrow(Exception('Query error'));

      final notifier = container.read(backtestProvider.notifier);
      await notifier.executeBacktest([_testCondition]);

      final state = container.read(backtestProvider);
      expect(state.isExecuting, isFalse);
      expect(state.result, isNull);
    });
  });

  // ===========================================================================
  // BacktestNotifier clearResults
  // ===========================================================================

  group('BacktestNotifier clearResults', () {
    test('clears result and error and resets progress', () {
      final notifier = container.read(backtestProvider.notifier);

      // Simulate some state changes
      notifier.updatePeriod(6);

      notifier.clearResults();

      final state = container.read(backtestProvider);
      expect(state.result, isNull);
      expect(state.error, isNull);
      expect(state.progress, 0.0);
      // Config should be preserved
      expect(state.config.periodMonths, 6);
    });
  });

  // ===========================================================================
  // Provider declaration
  // ===========================================================================

  group('backtestProvider', () {
    test('provides initial state', () {
      final state = container.read(backtestProvider);
      expect(state, isA<BacktestState>());
      expect(state.isExecuting, isFalse);
    });

    test('notifier is accessible', () {
      final notifier = container.read(backtestProvider.notifier);
      expect(notifier, isA<BacktestNotifier>());
    });
  });
}
