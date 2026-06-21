import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/data/remote/tpex_client.dart';
import 'package:afterclose/presentation/providers/market_overview_provider.dart';
import 'package:afterclose/presentation/providers/providers.dart';

// ==========================================
// Mocks
// ==========================================

class MockAppDatabase extends Mock implements AppDatabase {}

class MockTwseClient extends Mock implements TwseClient {}

class MockTpexClient extends Mock implements TpexClient {}

// ==========================================
// Tests
// ==========================================

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
    ).thenAnswer((_) async => (advance: 0, decline: 0, unchanged: 0));
    when(
      () => mockTwse.getInstitutionalAmounts(date: any(named: 'date')),
    ).thenAnswer((_) async => null);
    when(
      () => mockTpex.getInstitutionalAmounts(date: any(named: 'date')),
    ).thenAnswer((_) async => null);
    when(() => mockDb.getLatestMarginTradingTotalsByMarket()).thenAnswer(
      (_) async =>
          <
            String,
            ({
              double marginBalance,
              double marginChange,
              double shortBalance,
              double shortChange,
              DateTime? dataDate,
            })
          >{},
    );
    when(
      () => mockDb.getIndexHistoryBatch(any(), days: any(named: 'days')),
    ).thenAnswer((_) async => {});
    when(
      () => mockDb.getAdvanceDeclineCountsByMarket(any()),
    ).thenAnswer((_) async => {});
    when(
      () => mockDb.getTurnoverSummaryByMarket(any()),
    ).thenAnswer((_) async => {});
    when(
      () => mockTpex.getTpexIndex(),
    ).thenAnswer((_) async => <TwseMarketIndex>[]);
    when(
      () => mockDb.getLimitUpDownCountsByMarket(any()),
    ).thenAnswer((_) async => <String, ({int limitUp, int limitDown})>{});
    when(
      () => mockDb.getRecentTurnoverByMarket(any(), days: any(named: 'days')),
    ).thenAnswer(
      (_) async => <String, List<({DateTime date, double turnover})>>{},
    );
    when(
      () => mockDb.getActiveWarningCountsByMarket(),
    ).thenAnswer((_) async => <String, Map<String, int>>{});
    when(
      () => mockDb.getRecentInstitutionalDailyByMarket(
        any(),
        days: any(named: 'days'),
      ),
    ).thenAnswer(
      (_) async =>
          <
            String,
            List<
              ({
                DateTime date,
                double foreignNet,
                double trustNet,
                double dealerNet,
              })
            >
          >{},
    );
    when(() => mockDb.getIndustrySummaryByMarket(any(), any())).thenAnswer(
      (_) async =>
          <
            ({
              String industry,
              int stockCount,
              double avgChangePct,
              int advance,
              int decline,
            })
          >[],
    );
    when(
      () => mockDb.getNewHighLowCountsByMarket(
        any(),
        lookbackDays: any(named: 'lookbackDays'),
      ),
    ).thenAnswer((_) async => <String, ({int newHighs, int newLows})>{});
    when(
      () => mockDb.getRecentAdvanceDeclineByMarket(
        any(),
        days: any(named: 'days'),
        minCoverage: any(named: 'minCoverage'),
      ),
    ).thenAnswer(
      (_) async =>
          <
            String,
            List<({DateTime date, int advance, int decline, int unchanged})>
          >{},
    );
  }

  group('MarketOverviewState', () {
    test('has correct default values', () {
      const state = MarketOverviewState();

      expect(state.indices, isEmpty);
      expect(state.indexHistory, isEmpty);
      expect(state.advanceDecline.total, 0);
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

      when(
        () => mockDb.getAdvanceDeclineCounts(any()),
      ).thenAnswer((_) async => (advance: 500, decline: 300, unchanged: 200));

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

    test('loadData populates institutional totals by market', () async {
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
      final twse = state.institutionalByMarket['TWSE']!;
      expect(twse.foreignNet, 1000000);
      expect(twse.trustNet, 500000);
      expect(twse.dealerNet, -200000);
      final tpex = state.institutionalByMarket['TPEx']!;
      expect(tpex.foreignNet, 300000);
    });

    test('loadData populates margin trading totals from DB', () async {
      setupEmptyDefaults();

      when(() => mockDb.getLatestMarginTradingTotalsByMarket()).thenAnswer(
        (_) async => {
          'TWSE': (
            marginBalance: 30000.0,
            marginChange: 700.0,
            shortBalance: 2000.0,
            shortChange: -100.0,
            dataDate: DateTime(2024, 3, 26),
          ),
          'TPEx': (
            marginBalance: 20000.0,
            marginChange: 300.0,
            shortBalance: 1000.0,
            shortChange: -100.0,
            dataDate: DateTime(2024, 3, 25),
          ),
        },
      );

      final notifier = container.read(marketOverviewProvider.notifier);
      await notifier.loadData();

      final state = container.read(marketOverviewProvider);
      final twseMargin = state.marginByMarket['TWSE']!;
      expect(twseMargin.marginBalance, 30000.0);
      expect(twseMargin.marginChange, 700.0);
      final tpexMargin = state.marginByMarket['TPEx']!;
      expect(tpexMargin.shortBalance, 1000.0);
      expect(tpexMargin.shortChange, -100.0);
    });

    test('loadData populates by-market breakdowns', () async {
      setupEmptyDefaults();

      when(() => mockDb.getAdvanceDeclineCountsByMarket(any())).thenAnswer(
        (_) async => {
          'TWSE': (advance: 400, decline: 200, unchanged: 100),
          'TPEx': (advance: 100, decline: 100, unchanged: 100),
        },
      );

      when(() => mockDb.getTurnoverSummaryByMarket(any())).thenAnswer(
        (_) async => {
          'TWSE': (totalTurnover: 200000000000.0),
          'TPEx': (totalTurnover: 50000000000.0),
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
      expect(state.error, isNotEmpty);
    });

    test('individual load failures do not affect other sections', () async {
      setupEmptyDefaults();

      // API indices fails, but DB queries succeed
      when(
        () => mockTwse.getMarketIndices(),
      ).thenThrow(Exception('Network error'));

      when(
        () => mockDb.getAdvanceDeclineCounts(any()),
      ).thenAnswer((_) async => (advance: 100, decline: 50, unchanged: 20));

      final notifier = container.read(marketOverviewProvider.notifier);
      await notifier.loadData();

      final state = container.read(marketOverviewProvider);
      expect(state.error, isNull); // no top-level error
      expect(state.indices, isEmpty); // indices failed gracefully
      expect(state.advanceDecline.advance, 100); // DB data loaded
    });

    test('loadData uses DateTime.now() when no data date in DB', () async {
      setupEmptyDefaults();
      when(() => mockDb.getLatestDataDate()).thenAnswer((_) async => null);

      final notifier = container.read(marketOverviewProvider.notifier);
      await notifier.loadData();

      final state = container.read(marketOverviewProvider);
      expect(state.dataDate, isNotNull);
    });

    test('loadData populates breadth trend (new high/low + AD line)', () async {
      setupEmptyDefaults();

      when(
        () => mockDb.getNewHighLowCountsByMarket(
          any(),
          lookbackDays: any(named: 'lookbackDays'),
        ),
      ).thenAnswer(
        (_) async => {
          'TWSE': (newHighs: 156, newLows: 29),
          'TPEx': (newHighs: 82, newLows: 55),
        },
      );

      // 日期降序（最新在前）：每日 adv-dec = +50, +30, -20
      // 反轉 oldest→newest 後累積 = [-20, 10, 60]
      when(
        () => mockDb.getRecentAdvanceDeclineByMarket(
          any(),
          days: any(named: 'days'),
          minCoverage: any(named: 'minCoverage'),
        ),
      ).thenAnswer(
        (_) async => {
          'TWSE': [
            (date: testDate, advance: 80, decline: 30, unchanged: 0), // +50
            (
              date: testDate.subtract(const Duration(days: 1)),
              advance: 60,
              decline: 30,
              unchanged: 0,
            ), // +30
            (
              date: testDate.subtract(const Duration(days: 2)),
              advance: 40,
              decline: 60,
              unchanged: 0,
            ), // -20
          ],
        },
      );

      final notifier = container.read(marketOverviewProvider.notifier);
      await notifier.loadData();

      final state = container.read(marketOverviewProvider);
      expect(state.newHighLowByMarket['TWSE']?.newHighs, 156);
      expect(state.newHighLowByMarket['TWSE']?.newLows, 29);
      expect(state.newHighLowByMarket['TPEx']?.newHighs, 82);
      expect(state.newHighLowByMarket['TPEx']?.newLows, 55);

      // 累積 AD 線 oldest→newest：[-20, -20+30=10, 10+50=60]
      expect(state.adLineByMarket['TWSE'], [-20.0, 10.0, 60.0]);
    });

    test('history sparklines 保留各自完整序列（不被情緒對齊的日期交集縮短）', () async {
      setupEmptyDefaults();

      // 兩組來源日期集刻意不同（重現 bug 前提）：
      // - turnover / advanceRatio：coverage-filter 過，僅 8 個完整日。
      // - institutional / margin：未 filter，12 個每日（含 turnover/AD 缺的 4 個舊日）。
      // 全部 DAO 回傳日期降序（最新在前）。
      DateTime d(int back) => testDate.subtract(Duration(days: back));

      // 8 個完整日（back 0..7）
      when(
        () => mockDb.getRecentTurnoverByMarket(any(), days: any(named: 'days')),
      ).thenAnswer(
        (_) async => {
          'TWSE': [
            for (var back = 0; back < 8; back++)
              (date: d(back), turnover: 1000.0 + back),
          ],
        },
      );
      when(
        () => mockDb.getRecentAdvanceDeclineByMarket(
          any(),
          days: any(named: 'days'),
          minCoverage: any(named: 'minCoverage'),
        ),
      ).thenAnswer(
        (_) async => {
          'TWSE': [
            for (var back = 0; back < 8; back++)
              (date: d(back), advance: 60, decline: 40, unchanged: 0),
          ],
        },
      );

      // 12 個每日（back 0..11）— 比上面多出 back 8..11 共 4 個舊日
      when(
        () => mockDb.getRecentInstitutionalDailyByMarket(
          any(),
          days: any(named: 'days'),
        ),
      ).thenAnswer(
        (_) async => {
          'TWSE': [
            for (var back = 0; back < 12; back++)
              (
                date: d(back),
                foreignNet: 100.0 + back,
                trustNet: 0.0,
                dealerNet: 0.0,
              ),
          ],
        },
      );
      when(
        () => mockDb.getRecentMarginTradingByMarket(
          any(),
          days: any(named: 'days'),
        ),
      ).thenAnswer(
        (_) async => {
          'TWSE': [
            for (var back = 0; back < 12; back++)
              (
                date: d(back),
                marginBalance: 10000.0 + back,
                shortBalance: 500.0 + back,
              ),
          ],
        },
      );

      final notifier = container.read(marketOverviewProvider.notifier);
      await notifier.loadData();

      final state = container.read(marketOverviewProvider);
      final trends = state.historyTrends;

      // 個別 sparkline 必須維持各自完整長度，不被 4-way 日期交集（8）縮短。
      expect(
        trends.turnover['TWSE'],
        hasLength(8),
        reason: 'turnover sparkline 應為完整 8 日',
      );
      expect(
        trends.advanceRatio['TWSE'],
        hasLength(8),
        reason: 'advanceRatio sparkline 應為完整 8 日',
      );
      expect(
        trends.institutionalTotalNet['TWSE'],
        hasLength(12),
        reason: 'institutional sparkline 應為完整 12 日（未被縮到交集 8）',
      );
      expect(
        trends.marginBalance['TWSE'],
        hasLength(12),
        reason: 'margin sparkline 應為完整 12 日（未被縮到交集 8）',
      );
      expect(
        trends.shortBalance['TWSE'],
        hasLength(12),
        reason: 'short sparkline 應為完整 12 日',
      );

      // 帶日期序列為 oldest→newest（最舊在前）。
      final turnover = trends.turnover['TWSE']!;
      expect(turnover.first.date.isBefore(turnover.last.date), isTrue);
    });
  });

  group('cumulativeAdLine', () {
    test('running sum oldest→newest on known series', () {
      expect(cumulativeAdLine([5, 3, -2, 4]), [5.0, 8.0, 6.0, 10.0]);
    });

    test('all-positive series strictly increases', () {
      expect(cumulativeAdLine([1, 1, 1]), [1.0, 2.0, 3.0]);
    });

    test('all-negative series strictly decreases', () {
      expect(cumulativeAdLine([-1, -2, -3]), [-1.0, -3.0, -6.0]);
    });

    test('single element returns itself', () {
      expect(cumulativeAdLine([7]), [7.0]);
    });

    test('empty input returns empty list', () {
      expect(cumulativeAdLine([]), isEmpty);
    });
  });
}
