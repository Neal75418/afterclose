import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/data/remote/tpex_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/data/repositories/institutional_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/portfolio_data_builders.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

class MockFinMindClient extends Mock implements FinMindClient {}

class MockTwseClient extends Mock implements TwseClient {}

class MockTpexClient extends Mock implements TpexClient {}

void main() {
  late MockAppDatabase mockDb;
  late MockFinMindClient mockClient;
  late MockTwseClient mockTwseClient;
  late MockTpexClient mockTpexClient;
  late InstitutionalRepository repo;

  setUp(() {
    mockDb = MockAppDatabase();
    mockClient = MockFinMindClient();
    mockTwseClient = MockTwseClient();
    mockTpexClient = MockTpexClient();
    repo = InstitutionalRepository(
      database: mockDb,
      finMindClient: mockClient,
      twseClient: mockTwseClient,
      tpexClient: mockTpexClient,
    );
  });

  /// Helper: create a DailyInstitutionalEntry
  DailyInstitutionalEntry createInstEntry({
    required String symbol,
    required DateTime date,
    double foreignNet = 100.0,
    double investmentTrustNet = 50.0,
    double dealerNet = 30.0,
  }) {
    return DailyInstitutionalEntry(
      symbol: symbol,
      date: date,
      foreignNet: foreignNet,
      investmentTrustNet: investmentTrustNet,
      dealerNet: dealerNet,
    );
  }

  // ==========================================
  // syncInstitutionalData
  // ==========================================
  group('syncInstitutionalData', () {
    test('success — inserts data and returns count', () async {
      final startDate = DateTime(2025, 1, 1);
      when(
        () => mockClient.getInstitutionalData(
          stockId: any(named: 'stockId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer(
        (_) async => [
          const FinMindInstitutional(
            stockId: '2330',
            date: '2025-01-15',
            foreignBuy: 1000,
            foreignSell: 500,
            investmentTrustBuy: 200,
            investmentTrustSell: 100,
            dealerBuy: 50,
            dealerSell: 30,
          ),
        ],
      );
      when(
        () => mockDb.insertInstitutionalData(any()),
      ).thenAnswer((_) async {});

      final result = await repo.syncInstitutionalData(
        '2330',
        startDate: startDate,
      );

      expect(result, equals(1));
      verify(() => mockDb.insertInstitutionalData(any())).called(1);
    });

    test('rethrows RateLimitException', () async {
      when(
        () => mockClient.getInstitutionalData(
          stockId: any(named: 'stockId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenThrow(const RateLimitException('Rate limited'));

      expect(
        () =>
            repo.syncInstitutionalData('2330', startDate: DateTime(2025, 1, 1)),
        throwsA(isA<RateLimitException>()),
      );
    });

    test('wraps other exceptions in DatabaseException', () async {
      when(
        () => mockClient.getInstitutionalData(
          stockId: any(named: 'stockId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenThrow(Exception('unknown error'));

      expect(
        () =>
            repo.syncInstitutionalData('2330', startDate: DateTime(2025, 1, 1)),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  // ==========================================
  // syncAllMarketInstitutional
  // ==========================================
  group('syncAllMarketInstitutional', () {
    test('skips when freshness threshold met', () async {
      final date = DateTime(2025, 1, 15);
      when(
        () => mockDb.getInstitutionalCountForDate(any()),
      ).thenAnswer((_) async => 2000);

      final result = await repo.syncAllMarketInstitutional(date);

      expect(result, equals(2000));
      verifyNever(
        () => mockTwseClient.getAllInstitutionalData(date: any(named: 'date')),
      );
    });

    test('fetches TWSE and TPEX data when not fresh', () async {
      final date = DateTime(2025, 1, 15);
      when(
        () => mockDb.getInstitutionalCountForDate(any()),
      ).thenAnswer((_) async => 0);
      when(
        () => mockTwseClient.getAllInstitutionalData(date: any(named: 'date')),
      ).thenAnswer(
        (_) async => [
          TwseInstitutional(
            date: date,
            code: '2330',
            name: '台積電',
            foreignBuy: 1000,
            foreignSell: 500,
            foreignNet: 500,
            investmentTrustBuy: 200,
            investmentTrustSell: 100,
            investmentTrustNet: 100,
            dealerBuy: 50,
            dealerSell: 30,
            dealerNet: 20,
            totalNet: 620,
          ),
        ],
      );
      when(
        () => mockTpexClient.getAllInstitutionalData(date: any(named: 'date')),
      ).thenAnswer((_) async => <TpexInstitutional>[]);
      when(() => mockDb.getAllActiveStocks()).thenAnswer(
        (_) async => [
          createTestStockMaster(symbol: '2330', name: '台積電', market: 'TWSE'),
        ],
      );
      when(
        () => mockDb.insertInstitutionalData(any()),
      ).thenAnswer((_) async {});

      final result = await repo.syncAllMarketInstitutional(date);

      expect(result, equals(1));
    });

    test('filters out invalid symbols not in stock master', () async {
      final date = DateTime(2025, 1, 15);
      when(
        () => mockDb.getInstitutionalCountForDate(any()),
      ).thenAnswer((_) async => 0);
      when(
        () => mockTwseClient.getAllInstitutionalData(date: any(named: 'date')),
      ).thenAnswer(
        (_) async => [
          TwseInstitutional(
            date: date,
            code: '9999',
            name: '不存在',
            foreignBuy: 100,
            foreignSell: 50,
            foreignNet: 50,
            investmentTrustBuy: 0,
            investmentTrustSell: 0,
            investmentTrustNet: 0,
            dealerBuy: 0,
            dealerSell: 0,
            dealerNet: 0,
            totalNet: 50,
          ),
        ],
      );
      when(
        () => mockTpexClient.getAllInstitutionalData(date: any(named: 'date')),
      ).thenAnswer((_) async => <TpexInstitutional>[]);
      when(
        () => mockDb.getAllActiveStocks(),
      ).thenAnswer((_) async => <StockMasterEntry>[]);
      when(
        () => mockDb.insertInstitutionalData(any()),
      ).thenAnswer((_) async {});

      final result = await repo.syncAllMarketInstitutional(date);

      // 9999 not in stock master → filtered out
      expect(result, equals(0));
    });
  });

  // ==========================================
  // hasDirectionReversal
  // ==========================================
  group('hasDirectionReversal', () {
    test('returns false when insufficient data', () async {
      when(
        () => mockDb.getInstitutionalHistory(
          any(),
          startDate: any(named: 'startDate'),
        ),
      ).thenAnswer((_) async => []);

      final result = await repo.hasDirectionReversal('2330');

      expect(result, isFalse);
    });

    test('returns true for positive→negative reversal', () async {
      // Recent: net negative, Previous: net positive
      final now = DateTime.now();
      final entries = <DailyInstitutionalEntry>[];

      // Previous period (days 10-6): positive net
      for (int i = 10; i >= 6; i--) {
        entries.add(
          createInstEntry(
            symbol: '2330',
            date: now.subtract(Duration(days: i)),
            foreignNet: 100,
            investmentTrustNet: 50,
            dealerNet: 30,
          ),
        );
      }
      // Recent period (days 5-1): negative net
      for (int i = 5; i >= 1; i--) {
        entries.add(
          createInstEntry(
            symbol: '2330',
            date: now.subtract(Duration(days: i)),
            foreignNet: -100,
            investmentTrustNet: -50,
            dealerNet: -30,
          ),
        );
      }

      when(
        () => mockDb.getInstitutionalHistory(
          any(),
          startDate: any(named: 'startDate'),
        ),
      ).thenAnswer((_) async => entries);

      final result = await repo.hasDirectionReversal('2330');

      expect(result, isTrue);
    });

    test('returns true for negative→positive reversal', () async {
      final now = DateTime.now();
      final entries = <DailyInstitutionalEntry>[];

      // Previous period: negative
      for (int i = 10; i >= 6; i--) {
        entries.add(
          createInstEntry(
            symbol: '2330',
            date: now.subtract(Duration(days: i)),
            foreignNet: -100,
            investmentTrustNet: -50,
            dealerNet: -30,
          ),
        );
      }
      // Recent period: positive
      for (int i = 5; i >= 1; i--) {
        entries.add(
          createInstEntry(
            symbol: '2330',
            date: now.subtract(Duration(days: i)),
            foreignNet: 100,
            investmentTrustNet: 50,
            dealerNet: 30,
          ),
        );
      }

      when(
        () => mockDb.getInstitutionalHistory(
          any(),
          startDate: any(named: 'startDate'),
        ),
      ).thenAnswer((_) async => entries);

      final result = await repo.hasDirectionReversal('2330');

      expect(result, isTrue);
    });

    test('returns false when same direction', () async {
      final now = DateTime.now();
      final entries = <DailyInstitutionalEntry>[];

      // Both periods: positive
      for (int i = 10; i >= 1; i--) {
        entries.add(
          createInstEntry(
            symbol: '2330',
            date: now.subtract(Duration(days: i)),
            foreignNet: 100,
            investmentTrustNet: 50,
            dealerNet: 30,
          ),
        );
      }

      when(
        () => mockDb.getInstitutionalHistory(
          any(),
          startDate: any(named: 'startDate'),
        ),
      ).thenAnswer((_) async => entries);

      final result = await repo.hasDirectionReversal('2330');

      expect(result, isFalse);
    });
  });

  // ==========================================
  // getTotalNetBuying
  // ==========================================
  group('getTotalNetBuying', () {
    test('returns null when history is empty', () async {
      when(
        () => mockDb.getInstitutionalHistory(
          any(),
          startDate: any(named: 'startDate'),
        ),
      ).thenAnswer((_) async => []);

      final result = await repo.getTotalNetBuying('2330');

      expect(result, isNull);
    });

    test('sums all net buying for recent days', () async {
      final now = DateTime.now();
      final entries = [
        createInstEntry(
          symbol: '2330',
          date: now.subtract(const Duration(days: 2)),
          foreignNet: 100,
          investmentTrustNet: 50,
          dealerNet: 30,
        ),
        createInstEntry(
          symbol: '2330',
          date: now.subtract(const Duration(days: 1)),
          foreignNet: 200,
          investmentTrustNet: -50,
          dealerNet: 10,
        ),
      ];

      when(
        () => mockDb.getInstitutionalHistory(
          any(),
          startDate: any(named: 'startDate'),
        ),
      ).thenAnswer((_) async => entries);

      final result = await repo.getTotalNetBuying('2330', days: 5);

      // Entry 1: 100+50+30 = 180, Entry 2: 200+(-50)+10 = 160
      // Total: 340
      expect(result, equals(340.0));
    });
  });

  // ==========================================
  // clearAllData
  // ==========================================
  group('clearAllData', () {
    test('delegates to database', () async {
      when(
        () => mockDb.clearAllInstitutionalData(),
      ).thenAnswer((_) async => 42);

      final result = await repo.clearAllData();

      expect(result, equals(42));
      verify(() => mockDb.clearAllInstitutionalData()).called(1);
    });
  });
}
