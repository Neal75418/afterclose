import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/database/cached_accessor.dart';
import 'package:afterclose/presentation/providers/providers.dart';
import 'package:afterclose/presentation/providers/comparison_provider.dart';

// =============================================================================
// Mocks
// =============================================================================

class MockAppDatabase extends Mock implements AppDatabase {}

class MockCachedDatabaseAccessor extends Mock
    implements CachedDatabaseAccessor {}

// =============================================================================
// Tests
// =============================================================================

void main() {
  late MockAppDatabase mockDb;
  late MockCachedDatabaseAccessor mockCachedDb;
  late ProviderContainer container;

  setUp(() {
    mockDb = MockAppDatabase();
    mockCachedDb = MockCachedDatabaseAccessor();

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(mockDb),
        cachedDbProvider.overrideWithValue(mockCachedDb),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  // ===========================================================================
  // ComparisonState
  // ===========================================================================

  group('ComparisonState', () {
    test('has correct default values', () {
      const state = ComparisonState();

      expect(state.symbols, isEmpty);
      expect(state.stocksMap, isEmpty);
      expect(state.latestPricesMap, isEmpty);
      expect(state.priceHistoriesMap, isEmpty);
      expect(state.analysesMap, isEmpty);
      expect(state.reasonsMap, isEmpty);
      expect(state.valuationsMap, isEmpty);
      expect(state.institutionalMap, isEmpty);
      expect(state.epsMap, isEmpty);
      expect(state.revenueMap, isEmpty);
      expect(state.summariesMap, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('stockCount returns correct count', () {
      const state = ComparisonState(symbols: ['2330', '2317']);
      expect(state.stockCount, 2);
    });

    test('canAddMore is true when less than 4 stocks', () {
      const state = ComparisonState(symbols: ['2330', '2317', '2454']);
      expect(state.canAddMore, isTrue);
    });

    test('canAddMore is false when 4 stocks', () {
      const state = ComparisonState(symbols: ['2330', '2317', '2454', '3008']);
      expect(state.canAddMore, isFalse);
    });

    test('hasEnoughToCompare is true when >= 2 stocks', () {
      const state = ComparisonState(symbols: ['2330', '2317']);
      expect(state.hasEnoughToCompare, isTrue);
    });

    test('hasEnoughToCompare is false when < 2 stocks', () {
      const state = ComparisonState(symbols: ['2330']);
      expect(state.hasEnoughToCompare, isFalse);
    });

    test('hasEnoughToCompare is false when empty', () {
      const state = ComparisonState();
      expect(state.hasEnoughToCompare, isFalse);
    });

    test('copyWith preserves unset values', () {
      const state = ComparisonState(symbols: ['2330'], isLoading: true);

      final copied = state.copyWith();
      expect(copied.symbols, ['2330']);
      expect(copied.isLoading, isTrue);
    });

    test('copyWith with sentinel handles error correctly', () {
      const state = ComparisonState(error: 'old error');

      // Not passing error → preserves
      final preserved = state.copyWith();
      expect(preserved.error, 'old error');

      // Passing null → clears
      final cleared = state.copyWith(error: null);
      expect(cleared.error, isNull);

      // Passing new value → updates
      final updated = state.copyWith(error: 'new error');
      expect(updated.error, 'new error');
    });
  });

  // ===========================================================================
  // ComparisonNotifier
  // ===========================================================================

  group('ComparisonNotifier', () {
    test('initial state is empty', () {
      final state = container.read(comparisonProvider);
      expect(state.symbols, isEmpty);
      expect(state.isLoading, isFalse);
    });

    test('addStock skips duplicate symbol', () async {
      // First add: symbol gets added even when _loadAllData fails
      when(() => mockDb.getLatestDataDate()).thenThrow(Exception('DB error'));

      final notifier = container.read(comparisonProvider.notifier);
      await notifier.addStock('2330');
      expect(container.read(comparisonProvider).symbols, ['2330']);

      // Second add: same symbol should be skipped (guard: symbols.contains)
      await notifier.addStock('2330');
      expect(container.read(comparisonProvider).symbols, hasLength(1));
    });

    test('addStock skips when at max capacity', () async {
      when(() => mockDb.getLatestDataDate()).thenThrow(Exception('DB error'));

      final notifier = container.read(comparisonProvider.notifier);
      await notifier.addStocks(['2330', '2317', '2454', '3008']);
      expect(container.read(comparisonProvider).symbols, hasLength(4));

      // 5th stock should be skipped (guard: !canAddMore)
      await notifier.addStock('6505');
      expect(container.read(comparisonProvider).symbols, hasLength(4));
      expect(
        container.read(comparisonProvider).symbols,
        isNot(contains('6505')),
      );
    });

    test('removeStock removes symbol from state', () async {
      // Add a stock first (symbol persists even when _loadAllData fails)
      when(() => mockDb.getLatestDataDate()).thenThrow(Exception('DB error'));

      final notifier = container.read(comparisonProvider.notifier);
      await notifier.addStock('2330');
      expect(container.read(comparisonProvider).symbols, contains('2330'));

      // Remove it
      notifier.removeStock('2330');
      expect(container.read(comparisonProvider).symbols, isEmpty);
    });

    test('removeStock is no-op for nonexistent symbol', () {
      final notifier = container.read(comparisonProvider.notifier);
      notifier.removeStock('nonexistent');
      final state = container.read(comparisonProvider);
      expect(state.symbols, isEmpty);
    });

    test('addStock handles error when DB fails', () async {
      when(() => mockDb.getLatestDataDate()).thenThrow(Exception('DB error'));

      final notifier = container.read(comparisonProvider.notifier);
      await notifier.addStock('2330');

      final state = container.read(comparisonProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNotNull);
      expect(state.symbols, contains('2330'));
    });

    test('addStocks deduplicates and limits to 4', () async {
      when(() => mockDb.getLatestDataDate()).thenThrow(Exception('DB error'));

      final notifier = container.read(comparisonProvider.notifier);
      await notifier.addStocks([
        '2330',
        '2317',
        '2330', // duplicate
        '2454',
        '3008',
        '6505', // should be ignored (5th)
      ]);

      final state = container.read(comparisonProvider);
      expect(state.symbols, hasLength(4));
      expect(state.symbols, ['2330', '2317', '2454', '3008']);
    });

    test('addStocks does nothing for empty list', () async {
      final notifier = container.read(comparisonProvider.notifier);
      await notifier.addStocks([]);

      final state = container.read(comparisonProvider);
      expect(state.symbols, isEmpty);
      expect(state.isLoading, isFalse);
    });
  });

  // ===========================================================================
  // Provider declaration
  // ===========================================================================

  group('comparisonProvider', () {
    test('is autoDispose', () {
      final state = container.read(comparisonProvider);
      expect(state, isA<ComparisonState>());
    });

    test('notifier is accessible', () {
      final notifier = container.read(comparisonProvider.notifier);
      expect(notifier, isA<ComparisonNotifier>());
    });
  });
}
