import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/data/repositories/shareholding_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

class MockFinMindClient extends Mock implements FinMindClient {}

void main() {
  late MockAppDatabase mockDb;
  late MockFinMindClient mockClient;
  late ShareholdingRepository repo;

  setUp(() {
    mockDb = MockAppDatabase();
    mockClient = MockFinMindClient();
    repo = ShareholdingRepository(database: mockDb, finMindClient: mockClient);
  });

  // ==========================================
  // syncShareholding
  // ==========================================
  group('syncShareholding', () {
    test('skips when latest data is same day as target', () async {
      final targetDate = DateTime(2025, 1, 15);
      when(() => mockDb.getLatestShareholding(any())).thenAnswer(
        (_) async => ShareholdingEntry(symbol: '2330', date: targetDate),
      );

      final result = await repo.syncShareholding(
        '2330',
        startDate: DateTime(2025, 1, 1),
        endDate: targetDate,
      );

      expect(result, equals(0));
      verifyNever(
        () => mockClient.getShareholding(
          stockId: any(named: 'stockId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      );
    });

    test('fetches and inserts data when not fresh', () async {
      when(
        () => mockDb.getLatestShareholding(any()),
      ).thenAnswer((_) async => null);
      when(
        () => mockClient.getShareholding(
          stockId: any(named: 'stockId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer(
        (_) async => [
          const FinMindShareholding(
            stockId: '2330',
            date: '2025-01-15',
            foreignInvestmentRemainingShares: 5000000,
            foreignInvestmentSharesRatio: 75.5,
            foreignInvestmentUpperLimitRatio: 100.0,
            chineseInvestmentUpperLimitRatio: 0.0,
            numberOfSharesIssued: 25930381,
            recentlyDeclareDate: '',
            note: '',
          ),
        ],
      );
      when(() => mockDb.insertShareholdingData(any())).thenAnswer((_) async {});

      final result = await repo.syncShareholding(
        '2330',
        startDate: DateTime(2025, 1, 1),
      );

      expect(result, equals(1));
      verify(() => mockDb.insertShareholdingData(any())).called(1);
    });

    test('rethrows RateLimitException', () async {
      when(
        () => mockDb.getLatestShareholding(any()),
      ).thenAnswer((_) async => null);
      when(
        () => mockClient.getShareholding(
          stockId: any(named: 'stockId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenThrow(const RateLimitException('Rate limited'));

      expect(
        () => repo.syncShareholding('2330', startDate: DateTime(2025, 1, 1)),
        throwsA(isA<RateLimitException>()),
      );
    });
  });

  // ==========================================
  // isForeignShareholdingIncreasing
  // ==========================================
  group('isForeignShareholdingIncreasing', () {
    test('returns false when insufficient data', () async {
      when(
        () => mockDb.getShareholdingHistory(
          any(),
          startDate: any(named: 'startDate'),
        ),
      ).thenAnswer((_) async => []);

      final result = await repo.isForeignShareholdingIncreasing('2330');

      expect(result, isFalse);
    });

    test('returns true when ratio increased', () async {
      final now = DateTime.now();
      final entries = [
        ShareholdingEntry(
          symbol: '2330',
          date: now.subtract(const Duration(days: 5)),
          foreignSharesRatio: 70.0,
        ),
        ShareholdingEntry(
          symbol: '2330',
          date: now.subtract(const Duration(days: 4)),
          foreignSharesRatio: 71.0,
        ),
        ShareholdingEntry(
          symbol: '2330',
          date: now.subtract(const Duration(days: 3)),
          foreignSharesRatio: 72.0,
        ),
        ShareholdingEntry(
          symbol: '2330',
          date: now.subtract(const Duration(days: 2)),
          foreignSharesRatio: 73.0,
        ),
        ShareholdingEntry(
          symbol: '2330',
          date: now.subtract(const Duration(days: 1)),
          foreignSharesRatio: 75.0,
        ),
      ];

      when(
        () => mockDb.getShareholdingHistory(
          any(),
          startDate: any(named: 'startDate'),
        ),
      ).thenAnswer((_) async => entries);

      final result = await repo.isForeignShareholdingIncreasing('2330');

      expect(result, isTrue);
    });

    test('returns false when ratio decreased', () async {
      final now = DateTime.now();
      final entries = [
        ShareholdingEntry(
          symbol: '2330',
          date: now.subtract(const Duration(days: 5)),
          foreignSharesRatio: 80.0,
        ),
        ShareholdingEntry(
          symbol: '2330',
          date: now.subtract(const Duration(days: 4)),
          foreignSharesRatio: 78.0,
        ),
        ShareholdingEntry(
          symbol: '2330',
          date: now.subtract(const Duration(days: 3)),
          foreignSharesRatio: 77.0,
        ),
        ShareholdingEntry(
          symbol: '2330',
          date: now.subtract(const Duration(days: 2)),
          foreignSharesRatio: 75.0,
        ),
        ShareholdingEntry(
          symbol: '2330',
          date: now.subtract(const Duration(days: 1)),
          foreignSharesRatio: 73.0,
        ),
      ];

      when(
        () => mockDb.getShareholdingHistory(
          any(),
          startDate: any(named: 'startDate'),
        ),
      ).thenAnswer((_) async => entries);

      final result = await repo.isForeignShareholdingIncreasing('2330');

      expect(result, isFalse);
    });
  });

  // ==========================================
  // syncHoldingDistribution
  // ==========================================
  group('syncHoldingDistribution', () {
    test('skips when latest date is same week', () async {
      // Today is a weekday, latest data is from this week
      final now = DateTime.now();
      when(
        () => mockDb.getLatestHoldingDistributionDate(any()),
      ).thenAnswer((_) async => now);

      final result = await repo.syncHoldingDistribution(
        '2330',
        startDate: DateTime(2025, 1, 1),
      );

      expect(result, equals(0));
      verifyNever(
        () => mockClient.getHoldingSharesPer(
          stockId: any(named: 'stockId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      );
    });

    test('rethrows RateLimitException', () async {
      when(
        () => mockDb.getLatestHoldingDistributionDate(any()),
      ).thenAnswer((_) async => null);
      when(
        () => mockClient.getHoldingSharesPer(
          stockId: any(named: 'stockId'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenThrow(const RateLimitException('Rate limited'));

      expect(
        () => repo.syncHoldingDistribution(
          '2330',
          startDate: DateTime(2025, 1, 1),
        ),
        throwsA(isA<RateLimitException>()),
      );
    });
  });

  // ==========================================
  // getConcentrationRatio
  // ==========================================
  group('getConcentrationRatio', () {
    test('returns null when distribution is empty', () async {
      when(
        () => mockDb.getLatestHoldingDistribution(any()),
      ).thenAnswer((_) async => []);

      final result = await repo.getConcentrationRatio('2330');

      expect(result, isNull);
    });

    test('sums percentages for levels above threshold', () async {
      when(() => mockDb.getLatestHoldingDistribution(any())).thenAnswer(
        (_) async => [
          HoldingDistributionEntry(
            symbol: '2330',
            date: DateTime(2025, 1, 15),
            level: '1-999',
            percent: 30.0,
          ),
          HoldingDistributionEntry(
            symbol: '2330',
            date: DateTime(2025, 1, 15),
            level: '400-600',
            percent: 15.0,
          ),
          HoldingDistributionEntry(
            symbol: '2330',
            date: DateTime(2025, 1, 15),
            level: '600-800',
            percent: 10.0,
          ),
          HoldingDistributionEntry(
            symbol: '2330',
            date: DateTime(2025, 1, 15),
            level: '1000以上',
            percent: 20.0,
          ),
        ],
      );

      final result = await repo.getConcentrationRatio('2330');

      // threshold=400: 400-600 (15%) + 600-800 (10%) + 1000以上 (20%) = 45%
      expect(result, closeTo(45.0, 0.1));
    });

    test('parses "over" format in level string', () async {
      when(() => mockDb.getLatestHoldingDistribution(any())).thenAnswer(
        (_) async => [
          HoldingDistributionEntry(
            symbol: '2330',
            date: DateTime(2025, 1, 15),
            level: 'over 1000',
            percent: 25.0,
          ),
        ],
      );

      final result = await repo.getConcentrationRatio('2330');

      expect(result, closeTo(25.0, 0.1));
    });
  });

  // ==========================================
  // Delegation
  // ==========================================
  group('delegation', () {
    test('getLatestShareholding delegates to db', () async {
      when(
        () => mockDb.getLatestShareholding(any()),
      ).thenAnswer((_) async => null);

      await repo.getLatestShareholding('2330');

      verify(() => mockDb.getLatestShareholding('2330')).called(1);
    });

    test('getLatestHoldingDistribution delegates to db', () async {
      when(
        () => mockDb.getLatestHoldingDistribution(any()),
      ).thenAnswer((_) async => []);

      await repo.getLatestHoldingDistribution('2330');

      verify(() => mockDb.getLatestHoldingDistribution('2330')).called(1);
    });
  });
}
