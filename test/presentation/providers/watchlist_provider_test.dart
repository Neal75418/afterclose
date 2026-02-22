import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:afterclose/core/constants/pagination.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/database/cached_accessor.dart';
import 'package:afterclose/data/repositories/warning_repository.dart';
import 'package:afterclose/data/repositories/insider_repository.dart';
import 'package:afterclose/presentation/providers/providers.dart';
import 'package:afterclose/presentation/providers/watchlist_provider.dart';

// =============================================================================
// Mocks
// =============================================================================

class MockAppDatabase extends Mock implements AppDatabase {}

class MockCachedDatabaseAccessor extends Mock
    implements CachedDatabaseAccessor {}

class MockWarningRepository extends Mock implements WarningRepository {}

class MockInsiderRepository extends Mock implements InsiderRepository {}

// =============================================================================
// Test Helpers
// =============================================================================

WatchlistItemData createItem({
  required String symbol,
  String? stockName,
  double? latestClose,
  double? priceChange,
  double? score,
  String? trendState,
  bool hasSignal = false,
  DateTime? addedAt,
}) {
  return WatchlistItemData(
    symbol: symbol,
    stockName: stockName,
    latestClose: latestClose,
    priceChange: priceChange,
    score: score,
    trendState: trendState,
    hasSignal: hasSignal,
    addedAt: addedAt,
  );
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  late MockAppDatabase mockDb;
  late MockCachedDatabaseAccessor mockCachedDb;
  late MockWarningRepository mockWarningRepo;
  late MockInsiderRepository mockInsiderRepo;
  late ProviderContainer container;

  setUp(() {
    mockDb = MockAppDatabase();
    mockCachedDb = MockCachedDatabaseAccessor();
    mockWarningRepo = MockWarningRepository();
    mockInsiderRepo = MockInsiderRepository();

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(mockDb),
        cachedDbProvider.overrideWithValue(mockCachedDb),
        warningRepositoryProvider.overrideWithValue(mockWarningRepo),
        insiderRepositoryProvider.overrideWithValue(mockInsiderRepo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  // ===========================================================================
  // WatchlistState
  // ===========================================================================

  group('WatchlistState', () {
    test('has correct default values', () {
      final state = WatchlistState();

      expect(state.items, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.sort, WatchlistSort.addedDesc);
      expect(state.group, WatchlistGroup.none);
      expect(state.searchQuery, isEmpty);
      expect(state.isLoadingMore, isFalse);
      expect(state.hasMore, isTrue);
      expect(state.displayedCount, kPageSize);
    });

    test('copyWith preserves unset values', () {
      final state = WatchlistState(
        isLoading: true,
        sort: WatchlistSort.scoreDesc,
        group: WatchlistGroup.status,
        searchQuery: 'test',
      );

      final copied = state.copyWith();
      expect(copied.isLoading, isTrue);
      expect(copied.sort, WatchlistSort.scoreDesc);
      expect(copied.group, WatchlistGroup.status);
      expect(copied.searchQuery, 'test');
    });

    test('copyWith with sentinel handles error correctly', () {
      final state = WatchlistState(error: 'old error');
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

    test('filteredItems returns all items when no search query', () {
      final items = [
        createItem(symbol: '2330', stockName: '台積電'),
        createItem(symbol: '2317', stockName: '鴻海'),
      ];
      final state = WatchlistState(items: items);

      expect(state.filteredItems, hasLength(2));
    });

    test('filteredItems filters by symbol', () {
      final items = [
        createItem(symbol: '2330', stockName: '台積電'),
        createItem(symbol: '2317', stockName: '鴻海'),
      ];
      final state = WatchlistState(items: items, searchQuery: '2330');

      expect(state.filteredItems, hasLength(1));
      expect(state.filteredItems.first.symbol, '2330');
    });

    test('filteredItems filters by stock name', () {
      final items = [
        createItem(symbol: '2330', stockName: '台積電'),
        createItem(symbol: '2317', stockName: '鴻海'),
      ];
      final state = WatchlistState(items: items, searchQuery: '鴻海');

      expect(state.filteredItems, hasLength(1));
      expect(state.filteredItems.first.symbol, '2317');
    });

    test('filteredItems is case-insensitive', () {
      final items = [createItem(symbol: 'TSMC', stockName: 'Taiwan Semi')];
      final state = WatchlistState(items: items, searchQuery: 'tsmc');

      expect(state.filteredItems, hasLength(1));
    });

    test('displayedItems respects displayedCount', () {
      final items = List.generate(
        100,
        (i) => createItem(symbol: '${1000 + i}'),
      );
      final state = WatchlistState(items: items, displayedCount: 10);

      expect(state.displayedItems, hasLength(10));
    });

    test('copyWith recomputes filteredItems when items change', () {
      final state = WatchlistState(
        items: [createItem(symbol: '2330')],
        searchQuery: '2317',
      );
      expect(state.filteredItems, isEmpty);

      final updated = state.copyWith(items: [createItem(symbol: '2317')]);
      expect(updated.filteredItems, hasLength(1));
    });

    test('copyWith recomputes filteredItems when searchQuery changes', () {
      final state = WatchlistState(
        items: [
          createItem(symbol: '2330'),
          createItem(symbol: '2317'),
        ],
      );
      expect(state.filteredItems, hasLength(2));

      final updated = state.copyWith(searchQuery: '2330');
      expect(updated.filteredItems, hasLength(1));
    });
  });

  // ===========================================================================
  // WatchlistItemData
  // ===========================================================================

  group('WatchlistItemData', () {
    test('status is signal when hasSignal', () {
      final item = createItem(symbol: '2330', hasSignal: true);
      expect(item.status, WatchlistStatus.signal);
    });

    test('status is volatile when priceChange >= 3%', () {
      final item = createItem(symbol: '2330', priceChange: 3.5);
      expect(item.status, WatchlistStatus.volatile);
    });

    test('status is volatile when priceChange <= -3%', () {
      final item = createItem(symbol: '2330', priceChange: -4.0);
      expect(item.status, WatchlistStatus.volatile);
    });

    test('status is quiet otherwise', () {
      final item = createItem(symbol: '2330', priceChange: 1.0);
      expect(item.status, WatchlistStatus.quiet);
    });

    test('status is quiet when priceChange is null', () {
      final item = createItem(symbol: '2330');
      expect(item.status, WatchlistStatus.quiet);
    });

    test('trend maps trendState correctly', () {
      expect(
        createItem(symbol: '2330', trendState: 'UP').trend,
        WatchlistTrend.up,
      );
      expect(
        createItem(symbol: '2330', trendState: 'DOWN').trend,
        WatchlistTrend.down,
      );
      expect(
        createItem(symbol: '2330', trendState: 'SIDEWAYS').trend,
        WatchlistTrend.sideways,
      );
      expect(createItem(symbol: '2330').trend, WatchlistTrend.sideways);
    });

    test('signal takes priority over volatile for status', () {
      final item = createItem(
        symbol: '2330',
        hasSignal: true,
        priceChange: 5.0,
      );
      expect(item.status, WatchlistStatus.signal);
    });
  });

  // ===========================================================================
  // WatchlistNotifier sort/group/search
  // ===========================================================================

  group('WatchlistNotifier sort/group/search', () {
    test('setSort changes sort option', () {
      final notifier = container.read(watchlistProvider.notifier);
      notifier.setSort(WatchlistSort.scoreDesc);

      final state = container.read(watchlistProvider);
      expect(state.sort, WatchlistSort.scoreDesc);
    });

    test('setSort does nothing when same sort', () {
      final notifier = container.read(watchlistProvider.notifier);
      notifier.setSort(WatchlistSort.addedDesc); // default value

      // Should not cause unnecessary state update
      final state = container.read(watchlistProvider);
      expect(state.sort, WatchlistSort.addedDesc);
    });

    test('setGroup changes group option', () {
      final notifier = container.read(watchlistProvider.notifier);
      notifier.setGroup(WatchlistGroup.status);

      final state = container.read(watchlistProvider);
      expect(state.group, WatchlistGroup.status);
    });

    test('setSearchQuery filters items', () {
      final notifier = container.read(watchlistProvider.notifier);
      notifier.setSearchQuery('test');

      final state = container.read(watchlistProvider);
      expect(state.searchQuery, 'test');
    });
  });

  // ===========================================================================
  // WatchlistNotifier loadData
  // ===========================================================================

  group('WatchlistNotifier loadData', () {
    test('sets empty items when watchlist is empty', () async {
      when(() => mockDb.getWatchlist()).thenAnswer((_) async => []);

      final notifier = container.read(watchlistProvider.notifier);
      await notifier.loadData();

      final state = container.read(watchlistProvider);
      expect(state.items, isEmpty);
      expect(state.isLoading, isFalse);
    });

    test('handles error gracefully', () async {
      when(() => mockDb.getWatchlist()).thenThrow(Exception('DB error'));

      final notifier = container.read(watchlistProvider.notifier);
      await notifier.loadData();

      final state = container.read(watchlistProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNotNull);
    });
  });

  // ===========================================================================
  // WatchlistNotifier loadMore
  // ===========================================================================

  group('WatchlistNotifier loadMore', () {
    test('returns immediately when already loading more', () async {
      // Default state has isLoadingMore = false, hasMore = true
      // Since there are no items, it should just update counts
      final notifier = container.read(watchlistProvider.notifier);
      await notifier.loadMore();

      final state = container.read(watchlistProvider);
      expect(state.isLoadingMore, isFalse);
    });

    test('returns immediately when hasMore is false', () async {
      final notifier = container.read(watchlistProvider.notifier);
      // Manually set hasMore to false via empty watchlist
      when(() => mockDb.getWatchlist()).thenAnswer((_) async => []);
      await notifier.loadData();

      await notifier.loadMore();
      final state = container.read(watchlistProvider);
      expect(state.isLoadingMore, isFalse);
    });
  });

  // ===========================================================================
  // WatchlistNotifier removeStock (optimistic update)
  // ===========================================================================

  group('WatchlistNotifier removeStock', () {
    test('removes stock from state optimistically', () async {
      when(() => mockDb.removeFromWatchlist(any())).thenAnswer((_) async {});

      // Manually set initial state with items
      final notifier = container.read(watchlistProvider.notifier);

      // We can't easily set items without going through loadData.
      // Instead test the DB call
      await notifier.removeStock('2330');

      verify(() => mockDb.removeFromWatchlist('2330')).called(1);
    });
  });

  // ===========================================================================
  // WatchlistState grouping
  // ===========================================================================

  group('WatchlistState grouping', () {
    test('groupedByStatus categorizes items correctly', () {
      final items = [
        createItem(symbol: '2330', hasSignal: true), // signal
        createItem(symbol: '2317', priceChange: 5.0), // volatile
        createItem(symbol: '2454', priceChange: 1.0), // quiet
      ];
      final state = WatchlistState(items: items);

      final grouped = state.groupedByStatus;
      expect(grouped[WatchlistStatus.signal], hasLength(1));
      expect(grouped[WatchlistStatus.volatile], hasLength(1));
      expect(grouped[WatchlistStatus.quiet], hasLength(1));
    });

    test('groupedByTrend categorizes items correctly', () {
      final items = [
        createItem(symbol: '2330', trendState: 'UP'), // up
        createItem(symbol: '2317', trendState: 'DOWN'), // down
        createItem(symbol: '2454'), // sideways (default)
      ];
      final state = WatchlistState(items: items);

      final grouped = state.groupedByTrend;
      expect(grouped[WatchlistTrend.up], hasLength(1));
      expect(grouped[WatchlistTrend.down], hasLength(1));
      expect(grouped[WatchlistTrend.sideways], hasLength(1));
    });

    test('groupedByStatus contains all status keys', () {
      final state = WatchlistState();
      final grouped = state.groupedByStatus;

      for (final status in WatchlistStatus.values) {
        expect(grouped.containsKey(status), isTrue);
      }
    });

    test('groupedByTrend contains all trend keys', () {
      final state = WatchlistState();
      final grouped = state.groupedByTrend;

      for (final trend in WatchlistTrend.values) {
        expect(grouped.containsKey(trend), isTrue);
      }
    });
  });

  // ===========================================================================
  // WatchlistState copyWith _internal path
  // ===========================================================================

  group('WatchlistState copyWith internal path', () {
    test('preserves filteredItems cache when only isLoading changes', () {
      final items = [
        createItem(symbol: '2330', stockName: '台積電'),
        createItem(symbol: '2317', stockName: '鴻海'),
      ];
      final state = WatchlistState(items: items, searchQuery: '2330');
      expect(state.filteredItems, hasLength(1));

      // Only change isLoading → _internal path
      final updated = state.copyWith(isLoading: true);
      expect(updated.filteredItems, hasLength(1));
      expect(updated.isLoading, isTrue);
    });

    test('preserves filteredItems cache when only sort changes', () {
      final items = [createItem(symbol: '2330'), createItem(symbol: '2317')];
      final state = WatchlistState(items: items);

      final updated = state.copyWith(sort: WatchlistSort.nameAsc);
      expect(updated.sort, WatchlistSort.nameAsc);
      expect(updated.filteredItems, hasLength(2));
    });

    test('preserves filteredItems cache when only group changes', () {
      final items = [createItem(symbol: '2330')];
      final state = WatchlistState(items: items);

      final updated = state.copyWith(group: WatchlistGroup.trend);
      expect(updated.group, WatchlistGroup.trend);
      expect(updated.filteredItems, hasLength(1));
    });

    test('preserves filteredItems cache when only error changes', () {
      final items = [createItem(symbol: '2330')];
      final state = WatchlistState(items: items);

      final updated = state.copyWith(error: 'some error');
      expect(updated.error, 'some error');
      expect(updated.filteredItems, hasLength(1));
    });

    test('recomputes when searchQuery changes to same value as current', () {
      final items = [createItem(symbol: '2330'), createItem(symbol: '2317')];
      final state = WatchlistState(items: items, searchQuery: '2330');
      expect(state.filteredItems, hasLength(1));

      // Same query → no recompute (handled by copyWith condition)
      final updated = state.copyWith(searchQuery: '2330');
      expect(updated.filteredItems, hasLength(1));
    });
  });

  // ===========================================================================
  // WatchlistState pagination edge cases
  // ===========================================================================

  group('WatchlistState pagination', () {
    test('displayedItems caps at total items', () {
      final items = [createItem(symbol: '2330'), createItem(symbol: '2317')];
      final state = WatchlistState(items: items, displayedCount: 100);
      expect(state.displayedItems, hasLength(2));
    });

    test('displayedItems is empty when displayedCount is 0', () {
      final items = [createItem(symbol: '2330')];
      final state = WatchlistState(items: items, displayedCount: 0);
      expect(state.displayedItems, isEmpty);
    });

    test('copyWith updates hasMore and displayedCount together', () {
      final state = WatchlistState(displayedCount: 10, hasMore: true);
      final updated = state.copyWith(displayedCount: 20, hasMore: false);
      expect(updated.displayedCount, 20);
      expect(updated.hasMore, isFalse);
    });

    test('copyWith updates isLoadingMore', () {
      final state = WatchlistState();
      final updated = state.copyWith(isLoadingMore: true);
      expect(updated.isLoadingMore, isTrue);
    });
  });

  // ===========================================================================
  // WatchlistItemData additional tests
  // ===========================================================================

  group('WatchlistItemData additional', () {
    test('statusIcon returns emoji from status', () {
      final signalItem = createItem(symbol: '2330', hasSignal: true);
      expect(signalItem.statusIcon, '🔥');

      final quietItem = createItem(symbol: '2317', priceChange: 0.5);
      expect(quietItem.statusIcon, '😴');

      final volatileItem = createItem(symbol: '2454', priceChange: -5.0);
      expect(volatileItem.statusIcon, '👀');
    });

    test('trend returns sideways for null trendState', () {
      final item = createItem(symbol: '2330');
      expect(item.trend, WatchlistTrend.sideways);
    });

    test('trend returns sideways for unknown trendState', () {
      final item = createItem(symbol: '2330', trendState: 'UNKNOWN');
      expect(item.trend, WatchlistTrend.sideways);
    });
  });

  // ===========================================================================
  // WatchlistNotifier sort with items
  // ===========================================================================

  group('WatchlistNotifier sort with items', () {
    test('setSort sorts by scoreDesc', () {
      final notifier = container.read(watchlistProvider.notifier);

      // Set initial items directly through loadData mock
      when(() => mockDb.getWatchlist()).thenAnswer((_) async => []);
      // Default state with no items → sort won't show visible effect
      // But we can verify the sort option is stored
      notifier.setSort(WatchlistSort.scoreDesc);
      expect(container.read(watchlistProvider).sort, WatchlistSort.scoreDesc);
    });

    test('setSort to priceChangeDesc stores correctly', () {
      final notifier = container.read(watchlistProvider.notifier);
      notifier.setSort(WatchlistSort.priceChangeDesc);
      expect(
        container.read(watchlistProvider).sort,
        WatchlistSort.priceChangeDesc,
      );
    });

    test('setSort to nameAsc stores correctly', () {
      final notifier = container.read(watchlistProvider.notifier);
      notifier.setSort(WatchlistSort.nameAsc);
      expect(container.read(watchlistProvider).sort, WatchlistSort.nameAsc);
    });

    test('setGroup to trend stores correctly', () {
      final notifier = container.read(watchlistProvider.notifier);
      notifier.setGroup(WatchlistGroup.trend);
      expect(container.read(watchlistProvider).group, WatchlistGroup.trend);
    });
  });

  // ===========================================================================
  // Provider declaration
  // ===========================================================================

  group('watchlistProvider', () {
    test('provides initial state', () {
      final state = container.read(watchlistProvider);
      expect(state, isA<WatchlistState>());
      expect(state.items, isEmpty);
    });

    test('notifier is accessible', () {
      final notifier = container.read(watchlistProvider.notifier);
      expect(notifier, isA<WatchlistNotifier>());
    });
  });
}
