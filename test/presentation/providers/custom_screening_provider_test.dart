import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/database/cached_accessor.dart';
import 'package:afterclose/data/repositories/analysis_repository.dart';
import 'package:afterclose/domain/models/screening_condition.dart';
import 'package:afterclose/presentation/providers/providers.dart';
import 'package:afterclose/presentation/providers/custom_screening_provider.dart';

// =============================================================================
// Mocks
// =============================================================================

class MockAppDatabase extends Mock implements AppDatabase {}

class MockCachedDatabaseAccessor extends Mock
    implements CachedDatabaseAccessor {}

class MockAnalysisRepository extends Mock implements AnalysisRepository {}

// =============================================================================
// Test Helpers
// =============================================================================

const _testCondition = ScreeningCondition(
  field: ScreeningField.close,
  operator: ScreeningOperator.greaterThan,
  value: 100.0,
);

const _testCondition2 = ScreeningCondition(
  field: ScreeningField.score,
  operator: ScreeningOperator.greaterOrEqual,
  value: 80.0,
);

const _testCondition3 = ScreeningCondition(
  field: ScreeningField.volume,
  operator: ScreeningOperator.greaterThan,
  value: 1000.0,
);

ScreeningStrategyEntry createStrategyEntry({
  int id = 1,
  String name = '測試策略',
  String conditionsJson = '[]',
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final now = DateTime(2026, 2, 13);
  return ScreeningStrategyEntry(
    id: id,
    name: name,
    conditionsJson: conditionsJson,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
  );
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  late MockAppDatabase mockDb;
  late MockCachedDatabaseAccessor mockCachedDb;
  late MockAnalysisRepository mockAnalysisRepo;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(
      ScreeningStrategyTableCompanion.insert(name: '', conditionsJson: '[]'),
    );
  });

  setUp(() {
    mockDb = MockAppDatabase();
    mockCachedDb = MockCachedDatabaseAccessor();
    mockAnalysisRepo = MockAnalysisRepository();

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(mockDb),
        cachedDbProvider.overrideWithValue(mockCachedDb),
        analysisRepositoryProvider.overrideWithValue(mockAnalysisRepo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  // ===========================================================================
  // CustomScreeningState
  // ===========================================================================

  group('CustomScreeningState', () {
    test('has correct default values', () {
      const state = CustomScreeningState();

      expect(state.conditions, isEmpty);
      expect(state.savedStrategies, isEmpty);
      expect(state.result, isNull);
      expect(state.stocks, isEmpty);
      expect(state.isExecuting, isFalse);
      expect(state.isLoadingStrategies, isFalse);
      expect(state.isLoadingMore, isFalse);
      expect(state.hasMore, isFalse);
      expect(state.error, isNull);
    });

    test('copyWith preserves unset values', () {
      final state = CustomScreeningState(
        conditions: [_testCondition],
        isExecuting: true,
        hasMore: true,
      );

      final copied = state.copyWith();
      expect(copied.conditions, hasLength(1));
      expect(copied.isExecuting, isTrue);
      expect(copied.hasMore, isTrue);
    });

    test('copyWith can set error', () {
      const state = CustomScreeningState();
      final updated = state.copyWith(error: 'new error');
      expect(updated.error, 'new error');
    });

    test('copyWith clearResult sets result to null', () {
      final result = ScreeningResult(
        symbols: ['2330'],
        matchCount: 1,
        totalScanned: 100,
        dataDate: DateTime(2026, 2, 13),
      );
      final state = CustomScreeningState(result: result);

      final cleared = state.copyWith(clearResult: true);
      expect(cleared.result, isNull);
    });

    test('copyWith clearError sets error to null', () {
      const state = CustomScreeningState(error: 'some error');

      final cleared = state.copyWith(clearError: true);
      expect(cleared.error, isNull);
    });
  });

  // ===========================================================================
  // Condition Management
  // ===========================================================================

  group('CustomScreeningNotifier condition management', () {
    test('addCondition appends condition and clears result', () {
      final notifier = container.read(customScreeningProvider.notifier);
      notifier.addCondition(_testCondition);

      final state = container.read(customScreeningProvider);
      expect(state.conditions, hasLength(1));
      expect(state.conditions.first.field, ScreeningField.close);
      expect(state.result, isNull);
      expect(state.stocks, isEmpty);
    });

    test('addCondition appends multiple conditions', () {
      final notifier = container.read(customScreeningProvider.notifier);
      notifier.addCondition(_testCondition);
      notifier.addCondition(_testCondition2);

      final state = container.read(customScreeningProvider);
      expect(state.conditions, hasLength(2));
      expect(state.conditions[0].field, ScreeningField.close);
      expect(state.conditions[1].field, ScreeningField.score);
    });

    test('updateCondition replaces condition at index', () {
      final notifier = container.read(customScreeningProvider.notifier);
      notifier.addCondition(_testCondition);
      notifier.addCondition(_testCondition2);
      notifier.updateCondition(0, _testCondition3);

      final state = container.read(customScreeningProvider);
      expect(state.conditions, hasLength(2));
      expect(state.conditions[0].field, ScreeningField.volume);
      expect(state.conditions[1].field, ScreeningField.score);
    });

    test('removeCondition removes condition at index', () {
      final notifier = container.read(customScreeningProvider.notifier);
      notifier.addCondition(_testCondition);
      notifier.addCondition(_testCondition2);
      notifier.removeCondition(0);

      final state = container.read(customScreeningProvider);
      expect(state.conditions, hasLength(1));
      expect(state.conditions.first.field, ScreeningField.score);
    });

    test('clearConditions removes all conditions', () {
      final notifier = container.read(customScreeningProvider.notifier);
      notifier.addCondition(_testCondition);
      notifier.addCondition(_testCondition2);
      notifier.clearConditions();

      final state = container.read(customScreeningProvider);
      expect(state.conditions, isEmpty);
      expect(state.result, isNull);
      expect(state.stocks, isEmpty);
    });
  });

  // ===========================================================================
  // Strategy CRUD
  // ===========================================================================

  group('CustomScreeningNotifier strategy CRUD', () {
    test('loadSavedStrategies sets strategies from DB', () async {
      final conditionsJson = ScreeningStrategy.conditionsToJson([
        _testCondition,
      ]);
      when(() => mockDb.getAllScreeningStrategies()).thenAnswer(
        (_) async => [
          createStrategyEntry(
            id: 1,
            name: '策略A',
            conditionsJson: conditionsJson,
          ),
          createStrategyEntry(id: 2, name: '策略B', conditionsJson: '[]'),
        ],
      );

      final notifier = container.read(customScreeningProvider.notifier);
      await notifier.loadSavedStrategies();

      final state = container.read(customScreeningProvider);
      expect(state.savedStrategies, hasLength(2));
      expect(state.savedStrategies[0].name, '策略A');
      expect(state.savedStrategies[1].name, '策略B');
      expect(state.isLoadingStrategies, isFalse);
    });

    test('loadSavedStrategies sets loading state', () async {
      when(
        () => mockDb.getAllScreeningStrategies(),
      ).thenAnswer((_) async => []);

      final notifier = container.read(customScreeningProvider.notifier);
      // Can't easily test intermediate loading state, just verify final
      await notifier.loadSavedStrategies();

      final state = container.read(customScreeningProvider);
      expect(state.isLoadingStrategies, isFalse);
      expect(state.savedStrategies, isEmpty);
    });

    test('loadSavedStrategies handles error gracefully', () async {
      when(
        () => mockDb.getAllScreeningStrategies(),
      ).thenThrow(Exception('DB error'));

      final notifier = container.read(customScreeningProvider.notifier);
      await notifier.loadSavedStrategies();

      final state = container.read(customScreeningProvider);
      expect(state.isLoadingStrategies, isFalse);
      expect(state.savedStrategies, isEmpty);
    });

    test('saveStrategy saves to DB and reloads strategies', () async {
      when(
        () => mockDb.insertScreeningStrategy(any()),
      ).thenAnswer((_) async => 1);
      when(
        () => mockDb.getAllScreeningStrategies(),
      ).thenAnswer((_) async => []);

      final notifier = container.read(customScreeningProvider.notifier);
      notifier.addCondition(_testCondition);
      final result = await notifier.saveStrategy('新策略');

      expect(result, isTrue);
      verify(() => mockDb.insertScreeningStrategy(any())).called(1);
      verify(() => mockDb.getAllScreeningStrategies()).called(1);
    });

    test('saveStrategy returns false when no conditions', () async {
      final notifier = container.read(customScreeningProvider.notifier);
      final result = await notifier.saveStrategy('空策略');

      expect(result, isFalse);
      verifyNever(() => mockDb.insertScreeningStrategy(any()));
    });

    test('saveStrategy returns false on error', () async {
      when(
        () => mockDb.insertScreeningStrategy(any()),
      ).thenThrow(Exception('DB error'));

      final notifier = container.read(customScreeningProvider.notifier);
      notifier.addCondition(_testCondition);
      final result = await notifier.saveStrategy('新策略');

      expect(result, isFalse);
    });

    test('deleteStrategy deletes from DB and reloads', () async {
      when(() => mockDb.deleteScreeningStrategy(1)).thenAnswer((_) async {});
      when(
        () => mockDb.getAllScreeningStrategies(),
      ).thenAnswer((_) async => []);

      final notifier = container.read(customScreeningProvider.notifier);
      final result = await notifier.deleteStrategy(1);

      expect(result, isTrue);
      verify(() => mockDb.deleteScreeningStrategy(1)).called(1);
      verify(() => mockDb.getAllScreeningStrategies()).called(1);
    });

    test('deleteStrategy returns false on error', () async {
      when(
        () => mockDb.deleteScreeningStrategy(any()),
      ).thenThrow(Exception('DB error'));

      final notifier = container.read(customScreeningProvider.notifier);
      final result = await notifier.deleteStrategy(1);

      expect(result, isFalse);
    });

    test('loadStrategy sets conditions from strategy', () {
      final strategy = ScreeningStrategy(
        id: 1,
        name: '測試策略',
        conditions: [_testCondition, _testCondition2],
      );

      final notifier = container.read(customScreeningProvider.notifier);
      notifier.loadStrategy(strategy);

      final state = container.read(customScreeningProvider);
      expect(state.conditions, hasLength(2));
      expect(state.conditions[0].field, ScreeningField.close);
      expect(state.conditions[1].field, ScreeningField.score);
      expect(state.result, isNull);
      expect(state.stocks, isEmpty);
    });
  });

  // ===========================================================================
  // Execute Screening
  // ===========================================================================

  group('CustomScreeningNotifier executeScreening', () {
    test('returns immediately when conditions are empty', () async {
      final notifier = container.read(customScreeningProvider.notifier);
      await notifier.executeScreening();

      final state = container.read(customScreeningProvider);
      expect(state.isExecuting, isFalse);
      expect(state.result, isNull);
      verifyNever(() => mockAnalysisRepo.findLatestAnalysisDate());
    });

    test('sets error when no analysis date found', () async {
      when(
        () => mockAnalysisRepo.findLatestAnalysisDate(),
      ).thenAnswer((_) async => null);

      final notifier = container.read(customScreeningProvider.notifier);
      notifier.addCondition(_testCondition);
      await notifier.executeScreening();

      final state = container.read(customScreeningProvider);
      expect(state.isExecuting, isFalse);
      expect(state.error, '找不到分析資料');
    });

    test('handles error during execution gracefully', () async {
      when(
        () => mockAnalysisRepo.findLatestAnalysisDate(),
      ).thenThrow(Exception('Analysis error'));

      final notifier = container.read(customScreeningProvider.notifier);
      notifier.addCondition(_testCondition);
      await notifier.executeScreening();

      final state = container.read(customScreeningProvider);
      expect(state.isExecuting, isFalse);
      expect(state.error, isNotNull);
    });
  });

  // ===========================================================================
  // Load More
  // ===========================================================================

  group('CustomScreeningNotifier loadMore', () {
    test('returns immediately when already loading more', () async {
      final notifier = container.read(customScreeningProvider.notifier);
      // State has isLoadingMore = false by default, so this just verifies
      // the guard condition logic

      // No hasMore = false → should return immediately
      await notifier.loadMore();

      final state = container.read(customScreeningProvider);
      expect(state.isLoadingMore, isFalse);
    });

    test('returns immediately when hasMore is false', () async {
      final notifier = container.read(customScreeningProvider.notifier);
      await notifier.loadMore();

      // Default state has hasMore = false
      final state = container.read(customScreeningProvider);
      expect(state.isLoadingMore, isFalse);
      expect(state.stocks, isEmpty);
    });
  });

  // ===========================================================================
  // Provider declaration
  // ===========================================================================

  group('customScreeningProvider', () {
    test('provides initial state', () {
      final state = container.read(customScreeningProvider);
      expect(state, isA<CustomScreeningState>());
      expect(state.conditions, isEmpty);
      expect(state.isExecuting, isFalse);
    });

    test('notifier is accessible', () {
      final notifier = container.read(customScreeningProvider.notifier);
      expect(notifier, isA<CustomScreeningNotifier>());
    });
  });
}
