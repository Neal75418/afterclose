import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:afterclose/core/constants/calibrated_scores/horizon.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/database/cached_accessor.dart';
import 'package:afterclose/data/repositories/analysis_repository.dart';
import 'package:afterclose/domain/services/data_sync_service.dart';
import 'package:afterclose/domain/services/update_service.dart';
import 'package:afterclose/presentation/providers/selected_horizon_provider.dart';
import 'package:afterclose/presentation/providers/today_provider.dart';
import 'package:afterclose/presentation/providers/providers.dart';

// ==========================================
// Mocks
// ==========================================

class MockAppDatabase extends Mock implements AppDatabase {}

class MockCachedDatabaseAccessor extends Mock
    implements CachedDatabaseAccessor {}

class MockAnalysisRepository extends Mock implements AnalysisRepository {}

class MockUpdateService extends Mock implements UpdateService {}

class MockDataSyncService extends Mock implements DataSyncService {}

// ==========================================
// Test Helpers
// ==========================================

/// 創建測試用的推薦資料
DailyRecommendationEntry createRecommendation({
  required String symbol,
  required double score,
  required int rank,
  DateTime? date,
}) {
  return DailyRecommendationEntry(
    symbol: symbol,
    date: date ?? DateTime(2026, 2, 13),
    score: score,
    rank: rank,
    horizon: 'short',
  );
}

/// 創建測試用的股票資料
StockMasterEntry createStock({
  required String symbol,
  String? name,
  String? market,
}) {
  return StockMasterEntry(
    symbol: symbol,
    name: name ?? '測試股票',
    market: market ?? 'TWSE',
    industry: '測試產業',
    isActive: true,
    updatedAt: DateTime(2026, 2, 13),
  );
}

/// 創建測試用的價格資料
DailyPriceEntry createPrice({
  required String symbol,
  required DateTime date,
  required double close,
}) {
  return DailyPriceEntry(
    symbol: symbol,
    date: date,
    open: close,
    high: close * 1.02,
    low: close * 0.98,
    close: close,
    volume: 1000,
  );
}

// ==========================================
// Tests
// ==========================================

void main() {
  late MockAppDatabase mockDb;
  late MockCachedDatabaseAccessor mockCachedDb;
  late MockAnalysisRepository mockAnalysisRepo;
  late MockUpdateService mockUpdateService;
  late MockDataSyncService mockDataSyncService;
  late ProviderContainer container;

  setUpAll(() {
    // Stage 5c: Horizon enum 需要 fallback 才能用 any(named: 'horizon')
    registerFallbackValue(Horizon.short);
  });

  setUp(() {
    mockDb = MockAppDatabase();
    mockCachedDb = MockCachedDatabaseAccessor();
    mockAnalysisRepo = MockAnalysisRepository();
    mockUpdateService = MockUpdateService();
    mockDataSyncService = MockDataSyncService();

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(mockDb),
        cachedDbProvider.overrideWithValue(mockCachedDb),
        analysisRepositoryProvider.overrideWithValue(mockAnalysisRepo),
        updateServiceProvider.overrideWithValue(mockUpdateService),
        dataSyncServiceProvider.overrideWithValue(mockDataSyncService),
      ],
    );

    // 設置預設的 mock 行為
    when(() => mockDb.getWatchlist()).thenAnswer((_) async => []);
    when(() => mockDb.getLatestUpdateRun()).thenAnswer((_) async => null);
    when(
      () => mockDb.getLatestDataDate(),
    ).thenAnswer((_) async => DateTime(2026, 2, 13));
    when(
      () => mockDb.getLatestInstitutionalDate(),
    ).thenAnswer((_) async => DateTime(2026, 2, 13));

    when(
      () => mockDataSyncService.getDisplayDataDate(any(), any()),
    ).thenReturn(DateTime(2026, 2, 13));

    when(
      () => mockCachedDb.loadStockListData(
        symbols: any(named: 'symbols'),
        analysisDate: any(named: 'analysisDate'),
        historyStart: any(named: 'historyStart'),
      ),
    ).thenAnswer(
      (_) async => (
        stocks: <String, StockMasterEntry>{},
        latestPrices: <String, DailyPriceEntry>{},
        analyses: <String, DailyAnalysisEntry>{},
        reasons: <String, List<DailyReasonEntry>>{},
        priceHistories: <String, List<DailyPriceEntry>>{},
      ),
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('TodayState', () {
    test('has correct default values', () {
      const state = TodayState();

      expect(state.recommendations, isEmpty);
      expect(state.lastUpdate, isNull);
      expect(state.dataDate, isNull);
      expect(state.isLoading, isFalse);
      expect(state.isUpdating, isFalse);
      expect(state.updateProgress, isNull);
      expect(state.error, isNull);
    });

    test('copyWith creates new instance with updated values', () {
      const originalState = TodayState(isLoading: true);

      final newState = originalState.copyWith(
        isLoading: false,
        error: 'Test error',
      );

      expect(newState.isLoading, isFalse);
      expect(newState.error, equals('Test error'));
      // 未修改的欄位應保持原值
      expect(newState.recommendations, equals(originalState.recommendations));
    });

    test('copyWith with sentinel preserves null values', () {
      const originalState = TodayState(error: 'Original error');

      // 不傳入 error 參數，應保留原值
      final state1 = originalState.copyWith(isLoading: true);
      expect(state1.error, equals('Original error'));

      // 明確傳入 null，應清除錯誤
      final state2 = originalState.copyWith(error: null);
      expect(state2.error, isNull);
    });
  });

  group('RecommendationWithDetails', () {
    test('reasonTypes are computed lazily', () {
      final rec = RecommendationWithDetails(
        symbol: '2330',
        score: 85.0,
        rank: 1,
        reasons: [
          DailyReasonEntry(
            symbol: '2330',
            date: DateTime(2026, 2, 13),
            rank: 1,
            reasonType: 'GOLDEN_CROSS',
            evidenceJson: '{}',
            ruleScoreShort: 10.0,
            ruleScoreLong: 10.0,
          ),
          DailyReasonEntry(
            symbol: '2330',
            date: DateTime(2026, 2, 13),
            rank: 2,
            reasonType: 'VOLUME_BREAKOUT',
            evidenceJson: '{}',
            ruleScoreShort: 8.0,
            ruleScoreLong: 8.0,
          ),
        ],
      );

      expect(rec.reasonTypes, equals(['GOLDEN_CROSS', 'VOLUME_BREAKOUT']));
    });

    test('reasonTypes handles empty reasons list', () {
      final rec = RecommendationWithDetails(
        symbol: '2330',
        score: 85.0,
        rank: 1,
      );

      expect(rec.reasonTypes, isEmpty);
    });
  });

  group('UpdateProgress', () {
    test('calculates progress correctly', () {
      const progress1 = UpdateProgress(
        currentStep: 5,
        totalSteps: 10,
        message: 'Step 5/10',
      );
      expect(progress1.progress, equals(0.5));

      const progress2 = UpdateProgress(
        currentStep: 10,
        totalSteps: 10,
        message: 'Complete',
      );
      expect(progress2.progress, equals(1.0));

      const progress3 = UpdateProgress(
        currentStep: 0,
        totalSteps: 10,
        message: 'Starting',
      );
      expect(progress3.progress, equals(0.0));
    });

    test('handles zero total steps gracefully', () {
      const progress = UpdateProgress(
        currentStep: 5,
        totalSteps: 0,
        message: 'Invalid state',
      );

      expect(progress.progress, equals(0.0));
    });
  });

  group('TodayNotifier', () {
    test('initial state is loading=false with empty recommendations', () {
      final state = container.read(todayProvider);

      expect(state.isLoading, isFalse);
      expect(state.isUpdating, isFalse);
      expect(state.recommendations, isEmpty);
      expect(state.error, isNull);
    });

    test('loadData sets loading state and loads recommendations', () async {
      // Arrange
      final mockRecs = [
        createRecommendation(symbol: '2330', score: 85.0, rank: 1),
        createRecommendation(symbol: '2317', score: 80.0, rank: 2),
      ];

      when(
        () => mockAnalysisRepo.getTodayRecommendations(
          horizon: any(named: 'horizon'),
        ),
      ).thenAnswer((_) async => mockRecs);

      when(
        () => mockCachedDb.loadStockListData(
          symbols: any(named: 'symbols'),
          analysisDate: any(named: 'analysisDate'),
          historyStart: any(named: 'historyStart'),
        ),
      ).thenAnswer(
        (_) async => (
          stocks: {
            '2330': createStock(symbol: '2330', name: '台積電'),
            '2317': createStock(symbol: '2317', name: '鴻海'),
          },
          latestPrices: {
            '2330': createPrice(
              symbol: '2330',
              date: DateTime(2026, 2, 13),
              close: 600.0,
            ),
            '2317': createPrice(
              symbol: '2317',
              date: DateTime(2026, 2, 13),
              close: 100.0,
            ),
          },
          analyses: <String, DailyAnalysisEntry>{},
          reasons: <String, List<DailyReasonEntry>>{},
          priceHistories: <String, List<DailyPriceEntry>>{},
        ),
      );

      // Act
      final notifier = container.read(todayProvider.notifier);
      final loadFuture = notifier.loadData();

      // 檢查 loading 狀態
      expect(container.read(todayProvider).isLoading, isTrue);

      await loadFuture;

      // Assert
      final state = container.read(todayProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.recommendations.length, equals(2));
      expect(state.recommendations[0].symbol, equals('2330'));
      expect(state.recommendations[1].symbol, equals('2317'));
    });

    test('loadData handles error gracefully', () async {
      // Arrange
      when(
        () => mockAnalysisRepo.getTodayRecommendations(
          horizon: any(named: 'horizon'),
        ),
      ).thenThrow(Exception('Database error'));

      // Act
      final notifier = container.read(todayProvider.notifier);
      await notifier.loadData();

      // Assert
      final state = container.read(todayProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNotNull);
      expect(state.error, isNotEmpty);
      expect(state.recommendations, isEmpty);
    });

    test('loadData clears previous error on successful load', () async {
      // Arrange - 先設定錯誤狀態
      when(
        () => mockAnalysisRepo.getTodayRecommendations(
          horizon: any(named: 'horizon'),
        ),
      ).thenThrow(Exception('First error'));

      final notifier = container.read(todayProvider.notifier);
      await notifier.loadData();

      expect(container.read(todayProvider).error, isNotNull);

      // Arrange - 設定成功的 mock
      when(
        () => mockAnalysisRepo.getTodayRecommendations(
          horizon: any(named: 'horizon'),
        ),
      ).thenAnswer(
        (_) async => [
          createRecommendation(symbol: '2330', score: 85.0, rank: 1),
        ],
      );

      // Act - 重新載入
      await notifier.loadData();

      // Assert - 錯誤應該被清除
      final state = container.read(todayProvider);
      expect(state.error, isNull);
      expect(state.recommendations.length, equals(1));
    });

    test(
      'loadData respects watchlist and merges with recommendations',
      () async {
        // Arrange
        final mockRecs = [
          createRecommendation(symbol: '2330', score: 85.0, rank: 1),
        ];

        final mockWatchlist = [
          WatchlistEntry(symbol: '2317', createdAt: DateTime(2026, 2, 13)),
        ];

        when(
          () => mockAnalysisRepo.getTodayRecommendations(
            horizon: any(named: 'horizon'),
          ),
        ).thenAnswer((_) async => mockRecs);

        when(
          () => mockDb.getWatchlist(),
        ).thenAnswer((_) async => mockWatchlist);

        List<String>? capturedSymbols;
        when(
          () => mockCachedDb.loadStockListData(
            symbols: any(named: 'symbols'),
            analysisDate: any(named: 'analysisDate'),
            historyStart: any(named: 'historyStart'),
          ),
        ).thenAnswer((invocation) async {
          capturedSymbols =
              invocation.namedArguments[const Symbol('symbols')]
                  as List<String>;
          return (
            stocks: <String, StockMasterEntry>{},
            latestPrices: <String, DailyPriceEntry>{},
            analyses: <String, DailyAnalysisEntry>{},
            reasons: <String, List<DailyReasonEntry>>{},
            priceHistories: <String, List<DailyPriceEntry>>{},
          );
        });

        // Act
        final notifier = container.read(todayProvider.notifier);
        await notifier.loadData();

        // Assert - 應該載入推薦 + 自選股的所有符號
        expect(capturedSymbols, isNotNull);
        expect(capturedSymbols, containsAll(['2330', '2317']));
      },
    );
  });

  group('Edge Cases', () {
    test('handles empty recommendations list', () async {
      // Arrange
      when(
        () => mockAnalysisRepo.getTodayRecommendations(
          horizon: any(named: 'horizon'),
        ),
      ).thenAnswer((_) async => []);

      // Act
      final notifier = container.read(todayProvider.notifier);
      await notifier.loadData();

      // Assert
      final state = container.read(todayProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.recommendations, isEmpty);
    });

    test('handles null dataDate gracefully', () async {
      // Arrange
      when(() => mockDb.getLatestDataDate()).thenAnswer((_) async => null);
      when(
        () => mockDb.getLatestInstitutionalDate(),
      ).thenAnswer((_) async => null);
      when(
        () => mockDataSyncService.getDisplayDataDate(null, null),
      ).thenReturn(null);

      when(
        () => mockAnalysisRepo.getTodayRecommendations(
          horizon: any(named: 'horizon'),
        ),
      ).thenAnswer((_) async => []);

      // Act
      final notifier = container.read(todayProvider.notifier);
      await notifier.loadData();

      // Assert
      final state = container.read(todayProvider);
      expect(state.isLoading, isFalse);
      expect(state.dataDate, isNull); // 應優雅處理 null dataDate
    });

    test('handles missing stock details in loadStockListData', () async {
      // Arrange
      final mockRecs = [
        createRecommendation(symbol: '2330', score: 85.0, rank: 1),
      ];

      when(
        () => mockAnalysisRepo.getTodayRecommendations(
          horizon: any(named: 'horizon'),
        ),
      ).thenAnswer((_) async => mockRecs);

      // 返回空的資料（模擬找不到股票詳情的情況）
      when(
        () => mockCachedDb.loadStockListData(
          symbols: any(named: 'symbols'),
          analysisDate: any(named: 'analysisDate'),
          historyStart: any(named: 'historyStart'),
        ),
      ).thenAnswer(
        (_) async => (
          stocks: <String, StockMasterEntry>{}, // 空的
          latestPrices: <String, DailyPriceEntry>{}, // 空的
          analyses: <String, DailyAnalysisEntry>{},
          reasons: <String, List<DailyReasonEntry>>{},
          priceHistories: <String, List<DailyPriceEntry>>{},
        ),
      );

      // Act
      final notifier = container.read(todayProvider.notifier);
      await notifier.loadData();

      // Assert - 應該正常完成，不應拋出異常
      final state = container.read(todayProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.recommendations.length, equals(1));
      // 詳細資訊可能為 null，但不應導致錯誤
      expect(state.recommendations[0].stockName, isNull);
      expect(state.recommendations[0].latestClose, isNull);
    });
  });

  // ==========================================
  // Stage 5c — horizon switch reload behavior
  // ==========================================

  group('TodayNotifier horizon switch', () {
    test(
      'switching horizon triggers reload with new horizon and swaps recommendations',
      () async {
        // 短線推薦：2330 + 2317
        final shortRecs = [
          createRecommendation(symbol: '2330', score: 85.0, rank: 1),
          createRecommendation(symbol: '2317', score: 80.0, rank: 2),
        ];
        // 長線推薦：完全不同的兩檔（驗證 list 真的有換）
        final longRecs = [
          createRecommendation(symbol: '2454', score: 88.0, rank: 1),
          createRecommendation(symbol: '2412', score: 75.0, rank: 2),
        ];

        when(
          () =>
              mockAnalysisRepo.getTodayRecommendations(horizon: Horizon.short),
        ).thenAnswer((_) async => shortRecs);
        when(
          () => mockAnalysisRepo.getTodayRecommendations(horizon: Horizon.long),
        ).thenAnswer((_) async => longRecs);

        // 初始載入（短線）
        final notifier = container.read(todayProvider.notifier);
        await notifier.loadData();

        var state = container.read(todayProvider);
        expect(state.recommendations.map((r) => r.symbol).toList(), [
          '2330',
          '2317',
        ]);

        // 切換到長線 — ref.listen callback 應該觸發 _reloadForHorizon
        container.read(selectedHorizonProvider.notifier).select(Horizon.long);

        // _reloadForHorizon 是 async fire-and-forget，要等 microtask 與
        // pending future 完成後才能斷言
        // Drain microtask queue until quiescent so the listener-spawned
        // _reloadForHorizon Future and all its nested awaits complete.
        await pumpEventQueue();

        state = container.read(todayProvider);
        expect(
          state.recommendations.map((r) => r.symbol).toList(),
          ['2454', '2412'],
          reason: '長線推薦應取代短線清單',
        );
      },
    );

    test(
      '_reloadForHorizon preserves lastUpdate and dataDate from original loadData',
      () async {
        final shortRecs = [
          createRecommendation(symbol: '2330', score: 85.0, rank: 1),
        ];
        final longRecs = [
          createRecommendation(symbol: '2454', score: 88.0, rank: 1),
        ];
        final lastRunFinishedAt = DateTime(2026, 2, 13, 16, 30);

        when(() => mockDb.getLatestUpdateRun()).thenAnswer(
          (_) async => UpdateRunEntry(
            id: 1,
            runDate: DateTime(2026, 2, 13),
            startedAt: DateTime(2026, 2, 13, 16, 0),
            finishedAt: lastRunFinishedAt,
            status: 'success',
          ),
        );
        when(
          () =>
              mockAnalysisRepo.getTodayRecommendations(horizon: Horizon.short),
        ).thenAnswer((_) async => shortRecs);
        when(
          () => mockAnalysisRepo.getTodayRecommendations(horizon: Horizon.long),
        ).thenAnswer((_) async => longRecs);

        final notifier = container.read(todayProvider.notifier);
        await notifier.loadData();

        final stateBefore = container.read(todayProvider);
        expect(stateBefore.lastUpdate, equals(lastRunFinishedAt));
        expect(stateBefore.dataDate, isNotNull);
        final dataDateBefore = stateBefore.dataDate;

        // 切換 horizon
        container.read(selectedHorizonProvider.notifier).select(Horizon.long);
        // Drain microtask queue until quiescent so the listener-spawned
        // _reloadForHorizon Future and all its nested awaits complete.
        await pumpEventQueue();

        final stateAfter = container.read(todayProvider);
        expect(
          stateAfter.lastUpdate,
          equals(lastRunFinishedAt),
          reason: 'lastUpdate 應保留原值',
        );
        expect(
          stateAfter.dataDate,
          equals(dataDateBefore),
          reason: 'dataDate 應保留原值',
        );
        // recommendations 已換成長線
        expect(stateAfter.recommendations.first.symbol, equals('2454'));
      },
    );

    test('selecting same horizon is a no-op', () async {
      final shortRecs = [
        createRecommendation(symbol: '2330', score: 85.0, rank: 1),
      ];

      when(
        () => mockAnalysisRepo.getTodayRecommendations(horizon: Horizon.short),
      ).thenAnswer((_) async => shortRecs);

      final notifier = container.read(todayProvider.notifier);
      await notifier.loadData();

      // 重置 verification counter
      clearInteractions(mockAnalysisRepo);

      // 「切換」回 short — 應該不觸發 reload
      container.read(selectedHorizonProvider.notifier).select(Horizon.short);
      // Drain microtask queue (same idiom as above).
      await pumpEventQueue();

      verifyNever(
        () => mockAnalysisRepo.getTodayRecommendations(horizon: Horizon.short),
      );
    });
  });
}
