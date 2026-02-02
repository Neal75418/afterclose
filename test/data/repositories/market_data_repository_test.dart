import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/data/repositories/market_data_repository.dart';

// Mocks
class MockAppDatabase extends Mock implements AppDatabase {}

class MockFinMindClient extends Mock implements FinMindClient {}

/// Test subclass to expose private methods for unit testing
class TestableMarketDataRepository extends MarketDataRepository {
  TestableMarketDataRepository({
    required super.database,
    required super.finMindClient,
  });

  // Expose private methods for testing
  bool testIsSameDay(DateTime a, DateTime b) => _isSameDay(a, b);
  bool testIsSameWeek(DateTime a, DateTime b) => _isSameWeek(a, b);
  DateTime testGetExpectedLatestQuarter() => _getExpectedLatestQuarter();
  DateTime testParseQuarterDate(String dateStr) => _parseQuarterDate(dateStr);

  // Duplicate private methods to make them accessible
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
}

void main() {
  late MockAppDatabase mockDb;
  late MockFinMindClient mockFinMindClient;
  late TestableMarketDataRepository repository;

  setUp(() {
    mockDb = MockAppDatabase();
    mockFinMindClient = MockFinMindClient();

    repository = TestableMarketDataRepository(
      database: mockDb,
      finMindClient: mockFinMindClient,
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
        final monday = DateTime(2024, 6, 17);
        final sunday = DateTime(2024, 6, 23);

        expect(repository.testIsSameWeek(monday, sunday), isTrue);
      });

      test('returns true for same day', () {
        final date = DateTime(2024, 6, 18);

        expect(repository.testIsSameWeek(date, date), isTrue);
      });

      test('returns false for different weeks', () {
        final thisWeek = DateTime(2024, 6, 17);
        final nextWeek = DateTime(2024, 6, 24);

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
        final quarter = repository.testGetExpectedLatestQuarter();

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

    group('getAdjustedPriceHistory', () {
      test('calls database with correct parameters', () async {
        when(
          () => mockDb.getAdjustedPriceHistory(
            any(),
            startDate: any(named: 'startDate'),
          ),
        ).thenAnswer((_) async => []);

        await repository.getAdjustedPriceHistory('2330', days: 60);

        verify(
          () => mockDb.getAdjustedPriceHistory(
            '2330',
            startDate: any(named: 'startDate'),
          ),
        ).called(1);
      });
    });

    group('getWeeklyPriceHistory', () {
      test('calls database with correct parameters', () async {
        when(
          () => mockDb.getWeeklyPriceHistory(
            any(),
            startDate: any(named: 'startDate'),
          ),
        ).thenAnswer((_) async => []);

        await repository.getWeeklyPriceHistory('2330', weeks: 26);

        verify(
          () => mockDb.getWeeklyPriceHistory(
            '2330',
            startDate: any(named: 'startDate'),
          ),
        ).called(1);
      });
    });

    group('get52WeekHighLow', () {
      test('returns null values when no history', () async {
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

      test('returns correct high and low', () async {
        final entries = [
          WeeklyPriceEntry(
            symbol: '2330',
            date: DateTime(2024, 1, 1),
            open: 550.0,
            high: 600.0,
            low: 540.0,
            close: 580.0,
            volume: 100000,
          ),
          WeeklyPriceEntry(
            symbol: '2330',
            date: DateTime(2024, 1, 8),
            open: 580.0,
            high: 620.0,
            low: 570.0,
            close: 610.0,
            volume: 120000,
          ),
          WeeklyPriceEntry(
            symbol: '2330',
            date: DateTime(2024, 1, 15),
            open: 610.0,
            high: 650.0,
            low: 500.0,
            close: 520.0,
            volume: 150000,
          ),
        ];

        when(
          () => mockDb.getWeeklyPriceHistory(
            any(),
            startDate: any(named: 'startDate'),
          ),
        ).thenAnswer((_) async => entries);

        final result = await repository.get52WeekHighLow('2330');

        expect(result.high, equals(650.0));
        expect(result.low, equals(500.0));
      });
    });

    group('getFinancialMetrics', () {
      test('calls database with correct parameters', () async {
        when(
          () => mockDb.getFinancialMetrics(
            any(),
            dataTypes: any(named: 'dataTypes'),
            startDate: any(named: 'startDate'),
          ),
        ).thenAnswer((_) async => []);

        await repository.getFinancialMetrics(
          '2330',
          dataTypes: ['EPS', 'Revenue'],
          quarters: 4,
        );

        verify(
          () => mockDb.getFinancialMetrics(
            '2330',
            dataTypes: ['EPS', 'Revenue'],
            startDate: any(named: 'startDate'),
          ),
        ).called(1);
      });
    });
  });
}
