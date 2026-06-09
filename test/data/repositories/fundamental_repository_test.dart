import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/data/remote/tpex_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/data/repositories/fundamental_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

class MockFinMindClient extends Mock implements FinMindClient {}

class MockTwseClient extends Mock implements TwseClient {}

class MockTpexClient extends Mock implements TpexClient {}

void main() {
  late MockAppDatabase mockDb;
  late MockFinMindClient mockFinMind;
  late MockTwseClient mockTwse;
  late MockTpexClient mockTpex;
  late FundamentalRepository repo;

  setUp(() {
    mockDb = MockAppDatabase();
    mockFinMind = MockFinMindClient();
    mockTwse = MockTwseClient();
    mockTpex = MockTpexClient();
    repo = FundamentalRepository(
      db: mockDb,
      finMind: mockFinMind,
      twse: mockTwse,
      tpex: mockTpex,
    );
  });

  // ==========================================
  // syncMonthlyRevenue
  // ==========================================
  group('syncMonthlyRevenue', () {
    test('returns 0 when API returns empty data', () async {
      when(
        () => mockFinMind.getMonthlyRevenue(
          stockId: any(named: 'stockId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer((_) async => []);

      final result = await repo.syncMonthlyRevenue(
        symbol: '2330',
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 31),
      );

      expect(result, equals(0));
    });

    test('rethrows RateLimitException', () async {
      when(
        () => mockFinMind.getMonthlyRevenue(
          stockId: any(named: 'stockId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenThrow(const RateLimitException('Rate limited'));

      await expectLater(
        () => repo.syncMonthlyRevenue(
          symbol: '2330',
          startDate: DateTime(2025, 1, 1),
          endDate: DateTime(2025, 1, 31),
        ),
        throwsA(isA<RateLimitException>()),
      );
    });

    test('wraps other exceptions as DatabaseException', () async {
      // 之前 return 0 屬於 silent failure（caller 看不出來是 0 筆還是壞了）。
      // 修為包成 DatabaseException 讓 upstream catch (e) 仍可降級但保留 cause。
      when(
        () => mockFinMind.getMonthlyRevenue(
          stockId: any(named: 'stockId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenThrow(Exception('unknown'));

      await expectLater(
        repo.syncMonthlyRevenue(
          symbol: '2330',
          startDate: DateTime(2025, 1, 1),
          endDate: DateTime(2025, 1, 31),
        ),
        throwsA(isA<DatabaseException>()),
      );
      verify(
        () => mockFinMind.getMonthlyRevenue(
          stockId: any(named: 'stockId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).called(1);
    });
  });

  // ==========================================
  // syncValuationData
  // ==========================================
  group('syncValuationData', () {
    test('returns 0 when API returns empty data', () async {
      when(
        () => mockFinMind.getPERData(
          stockId: any(named: 'stockId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer((_) async => []);

      final result = await repo.syncValuationData(
        symbol: '2330',
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 31),
      );

      expect(result, equals(0));
    });

    test('rethrows RateLimitException', () async {
      when(
        () => mockFinMind.getPERData(
          stockId: any(named: 'stockId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenThrow(const RateLimitException('Rate limited'));

      await expectLater(
        () => repo.syncValuationData(
          symbol: '2330',
          startDate: DateTime(2025, 1, 1),
          endDate: DateTime(2025, 1, 31),
        ),
        throwsA(isA<RateLimitException>()),
      );
    });
  });

  // ==========================================
  // syncAllMarketValuation
  // ==========================================
  group('syncAllMarketValuation', () {
    test('returns 0 when TWSE returns empty data', () async {
      when(
        () => mockTwse.getAllStockValuation(date: any(named: 'date')),
      ).thenAnswer((_) async => []);

      final result = await repo.syncAllMarketValuation(DateTime(2025, 1, 15));

      expect(result, equals(0));
    });

    test('rethrows NetworkException', () async {
      when(
        () => mockTwse.getAllStockValuation(date: any(named: 'date')),
      ).thenThrow(const NetworkException('Timeout'));

      await expectLater(
        () => repo.syncAllMarketValuation(DateTime(2025, 1, 15)),
        throwsA(isA<NetworkException>()),
      );
    });

    test('wraps other exceptions as DatabaseException', () async {
      // 之前 return 0 屬 silent failure（caller 看不出來是真 0 還是壞了）。
      when(
        () => mockTwse.getAllStockValuation(date: any(named: 'date')),
      ).thenThrow(Exception('unknown'));

      await expectLater(
        repo.syncAllMarketValuation(DateTime(2025, 1, 15)),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  // ==========================================
  // syncOtcValuation
  // ==========================================
  group('syncOtcValuation', () {
    test('returns 0 for empty symbols', () async {
      final result = await repo.syncOtcValuation([]);

      expect(result, equals(0));
    });

    test('rethrows NetworkException', () async {
      // Skip freshness check by using force
      when(
        () => mockTpex.getAllValuation(date: any(named: 'date')),
      ).thenThrow(const NetworkException('Timeout'));

      await expectLater(
        () => repo.syncOtcValuation(['6547'], force: true),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  // ==========================================
  // syncAllMarketRevenue
  // ==========================================
  group('syncAllMarketRevenue', () {
    test('returns 0 when API returns empty data', () async {
      when(() => mockTwse.getAllMonthlyRevenue()).thenAnswer((_) async => []);

      final result = await repo.syncAllMarketRevenue(DateTime(2025, 1, 15));

      expect(result, equals(0));
    });

    test('rethrows NetworkException', () async {
      when(
        () => mockTwse.getAllMonthlyRevenue(),
      ).thenThrow(const NetworkException('Timeout'));

      await expectLater(
        () => repo.syncAllMarketRevenue(DateTime(2025, 1, 15)),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
