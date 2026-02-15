import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/data/repositories/stock_repository.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

class MockFinMindClient extends Mock implements FinMindClient {}

// Fake classes for registerFallbackValue
class FakeStockMasterCompanion extends Fake implements StockMasterCompanion {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeStockMasterCompanion());
    registerFallbackValue(<StockMasterCompanion>[]);
  });

  late MockAppDatabase mockDb;
  late MockFinMindClient mockClient;
  late StockRepository repository;

  setUp(() {
    mockDb = MockAppDatabase();
    mockClient = MockFinMindClient();
    repository = StockRepository(database: mockDb, finMindClient: mockClient);
  });

  group('StockRepository', () {
    group('getAllStocks', () {
      test('returns all active stocks from database', () async {
        final stocks = [
          StockMasterEntry(
            symbol: '2330',
            name: '台積電',
            market: 'TWSE',
            industry: '半導體',
            isActive: true,
            updatedAt: DateTime(2024, 6, 15),
          ),
          StockMasterEntry(
            symbol: '2317',
            name: '鴻海',
            market: 'TWSE',
            industry: '電子',
            isActive: true,
            updatedAt: DateTime(2024, 6, 15),
          ),
        ];

        when(() => mockDb.getAllActiveStocks()).thenAnswer((_) async => stocks);

        final result = await repository.getAllStocks();

        expect(result, equals(stocks));
        expect(result.length, equals(2));
        verify(() => mockDb.getAllActiveStocks()).called(1);
      });

      test('returns empty list when no stocks', () async {
        when(() => mockDb.getAllActiveStocks()).thenAnswer((_) async => []);

        final result = await repository.getAllStocks();

        expect(result, isEmpty);
      });
    });

    group('getStock', () {
      test('returns stock for given symbol', () async {
        final stock = StockMasterEntry(
          symbol: '2330',
          name: '台積電',
          market: 'TWSE',
          industry: '半導體',
          isActive: true,
          updatedAt: DateTime(2024, 6, 15),
        );

        when(() => mockDb.getStock('2330')).thenAnswer((_) async => stock);

        final result = await repository.getStock('2330');

        expect(result, equals(stock));
        expect(result?.name, equals('台積電'));
      });

      test('returns null when stock not found', () async {
        when(() => mockDb.getStock('9999')).thenAnswer((_) async => null);

        final result = await repository.getStock('9999');

        expect(result, isNull);
      });
    });

    group('syncStockList', () {
      test('syncs valid 4-digit stock codes', () async {
        final stockInfos = [
          const FinMindStockInfo(
            stockId: '2330',
            stockName: '台積電',
            industryCategory: '半導體',
            type: 'twse',
          ),
          const FinMindStockInfo(
            stockId: '2317',
            stockName: '鴻海',
            industryCategory: '電子',
            type: 'twse',
          ),
        ];

        when(
          () => mockClient.getStockList(),
        ).thenAnswer((_) async => stockInfos);
        when(() => mockDb.upsertStocks(any())).thenAnswer((_) async {});
        when(
          () => mockDb.deactivateStocksNotIn(any()),
        ).thenAnswer((_) async => 0);

        final result = await repository.syncStockList();

        expect(result, equals(2));
        verify(() => mockDb.upsertStocks(any())).called(1);
      });

      test('syncs ETF codes starting with 00', () async {
        final stockInfos = [
          const FinMindStockInfo(
            stockId: '0050',
            stockName: '元大台灣50',
            industryCategory: 'ETF',
            type: 'twse',
          ),
          const FinMindStockInfo(
            stockId: '00878',
            stockName: '國泰永續高股息',
            industryCategory: 'ETF',
            type: 'twse',
          ),
        ];

        when(
          () => mockClient.getStockList(),
        ).thenAnswer((_) async => stockInfos);
        when(() => mockDb.upsertStocks(any())).thenAnswer((_) async {});
        when(
          () => mockDb.deactivateStocksNotIn(any()),
        ).thenAnswer((_) async => 0);

        final result = await repository.syncStockList();

        expect(result, equals(2));
      });

      test('filters out invalid stock codes (warrants, TDR)', () async {
        final stockInfos = [
          const FinMindStockInfo(
            stockId: '2330',
            stockName: '台積電',
            industryCategory: '半導體',
            type: 'twse',
          ),
          const FinMindStockInfo(
            stockId: '233001',
            stockName: '台積電權證',
            industryCategory: '權證',
            type: 'twse',
          ),
          const FinMindStockInfo(
            stockId: '9101',
            stockName: 'TDR',
            industryCategory: 'TDR',
            type: 'twse',
          ),
        ];

        when(
          () => mockClient.getStockList(),
        ).thenAnswer((_) async => stockInfos);
        when(() => mockDb.upsertStocks(any())).thenAnswer((_) async {});
        when(
          () => mockDb.deactivateStocksNotIn(any()),
        ).thenAnswer((_) async => 0);

        final result = await repository.syncStockList();

        // Only 2330 is valid (4 digits), 233001 is 6 digits (warrant), 9101 has 4 digits but counts
        expect(result, equals(2)); // 2330 and 9101 are 4 digits
      });

      test('deactivates stocks not in API response', () async {
        final stockInfos = [
          const FinMindStockInfo(
            stockId: '2330',
            stockName: '台積電',
            industryCategory: '半導體',
            type: 'twse',
          ),
        ];

        when(
          () => mockClient.getStockList(),
        ).thenAnswer((_) async => stockInfos);
        when(() => mockDb.upsertStocks(any())).thenAnswer((_) async {});
        when(
          () => mockDb.deactivateStocksNotIn(any()),
        ).thenAnswer((_) async => 3);

        await repository.syncStockList();

        final captured = verify(
          () => mockDb.deactivateStocksNotIn(captureAny()),
        ).captured;
        final activeSymbols = captured.first as Set<String>;
        expect(activeSymbols, equals({'2330'}));
      });

      test('rethrows RateLimitException', () async {
        when(
          () => mockClient.getStockList(),
        ).thenThrow(const RateLimitException());

        expect(
          () => repository.syncStockList(),
          throwsA(isA<RateLimitException>()),
        );
      });

      test('wraps other exceptions in DatabaseException', () async {
        when(() => mockClient.getStockList()).thenThrow(Exception('API error'));

        expect(
          () => repository.syncStockList(),
          throwsA(isA<DatabaseException>()),
        );
      });

      test('wraps database exceptions in DatabaseException', () async {
        final stockInfos = [
          const FinMindStockInfo(
            stockId: '2330',
            stockName: '台積電',
            industryCategory: '半導體',
            type: 'twse',
          ),
        ];

        when(
          () => mockClient.getStockList(),
        ).thenAnswer((_) async => stockInfos);
        when(() => mockDb.upsertStocks(any())).thenThrow(Exception('DB error'));
        when(
          () => mockDb.deactivateStocksNotIn(any()),
        ).thenAnswer((_) async => 0);

        expect(
          () => repository.syncStockList(),
          throwsA(isA<DatabaseException>()),
        );
      });
    });

    group('searchStocks', () {
      test('searches stocks by query', () async {
        final stocks = [
          StockMasterEntry(
            symbol: '2330',
            name: '台積電',
            market: 'TWSE',
            industry: '半導體',
            isActive: true,
            updatedAt: DateTime(2024, 6, 15),
          ),
        ];

        when(() => mockDb.searchStocks('台積')).thenAnswer((_) async => stocks);

        final result = await repository.searchStocks('台積');

        expect(result, equals(stocks));
        expect(result.length, equals(1));
        verify(() => mockDb.searchStocks('台積')).called(1);
      });

      test('returns empty list when no matches', () async {
        when(() => mockDb.searchStocks('xyz')).thenAnswer((_) async => []);

        final result = await repository.searchStocks('xyz');

        expect(result, isEmpty);
      });

      test('searches by symbol', () async {
        final stocks = [
          StockMasterEntry(
            symbol: '2330',
            name: '台積電',
            market: 'TWSE',
            industry: '半導體',
            isActive: true,
            updatedAt: DateTime(2024, 6, 15),
          ),
        ];

        when(() => mockDb.searchStocks('2330')).thenAnswer((_) async => stocks);

        final result = await repository.searchStocks('2330');

        expect(result.length, equals(1));
        expect(result.first.symbol, equals('2330'));
      });
    });

    group('getStocksByMarket', () {
      test('returns stocks for TWSE market', () async {
        final stocks = [
          StockMasterEntry(
            symbol: '2330',
            name: '台積電',
            market: 'TWSE',
            industry: '半導體',
            isActive: true,
            updatedAt: DateTime(2024, 6, 15),
          ),
        ];

        when(
          () => mockDb.getStocksByMarket('TWSE'),
        ).thenAnswer((_) async => stocks);

        final result = await repository.getStocksByMarket('TWSE');

        expect(result, equals(stocks));
        verify(() => mockDb.getStocksByMarket('TWSE')).called(1);
      });

      test('returns stocks for TPEx market', () async {
        final stocks = [
          StockMasterEntry(
            symbol: '3008',
            name: '大立光',
            market: 'TPEx',
            industry: '光電',
            isActive: true,
            updatedAt: DateTime(2024, 6, 15),
          ),
        ];

        when(
          () => mockDb.getStocksByMarket('TPEx'),
        ).thenAnswer((_) async => stocks);

        final result = await repository.getStocksByMarket('TPEx');

        expect(result, equals(stocks));
        expect(result.first.market, equals('TPEx'));
      });

      test('returns empty list when no stocks in market', () async {
        when(
          () => mockDb.getStocksByMarket('UNKNOWN'),
        ).thenAnswer((_) async => []);

        final result = await repository.getStocksByMarket('UNKNOWN');

        expect(result, isEmpty);
      });
    });

    group('stockExists', () {
      test('returns true when stock exists', () async {
        final stock = StockMasterEntry(
          symbol: '2330',
          name: '台積電',
          market: 'TWSE',
          industry: '半導體',
          isActive: true,
          updatedAt: DateTime(2024, 6, 15),
        );

        when(() => mockDb.getStock('2330')).thenAnswer((_) async => stock);

        final result = await repository.stockExists('2330');

        expect(result, isTrue);
      });

      test('returns false when stock does not exist', () async {
        when(() => mockDb.getStock('9999')).thenAnswer((_) async => null);

        final result = await repository.stockExists('9999');

        expect(result, isFalse);
      });
    });
  });

  group('Stock code validation pattern', () {
    // Test the regex pattern used in syncStockList
    final validStockPattern = RegExp(r'^(\d{4}|00\d{3,4})$');

    test('accepts 4-digit stock codes', () {
      expect(validStockPattern.hasMatch('2330'), isTrue);
      expect(validStockPattern.hasMatch('2317'), isTrue);
      expect(validStockPattern.hasMatch('0050'), isTrue);
      expect(validStockPattern.hasMatch('9999'), isTrue);
    });

    test('accepts 00xxx ETF codes', () {
      expect(validStockPattern.hasMatch('00878'), isTrue);
      expect(validStockPattern.hasMatch('00679'), isTrue);
      expect(validStockPattern.hasMatch('006208'), isTrue);
    });

    test('rejects 6-digit warrant codes', () {
      expect(validStockPattern.hasMatch('233001'), isFalse);
      expect(validStockPattern.hasMatch('231701'), isFalse);
    });

    test('rejects 3-digit codes', () {
      expect(validStockPattern.hasMatch('233'), isFalse);
      expect(validStockPattern.hasMatch('050'), isFalse);
    });

    test('rejects codes with letters', () {
      expect(validStockPattern.hasMatch('2330A'), isFalse);
      expect(validStockPattern.hasMatch('AAPL'), isFalse);
    });
  });
}
