import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:afterclose/domain/services/rule_accuracy_service.dart';
import 'package:afterclose/presentation/providers/providers.dart';
import 'package:afterclose/presentation/providers/recommendation_performance_provider.dart';

// ==========================================
// Mocks
// ==========================================

class MockRuleAccuracyService extends Mock implements RuleAccuracyService {}

// ==========================================
// Test Helpers
// ==========================================

final _record1 = StockValidationRecord(
  symbol: '2330',
  stockName: '台積電',
  recommendationDate: DateTime(2026, 3, 1),
  primaryRuleId: 'rule_01',
  entryPrice: 100.0,
  holdingDays: 5,
);

final _record2 = StockValidationRecord(
  symbol: '2317',
  stockName: '鴻海',
  recommendationDate: DateTime(2026, 3, 1),
  primaryRuleId: 'rule_02',
  entryPrice: 50.0,
  holdingDays: 5,
);

const _stats = OverallPerformanceStats(
  totalCount: 10,
  successCount: 7,
  avgReturn: 2.5,
);

const _stats5D = OverallPerformanceStats(
  totalCount: 5,
  successCount: 3,
  avgReturn: 1.2,
);

// ==========================================
// Tests
// ==========================================

void main() {
  late MockRuleAccuracyService mockService;
  late ProviderContainer container;

  setUp(() {
    mockService = MockRuleAccuracyService();

    // 預設 mock：讓 build() 中的 Future.microtask(loadData) 成功
    when(
      () => mockService.getStockValidationRecords(
        period: any(named: 'period'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => [_record1]);
    when(
      () =>
          mockService.getOverallPerformanceStats(period: any(named: 'period')),
    ).thenAnswer((_) async => _stats);

    container = ProviderContainer(
      overrides: [ruleAccuracyServiceProvider.overrideWithValue(mockService)],
    );
  });

  tearDown(() {
    container.dispose();
  });

  // ==========================================
  // RecommendationPerformanceState
  // ==========================================

  group('RecommendationPerformanceState', () {
    test('has correct default values', () {
      const state = RecommendationPerformanceState();

      expect(state.selectedPeriod, 'ALL');
      expect(state.stockRecords, isEmpty);
      expect(state.overallStats, isNull);
      expect(state.isLoading, isFalse);
      expect(state.isBackfilling, isFalse);
      expect(state.backfillProgress, 0.0);
      expect(state.backfillCurrent, 0);
      expect(state.backfillTotal, 0);
      expect(state.error, isNull);
    });

    test('copyWith preserves unset values', () {
      const state = RecommendationPerformanceState(
        selectedPeriod: '5D',
        isLoading: true,
      );

      final copied = state.copyWith();
      expect(copied.selectedPeriod, '5D');
      expect(copied.isLoading, isTrue);
    });

    test('copyWith clearError sets error to null', () {
      const state = RecommendationPerformanceState(error: 'old error');

      final cleared = state.copyWith(clearError: true);
      expect(cleared.error, isNull);
    });
  });

  // ==========================================
  // RecommendationPerformanceNotifier
  // ==========================================

  group('RecommendationPerformanceNotifier', () {
    test('build triggers initial loadData', () async {
      // 讀取 provider 觸發 build()（含 Future.microtask loadData）
      container.read(recommendationPerformanceProvider);

      // 等待 microtask 完成
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final state = container.read(recommendationPerformanceProvider);
      expect(state.stockRecords, hasLength(1));
      expect(state.overallStats, isNotNull);
      expect(state.isLoading, isFalse);
    });

    test('selectPeriod changes period and reloads', () async {
      // 等待初始載入完成
      container.read(recommendationPerformanceProvider);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // 為 5D 設定不同回傳值
      when(
        () => mockService.getStockValidationRecords(
          period: '5D',
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [_record1, _record2]);
      when(
        () => mockService.getOverallPerformanceStats(period: '5D'),
      ).thenAnswer((_) async => _stats5D);

      final notifier = container.read(
        recommendationPerformanceProvider.notifier,
      );
      await notifier.selectPeriod('5D');

      final state = container.read(recommendationPerformanceProvider);
      expect(state.selectedPeriod, '5D');
      expect(state.stockRecords, hasLength(2));
      expect(state.overallStats?.avgReturn, 1.2);
    });

    test('selectPeriod skips same period', () async {
      container.read(recommendationPerformanceProvider);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final notifier = container.read(
        recommendationPerformanceProvider.notifier,
      );

      // 重設 callCount
      clearInteractions(mockService);
      when(
        () => mockService.getStockValidationRecords(
          period: any(named: 'period'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [_record1]);
      when(
        () => mockService.getOverallPerformanceStats(
          period: any(named: 'period'),
        ),
      ).thenAnswer((_) async => _stats);

      await notifier.selectPeriod('ALL'); // 相同 period
      verifyNever(
        () => mockService.getStockValidationRecords(
          period: any(named: 'period'),
          limit: any(named: 'limit'),
        ),
      );
    });

    test('loadData handles error', () async {
      container.read(recommendationPerformanceProvider);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // 讓下次 loadData 失敗
      when(
        () => mockService.getStockValidationRecords(
          period: any(named: 'period'),
          limit: any(named: 'limit'),
        ),
      ).thenThrow(Exception('DB error'));

      final notifier = container.read(
        recommendationPerformanceProvider.notifier,
      );
      await notifier.loadData();

      final state = container.read(recommendationPerformanceProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNotNull);
    });
  });

  // ==========================================
  // loadData generation token
  // ==========================================

  group('loadData generation token', () {
    test('stale selectPeriod result does not overwrite newer period', () async {
      // 等待初始載入完成
      container.read(recommendationPerformanceProvider);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // 用 Completer 控制第一次 selectPeriod('5D') 的完成時機
      final firstCompleter = Completer<List<StockValidationRecord>>();
      var recordsCallCount = 0;

      when(
        () => mockService.getStockValidationRecords(
          period: any(named: 'period'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) {
        recordsCallCount++;
        if (recordsCallCount == 1) return firstCompleter.future; // 5D：延遲
        return Future.value([_record2]); // 10D：立即完成
      });
      when(
        () => mockService.getOverallPerformanceStats(
          period: any(named: 'period'),
        ),
      ).thenAnswer((_) async => _stats5D);

      final notifier = container.read(
        recommendationPerformanceProvider.notifier,
      );

      // 先選 5D（不 await），再立刻選 10D
      final firstFuture = notifier.selectPeriod('5D');
      final secondFuture = notifier.selectPeriod('10D');

      // 10D 先完成
      await secondFuture;
      expect(
        container.read(recommendationPerformanceProvider).selectedPeriod,
        '10D',
      );

      // 5D 晚回來
      firstCompleter.complete([_record1]);
      await firstFuture;

      // 最終 state 應該是 10D，不被 5D 覆蓋
      final state = container.read(recommendationPerformanceProvider);
      expect(state.selectedPeriod, '10D');
      expect(state.stockRecords.first.symbol, '2317'); // 10D 的結果
    });
  });
}
