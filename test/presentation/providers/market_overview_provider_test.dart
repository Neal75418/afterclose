import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/data/remote/tpex_client.dart';
import 'package:afterclose/presentation/providers/market_overview_provider.dart';
import 'package:afterclose/presentation/providers/providers.dart';

// =============================================================================
// Mocks
// =============================================================================

class MockAppDatabase extends Mock implements AppDatabase {}

class MockTwseClient extends Mock implements TwseClient {}

class MockTpexClient extends Mock implements TpexClient {}

// =============================================================================
// Tests
// =============================================================================

void main() {
  late MockAppDatabase mockDb;
  late MockTwseClient mockTwse;
  late MockTpexClient mockTpex;
  late ProviderContainer container;

  final testDate = DateTime.utc(2026, 2, 13);

  setUp(() {
    mockDb = MockAppDatabase();
    mockTwse = MockTwseClient();
    mockTpex = MockTpexClient();

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(mockDb),
        twseClientProvider.overrideWithValue(mockTwse),
        tpexClientProvider.overrideWithValue(mockTpex),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  /// 設定所有 mock 回傳空/預設值
  void setupEmptyDefaults() {
    when(() => mockDb.getLatestDataDate()).thenAnswer((_) async => testDate);
    when(() => mockTwse.getMarketIndices()).thenAnswer((_) async => []);
    when(
      () => mockDb.getAdvanceDeclineCounts(any()),
    ).thenAnswer((_) async => {});
    when(
      () => mockTwse.getInstitutionalAmounts(date: any(named: 'date')),
    ).thenAnswer((_) async => null);
    when(
      () => mockTpex.getInstitutionalAmounts(date: any(named: 'date')),
    ).thenAnswer((_) async => null);
    when(
      () => mockDb.getMarginTradingTotals(any()),
    ).thenAnswer((_) async => {});
    when(
      () => mockDb.getIndexHistoryBatch(any(), days: any(named: 'days')),
    ).thenAnswer((_) async => {});
    when(
      () => mockDb.getAdvanceDeclineCountsByMarket(any()),
    ).thenAnswer((_) async => {});
    when(
      () => mockDb.getMarginTradingTotalsByMarket(any()),
    ).thenAnswer((_) async => {});
    when(
      () => mockDb.getTurnoverSummaryByMarket(any()),
    ).thenAnswer((_) async => {});
  }

  group('MarketOverviewState', () {
    test('has correct default values', () {
      const state = MarketOverviewState();

      expect(state.indices, isEmpty);
      expect(state.indexHistory, isEmpty);
      expect(state.advanceDecline.total, 0);
      expect(state.institutional.totalNet, 0);
      expect(state.margin.marginBalance, 0);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.dataDate, isNull);
      expect(state.hasData, isFalse);
    });

    test('hasData returns true when indices present', () {
      final state = MarketOverviewState(
        indices: [
          TwseMarketIndex(
            date: testDate,
            name: '加權指數',
            close: 20000,
            change: 100,
            changePercent: 0.5,
          ),
        ],
      );

      expect(state.hasData, isTrue);
    });

    test('hasData returns true when advanceDecline has data', () {
      const state = MarketOverviewState(
        advanceDecline: AdvanceDecline(advance: 500, decline: 300),
      );

      expect(state.hasData, isTrue);
    });

    test('copyWith creates new instance preserving unset values', () {
      const original = MarketOverviewState(isLoading: true);

      final updated = original.copyWith(isLoading: false, error: 'test');

      expect(updated.isLoading, isFalse);
      expect(updated.error, 'test');
      expect(updated.indices, isEmpty);
    });
  });

  group('AdvanceDecline', () {
    test('total is sum of all components', () {
      const ad = AdvanceDecline(advance: 500, decline: 300, unchanged: 200);

      expect(ad.total, 1000);
    });
  });

  group('MarketOverviewNotifier', () {
    test('initial state has default values', () {
      setupEmptyDefaults();

      final state = container.read(marketOverviewProvider);

      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.indices, isEmpty);
    });

    test('loadData sets loading and loads all data in parallel', () async {
      setupEmptyDefaults();

      // Override with actual data
      when(() => mockTwse.getMarketIndices()).thenAnswer(
        (_) async => [
          TwseMarketIndex(
            date: testDate,
            name: '發行量加權股價指數',
            close: 20000,
            change: 150,
            changePercent: 0.75,
          ),
          TwseMarketIndex(
            date: testDate,
            name: '未上榜指數',
            close: 100,
            change: 1,
            changePercent: 0.01,
          ),
        ],
      );

      when(() => mockDb.getAdvanceDeclineCounts(any())).thenAnswer(
        (_) async => {'advance': 500, 'decline': 300, 'unchanged': 200},
      );

      final notifier = container.read(marketOverviewProvider.notifier);
      final loadFuture = notifier.loadData();

      // isLoading should be true immediately
      expect(container.read(marketOverviewProvider).isLoading, isTrue);

      await loadFuture;

      final state = container.read(marketOverviewProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.dataDate, testDate);
      expect(state.advanceDecline.advance, 500);
      expect(state.advanceDecline.decline, 300);
      expect(state.advanceDecline.unchanged, 200);

      // Verify indices are filtered to dashboardIndices only
      expect(state.indices.length, 1);
      expect(state.indices[0].name, '發行量加權股價指數');
    });

    test('loadData populates institutional totals from TWSE + TPEX', () async {
      setupEmptyDefaults();

      when(
        () => mockTwse.getInstitutionalAmounts(date: any(named: 'date')),
      ).thenAnswer(
        (_) async => TwseInstitutionalAmounts(
          date: testDate,
          foreignNet: 1000000,
          trustNet: 500000,
          dealerNet: -200000,
        ),
      );

      when(
        () => mockTpex.getInstitutionalAmounts(date: any(named: 'date')),
      ).thenAnswer(
        (_) async => TpexInstitutionalAmounts(
          date: testDate,
          foreignNet: 300000,
          trustNet: 100000,
          dealerNet: -50000,
        ),
      );

      final notifier = container.read(marketOverviewProvider.notifier);
      await notifier.loadData();

      final state = container.read(marketOverviewProvider);
      expect(state.institutional.foreignNet, 1300000); // TWSE + TPEX
      expect(state.institutional.trustNet, 600000);
      expect(state.institutional.dealerNet, -250000);
      expect(state.institutional.totalNet, 1650000);
    });

    test('loadData populates margin trading totals from DB', () async {
      setupEmptyDefaults();

      when(() => mockDb.getMarginTradingTotals(any())).thenAnswer(
        (_) async => {
          'marginBalance': 50000.0,
          'marginChange': 1000.0,
          'shortBalance': 3000.0,
          'shortChange': -200.0,
        },
      );

      final notifier = container.read(marketOverviewProvider.notifier);
      await notifier.loadData();

      final state = container.read(marketOverviewProvider);
      expect(state.margin.marginBalance, 50000.0);
      expect(state.margin.marginChange, 1000.0);
      expect(state.margin.shortBalance, 3000.0);
      expect(state.margin.shortChange, -200.0);
    });

    test('loadData populates by-market breakdowns', () async {
      setupEmptyDefaults();

      when(() => mockDb.getAdvanceDeclineCountsByMarket(any())).thenAnswer(
        (_) async => {
          'TWSE': {'advance': 400, 'decline': 200, 'unchanged': 100},
          'TPEx': {'advance': 100, 'decline': 100, 'unchanged': 100},
        },
      );

      when(() => mockDb.getTurnoverSummaryByMarket(any())).thenAnswer(
        (_) async => {
          'TWSE': {'totalTurnover': 200000000000.0},
          'TPEx': {'totalTurnover': 50000000000.0},
        },
      );

      final notifier = container.read(marketOverviewProvider.notifier);
      await notifier.loadData();

      final state = container.read(marketOverviewProvider);
      expect(state.advanceDeclineByMarket['TWSE']?.advance, 400);
      expect(state.advanceDeclineByMarket['TPEx']?.decline, 100);
      expect(state.turnoverByMarket['TWSE']?.totalTurnover, 200000000000.0);
    });

    test('loadData handles error gracefully', () async {
      when(
        () => mockDb.getLatestDataDate(),
      ).thenThrow(Exception('DB connection failed'));

      final notifier = container.read(marketOverviewProvider.notifier);
      await notifier.loadData();

      final state = container.read(marketOverviewProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNotNull);
      expect(state.error, contains('DB connection failed'));
    });

    test('individual load failures do not affect other sections', () async {
      setupEmptyDefaults();

      // API indices fails, but DB queries succeed
      when(
        () => mockTwse.getMarketIndices(),
      ).thenThrow(Exception('Network error'));

      when(() => mockDb.getAdvanceDeclineCounts(any())).thenAnswer(
        (_) async => {'advance': 100, 'decline': 50, 'unchanged': 20},
      );

      final notifier = container.read(marketOverviewProvider.notifier);
      await notifier.loadData();

      final state = container.read(marketOverviewProvider);
      expect(state.error, isNull); // no top-level error
      expect(state.indices, isEmpty); // indices failed gracefully
      expect(state.advanceDecline.advance, 100); // DB data loaded
    });

    test('loadData uses DateTime.now() when no data date in DB', () async {
      when(() => mockDb.getLatestDataDate()).thenAnswer((_) async => null);
      when(() => mockTwse.getMarketIndices()).thenAnswer((_) async => []);
      when(
        () => mockDb.getAdvanceDeclineCounts(any()),
      ).thenAnswer((_) async => {});
      when(
        () => mockTwse.getInstitutionalAmounts(date: any(named: 'date')),
      ).thenAnswer((_) async => null);
      when(
        () => mockTpex.getInstitutionalAmounts(date: any(named: 'date')),
      ).thenAnswer((_) async => null);
      when(
        () => mockDb.getMarginTradingTotals(any()),
      ).thenAnswer((_) async => {});
      when(
        () => mockDb.getIndexHistoryBatch(any(), days: any(named: 'days')),
      ).thenAnswer((_) async => {});
      when(
        () => mockDb.getAdvanceDeclineCountsByMarket(any()),
      ).thenAnswer((_) async => {});
      when(
        () => mockDb.getMarginTradingTotalsByMarket(any()),
      ).thenAnswer((_) async => {});
      when(
        () => mockDb.getTurnoverSummaryByMarket(any()),
      ).thenAnswer((_) async => {});

      final notifier = container.read(marketOverviewProvider.notifier);
      await notifier.loadData();

      final state = container.read(marketOverviewProvider);
      expect(state.dataDate, isNotNull);
    });
  });
}
