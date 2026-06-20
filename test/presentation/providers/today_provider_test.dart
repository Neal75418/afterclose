import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:afterclose/core/constants/calibrated_scores/horizon.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/database/cached_accessor.dart';
import 'package:afterclose/data/repositories/analysis_repository.dart';
import 'package:afterclose/domain/services/data_sync_service.dart';
import 'package:afterclose/domain/services/update_service.dart';
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
    // Horizon enum 需要 fallback 才能用 any(named: 'horizon')
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

    // 設置 loadData 編排路徑的預設 mock 行為。
    // loadData 透過 marketDataRepositoryProvider（內部委派給 databaseProvider）
    // 讀取 getLatestUpdateRun / getLatestDataDate / getLatestInstitutionalDate，
    // 再交給 dataSyncService.getDisplayDataDate 計算顯示日期。
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
  });

  tearDown(() {
    container.dispose();
  });

  group('TodayState', () {
    test('has correct default values', () {
      const state = TodayState();

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
      expect(newState.dataDate, equals(originalState.dataDate));
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
    test('initial state is loading=false with no error', () {
      final state = container.read(todayProvider);

      expect(state.isLoading, isFalse);
      expect(state.isUpdating, isFalse);
      expect(state.error, isNull);
    });

    test('loadData sets loading state and loads orchestration state', () async {
      // Arrange — 提供完整編排路徑的回傳值
      final finishedAt = DateTime(2026, 2, 13, 16, 30);
      when(() => mockDb.getLatestUpdateRun()).thenAnswer(
        (_) async => UpdateRunEntry(
          id: 1,
          runDate: DateTime(2026, 2, 13),
          startedAt: DateTime(2026, 2, 13, 16, 0),
          finishedAt: finishedAt,
          status: 'success',
        ),
      );
      when(
        () => mockDb.getLatestDataDate(),
      ).thenAnswer((_) async => DateTime(2026, 2, 12));
      when(
        () => mockDb.getLatestInstitutionalDate(),
      ).thenAnswer((_) async => DateTime(2026, 2, 12));
      when(
        () => mockDataSyncService.getDisplayDataDate(any(), any()),
      ).thenReturn(DateTime(2026, 2, 12));

      // Act
      final notifier = container.read(todayProvider.notifier);
      final loadFuture = notifier.loadData();

      // 檢查 loading 狀態
      expect(container.read(todayProvider).isLoading, isTrue);

      await loadFuture;

      // Assert — 不再有 recommendations，只驗證編排 state
      final state = container.read(todayProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.lastUpdate, equals(finishedAt));
      expect(state.dataDate, equals(DateTime(2026, 2, 12)));
    });

    test('loadData handles error gracefully', () async {
      // Arrange — 讓編排路徑其中一個呼叫拋例外
      when(
        () => mockDb.getLatestUpdateRun(),
      ).thenThrow(Exception('Database error'));

      // Act
      final notifier = container.read(todayProvider.notifier);
      await notifier.loadData();

      // Assert
      final state = container.read(todayProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNotNull);
      expect(state.error, isNotEmpty);
    });

    test('loadData clears previous error on successful load', () async {
      // Arrange — 先讓編排路徑失敗一次
      when(
        () => mockDb.getLatestUpdateRun(),
      ).thenThrow(Exception('First error'));

      final notifier = container.read(todayProvider.notifier);
      await notifier.loadData();

      expect(container.read(todayProvider).error, isNotNull);

      // Arrange — 還原成功的 mock
      when(() => mockDb.getLatestUpdateRun()).thenAnswer((_) async => null);

      // Act — 重新載入
      await notifier.loadData();

      // Assert — 錯誤應該被清除
      final state = container.read(todayProvider);
      expect(state.error, isNull);
    });
  });

  group('Edge Cases', () {
    test('handles null dataDate gracefully', () async {
      // Arrange
      when(() => mockDb.getLatestDataDate()).thenAnswer((_) async => null);
      when(
        () => mockDb.getLatestInstitutionalDate(),
      ).thenAnswer((_) async => null);
      when(
        () => mockDataSyncService.getDisplayDataDate(null, null),
      ).thenReturn(null);

      // Act
      final notifier = container.read(todayProvider.notifier);
      await notifier.loadData();

      // Assert
      final state = container.read(todayProvider);
      expect(state.isLoading, isFalse);
      expect(state.dataDate, isNull); // 應優雅處理 null dataDate
    });
  });
}
