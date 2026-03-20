import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/data/repositories/market_data_repository.dart';

// Mocks
class MockAppDatabase extends Mock implements AppDatabase {}

class MockFinMindClient extends Mock implements FinMindClient {}

void main() {
  late MockAppDatabase mockDb;
  late MockFinMindClient mockFinMindClient;
  late MarketDataRepository repository;

  setUp(() {
    mockDb = MockAppDatabase();
    mockFinMindClient = MockFinMindClient();

    repository = MarketDataRepository(
      database: mockDb,
      finMindClient: mockFinMindClient,
    );
  });

  group('MarketDataRepository', () {
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
