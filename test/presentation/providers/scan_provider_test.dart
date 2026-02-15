import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/database/cached_accessor.dart';
import 'package:afterclose/data/repositories/analysis_repository.dart';
import 'package:afterclose/domain/services/data_sync_service.dart';
import 'package:afterclose/presentation/providers/scan_provider.dart';
import 'package:afterclose/presentation/providers/providers.dart';

// =============================================================================
// Mocks
// =============================================================================

class MockAppDatabase extends Mock implements AppDatabase {}

class MockCachedDatabaseAccessor extends Mock
    implements CachedDatabaseAccessor {}

class MockAnalysisRepository extends Mock implements AnalysisRepository {}

class MockDataSyncService extends Mock implements DataSyncService {}

// =============================================================================
// Test Helpers
// =============================================================================

DailyAnalysisEntry createAnalysis({
  required String symbol,
  double score = 80.0,
  DateTime? date,
}) {
  return DailyAnalysisEntry(
    symbol: symbol,
    date: date ?? DateTime.utc(2026, 2, 13),
    trendState: 'BULLISH',
    reversalState: 'NONE',
    score: score,
    computedAt: DateTime.utc(2026, 2, 13),
  );
}

DailyReasonEntry createReason({
  required String symbol,
  String reasonType = 'VOLUME_BREAKOUT',
  DateTime? date,
}) {
  return DailyReasonEntry(
    symbol: symbol,
    date: date ?? DateTime.utc(2026, 2, 13),
    rank: 1,
    reasonType: reasonType,
    evidenceJson: '{}',
    ruleScore: 10.0,
  );
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  late MockAppDatabase mockDb;
  late MockCachedDatabaseAccessor mockCachedDb;
  late MockAnalysisRepository mockAnalysisRepo;
  late MockDataSyncService mockDataSyncService;
  late ProviderContainer container;

  final testDate = DateTime.utc(2026, 2, 13);

  setUp(() {
    mockDb = MockAppDatabase();
    mockCachedDb = MockCachedDatabaseAccessor();
    mockAnalysisRepo = MockAnalysisRepository();
    mockDataSyncService = MockDataSyncService();

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(mockDb),
        cachedDbProvider.overrideWithValue(mockCachedDb),
        analysisRepositoryProvider.overrideWithValue(mockAnalysisRepo),
        dataSyncServiceProvider.overrideWithValue(mockDataSyncService),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  /// 設定 loadData 成功所需的完整 mock 行為
  void setupLoadDataDefaults({
    List<DailyAnalysisEntry> analyses = const [],
    Map<String, List<DailyReasonEntry>>? reasons,
  }) {
    when(
      () => mockAnalysisRepo.findLatestAnalyses(),
    ).thenAnswer((_) async => (targetDate: testDate, analyses: analyses));
    when(
      () => mockDb.getReasonsBatch(any(), any()),
    ).thenAnswer((_) async => reasons ?? {});
    when(() => mockDb.getLatestDataDate()).thenAnswer((_) async => testDate);
    when(
      () => mockDb.getLatestInstitutionalDate(),
    ).thenAnswer((_) async => testDate);
    when(
      () => mockDataSyncService.getDisplayDataDate(any(), any()),
    ).thenReturn(testDate);
    when(
      () => mockDb.getDistinctIndustries(),
    ).thenAnswer((_) async => ['半導體業', '金融業']);
    when(() => mockDb.getWatchlist()).thenAnswer((_) async => []);
    when(
      () => mockCachedDb.loadScanData(
        symbols: any(named: 'symbols'),
        analysisDate: any(named: 'analysisDate'),
        historyStart: any(named: 'historyStart'),
      ),
    ).thenAnswer(
      (_) async => (
        stocks: <String, StockMasterEntry>{},
        latestPrices: <String, DailyPriceEntry>{},
        reasons: <String, List<DailyReasonEntry>>{},
        priceHistories: <String, List<DailyPriceEntry>>{},
      ),
    );
  }

  group('ScanState', () {
    test('has correct default values', () {
      const state = ScanState();

      expect(state.allStocks, isEmpty);
      expect(state.stocks, isEmpty);
      expect(state.filter, ScanFilter.all);
      expect(state.sort, ScanSort.scoreDesc);
      expect(state.industryFilter, isNull);
      expect(state.industries, isEmpty);
      expect(state.dataDate, isNull);
      expect(state.isLoading, isFalse);
      expect(state.isFiltering, isFalse);
      expect(state.isLoadingMore, isFalse);
      expect(state.hasMore, isTrue);
      expect(state.totalCount, 0);
      expect(state.totalAnalyzedCount, 0);
      expect(state.error, isNull);
    });

    test('copyWith creates new instance with updated values', () {
      const original = ScanState(isLoading: true, totalCount: 100);

      final updated = original.copyWith(isLoading: false, error: 'test');

      expect(updated.isLoading, isFalse);
      expect(updated.error, 'test');
      expect(updated.totalCount, 100); // preserved
    });

    test('copyWith with clearIndustryFilter clears industry', () {
      const original = ScanState(industryFilter: '半導體業');

      final updated = original.copyWith(clearIndustryFilter: true);

      expect(updated.industryFilter, isNull);
    });

    test('copyWith preserves industryFilter when not clearing', () {
      const original = ScanState(industryFilter: '半導體業');

      final updated = original.copyWith(isLoading: true);

      expect(updated.industryFilter, '半導體業');
    });
  });

  group('ScanStockItem', () {
    test('copyWith toggles watchlist', () {
      final item = ScanStockItem(
        symbol: '2330',
        score: 85.0,
        isInWatchlist: false,
      );

      final toggled = item.copyWith(isInWatchlist: true);

      expect(toggled.isInWatchlist, isTrue);
      expect(toggled.symbol, '2330');
      expect(toggled.score, 85.0);
    });

    test('reasonTypes computed from reasons', () {
      final item = ScanStockItem(
        symbol: '2330',
        score: 85.0,
        reasons: [
          createReason(symbol: '2330', reasonType: 'VOLUME_BREAKOUT'),
          createReason(symbol: '2330', reasonType: 'GOLDEN_CROSS'),
        ],
      );

      expect(item.reasonTypes, equals(['VOLUME_BREAKOUT', 'GOLDEN_CROSS']));
    });

    test('reasonTypes is empty when no reasons', () {
      final item = ScanStockItem(symbol: '2330', score: 85.0);

      expect(item.reasonTypes, isEmpty);
    });
  });

  group('ScanFilter', () {
    test('all filter has null reasonCode', () {
      expect(ScanFilter.all.reasonCode, isNull);
    });

    test('specific filter has non-null reasonCode', () {
      expect(ScanFilter.volumeSpike.reasonCode, isNotNull);
    });

    test('group filters returns correct members', () {
      final reversalFilters = ScanFilterGroup.reversal.filters;

      expect(reversalFilters, contains(ScanFilter.reversalW2S));
      expect(reversalFilters, contains(ScanFilter.reversalS2W));
      expect(reversalFilters.length, 2);
    });
  });

  group('ScanNotifier', () {
    test('initial state has default values', () {
      final state = container.read(scanProvider);

      expect(state.isLoading, isFalse);
      expect(state.stocks, isEmpty);
      expect(state.error, isNull);
    });

    test('loadData with no analyses results in empty state', () async {
      setupLoadDataDefaults(analyses: []);

      final notifier = container.read(scanProvider.notifier);
      await notifier.loadData();

      final state = container.read(scanProvider);
      expect(state.isLoading, isFalse);
      expect(state.stocks, isEmpty);
      expect(state.totalCount, 0);
      expect(state.hasMore, isFalse);
      expect(state.error, isNull);
    });

    test('loadData filters out analyses with score <= 0', () async {
      final analyses = [
        createAnalysis(symbol: '2330', score: 85),
        createAnalysis(symbol: '2317', score: 0), // should be filtered
        createAnalysis(symbol: '2454', score: -5), // should be filtered
      ];

      setupLoadDataDefaults(analyses: analyses);

      final notifier = container.read(scanProvider.notifier);
      await notifier.loadData();

      final state = container.read(scanProvider);
      expect(state.totalAnalyzedCount, 1); // only 2330 has score > 0
    });

    test('loadData sets loading state', () async {
      setupLoadDataDefaults();

      final notifier = container.read(scanProvider.notifier);
      final loadFuture = notifier.loadData();

      expect(container.read(scanProvider).isLoading, isTrue);

      await loadFuture;

      expect(container.read(scanProvider).isLoading, isFalse);
    });

    test('loadData handles error gracefully', () async {
      when(
        () => mockAnalysisRepo.findLatestAnalyses(),
      ).thenThrow(Exception('Database error'));

      final notifier = container.read(scanProvider.notifier);
      await notifier.loadData();

      final state = container.read(scanProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNotNull);
      expect(state.error, contains('Database error'));
    });

    test('loadData loads industries list', () async {
      setupLoadDataDefaults();

      final notifier = container.read(scanProvider.notifier);
      await notifier.loadData();

      final state = container.read(scanProvider);
      expect(state.industries, equals(['半導體業', '金融業']));
    });

    test('setFilter skips if same filter', () {
      setupLoadDataDefaults();

      final notifier = container.read(scanProvider.notifier);
      final stateBefore = container.read(scanProvider);

      notifier.setFilter(ScanFilter.all); // same as default

      final stateAfter = container.read(scanProvider);
      expect(identical(stateBefore, stateAfter), isTrue);
    });

    test('setSort skips if same sort', () {
      setupLoadDataDefaults();

      final notifier = container.read(scanProvider.notifier);
      final stateBefore = container.read(scanProvider);

      notifier.setSort(ScanSort.scoreDesc); // same as default

      final stateAfter = container.read(scanProvider);
      expect(identical(stateBefore, stateAfter), isTrue);
    });

    test('toggleWatchlist toggles stock watchlist status', () async {
      // Setup: stock is in watchlist
      when(() => mockDb.isInWatchlist('2330')).thenAnswer((_) async => true);
      when(() => mockDb.removeFromWatchlist('2330')).thenAnswer((_) async => 1);

      // Pre-populate state with a stock item
      setupLoadDataDefaults(
        analyses: [createAnalysis(symbol: '2330', score: 85)],
      );

      final notifier = container.read(scanProvider.notifier);
      await notifier.loadData();

      // Now toggle
      await notifier.toggleWatchlist('2330');

      verify(() => mockDb.removeFromWatchlist('2330')).called(1);
    });

    test('toggleWatchlist adds to watchlist when not present', () async {
      when(() => mockDb.isInWatchlist('2330')).thenAnswer((_) async => false);
      when(() => mockDb.addToWatchlist('2330')).thenAnswer((_) async => 1);

      setupLoadDataDefaults(
        analyses: [createAnalysis(symbol: '2330', score: 85)],
      );

      final notifier = container.read(scanProvider.notifier);
      await notifier.loadData();

      await notifier.toggleWatchlist('2330');

      verify(() => mockDb.addToWatchlist('2330')).called(1);
    });

    test('loadMore does nothing when no more data', () async {
      setupLoadDataDefaults(analyses: []);

      final notifier = container.read(scanProvider.notifier);
      await notifier.loadData();

      // hasMore is false after empty load
      await notifier.loadMore();

      final state = container.read(scanProvider);
      expect(state.isLoadingMore, isFalse);
    });

    test('setIndustryFilter sets filter and triggers reload', () async {
      setupLoadDataDefaults(
        analyses: [createAnalysis(symbol: '2330', score: 85)],
      );

      when(
        () => mockDb.getSymbolsByIndustry('半導體業'),
      ).thenAnswer((_) async => {'2330'});

      final notifier = container.read(scanProvider.notifier);
      await notifier.loadData();

      await notifier.setIndustryFilter('半導體業');

      // _reloadFirstPage is fire-and-forget, let it complete
      await Future<void>.delayed(Duration.zero);

      final state = container.read(scanProvider);
      expect(state.industryFilter, '半導體業');
      expect(state.isFiltering, isFalse);
    });

    test('setIndustryFilter clears when null', () async {
      setupLoadDataDefaults(
        analyses: [createAnalysis(symbol: '2330', score: 85)],
      );

      when(
        () => mockDb.getSymbolsByIndustry('半導體業'),
      ).thenAnswer((_) async => {'2330'});

      final notifier = container.read(scanProvider.notifier);
      await notifier.loadData();

      // Set industry
      await notifier.setIndustryFilter('半導體業');
      await Future<void>.delayed(Duration.zero);
      expect(container.read(scanProvider).industryFilter, '半導體業');

      // Clear industry
      await notifier.setIndustryFilter(null);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(scanProvider).industryFilter, isNull);
    });

    test('setIndustryFilter race condition: latest call wins', () async {
      setupLoadDataDefaults(
        analyses: [createAnalysis(symbol: '2330', score: 85)],
      );

      // First call delays, second resolves immediately
      when(() => mockDb.getSymbolsByIndustry('半導體業')).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return {'2330'};
      });
      when(
        () => mockDb.getSymbolsByIndustry('金融業'),
      ).thenAnswer((_) async => {'2882'});

      final notifier = container.read(scanProvider.notifier);
      await notifier.loadData();

      // Fire first (slow) call without awaiting
      unawaited(notifier.setIndustryFilter('半導體業'));
      // Immediately override with second (fast) call
      await notifier.setIndustryFilter('金融業');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // The latest call should be the winner
      final state = container.read(scanProvider);
      expect(state.industryFilter, '金融業');
    });
  });
}
