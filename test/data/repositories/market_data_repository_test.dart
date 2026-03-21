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
