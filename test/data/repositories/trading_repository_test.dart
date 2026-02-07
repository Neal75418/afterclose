import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/data/remote/tpex_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/data/repositories/trading_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

class MockFinMindClient extends Mock implements FinMindClient {}

class MockTwseClient extends Mock implements TwseClient {}

class MockTpexClient extends Mock implements TpexClient {}

void main() {
  late MockAppDatabase mockDb;
  late MockFinMindClient mockClient;
  late MockTwseClient mockTwse;
  late MockTpexClient mockTpex;
  late TradingRepository repo;

  setUp(() {
    mockDb = MockAppDatabase();
    mockClient = MockFinMindClient();
    mockTwse = MockTwseClient();
    mockTpex = MockTpexClient();
    repo = TradingRepository(
      database: mockDb,
      finMindClient: mockClient,
      twseClient: mockTwse,
      tpexClient: mockTpex,
    );
  });

  // ==========================================
  // isHighDayTradingStock
  // ==========================================
  group('isHighDayTradingStock', () {
    test('returns false when no data', () async {
      when(
        () => mockDb.getLatestDayTrading(any()),
      ).thenAnswer((_) async => null);

      final result = await repo.isHighDayTradingStock('2330');

      expect(result, isFalse);
    });

    test('returns true when ratio > 30%', () async {
      when(() => mockDb.getLatestDayTrading(any())).thenAnswer(
        (_) async => DayTradingEntry(
          symbol: '2330',
          date: DateTime(2025, 1, 15),
          dayTradingRatio: 45.0,
        ),
      );

      final result = await repo.isHighDayTradingStock('2330');

      expect(result, isTrue);
    });

    test('returns false when ratio <= 30%', () async {
      when(() => mockDb.getLatestDayTrading(any())).thenAnswer(
        (_) async => DayTradingEntry(
          symbol: '2330',
          date: DateTime(2025, 1, 15),
          dayTradingRatio: 25.0,
        ),
      );

      final result = await repo.isHighDayTradingStock('2330');

      expect(result, isFalse);
    });
  });

  // ==========================================
  // getAverageDayTradingRatio
  // ==========================================
  group('getAverageDayTradingRatio', () {
    test('returns null when history is empty', () async {
      when(
        () => mockDb.getDayTradingHistory(
          any(),
          startDate: any(named: 'startDate'),
        ),
      ).thenAnswer((_) async => []);

      final result = await repo.getAverageDayTradingRatio('2330');

      expect(result, isNull);
    });

    test('calculates average correctly', () async {
      final now = DateTime.now();
      final entries = [
        DayTradingEntry(
          symbol: '2330',
          date: now.subtract(const Duration(days: 3)),
          dayTradingRatio: 30.0,
        ),
        DayTradingEntry(
          symbol: '2330',
          date: now.subtract(const Duration(days: 2)),
          dayTradingRatio: 40.0,
        ),
        DayTradingEntry(
          symbol: '2330',
          date: now.subtract(const Duration(days: 1)),
          dayTradingRatio: 50.0,
        ),
      ];

      when(
        () => mockDb.getDayTradingHistory(
          any(),
          startDate: any(named: 'startDate'),
        ),
      ).thenAnswer((_) async => entries);

      final result = await repo.getAverageDayTradingRatio('2330', days: 5);

      // (30 + 40 + 50) / 3 = 40
      expect(result, equals(40.0));
    });

    test('skips null dayTradingRatio entries', () async {
      final now = DateTime.now();
      final entries = [
        DayTradingEntry(
          symbol: '2330',
          date: now.subtract(const Duration(days: 2)),
          dayTradingRatio: null,
        ),
        DayTradingEntry(
          symbol: '2330',
          date: now.subtract(const Duration(days: 1)),
          dayTradingRatio: 40.0,
        ),
      ];

      when(
        () => mockDb.getDayTradingHistory(
          any(),
          startDate: any(named: 'startDate'),
        ),
      ).thenAnswer((_) async => entries);

      final result = await repo.getAverageDayTradingRatio('2330', days: 5);

      // Only 40.0 counted, average = 40/1 = 40
      expect(result, equals(40.0));
    });
  });

  // ==========================================
  // getShortMarginRatio
  // ==========================================
  group('getShortMarginRatio', () {
    test('returns null when no data', () async {
      when(
        () => mockDb.getLatestMarginTrading(any()),
      ).thenAnswer((_) async => null);

      final result = await repo.getShortMarginRatio('2330');

      expect(result, isNull);
    });

    test('returns null when marginBalance <= 0', () async {
      when(() => mockDb.getLatestMarginTrading(any())).thenAnswer(
        (_) async => MarginTradingEntry(
          symbol: '2330',
          date: DateTime(2025, 1, 15),
          marginBalance: 0,
          shortBalance: 100,
        ),
      );

      final result = await repo.getShortMarginRatio('2330');

      expect(result, isNull);
    });

    test('calculates short/margin ratio correctly', () async {
      when(() => mockDb.getLatestMarginTrading(any())).thenAnswer(
        (_) async => MarginTradingEntry(
          symbol: '2330',
          date: DateTime(2025, 1, 15),
          marginBalance: 1000,
          shortBalance: 300,
        ),
      );

      final result = await repo.getShortMarginRatio('2330');

      // (300 / 1000) * 100 = 30%
      expect(result, closeTo(30.0, 0.1));
    });
  });

  // ==========================================
  // isMarginIncreasing
  // ==========================================
  group('isMarginIncreasing', () {
    test('returns false when insufficient data', () async {
      when(
        () => mockDb.getMarginTradingHistory(
          any(),
          startDate: any(named: 'startDate'),
        ),
      ).thenAnswer((_) async => []);

      final result = await repo.isMarginIncreasing('2330');

      expect(result, isFalse);
    });

    test('returns true when margin balance increasing', () async {
      final now = DateTime.now();
      final entries = List.generate(
        10,
        (i) => MarginTradingEntry(
          symbol: '2330',
          date: now.subtract(Duration(days: 10 - i)),
          marginBalance: 1000.0 + i * 100, // increasing
        ),
      );

      when(
        () => mockDb.getMarginTradingHistory(
          any(),
          startDate: any(named: 'startDate'),
        ),
      ).thenAnswer((_) async => entries);

      final result = await repo.isMarginIncreasing('2330');

      expect(result, isTrue);
    });

    test('returns false when margin balance decreasing', () async {
      final now = DateTime.now();
      final entries = List.generate(
        10,
        (i) => MarginTradingEntry(
          symbol: '2330',
          date: now.subtract(Duration(days: 10 - i)),
          marginBalance: 2000.0 - i * 100, // decreasing
        ),
      );

      when(
        () => mockDb.getMarginTradingHistory(
          any(),
          startDate: any(named: 'startDate'),
        ),
      ).thenAnswer((_) async => entries);

      final result = await repo.isMarginIncreasing('2330');

      expect(result, isFalse);
    });
  });

  // ==========================================
  // isShortIncreasing
  // ==========================================
  group('isShortIncreasing', () {
    test('returns false when insufficient data', () async {
      when(
        () => mockDb.getMarginTradingHistory(
          any(),
          startDate: any(named: 'startDate'),
        ),
      ).thenAnswer((_) async => []);

      final result = await repo.isShortIncreasing('2330');

      expect(result, isFalse);
    });

    test('returns true when short balance increasing', () async {
      final now = DateTime.now();
      final entries = List.generate(
        10,
        (i) => MarginTradingEntry(
          symbol: '2330',
          date: now.subtract(Duration(days: 10 - i)),
          shortBalance: 100.0 + i * 20, // increasing
        ),
      );

      when(
        () => mockDb.getMarginTradingHistory(
          any(),
          startDate: any(named: 'startDate'),
        ),
      ).thenAnswer((_) async => entries);

      final result = await repo.isShortIncreasing('2330');

      expect(result, isTrue);
    });
  });

  // ==========================================
  // Delegation
  // ==========================================
  group('delegation', () {
    test('getLatestDayTrading delegates to db', () async {
      when(
        () => mockDb.getLatestDayTrading(any()),
      ).thenAnswer((_) async => null);

      await repo.getLatestDayTrading('2330');

      verify(() => mockDb.getLatestDayTrading('2330')).called(1);
    });

    test('getLatestMarginTrading delegates to db', () async {
      when(
        () => mockDb.getLatestMarginTrading(any()),
      ).thenAnswer((_) async => null);

      await repo.getLatestMarginTrading('2330');

      verify(() => mockDb.getLatestMarginTrading('2330')).called(1);
    });
  });
}
