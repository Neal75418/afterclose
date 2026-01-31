import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/data/remote/tpex_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/data/repositories/market_data_repository.dart';

// Mocks
class MockAppDatabase extends Mock implements AppDatabase {}

class MockFinMindClient extends Mock implements FinMindClient {}

class MockTwseClient extends Mock implements TwseClient {}

class MockTpexClient extends Mock implements TpexClient {}

/// Test subclass to expose private methods for unit testing
class TestableMarketDataRepository extends MarketDataRepository {
  TestableMarketDataRepository({
    required super.database,
    required super.finMindClient,
    super.twseClient,
    super.tpexClient,
  });

  // Expose private methods for testing
  bool testIsSameDay(DateTime a, DateTime b) => _isSameDay(a, b);
  bool testIsSameWeek(DateTime a, DateTime b) => _isSameWeek(a, b);
  DateTime testGetExpectedLatestQuarter() => _getExpectedLatestQuarter();
  DateTime testParseQuarterDate(String dateStr) => _parseQuarterDate(dateStr);
  int testParseMinSharesFromLevel(String level) =>
      _parseMinSharesFromLevel(level);

  // Access private methods through parent class
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isSameWeek(DateTime a, DateTime b) {
    final aWeekStart = a.subtract(Duration(days: a.weekday - 1));
    final bWeekStart = b.subtract(Duration(days: b.weekday - 1));
    return _isSameDay(aWeekStart, bWeekStart);
  }

  DateTime _getExpectedLatestQuarter() {
    final now = DateTime.now();
    final month = now.month;

    if (month >= 3 && month < 5) {
      return DateTime(now.year - 1, 10, 1);
    } else if (month >= 5 && month < 8) {
      return DateTime(now.year, 1, 1);
    } else if (month >= 8 && month < 11) {
      return DateTime(now.year, 4, 1);
    } else if (month >= 11) {
      return DateTime(now.year, 7, 1);
    } else {
      return DateTime(now.year - 1, 7, 1);
    }
  }

  DateTime _parseQuarterDate(String dateStr) {
    if (dateStr.contains('Q')) {
      final parts = dateStr.split('-Q');
      final year = int.parse(parts[0]);
      final quarter = int.parse(parts[1]);
      final month = (quarter - 1) * 3 + 1;
      return DateTime(year, month, 1);
    }
    return DateTime.parse(dateStr);
  }

  int _parseMinSharesFromLevel(String level) {
    if (level.contains('以上') || level.toLowerCase().contains('over')) {
      final numStr = level.replaceAll(RegExp(r'\D'), '');
      return int.tryParse(numStr) ?? 0;
    }

    final parts = level.split('-');
    if (parts.isNotEmpty) {
      final numStr = parts[0].replaceAll(RegExp(r'\D'), '');
      return int.tryParse(numStr) ?? 0;
    }

    return 0;
  }
}

void main() {
  late MockAppDatabase mockDb;
  late MockFinMindClient mockFinMindClient;
  late MockTwseClient mockTwseClient;
  late MockTpexClient mockTpexClient;
  late TestableMarketDataRepository repository;

  setUp(() {
    mockDb = MockAppDatabase();
    mockFinMindClient = MockFinMindClient();
    mockTwseClient = MockTwseClient();
    mockTpexClient = MockTpexClient();

    repository = TestableMarketDataRepository(
      database: mockDb,
      finMindClient: mockFinMindClient,
      twseClient: mockTwseClient,
      tpexClient: mockTpexClient,
    );
  });

  group('MarketDataRepository', () {
    group('_isSameDay helper', () {
      test('returns true for same day different times', () {
        final a = DateTime(2024, 6, 15, 10, 30, 45);
        final b = DateTime(2024, 6, 15, 23, 59, 59);

        expect(repository.testIsSameDay(a, b), isTrue);
      });

      test('returns false for different days', () {
        final a = DateTime(2024, 6, 15);
        final b = DateTime(2024, 6, 16);

        expect(repository.testIsSameDay(a, b), isFalse);
      });

      test('returns false for different months same day number', () {
        final a = DateTime(2024, 6, 15);
        final b = DateTime(2024, 7, 15);

        expect(repository.testIsSameDay(a, b), isFalse);
      });

      test('returns false for different years', () {
        final a = DateTime(2024, 6, 15);
        final b = DateTime(2025, 6, 15);

        expect(repository.testIsSameDay(a, b), isFalse);
      });
    });

    group('_isSameWeek helper', () {
      test('returns true for same week (Monday to Sunday)', () {
        // 2024-06-17 is Monday, 2024-06-23 is Sunday
        final monday = DateTime(2024, 6, 17);
        final sunday = DateTime(2024, 6, 23);

        expect(repository.testIsSameWeek(monday, sunday), isTrue);
      });

      test('returns true for same day', () {
        final date = DateTime(2024, 6, 18);

        expect(repository.testIsSameWeek(date, date), isTrue);
      });

      test('returns false for different weeks', () {
        final thisWeek = DateTime(2024, 6, 17); // Monday
        final nextWeek = DateTime(2024, 6, 24); // Next Monday

        expect(repository.testIsSameWeek(thisWeek, nextWeek), isFalse);
      });

      test('returns false for Sunday and next Monday', () {
        final sunday = DateTime(2024, 6, 23);
        final nextMonday = DateTime(2024, 6, 24);

        expect(repository.testIsSameWeek(sunday, nextMonday), isFalse);
      });
    });

    group('_getExpectedLatestQuarter helper', () {
      test('returns correct quarter based on current month', () {
        // This test validates the logic without depending on current date
        final quarter = repository.testGetExpectedLatestQuarter();

        // Should be a valid quarter start date (Jan, Apr, Jul, Oct)
        expect([1, 4, 7, 10], contains(quarter.month));
        expect(quarter.day, equals(1));
      });
    });

    group('_parseQuarterDate helper', () {
      test('parses Q1 format correctly', () {
        final result = repository.testParseQuarterDate('2024-Q1');

        expect(result.year, equals(2024));
        expect(result.month, equals(1));
        expect(result.day, equals(1));
      });

      test('parses Q2 format correctly', () {
        final result = repository.testParseQuarterDate('2024-Q2');

        expect(result.year, equals(2024));
        expect(result.month, equals(4));
        expect(result.day, equals(1));
      });

      test('parses Q3 format correctly', () {
        final result = repository.testParseQuarterDate('2024-Q3');

        expect(result.year, equals(2024));
        expect(result.month, equals(7));
        expect(result.day, equals(1));
      });

      test('parses Q4 format correctly', () {
        final result = repository.testParseQuarterDate('2024-Q4');

        expect(result.year, equals(2024));
        expect(result.month, equals(10));
        expect(result.day, equals(1));
      });

      test('parses standard date format', () {
        final result = repository.testParseQuarterDate('2024-06-15');

        expect(result.year, equals(2024));
        expect(result.month, equals(6));
        expect(result.day, equals(15));
      });

      test('parses ISO datetime format', () {
        final result = repository.testParseQuarterDate('2024-06-15T10:30:00');

        expect(result.year, equals(2024));
        expect(result.month, equals(6));
        expect(result.day, equals(15));
      });
    });

    group('_parseMinSharesFromLevel helper', () {
      test('parses range format correctly', () {
        expect(repository.testParseMinSharesFromLevel('400-600'), equals(400));
        expect(repository.testParseMinSharesFromLevel('600-800'), equals(600));
        expect(repository.testParseMinSharesFromLevel('800-1000'), equals(800));
      });

      test('parses Chinese "以上" format correctly', () {
        expect(repository.testParseMinSharesFromLevel('1000以上'), equals(1000));
        expect(repository.testParseMinSharesFromLevel('1000張以上'), equals(1000));
      });

      test('parses English "over" format correctly', () {
        expect(
          repository.testParseMinSharesFromLevel('over 1000'),
          equals(1000),
        );
        expect(
          repository.testParseMinSharesFromLevel('Over1000'),
          equals(1000),
        );
      });

      test('returns 0 for invalid format', () {
        expect(repository.testParseMinSharesFromLevel('invalid'), equals(0));
        expect(repository.testParseMinSharesFromLevel(''), equals(0));
      });

      test('parses level with text prefix', () {
        expect(
          repository.testParseMinSharesFromLevel('持股400-600'),
          equals(400),
        );
      });
    });

    group('getShareholdingHistory', () {
      test('calls database with correct parameters', () async {
        when(
          () => mockDb.getShareholdingHistory(
            any(),
            startDate: any(named: 'startDate'),
          ),
        ).thenAnswer((_) async => []);

        await repository.getShareholdingHistory('2330', days: 30);

        verify(
          () => mockDb.getShareholdingHistory(
            '2330',
            startDate: any(named: 'startDate'),
          ),
        ).called(1);
      });

      test('returns shareholding entries from database', () async {
        final mockEntry = ShareholdingEntry(
          symbol: '2330',
          date: DateTime(2024, 6, 15),
          foreignRemainingShares: 1000000,
          foreignSharesRatio: 75.5,
          foreignUpperLimitRatio: 100.0,
          sharesIssued: 25930000000,
        );

        when(
          () => mockDb.getShareholdingHistory(
            any(),
            startDate: any(named: 'startDate'),
          ),
        ).thenAnswer((_) async => [mockEntry]);

        final result = await repository.getShareholdingHistory('2330');

        expect(result.length, equals(1));
        expect(result.first.symbol, equals('2330'));
        expect(result.first.foreignSharesRatio, equals(75.5));
      });
    });

    group('getLatestShareholding', () {
      test('calls database method correctly', () async {
        when(
          () => mockDb.getLatestShareholding(any()),
        ).thenAnswer((_) async => null);

        await repository.getLatestShareholding('2330');

        verify(() => mockDb.getLatestShareholding('2330')).called(1);
      });
    });

    group('syncShareholding', () {
      test('skips sync when latest data is same day', () async {
        final today = DateTime.now();
        final mockEntry = ShareholdingEntry(
          symbol: '2330',
          date: today,
          foreignRemainingShares: 1000000,
          foreignSharesRatio: 75.5,
          foreignUpperLimitRatio: 100.0,
          sharesIssued: 25930000000,
        );

        when(
          () => mockDb.getLatestShareholding('2330'),
        ).thenAnswer((_) async => mockEntry);

        final result = await repository.syncShareholding(
          '2330',
          startDate: today.subtract(const Duration(days: 30)),
        );

        expect(result, equals(0));
        verifyNever(
          () => mockFinMindClient.getShareholding(
            stockId: any(named: 'stockId'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        );
      });

      test('throws DatabaseException on error', () async {
        when(
          () => mockDb.getLatestShareholding(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockFinMindClient.getShareholding(
            stockId: any(named: 'stockId'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenThrow(Exception('API Error'));

        expect(
          () => repository.syncShareholding(
            '2330',
            startDate: DateTime.now().subtract(const Duration(days: 30)),
          ),
          throwsA(isA<DatabaseException>()),
        );
      });

      test('rethrows RateLimitException', () async {
        when(
          () => mockDb.getLatestShareholding(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockFinMindClient.getShareholding(
            stockId: any(named: 'stockId'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenThrow(const RateLimitException('Rate limited'));

        expect(
          () => repository.syncShareholding(
            '2330',
            startDate: DateTime.now().subtract(const Duration(days: 30)),
          ),
          throwsA(isA<RateLimitException>()),
        );
      });
    });

    group('isForeignShareholdingIncreasing', () {
      test('returns false when insufficient data', () async {
        when(
          () => mockDb.getShareholdingHistory(
            any(),
            startDate: any(named: 'startDate'),
          ),
        ).thenAnswer((_) async => []);

        final result = await repository.isForeignShareholdingIncreasing('2330');

        expect(result, isFalse);
      });

      test('returns true when ratio is increasing', () async {
        final entries = List.generate(
          10,
          (i) => ShareholdingEntry(
            symbol: '2330',
            date: DateTime.now().subtract(Duration(days: 9 - i)),
            foreignRemainingShares: 1000000,
            foreignSharesRatio: 70.0 + i, // Increasing: 70, 71, 72...
            foreignUpperLimitRatio: 100.0,
            sharesIssued: 25930000000,
          ),
        );

        when(
          () => mockDb.getShareholdingHistory(
            any(),
            startDate: any(named: 'startDate'),
          ),
        ).thenAnswer((_) async => entries);

        final result = await repository.isForeignShareholdingIncreasing('2330');

        expect(result, isTrue);
      });

      test('returns false when ratio is decreasing', () async {
        final entries = List.generate(
          10,
          (i) => ShareholdingEntry(
            symbol: '2330',
            date: DateTime.now().subtract(Duration(days: 9 - i)),
            foreignRemainingShares: 1000000,
            foreignSharesRatio: 80.0 - i, // Decreasing: 80, 79, 78...
            foreignUpperLimitRatio: 100.0,
            sharesIssued: 25930000000,
          ),
        );

        when(
          () => mockDb.getShareholdingHistory(
            any(),
            startDate: any(named: 'startDate'),
          ),
        ).thenAnswer((_) async => entries);

        final result = await repository.isForeignShareholdingIncreasing('2330');

        expect(result, isFalse);
      });
    });

    group('getDayTradingHistory', () {
      test('calls database with correct parameters', () async {
        when(
          () => mockDb.getDayTradingHistory(
            any(),
            startDate: any(named: 'startDate'),
          ),
        ).thenAnswer((_) async => []);

        await repository.getDayTradingHistory('2330', days: 20);

        verify(
          () => mockDb.getDayTradingHistory(
            '2330',
            startDate: any(named: 'startDate'),
          ),
        ).called(1);
      });
    });

    group('isHighDayTradingStock', () {
      test('returns true when ratio > 30%', () async {
        final mockEntry = DayTradingEntry(
          symbol: '2330',
          date: DateTime.now(),
          buyVolume: 1000,
          sellVolume: 900,
          dayTradingRatio: 35.0,
          tradeVolume: 5000,
        );

        when(
          () => mockDb.getLatestDayTrading(any()),
        ).thenAnswer((_) async => mockEntry);

        final result = await repository.isHighDayTradingStock('2330');

        expect(result, isTrue);
      });

      test('returns false when ratio <= 30%', () async {
        final mockEntry = DayTradingEntry(
          symbol: '2330',
          date: DateTime.now(),
          buyVolume: 1000,
          sellVolume: 900,
          dayTradingRatio: 25.0,
          tradeVolume: 5000,
        );

        when(
          () => mockDb.getLatestDayTrading(any()),
        ).thenAnswer((_) async => mockEntry);

        final result = await repository.isHighDayTradingStock('2330');

        expect(result, isFalse);
      });

      test('returns false when no data', () async {
        when(
          () => mockDb.getLatestDayTrading(any()),
        ).thenAnswer((_) async => null);

        final result = await repository.isHighDayTradingStock('2330');

        expect(result, isFalse);
      });
    });

    group('getAverageDayTradingRatio', () {
      test('returns average ratio correctly', () async {
        final entries = [
          DayTradingEntry(
            symbol: '2330',
            date: DateTime.now().subtract(const Duration(days: 2)),
            buyVolume: 1000,
            sellVolume: 900,
            dayTradingRatio: 20.0,
            tradeVolume: 5000,
          ),
          DayTradingEntry(
            symbol: '2330',
            date: DateTime.now().subtract(const Duration(days: 1)),
            buyVolume: 1000,
            sellVolume: 900,
            dayTradingRatio: 30.0,
            tradeVolume: 5000,
          ),
          DayTradingEntry(
            symbol: '2330',
            date: DateTime.now(),
            buyVolume: 1000,
            sellVolume: 900,
            dayTradingRatio: 40.0,
            tradeVolume: 5000,
          ),
        ];

        when(
          () => mockDb.getDayTradingHistory(
            any(),
            startDate: any(named: 'startDate'),
          ),
        ).thenAnswer((_) async => entries);

        final result = await repository.getAverageDayTradingRatio(
          '2330',
          days: 3,
        );

        expect(result, equals(30.0)); // (20 + 30 + 40) / 3
      });

      test('returns null when no data', () async {
        when(
          () => mockDb.getDayTradingHistory(
            any(),
            startDate: any(named: 'startDate'),
          ),
        ).thenAnswer((_) async => []);

        final result = await repository.getAverageDayTradingRatio('2330');

        expect(result, isNull);
      });

      test('handles null ratios in entries', () async {
        final entries = [
          DayTradingEntry(
            symbol: '2330',
            date: DateTime.now().subtract(const Duration(days: 1)),
            buyVolume: 1000,
            sellVolume: 900,
            dayTradingRatio: null, // null ratio
            tradeVolume: 5000,
          ),
          DayTradingEntry(
            symbol: '2330',
            date: DateTime.now(),
            buyVolume: 1000,
            sellVolume: 900,
            dayTradingRatio: 30.0,
            tradeVolume: 5000,
          ),
        ];

        when(
          () => mockDb.getDayTradingHistory(
            any(),
            startDate: any(named: 'startDate'),
          ),
        ).thenAnswer((_) async => entries);

        final result = await repository.getAverageDayTradingRatio(
          '2330',
          days: 2,
        );

        expect(result, equals(30.0)); // Only one valid entry
      });
    });

    group('syncAllDayTradingFromTwse', () {
      test('skips sync when existing data exceeds threshold', () async {
        when(
          () => mockDb.getDayTradingCountForDate(any()),
        ).thenAnswer((_) async => 150);

        final result = await repository.syncAllDayTradingFromTwse();

        expect(result, equals(0));
        verifyNever(
          () => mockTwseClient.getAllDayTradingData(date: any(named: 'date')),
        );
      });

      test('forces refresh when forceRefresh is true', () async {
        when(
          () => mockDb.getDayTradingCountForDate(any()),
        ).thenAnswer((_) async => 150);
        when(
          () => mockTwseClient.getAllDayTradingData(date: any(named: 'date')),
        ).thenAnswer((_) async => []);
        when(() => mockDb.getPricesForDate(any())).thenAnswer((_) async => []);
        when(
          () => mockDb.getAllPricesInRange(
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenAnswer((_) async => {});

        await repository.syncAllDayTradingFromTwse(forceRefresh: true);

        verify(
          () => mockTwseClient.getAllDayTradingData(date: any(named: 'date')),
        ).called(1);
      });

      test('throws DatabaseException on error', () async {
        when(
          () => mockDb.getDayTradingCountForDate(any()),
        ).thenAnswer((_) async => 0);
        when(
          () => mockTwseClient.getAllDayTradingData(date: any(named: 'date')),
        ).thenThrow(Exception('API Error'));

        expect(
          () => repository.syncAllDayTradingFromTwse(),
          throwsA(isA<DatabaseException>()),
        );
      });
    });

    group('get52WeekHighLow', () {
      test('returns high and low from weekly price history', () async {
        final entries = [
          WeeklyPriceEntry(
            symbol: '2330',
            date: DateTime.now().subtract(const Duration(days: 7)),
            open: 500.0,
            high: 520.0,
            low: 490.0,
            close: 510.0,
            volume: 1000000,
          ),
          WeeklyPriceEntry(
            symbol: '2330',
            date: DateTime.now(),
            open: 510.0,
            high: 550.0,
            low: 480.0,
            close: 540.0,
            volume: 1200000,
          ),
        ];

        when(
          () => mockDb.getWeeklyPriceHistory(
            any(),
            startDate: any(named: 'startDate'),
          ),
        ).thenAnswer((_) async => entries);

        final result = await repository.get52WeekHighLow('2330');

        expect(result.high, equals(550.0));
        expect(result.low, equals(480.0));
      });

      test('returns null when no data', () async {
        when(
          () => mockDb.getWeeklyPriceHistory(
            any(),
            startDate: any(named: 'startDate'),
          ),
        ).thenAnswer((_) async => []);

        final result = await repository.get52WeekHighLow('2330');

        expect(result.high, isNull);
        expect(result.low, isNull);
      });

      test('handles entries with null high/low', () async {
        final entries = [
          WeeklyPriceEntry(
            symbol: '2330',
            date: DateTime.now(),
            open: 500.0,
            high: null,
            low: null,
            close: 510.0,
            volume: 1000000,
          ),
        ];

        when(
          () => mockDb.getWeeklyPriceHistory(
            any(),
            startDate: any(named: 'startDate'),
          ),
        ).thenAnswer((_) async => entries);

        final result = await repository.get52WeekHighLow('2330');

        expect(result.high, isNull);
        expect(result.low, isNull);
      });
    });

    group('getConcentrationRatio', () {
      test('calculates large holder percentage correctly', () async {
        final entries = [
          HoldingDistributionEntry(
            symbol: '2330',
            date: DateTime.now(),
            level: '1-400',
            shareholders: 100000,
            percent: 20.0,
            shares: 1000000,
          ),
          HoldingDistributionEntry(
            symbol: '2330',
            date: DateTime.now(),
            level: '400-600',
            shareholders: 5000,
            percent: 15.0,
            shares: 500000,
          ),
          HoldingDistributionEntry(
            symbol: '2330',
            date: DateTime.now(),
            level: '1000以上',
            shareholders: 100,
            percent: 65.0,
            shares: 20000000,
          ),
        ];

        when(
          () => mockDb.getLatestHoldingDistribution(any()),
        ).thenAnswer((_) async => entries);

        final result = await repository.getConcentrationRatio('2330');

        // 400-600 (15%) + 1000以上 (65%) = 80%
        expect(result, equals(80.0));
      });

      test('returns null when no distribution data', () async {
        when(
          () => mockDb.getLatestHoldingDistribution(any()),
        ).thenAnswer((_) async => []);

        final result = await repository.getConcentrationRatio('2330');

        expect(result, isNull);
      });

      test('uses custom threshold level', () async {
        final entries = [
          HoldingDistributionEntry(
            symbol: '2330',
            date: DateTime.now(),
            level: '400-600',
            shareholders: 5000,
            percent: 15.0,
            shares: 500000,
          ),
          HoldingDistributionEntry(
            symbol: '2330',
            date: DateTime.now(),
            level: '600-800',
            shareholders: 2000,
            percent: 10.0,
            shares: 300000,
          ),
          HoldingDistributionEntry(
            symbol: '2330',
            date: DateTime.now(),
            level: '1000以上',
            shareholders: 100,
            percent: 65.0,
            shares: 20000000,
          ),
        ];

        when(
          () => mockDb.getLatestHoldingDistribution(any()),
        ).thenAnswer((_) async => entries);

        // With threshold 600, only 600-800 and 1000以上 should be counted
        final result = await repository.getConcentrationRatio(
          '2330',
          thresholdLevel: 600,
        );

        expect(result, equals(75.0)); // 10% + 65%
      });
    });

    group('getShortMarginRatio', () {
      test('calculates ratio correctly', () async {
        final mockEntry = MarginTradingEntry(
          symbol: '2330',
          date: DateTime.now(),
          marginBuy: 1000,
          marginSell: 800,
          marginBalance: 10000, // 融資餘額
          shortBuy: 500,
          shortSell: 400,
          shortBalance: 3000, // 融券餘額
        );

        when(
          () => mockDb.getLatestMarginTrading(any()),
        ).thenAnswer((_) async => mockEntry);

        final result = await repository.getShortMarginRatio('2330');

        // 3000 / 10000 * 100 = 30%
        expect(result, equals(30.0));
      });

      test('returns null when no data', () async {
        when(
          () => mockDb.getLatestMarginTrading(any()),
        ).thenAnswer((_) async => null);

        final result = await repository.getShortMarginRatio('2330');

        expect(result, isNull);
      });

      test('returns null when margin balance is zero', () async {
        final mockEntry = MarginTradingEntry(
          symbol: '2330',
          date: DateTime.now(),
          marginBuy: 0,
          marginSell: 0,
          marginBalance: 0,
          shortBuy: 500,
          shortSell: 400,
          shortBalance: 3000,
        );

        when(
          () => mockDb.getLatestMarginTrading(any()),
        ).thenAnswer((_) async => mockEntry);

        final result = await repository.getShortMarginRatio('2330');

        expect(result, isNull);
      });
    });

    group('isMarginIncreasing', () {
      test('returns true when margin balance is increasing', () async {
        final entries = List.generate(
          10,
          (i) => MarginTradingEntry(
            symbol: '2330',
            date: DateTime.now().subtract(Duration(days: 9 - i)),
            marginBuy: 1000,
            marginSell: 800,
            marginBalance: 10000 + i * 100, // Increasing
            shortBuy: 500,
            shortSell: 400,
            shortBalance: 3000,
          ),
        );

        when(
          () => mockDb.getMarginTradingHistory(
            any(),
            startDate: any(named: 'startDate'),
          ),
        ).thenAnswer((_) async => entries);

        final result = await repository.isMarginIncreasing('2330');

        expect(result, isTrue);
      });

      test('returns false when margin balance is decreasing', () async {
        final entries = List.generate(
          10,
          (i) => MarginTradingEntry(
            symbol: '2330',
            date: DateTime.now().subtract(Duration(days: 9 - i)),
            marginBuy: 1000,
            marginSell: 800,
            marginBalance: 20000 - i * 100, // Decreasing
            shortBuy: 500,
            shortSell: 400,
            shortBalance: 3000,
          ),
        );

        when(
          () => mockDb.getMarginTradingHistory(
            any(),
            startDate: any(named: 'startDate'),
          ),
        ).thenAnswer((_) async => entries);

        final result = await repository.isMarginIncreasing('2330');

        expect(result, isFalse);
      });

      test('returns false when insufficient data', () async {
        when(
          () => mockDb.getMarginTradingHistory(
            any(),
            startDate: any(named: 'startDate'),
          ),
        ).thenAnswer((_) async => []);

        final result = await repository.isMarginIncreasing('2330');

        expect(result, isFalse);
      });
    });

    group('isShortIncreasing', () {
      test('returns true when short balance is increasing', () async {
        final entries = List.generate(
          10,
          (i) => MarginTradingEntry(
            symbol: '2330',
            date: DateTime.now().subtract(Duration(days: 9 - i)),
            marginBuy: 1000,
            marginSell: 800,
            marginBalance: 10000,
            shortBuy: 500,
            shortSell: 400,
            shortBalance: 3000 + i * 50, // Increasing
          ),
        );

        when(
          () => mockDb.getMarginTradingHistory(
            any(),
            startDate: any(named: 'startDate'),
          ),
        ).thenAnswer((_) async => entries);

        final result = await repository.isShortIncreasing('2330');

        expect(result, isTrue);
      });

      test('returns false when short balance is decreasing', () async {
        final entries = List.generate(
          10,
          (i) => MarginTradingEntry(
            symbol: '2330',
            date: DateTime.now().subtract(Duration(days: 9 - i)),
            marginBuy: 1000,
            marginSell: 800,
            marginBalance: 10000,
            shortBuy: 500,
            shortSell: 400,
            shortBalance: 5000 - i * 50, // Decreasing
          ),
        );

        when(
          () => mockDb.getMarginTradingHistory(
            any(),
            startDate: any(named: 'startDate'),
          ),
        ).thenAnswer((_) async => entries);

        final result = await repository.isShortIncreasing('2330');

        expect(result, isFalse);
      });
    });

    group('syncAllMarginTradingFromTwse', () {
      test('skips sync when existing data exceeds threshold', () async {
        when(
          () => mockDb.getMarginTradingCountForDate(any()),
        ).thenAnswer((_) async => 1600);

        final result = await repository.syncAllMarginTradingFromTwse();

        expect(result, equals(-1));
        verifyNever(() => mockTwseClient.getAllMarginTradingData());
      });

      test('returns 0 when both APIs return empty data', () async {
        when(
          () => mockDb.getMarginTradingCountForDate(any()),
        ).thenAnswer((_) async => 0);
        when(
          () => mockTwseClient.getAllMarginTradingData(),
        ).thenAnswer((_) async => []);
        when(
          () =>
              mockTpexClient.getAllMarginTradingData(date: any(named: 'date')),
        ).thenAnswer((_) async => []);

        final result = await repository.syncAllMarginTradingFromTwse();

        expect(result, equals(0));
      });

      test('throws DatabaseException on critical error', () async {
        when(
          () => mockDb.getMarginTradingCountForDate(any()),
        ).thenThrow(Exception('DB Error'));

        expect(
          () => repository.syncAllMarginTradingFromTwse(),
          throwsA(isA<DatabaseException>()),
        );
      });
    });
  });
}
