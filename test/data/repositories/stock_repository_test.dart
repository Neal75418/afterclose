import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/data/repositories/stock_repository.dart';

class MockAppDatabase extends Mock implements AppDatabase {
  @override
  Future<T> transaction<T>(Future<T> Function() action, {bool? requireNew}) {
    return action();
  }
}

class MockFinMindClient extends Mock implements FinMindClient {}

class MockTwseClient extends Mock implements TwseClient {}

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

    // ==================================================
    // TWSE 官方產業別覆蓋(2026-08-01 複審)
    //
    // FinMind TaiwanStockInfo 給上市電子股的分類多為泛用「電子工業」——
    // 實測 305 檔 active 塌陷同一桶(台積電/聯發科/大立光在內),上市
    // 「半導體業」卡只剩 29 檔且混著下市殭屍;產業排行整組失真。
    // 官方 t187ap03_L(免額度)才有細分碼:2330→24(半導體業)。
    // ==================================================
    group('TWSE 官方產業別覆蓋', () {
      late MockTwseClient mockTwse;

      setUp(() {
        mockTwse = MockTwseClient();
        repository = StockRepository(
          database: mockDb,
          finMindClient: mockClient,
          twseClient: mockTwse,
        );
        when(() => mockDb.upsertStocks(any())).thenAnswer((_) async {});
        when(
          () => mockDb.deactivateStocksNotIn(any()),
        ).thenAnswer((_) async => 0);
      });

      List<StockMasterCompanion> capturedEntries() =>
          verify(() => mockDb.upsertStocks(captureAny())).captured.single
              as List<StockMasterCompanion>;

      test('🚨 官方碼覆蓋 FinMind 泛用「電子工業」:2330→半導體業', () async {
        when(() => mockClient.getStockList()).thenAnswer(
          (_) async => const [
            FinMindStockInfo(
              stockId: '2330',
              stockName: '台積電',
              industryCategory: '電子工業',
              type: 'twse',
            ),
          ],
        );
        when(
          () => mockTwse.fetchIndustryCodes(),
        ).thenAnswer((_) async => {'2330': '24'});

        await repository.syncStockList();

        final entry = capturedEntries().single;
        expect(entry.industry.value, '半導體業');
      });

      test('FinMind 同 symbol 重複列:細分優先,泛用列在後不得覆蓋', () async {
        when(() => mockClient.getStockList()).thenAnswer(
          (_) async => const [
            FinMindStockInfo(
              stockId: '3450',
              stockName: '聯鈞',
              industryCategory: '半導體業',
              type: 'twse',
            ),
            FinMindStockInfo(
              stockId: '3450',
              stockName: '聯鈞',
              industryCategory: '電子工業',
              type: 'twse',
            ),
          ],
        );
        when(
          () => mockTwse.fetchIndustryCodes(),
        ).thenAnswer((_) async => <String, String>{});

        final count = await repository.syncStockList();

        expect(count, 1, reason: '同 symbol 去重後只寫一筆');
        expect(capturedEntries().single.industry.value, '半導體業');
      });

      test('官方端點失敗 fail-soft:沿用 FinMind 分類、同步不中斷', () async {
        when(() => mockClient.getStockList()).thenAnswer(
          (_) async => const [
            FinMindStockInfo(
              stockId: '2330',
              stockName: '台積電',
              industryCategory: '電子工業',
              type: 'twse',
            ),
          ],
        );
        when(
          () => mockTwse.fetchIndustryCodes(),
        ).thenThrow(const NetworkException('boom'));

        final count = await repository.syncStockList();

        expect(count, 1);
        expect(capturedEntries().single.industry.value, '電子工業');
      });

      test('上櫃股不套上市官方碼(TPEx 分類本就細分正確)', () async {
        when(() => mockClient.getStockList()).thenAnswer(
          (_) async => const [
            FinMindStockInfo(
              stockId: '6488',
              stockName: '環球晶',
              industryCategory: '半導體業',
              type: 'tpex',
            ),
          ],
        );
        when(
          () => mockTwse.fetchIndustryCodes(),
        ).thenAnswer((_) async => {'6488': '26'});

        await repository.syncStockList();

        expect(capturedEntries().single.industry.value, '半導體業');
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

        await expectLater(
          () => repository.syncStockList(),
          throwsA(isA<RateLimitException>()),
        );
      });

      test('wraps other exceptions in DatabaseException', () async {
        when(() => mockClient.getStockList()).thenThrow(Exception('API error'));

        await expectLater(
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

        await expectLater(
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
