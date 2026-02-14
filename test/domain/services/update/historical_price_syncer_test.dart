import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/repositories/price_repository.dart';
import 'package:afterclose/domain/services/update/historical_price_syncer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

class MockPriceRepository extends Mock implements PriceRepository {}

void main() {
  late MockAppDatabase mockDb;
  late MockPriceRepository mockPriceRepo;
  late HistoricalPriceSyncer syncer;

  final testDate = DateTime(2025, 1, 15);

  /// 建立 N 天的價格資料
  List<DailyPriceEntry> createPrices(
    String symbol,
    int days, {
    DateTime? firstDate,
  }) {
    final start = firstDate ?? testDate.subtract(Duration(days: days));
    return List.generate(
      days,
      (i) => DailyPriceEntry(
        symbol: symbol,
        date: start.add(Duration(days: i)),
        close: 100.0,
      ),
    );
  }

  /// 設定 DB 的 getSymbolsWithSufficientData 回傳值
  void setupSufficientDataSymbols(List<String> symbols) {
    when(
      () => mockDb.getSymbolsWithSufficientData(
        minDays: any(named: 'minDays'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer((_) async => symbols);
  }

  /// 設定 DB 的 getPriceHistoryBatch 回傳值
  void setupPriceHistoryBatch(Map<String, List<DailyPriceEntry>> batch) {
    when(
      () => mockDb.getPriceHistoryBatch(
        any(),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer((_) async => batch);
  }

  /// 設定 PriceRepo 的 syncStockPrices 成功回傳
  void setupSyncSuccess(String symbol, {int count = 10}) {
    when(
      () => mockPriceRepo.syncStockPrices(
        symbol,
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer((_) async => count);
  }

  /// 設定 PriceRepo 的 syncStockPrices 拋出錯誤
  void setupSyncFailure(String symbol) {
    when(
      () => mockPriceRepo.syncStockPrices(
        symbol,
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenThrow(Exception('API Error'));
  }

  setUp(() {
    mockDb = MockAppDatabase();
    mockPriceRepo = MockPriceRepository();
    syncer = HistoricalPriceSyncer(
      database: mockDb,
      priceRepository: mockPriceRepo,
    );
  });

  group('HistoricalPriceSyncer', () {
    group('syncHistoricalPrices', () {
      test('returns zero when all symbols have sufficient data', () async {
        setupSufficientDataSymbols([]);
        setupPriceHistoryBatch({
          '2330': createPrices('2330', 260),
          '2317': createPrices('2317', 260),
        });

        final result = await syncer.syncHistoricalPrices(
          date: testDate,
          watchlistSymbols: ['2330', '2317'],
          popularStocks: [],
          marketCandidates: [],
        );

        expect(result.syncedCount, 0);
        expect(result.symbolsProcessed, 0);
        verifyNever(
          () => mockPriceRepo.syncStockPrices(
            any(),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        );
      });

      test('syncs symbols with zero price data', () async {
        setupSufficientDataSymbols([]);
        setupPriceHistoryBatch({'2330': []});
        setupSyncSuccess('2330', count: 250);

        final result = await syncer.syncHistoricalPrices(
          date: testDate,
          watchlistSymbols: ['2330'],
          popularStocks: [],
          marketCandidates: [],
        );

        expect(result.syncedCount, 250);
        expect(result.symbolsProcessed, 1);
        expect(result.hasFailures, isFalse);
      });

      test('skips symbols with near-complete data (>= 180 days)', () async {
        // firstDate > 365 days ago ensures _hasEnoughDataForAge won't skip
        final oldFirstDate = testDate.subtract(const Duration(days: 400));

        setupSufficientDataSymbols([]);
        setupPriceHistoryBatch({
          '2330': createPrices('2330', 200), // >= 180, should skip
          '2317': createPrices(
            '2317',
            50,
            firstDate: oldFirstDate,
          ), // < 180, needs sync
        });
        setupSyncSuccess('2317', count: 200);

        final result = await syncer.syncHistoricalPrices(
          date: testDate,
          watchlistSymbols: ['2330', '2317'],
          popularStocks: [],
          marketCandidates: [],
        );

        expect(result.syncedCount, 200);
        expect(result.symbolsProcessed, 1);

        // 2330 should not be synced
        verifyNever(
          () => mockPriceRepo.syncStockPrices(
            '2330',
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        );
      });

      test('handles partial failures gracefully', () async {
        setupSufficientDataSymbols([]);
        setupPriceHistoryBatch({'2330': [], '2317': []});
        setupSyncSuccess('2330', count: 250);
        setupSyncFailure('2317');

        final result = await syncer.syncHistoricalPrices(
          date: testDate,
          watchlistSymbols: ['2330', '2317'],
          popularStocks: [],
          marketCandidates: [],
        );

        expect(result.syncedCount, 250);
        expect(result.symbolsProcessed, 1);
        expect(result.hasFailures, isTrue);
        expect(result.failedSymbols, contains('2317'));
      });

      test('deduplicates symbols from multiple sources', () async {
        final oldFirstDate = testDate.subtract(const Duration(days: 400));

        setupSufficientDataSymbols(['2330']);
        setupPriceHistoryBatch({
          '2330': createPrices(
            '2330',
            50,
            firstDate: oldFirstDate,
          ), // needs sync
          '2317': createPrices('2317', 260), // sufficient
        });
        setupSyncSuccess('2330', count: 200);

        final result = await syncer.syncHistoricalPrices(
          date: testDate,
          watchlistSymbols: ['2330'],
          popularStocks: ['2330', '2317'],
          marketCandidates: ['2330'],
        );

        // 2330 should only be synced once
        expect(result.symbolsProcessed, 1);
        verify(
          () => mockPriceRepo.syncStockPrices(
            '2330',
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).called(1);
      });

      test('calls onProgress callback', () async {
        setupSufficientDataSymbols([]);
        setupPriceHistoryBatch({'2330': []});
        setupSyncSuccess('2330', count: 10);

        final progressMessages = <String>[];

        await syncer.syncHistoricalPrices(
          date: testDate,
          watchlistSymbols: ['2330'],
          popularStocks: [],
          marketCandidates: [],
          onProgress: progressMessages.add,
        );

        expect(progressMessages, isNotEmpty);
        expect(progressMessages.any((m) => m.contains('歷史資料')), isTrue);
      });
    });

    group('fresh database scenario', () {
      test('syncs popular stocks with only 1 day of data (fresh DB)', () async {
        // Fresh DB: 每檔股票只有今天 1 天資料
        // _hasEnoughDataForAge 會誤判為「剛上市」，但新增的 swingWindow guard 應觸發同步
        setupSufficientDataSymbols([]);
        setupPriceHistoryBatch({
          '2330': createPrices('2330', 1, firstDate: testDate),
          '2317': createPrices('2317', 1, firstDate: testDate),
        });
        setupSyncSuccess('2330', count: 250);
        setupSyncSuccess('2317', count: 250);

        final result = await syncer.syncHistoricalPrices(
          date: testDate,
          watchlistSymbols: [],
          popularStocks: ['2330', '2317'],
          marketCandidates: [],
        );

        expect(result.syncedCount, 500);
        expect(result.symbolsProcessed, 2);
        verify(
          () => mockPriceRepo.syncStockPrices(
            '2330',
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).called(1);
        verify(
          () => mockPriceRepo.syncStockPrices(
            '2317',
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).called(1);
      });
    });

    group('_hasEnoughDataForAge', () {
      test('skips new stock with proportional data', () async {
        // Stock listed 100 days ago with 50 days of data
        // Expected: ~71 trading days, threshold: ~35 days
        // 50 >= 35, should skip
        final firstDate = testDate.subtract(const Duration(days: 100));

        setupSufficientDataSymbols([]);
        setupPriceHistoryBatch({
          '6547': createPrices('6547', 50, firstDate: firstDate),
        });

        final result = await syncer.syncHistoricalPrices(
          date: testDate,
          watchlistSymbols: ['6547'],
          popularStocks: [],
          marketCandidates: [],
        );

        expect(result.syncedCount, 0);
        expect(result.symbolsProcessed, 0);
      });

      test('syncs new stock with insufficient proportional data', () async {
        // Stock listed 100 days ago with only 10 days of data
        // Expected: ~71 trading days, threshold: ~35 days
        // 10 < 35, should sync
        final firstDate = testDate.subtract(const Duration(days: 100));

        setupSufficientDataSymbols([]);
        setupPriceHistoryBatch({
          '6547': createPrices('6547', 10, firstDate: firstDate),
        });
        setupSyncSuccess('6547', count: 60);

        final result = await syncer.syncHistoricalPrices(
          date: testDate,
          watchlistSymbols: ['6547'],
          popularStocks: [],
          marketCandidates: [],
        );

        expect(result.syncedCount, 60);
        expect(result.symbolsProcessed, 1);
      });
    });

    group('_prioritizeSymbols', () {
      test('prioritizes watchlist over popular over others', () async {
        // Create 205 symbols that all need data (> maxSyncCount of 200)
        final allSymbols = List.generate(
          205,
          (i) => 'S${i.toString().padLeft(3, '0')}',
        );
        final watchlistSymbols = [
          'S200',
          'S201',
          'S202',
        ]; // last 3 are watchlist
        final popularSymbols = ['S203', 'S204']; // and 2 popular

        setupSufficientDataSymbols([]);
        setupPriceHistoryBatch(
          Map.fromEntries(
            allSymbols.map((s) => MapEntry(s, <DailyPriceEntry>[])),
          ),
        );

        // Mock getStocksBatch for market-aware prioritization
        when(() => mockDb.getStocksBatch(any())).thenAnswer(
          (_) async => {
            for (final s in allSymbols)
              s: StockMasterEntry(
                symbol: s,
                name: s,
                market: 'TWSE',
                isActive: true,
                updatedAt: testDate,
              ),
          },
        );

        // Setup sync for all
        for (final symbol in allSymbols) {
          setupSyncSuccess(symbol, count: 1);
        }

        final result = await syncer.syncHistoricalPrices(
          date: testDate,
          watchlistSymbols: watchlistSymbols,
          popularStocks: popularSymbols,
          marketCandidates: allSymbols,
        );

        // Should process exactly 200 (maxSyncCount)
        expect(result.symbolsProcessed, 200);
        expect(result.totalSymbolsNeeded, 205);

        // Watchlist symbols should always be synced
        for (final symbol in watchlistSymbols) {
          verify(
            () => mockPriceRepo.syncStockPrices(
              symbol,
              startDate: any(named: 'startDate'),
              endDate: any(named: 'endDate'),
            ),
          ).called(1);
        }

        // Popular symbols should also be synced
        for (final symbol in popularSymbols) {
          verify(
            () => mockPriceRepo.syncStockPrices(
              symbol,
              startDate: any(named: 'startDate'),
              endDate: any(named: 'endDate'),
            ),
          ).called(1);
        }
      });
    });
  });
}
