import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/data/remote/tpex_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/data/repositories/price_repository.dart';
import 'package:afterclose/domain/repositories/price_repository.dart';

// Mocks
class MockAppDatabase extends Mock implements AppDatabase {}

class MockFinMindClient extends Mock implements FinMindClient {}

class MockTwseClient extends Mock implements TwseClient {}

class MockTpexClient extends Mock implements TpexClient {}

void main() {
  late MockAppDatabase mockDb;
  late MockFinMindClient mockFinMindClient;
  late MockTwseClient mockTwseClient;
  late MockTpexClient mockTpexClient;
  late PriceRepository repository;

  setUp(() {
    mockDb = MockAppDatabase();
    mockFinMindClient = MockFinMindClient();
    mockTwseClient = MockTwseClient();
    mockTpexClient = MockTpexClient();

    repository = PriceRepository(
      database: mockDb,
      finMindClient: mockFinMindClient,
      twseClient: mockTwseClient,
      tpexClient: mockTpexClient,
    );
  });

  group('PriceRepository', () {
    group('getPriceHistory', () {
      test('calls database with correct parameters', () async {
        when(
          () => mockDb.getPriceHistory(
            any(),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenAnswer((_) async => []);

        await repository.getPriceHistory('2330', days: 30);

        verify(
          () => mockDb.getPriceHistory(
            '2330',
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).called(1);
      });

      test('returns price entries from database', () async {
        final mockEntries = [
          DailyPriceEntry(
            symbol: '2330',
            date: DateTime(2024, 6, 14),
            open: 500.0,
            high: 510.0,
            low: 495.0,
            close: 505.0,
            volume: 20000000,
          ),
          DailyPriceEntry(
            symbol: '2330',
            date: DateTime(2024, 6, 15),
            open: 505.0,
            high: 520.0,
            low: 500.0,
            close: 515.0,
            volume: 25000000,
          ),
        ];

        when(
          () => mockDb.getPriceHistory(
            any(),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenAnswer((_) async => mockEntries);

        final result = await repository.getPriceHistory('2330');

        expect(result.length, equals(2));
        expect(result.first.symbol, equals('2330'));
        expect(result.last.close, equals(515.0));
      });
    });

    group('getLatestPrice', () {
      test('returns latest price from database', () async {
        final mockEntry = DailyPriceEntry(
          symbol: '2330',
          date: DateTime(2024, 6, 15),
          open: 505.0,
          high: 520.0,
          low: 500.0,
          close: 515.0,
          volume: 25000000,
        );

        when(
          () => mockDb.getLatestPrice(any()),
        ).thenAnswer((_) async => mockEntry);

        final result = await repository.getLatestPrice('2330');

        expect(result, isNotNull);
        expect(result!.close, equals(515.0));
      });

      test('returns null when no price data', () async {
        when(() => mockDb.getLatestPrice(any())).thenAnswer((_) async => null);

        final result = await repository.getLatestPrice('2330');

        expect(result, isNull);
      });
    });

    group('getPriceChange', () {
      test('calculates price change correctly', () async {
        final mockEntries = [
          DailyPriceEntry(
            symbol: '2330',
            date: DateTime(2024, 6, 14),
            open: 500.0,
            high: 510.0,
            low: 495.0,
            close: 500.0, // Yesterday
            volume: 20000000,
          ),
          DailyPriceEntry(
            symbol: '2330',
            date: DateTime(2024, 6, 15),
            open: 505.0,
            high: 520.0,
            low: 500.0,
            close: 510.0, // Today
            volume: 25000000,
          ),
        ];

        when(
          () => mockDb.getPriceHistory(
            any(),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenAnswer((_) async => mockEntries);

        final result = await repository.getPriceChange('2330');

        // (510 - 500) / 500 * 100 = 2%
        expect(result, equals(2.0));
      });

      test('returns null when insufficient data', () async {
        when(
          () => mockDb.getPriceHistory(
            any(),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenAnswer((_) async => []);

        final result = await repository.getPriceChange('2330');

        expect(result, isNull);
      });

      test('returns null when close price is null', () async {
        final mockEntries = [
          DailyPriceEntry(
            symbol: '2330',
            date: DateTime(2024, 6, 14),
            open: 500.0,
            high: 510.0,
            low: 495.0,
            close: null,
            volume: 20000000,
          ),
          DailyPriceEntry(
            symbol: '2330',
            date: DateTime(2024, 6, 15),
            open: 505.0,
            high: 520.0,
            low: 500.0,
            close: 510.0,
            volume: 25000000,
          ),
        ];

        when(
          () => mockDb.getPriceHistory(
            any(),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenAnswer((_) async => mockEntries);

        final result = await repository.getPriceChange('2330');

        expect(result, isNull);
      });

      test('returns null when yesterday close is zero', () async {
        final mockEntries = [
          DailyPriceEntry(
            symbol: '2330',
            date: DateTime(2024, 6, 14),
            open: 0.0,
            high: 0.0,
            low: 0.0,
            close: 0.0,
            volume: 0,
          ),
          DailyPriceEntry(
            symbol: '2330',
            date: DateTime(2024, 6, 15),
            open: 505.0,
            high: 520.0,
            low: 500.0,
            close: 510.0,
            volume: 25000000,
          ),
        ];

        when(
          () => mockDb.getPriceHistory(
            any(),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenAnswer((_) async => mockEntries);

        final result = await repository.getPriceChange('2330');

        expect(result, isNull);
      });
    });

    group('getVolumeMA20', () {
      test('calculates 20-day volume MA correctly', () async {
        // Generate 25 days of price data
        final mockEntries = List.generate(
          25,
          (i) => DailyPriceEntry(
            symbol: '2330',
            date: DateTime(2024, 6, 1).add(Duration(days: i)),
            open: 500.0,
            high: 510.0,
            low: 495.0,
            close: 505.0,
            volume: 1000000.0 + i * 10000, // Varying volume
          ),
        );

        when(
          () => mockDb.getPriceHistory(
            any(),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenAnswer((_) async => mockEntries);

        final result = await repository.getVolumeMA20('2330');

        expect(result, isNotNull);
        // Should be average of last 20 volumes
        expect(result, greaterThan(0));
      });

      test('returns null when insufficient data', () async {
        // Only 10 days of data
        final mockEntries = List.generate(
          10,
          (i) => DailyPriceEntry(
            symbol: '2330',
            date: DateTime(2024, 6, 1).add(Duration(days: i)),
            open: 500.0,
            high: 510.0,
            low: 495.0,
            close: 505.0,
            volume: 1000000,
          ),
        );

        when(
          () => mockDb.getPriceHistory(
            any(),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenAnswer((_) async => mockEntries);

        final result = await repository.getVolumeMA20('2330');

        expect(result, isNull);
      });
    });

    group('syncAllPricesForDate', () {
      test('skips sync when existing data exceeds threshold', () async {
        when(
          () => mockDb.getPriceCountForDate(any()),
        ).thenAnswer((_) async => 1600);
        when(() => mockDb.getPricesForDate(any())).thenAnswer((_) async => []);

        final result = await repository.syncAllPricesForDate(DateTime.now());

        expect(result.skipped, isTrue);
        verifyNever(() => mockTwseClient.getAllDailyPrices());
      });

      test('forces refresh when force is true', () async {
        when(
          () => mockDb.getPriceCountForDate(any()),
        ).thenAnswer((_) async => 1600);
        when(
          () => mockTwseClient.getAllDailyPrices(),
        ).thenAnswer((_) async => []);
        when(
          () => mockTpexClient.getAllDailyPrices(),
        ).thenAnswer((_) async => []);

        final result = await repository.syncAllPricesForDate(
          DateTime.now(),
          force: true,
        );

        expect(result.count, equals(0));
        verify(() => mockTwseClient.getAllDailyPrices()).called(1);
      });

      test('syncs from TWSE and TPEX APIs', () async {
        when(
          () => mockDb.getPriceCountForDate(any()),
        ).thenAnswer((_) async => 0);

        final twsePrices = [
          TwseDailyPrice(
            code: '2330',
            name: '台積電',
            date: DateTime(2024, 6, 15),
            open: 500.0,
            high: 510.0,
            low: 495.0,
            close: 505.0,
            change: 5.0,
            volume: 20000000,
          ),
        ];

        final tpexPrices = [
          TpexDailyPrice(
            code: '6533',
            name: '晶心科',
            date: DateTime(2024, 6, 15),
            open: 100.0,
            high: 105.0,
            low: 98.0,
            close: 103.0,
            change: 3.0,
            volume: 5000000,
          ),
        ];

        when(
          () => mockTwseClient.getAllDailyPrices(),
        ).thenAnswer((_) async => twsePrices);
        when(
          () => mockTpexClient.getAllDailyPrices(),
        ).thenAnswer((_) async => tpexPrices);
        when(() => mockDb.upsertStocks(any())).thenAnswer((_) async {});
        when(() => mockDb.insertPrices(any())).thenAnswer((_) async {});

        final result = await repository.syncAllPricesForDate(
          DateTime(2024, 6, 15),
        );

        expect(result.count, equals(2));
        expect(result.candidates, isNotEmpty);
        verify(() => mockDb.insertPrices(any())).called(1);
      });

      test('returns empty result when both APIs fail', () async {
        when(
          () => mockDb.getPriceCountForDate(any()),
        ).thenAnswer((_) async => 0);
        when(() => mockTwseClient.getAllDailyPrices()).thenAnswer((_) async {
          throw Exception('API Error');
        });
        when(() => mockTpexClient.getAllDailyPrices()).thenAnswer((_) async {
          throw Exception('API Error');
        });

        final result = await repository.syncAllPricesForDate(DateTime.now());

        expect(result.count, equals(0));
        expect(result.candidates, isEmpty);
      });

      test('continues when one API fails', () async {
        when(
          () => mockDb.getPriceCountForDate(any()),
        ).thenAnswer((_) async => 0);

        final twsePrices = [
          TwseDailyPrice(
            code: '2330',
            name: '台積電',
            date: DateTime(2024, 6, 15),
            open: 500.0,
            high: 510.0,
            low: 495.0,
            close: 505.0,
            change: 5.0,
            volume: 20000000,
          ),
        ];

        when(
          () => mockTwseClient.getAllDailyPrices(),
        ).thenAnswer((_) async => twsePrices);
        when(() => mockTpexClient.getAllDailyPrices()).thenAnswer((_) async {
          throw Exception('TPEX Error');
        });
        when(() => mockDb.upsertStocks(any())).thenAnswer((_) async {});
        when(() => mockDb.insertPrices(any())).thenAnswer((_) async {});

        final result = await repository.syncAllPricesForDate(
          DateTime(2024, 6, 15),
        );

        expect(result.count, equals(1));
      });
    });

    group('syncTodayPrices', () {
      test('delegates to syncAllPricesForDate', () async {
        when(
          () => mockDb.getPriceCountForDate(any()),
        ).thenAnswer((_) async => 1600);
        when(() => mockDb.getPricesForDate(any())).thenAnswer((_) async => []);

        final result = await repository.syncTodayPrices();

        expect(result.skipped, isTrue);
      });
    });

    group('syncStockPrices', () {
      test('skips when all months have sufficient data', () async {
        // Generate sufficient data for 2 months
        final mockEntries = List.generate(
          50,
          (i) => DailyPriceEntry(
            symbol: '2330',
            date: DateTime(2024, 5, 1).add(Duration(days: i)),
            open: 500.0,
            high: 510.0,
            low: 495.0,
            close: 505.0,
            volume: 20000000,
          ),
        );

        when(
          () => mockDb.getPriceHistory(
            any(),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenAnswer((_) async => mockEntries);

        final result = await repository.syncStockPrices(
          '2330',
          startDate: DateTime(2024, 5, 1),
          endDate: DateTime(2024, 6, 15),
        );

        expect(result, equals(0));
        verifyNever(
          () => mockTwseClient.getStockMonthlyPrices(
            code: any(named: 'code'),
            year: any(named: 'year'),
            month: any(named: 'month'),
          ),
        );
      });

      test('uses FinMind for OTC stocks', () async {
        when(
          () => mockDb.getPriceHistory(
            any(),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenAnswer((_) async => []);
        when(() => mockDb.getStock(any())).thenAnswer(
          (_) async => StockMasterEntry(
            symbol: '6533',
            name: '晶心科',
            market: 'TPEx',
            isActive: true,
            updatedAt: DateTime(2024, 6, 15),
          ),
        );
        when(
          () => mockFinMindClient.getDailyPrices(
            stockId: any(named: 'stockId'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenAnswer((_) async => []);

        await repository.syncStockPrices(
          '6533',
          startDate: DateTime(2024, 5, 1),
        );

        verify(
          () => mockFinMindClient.getDailyPrices(
            stockId: '6533',
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).called(1);
      });

      test('throws DatabaseException on error', () async {
        when(
          () => mockDb.getPriceHistory(
            any(),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenThrow(Exception('DB Error'));

        expect(
          () => repository.syncStockPrices(
            '2330',
            startDate: DateTime(2024, 5, 1),
          ),
          throwsA(isA<DatabaseException>()),
        );
      });
    });

    group('getPriceChangesBatch', () {
      test('returns batch price changes correctly', () async {
        final priceHistories = {
          '2330': [
            DailyPriceEntry(
              symbol: '2330',
              date: DateTime(2024, 6, 14),
              open: 500.0,
              high: 510.0,
              low: 495.0,
              close: 500.0,
              volume: 20000000,
            ),
            DailyPriceEntry(
              symbol: '2330',
              date: DateTime(2024, 6, 15),
              open: 505.0,
              high: 520.0,
              low: 500.0,
              close: 510.0, // +2%
              volume: 25000000,
            ),
          ],
          '2317': [
            DailyPriceEntry(
              symbol: '2317',
              date: DateTime(2024, 6, 14),
              open: 100.0,
              high: 102.0,
              low: 99.0,
              close: 100.0,
              volume: 10000000,
            ),
            DailyPriceEntry(
              symbol: '2317',
              date: DateTime(2024, 6, 15),
              open: 99.0,
              high: 100.0,
              low: 97.0,
              close: 97.0, // -3%
              volume: 15000000,
            ),
          ],
        };

        when(
          () => mockDb.getPriceHistoryBatch(
            any(),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenAnswer((_) async => priceHistories);

        final result = await repository.getPriceChangesBatch(['2330', '2317']);

        expect(result['2330'], equals(2.0));
        expect(result['2317'], equals(-3.0));
      });

      test('returns empty map for empty symbols', () async {
        final result = await repository.getPriceChangesBatch([]);

        expect(result, isEmpty);
      });

      test('handles missing data gracefully', () async {
        final priceHistories = <String, List<DailyPriceEntry>>{
          '2330': [], // No data
        };

        when(
          () => mockDb.getPriceHistoryBatch(
            any(),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenAnswer((_) async => priceHistories);

        final result = await repository.getPriceChangesBatch(['2330']);

        expect(result['2330'], isNull);
      });

      test('throws DatabaseException on error', () async {
        when(
          () => mockDb.getPriceHistoryBatch(
            any(),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenThrow(Exception('DB Error'));

        expect(
          () => repository.getPriceChangesBatch(['2330']),
          throwsA(isA<DatabaseException>()),
        );
      });
    });

    group('getVolumeMA20Batch', () {
      test('returns batch volume MA correctly', () async {
        // Generate 25 days of data for each symbol
        final priceHistories = {
          '2330': List.generate(
            25,
            (i) => DailyPriceEntry(
              symbol: '2330',
              date: DateTime(2024, 6, 1).add(Duration(days: i)),
              open: 500.0,
              high: 510.0,
              low: 495.0,
              close: 505.0,
              volume: 1000000.0 + i * 10000,
            ),
          ),
          '2317': List.generate(
            25,
            (i) => DailyPriceEntry(
              symbol: '2317',
              date: DateTime(2024, 6, 1).add(Duration(days: i)),
              open: 100.0,
              high: 102.0,
              low: 99.0,
              close: 101.0,
              volume: 500000.0 + i * 5000,
            ),
          ),
        };

        when(
          () => mockDb.getPriceHistoryBatch(
            any(),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenAnswer((_) async => priceHistories);

        final result = await repository.getVolumeMA20Batch(['2330', '2317']);

        expect(result['2330'], isNotNull);
        expect(result['2317'], isNotNull);
        expect(result['2330'], greaterThan(result['2317']!));
      });

      test('returns empty map for empty symbols', () async {
        final result = await repository.getVolumeMA20Batch([]);

        expect(result, isEmpty);
      });

      test('handles insufficient data', () async {
        final priceHistories = {
          '2330': List.generate(
            10, // Only 10 days, not enough for MA20
            (i) => DailyPriceEntry(
              symbol: '2330',
              date: DateTime(2024, 6, 1).add(Duration(days: i)),
              open: 500.0,
              high: 510.0,
              low: 495.0,
              close: 505.0,
              volume: 1000000,
            ),
          ),
        };

        when(
          () => mockDb.getPriceHistoryBatch(
            any(),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenAnswer((_) async => priceHistories);

        final result = await repository.getVolumeMA20Batch(['2330']);

        expect(result['2330'], isNull);
      });
    });

    group('getSymbolsNeedingUpdate', () {
      test('returns symbols without latest price', () async {
        final latestPrices = {
          '2330': DailyPriceEntry(
            symbol: '2330',
            date: DateTime(2024, 6, 15),
            open: 500.0,
            high: 510.0,
            low: 495.0,
            close: 505.0,
            volume: 20000000,
          ),
          // '2317' is missing - needs update
        };

        when(
          () => mockDb.getLatestPricesBatch(any()),
        ).thenAnswer((_) async => latestPrices);

        final result = await repository.getSymbolsNeedingUpdate([
          '2330',
          '2317',
        ], DateTime(2024, 6, 15));

        expect(result, equals(['2317']));
      });

      test('returns symbols with outdated price', () async {
        final latestPrices = {
          '2330': DailyPriceEntry(
            symbol: '2330',
            date: DateTime(2024, 6, 14), // Yesterday - needs update
            open: 500.0,
            high: 510.0,
            low: 495.0,
            close: 505.0,
            volume: 20000000,
          ),
        };

        when(
          () => mockDb.getLatestPricesBatch(any()),
        ).thenAnswer((_) async => latestPrices);

        final result = await repository.getSymbolsNeedingUpdate([
          '2330',
        ], DateTime(2024, 6, 15));

        expect(result, equals(['2330']));
      });

      test('returns empty for up-to-date symbols', () async {
        final targetDate = DateTime(2024, 6, 15);
        final latestPrices = {
          '2330': DailyPriceEntry(
            symbol: '2330',
            date: targetDate,
            open: 500.0,
            high: 510.0,
            low: 495.0,
            close: 505.0,
            volume: 20000000,
          ),
        };

        when(
          () => mockDb.getLatestPricesBatch(any()),
        ).thenAnswer((_) async => latestPrices);

        final result = await repository.getSymbolsNeedingUpdate([
          '2330',
        ], targetDate);

        expect(result, isEmpty);
      });

      test('returns empty for empty input', () async {
        final result = await repository.getSymbolsNeedingUpdate(
          [],
          DateTime.now(),
        );

        expect(result, isEmpty);
      });
    });

    group('MarketSyncResult', () {
      test('creates with default values', () {
        const result = MarketSyncResult(
          count: 100,
          candidates: ['2330', '2317'],
        );

        expect(result.count, equals(100));
        expect(result.candidates, equals(['2330', '2317']));
        expect(result.skipped, isFalse);
        expect(result.dataDate, isNull);
      });

      test('creates with all values', () {
        final dataDate = DateTime(2024, 6, 15);
        final result = MarketSyncResult(
          count: 100,
          candidates: ['2330'],
          dataDate: dataDate,
          tpexDataDate: dataDate,
          skipped: true,
        );

        expect(result.skipped, isTrue);
        expect(result.dataDate, equals(dataDate));
        expect(result.tpexDataDate, equals(dataDate));
      });
    });
  });
}
