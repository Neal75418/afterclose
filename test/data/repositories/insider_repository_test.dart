import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/tpex_client.dart';
import 'package:afterclose/data/repositories/insider_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

class MockTpexClient extends Mock implements TpexClient {}

void main() {
  late MockAppDatabase mockDb;
  late MockTpexClient mockTpexClient;
  late InsiderRepository repository;

  setUp(() {
    mockDb = MockAppDatabase();
    mockTpexClient = MockTpexClient();
    repository = InsiderRepository(
      database: mockDb,
      tpexClient: mockTpexClient,
    );
  });

  group('InsiderRepository', () {
    group('hasConsecutiveSellingStreak', () {
      test('returns true when >= 3 consecutive months of decrease', () async {
        // 模擬連續 3 個月減持：30% -> 28% -> 26% -> 24%
        final history = [
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2025, 10, 15),
            insiderRatio: 30.0,
          ),
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2025, 11, 15),
            insiderRatio: 28.0,
          ),
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2025, 12, 15),
            insiderRatio: 26.0,
          ),
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2026, 1, 15),
            insiderRatio: 24.0,
          ),
        ];

        when(
          () => mockDb.getRecentInsiderHoldings('TEST', months: 4),
        ).thenAnswer((_) async => history);

        final result = await repository.hasConsecutiveSellingStreak(
          'TEST',
          months: 3,
        );

        expect(result, isTrue);
      });

      test('returns false when < 3 consecutive months of decrease', () async {
        // 僅 2 個月減持：30% -> 28% -> 26%
        final history = [
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2025, 11, 15),
            insiderRatio: 30.0,
          ),
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2025, 12, 15),
            insiderRatio: 28.0,
          ),
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2026, 1, 15),
            insiderRatio: 26.0,
          ),
        ];

        when(
          () => mockDb.getRecentInsiderHoldings('TEST', months: 4),
        ).thenAnswer((_) async => history);

        final result = await repository.hasConsecutiveSellingStreak(
          'TEST',
          months: 3,
        );

        expect(result, isFalse);
      });

      test('returns false when ratio increases mid-streak', () async {
        // 減持後增持：30% -> 28% -> 29% -> 27%
        final history = [
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2025, 10, 15),
            insiderRatio: 30.0,
          ),
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2025, 11, 15),
            insiderRatio: 28.0,
          ),
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2025, 12, 15),
            insiderRatio: 29.0, // 增持，重置計數
          ),
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2026, 1, 15),
            insiderRatio: 27.0,
          ),
        ];

        when(
          () => mockDb.getRecentInsiderHoldings('TEST', months: 4),
        ).thenAnswer((_) async => history);

        final result = await repository.hasConsecutiveSellingStreak(
          'TEST',
          months: 3,
        );

        expect(result, isFalse);
      });

      test('skips null values and continues streak', () async {
        // 中間有 null 值：30% -> 28% -> null -> 26% -> 24%
        final history = [
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2025, 9, 15),
            insiderRatio: 30.0,
          ),
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2025, 10, 15),
            insiderRatio: 28.0,
          ),
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2025, 11, 15),
            insiderRatio: null, // null 會被跳過
          ),
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2025, 12, 15),
            insiderRatio: 26.0,
          ),
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2026, 1, 15),
            insiderRatio: 24.0,
          ),
        ];

        when(
          () => mockDb.getRecentInsiderHoldings('TEST', months: 4),
        ).thenAnswer((_) async => history);

        final result = await repository.hasConsecutiveSellingStreak(
          'TEST',
          months: 3,
        );

        expect(result, isTrue);
      });

      test('returns false when insufficient data', () async {
        // 資料不足
        final history = [
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2025, 12, 15),
            insiderRatio: 28.0,
          ),
        ];

        when(
          () => mockDb.getRecentInsiderHoldings('TEST', months: 4),
        ).thenAnswer((_) async => history);

        final result = await repository.hasConsecutiveSellingStreak(
          'TEST',
          months: 3,
        );

        expect(result, isFalse);
      });

      // ==========================================
      // 邊界案例測試
      // ==========================================

      test('returns false when all values are null', () async {
        // 全部為 null
        final history = [
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2025, 10, 15),
            insiderRatio: null,
          ),
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2025, 11, 15),
            insiderRatio: null,
          ),
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2025, 12, 15),
            insiderRatio: null,
          ),
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2026, 1, 15),
            insiderRatio: null,
          ),
        ];

        when(
          () => mockDb.getRecentInsiderHoldings('TEST', months: 4),
        ).thenAnswer((_) async => history);

        final result = await repository.hasConsecutiveSellingStreak(
          'TEST',
          months: 3,
        );

        expect(result, isFalse);
      });

      test('returns false when values are equal (no change)', () async {
        // 持平不算減持
        final history = [
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2025, 10, 15),
            insiderRatio: 30.0,
          ),
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2025, 11, 15),
            insiderRatio: 30.0,
          ),
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2025, 12, 15),
            insiderRatio: 30.0,
          ),
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2026, 1, 15),
            insiderRatio: 30.0,
          ),
        ];

        when(
          () => mockDb.getRecentInsiderHoldings('TEST', months: 4),
        ).thenAnswer((_) async => history);

        final result = await repository.hasConsecutiveSellingStreak(
          'TEST',
          months: 3,
        );

        expect(result, isFalse);
      });

      test('returns false when history is empty', () async {
        when(
          () => mockDb.getRecentInsiderHoldings('TEST', months: 4),
        ).thenAnswer((_) async => []);

        final result = await repository.hasConsecutiveSellingStreak(
          'TEST',
          months: 3,
        );

        expect(result, isFalse);
      });

      test('skips zero values and continues streak', () async {
        // 零值應被跳過（與 null 同樣處理）
        final history = [
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2025, 9, 15),
            insiderRatio: 30.0,
          ),
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2025, 10, 15),
            insiderRatio: 28.0,
          ),
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2025, 11, 15),
            insiderRatio: 0.0, // 零值會被跳過
          ),
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2025, 12, 15),
            insiderRatio: 26.0,
          ),
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2026, 1, 15),
            insiderRatio: 24.0,
          ),
        ];

        when(
          () => mockDb.getRecentInsiderHoldings('TEST', months: 4),
        ).thenAnswer((_) async => history);

        final result = await repository.hasConsecutiveSellingStreak(
          'TEST',
          months: 3,
        );

        expect(result, isTrue);
      });
    });

    group('hasSignificantBuying', () {
      test('returns true when buying change >= threshold', () async {
        // 增持超過 5%：20% -> 26%
        final history = [
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2026, 1, 15),
            insiderRatio: 26.0,
          ),
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2025, 12, 15),
            insiderRatio: 20.0,
          ),
        ];

        when(
          () => mockDb.getRecentInsiderHoldings('TEST', months: 2),
        ).thenAnswer((_) async => history);

        final result = await repository.hasSignificantBuying(
          'TEST',
          threshold: 5.0,
        );

        expect(result, isTrue);
      });

      test('returns false when buying change < threshold', () async {
        // 增持不到 5%：20% -> 23%
        final history = [
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2026, 1, 15),
            insiderRatio: 23.0,
          ),
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2025, 12, 15),
            insiderRatio: 20.0,
          ),
        ];

        when(
          () => mockDb.getRecentInsiderHoldings('TEST', months: 2),
        ).thenAnswer((_) async => history);

        final result = await repository.hasSignificantBuying(
          'TEST',
          threshold: 5.0,
        );

        expect(result, isFalse);
      });

      test('returns false when decreasing', () async {
        // 減持：26% -> 20%
        final history = [
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2026, 1, 15),
            insiderRatio: 20.0,
          ),
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2025, 12, 15),
            insiderRatio: 26.0,
          ),
        ];

        when(
          () => mockDb.getRecentInsiderHoldings('TEST', months: 2),
        ).thenAnswer((_) async => history);

        final result = await repository.hasSignificantBuying(
          'TEST',
          threshold: 5.0,
        );

        expect(result, isFalse);
      });

      test('returns false when insufficient data', () async {
        // 僅一筆資料
        final history = [
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2026, 1, 15),
            insiderRatio: 26.0,
          ),
        ];

        when(
          () => mockDb.getRecentInsiderHoldings('TEST', months: 2),
        ).thenAnswer((_) async => history);

        final result = await repository.hasSignificantBuying(
          'TEST',
          threshold: 5.0,
        );

        expect(result, isFalse);
      });

      test('returns false when previous ratio is 0', () async {
        // 前期為 0（避免除以零）
        final history = [
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2026, 1, 15),
            insiderRatio: 26.0,
          ),
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2025, 12, 15),
            insiderRatio: 0.0,
          ),
        ];

        when(
          () => mockDb.getRecentInsiderHoldings('TEST', months: 2),
        ).thenAnswer((_) async => history);

        final result = await repository.hasSignificantBuying(
          'TEST',
          threshold: 5.0,
        );

        expect(result, isFalse);
      });

      // ==========================================
      // 邊界案例測試
      // ==========================================

      test('returns true when change exactly equals threshold', () async {
        // 剛好等於門檻：20% -> 25% (change = 5.0)
        final history = [
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2026, 1, 15),
            insiderRatio: 25.0,
          ),
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2025, 12, 15),
            insiderRatio: 20.0,
          ),
        ];

        when(
          () => mockDb.getRecentInsiderHoldings('TEST', months: 2),
        ).thenAnswer((_) async => history);

        final result = await repository.hasSignificantBuying(
          'TEST',
          threshold: 5.0,
        );

        expect(result, isTrue);
      });

      test('returns false when both values are null', () async {
        final history = [
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2026, 1, 15),
            insiderRatio: null,
          ),
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2025, 12, 15),
            insiderRatio: null,
          ),
        ];

        when(
          () => mockDb.getRecentInsiderHoldings('TEST', months: 2),
        ).thenAnswer((_) async => history);

        final result = await repository.hasSignificantBuying(
          'TEST',
          threshold: 5.0,
        );

        expect(result, isFalse);
      });

      test('returns false when latest is null', () async {
        final history = [
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2026, 1, 15),
            insiderRatio: null,
          ),
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2025, 12, 15),
            insiderRatio: 20.0,
          ),
        ];

        when(
          () => mockDb.getRecentInsiderHoldings('TEST', months: 2),
        ).thenAnswer((_) async => history);

        final result = await repository.hasSignificantBuying(
          'TEST',
          threshold: 5.0,
        );

        expect(result, isFalse);
      });

      test('returns false when previous ratio is negative', () async {
        // 前期為負值（無效資料）
        final history = [
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2026, 1, 15),
            insiderRatio: 26.0,
          ),
          _createInsiderHolding(
            symbol: 'TEST',
            date: DateTime(2025, 12, 15),
            insiderRatio: -5.0,
          ),
        ];

        when(
          () => mockDb.getRecentInsiderHoldings('TEST', months: 2),
        ).thenAnswer((_) async => history);

        final result = await repository.hasSignificantBuying(
          'TEST',
          threshold: 5.0,
        );

        expect(result, isFalse);
      });
    });

    group('isHighPledgeRisk', () {
      test('returns true when pledge ratio >= threshold', () async {
        final holding = _createInsiderHolding(
          symbol: 'TEST',
          date: DateTime(2026, 1, 15),
          pledgeRatio: 55.0,
        );

        when(
          () => mockDb.getLatestInsiderHolding('TEST'),
        ).thenAnswer((_) async => holding);

        final result = await repository.isHighPledgeRisk(
          'TEST',
          threshold: RuleParams.highPledgeRatioThreshold,
        );

        expect(result, isTrue);
      });

      test('returns false when pledge ratio < threshold', () async {
        final holding = _createInsiderHolding(
          symbol: 'TEST',
          date: DateTime(2026, 1, 15),
          pledgeRatio: 40.0,
        );

        when(
          () => mockDb.getLatestInsiderHolding('TEST'),
        ).thenAnswer((_) async => holding);

        final result = await repository.isHighPledgeRisk(
          'TEST',
          threshold: RuleParams.highPledgeRatioThreshold,
        );

        expect(result, isFalse);
      });

      test('returns false when no data', () async {
        when(
          () => mockDb.getLatestInsiderHolding('TEST'),
        ).thenAnswer((_) async => null);

        final result = await repository.isHighPledgeRisk(
          'TEST',
          threshold: RuleParams.highPledgeRatioThreshold,
        );

        expect(result, isFalse);
      });

      test('returns false when pledge ratio is null', () async {
        final holding = _createInsiderHolding(
          symbol: 'TEST',
          date: DateTime(2026, 1, 15),
          pledgeRatio: null,
        );

        when(
          () => mockDb.getLatestInsiderHolding('TEST'),
        ).thenAnswer((_) async => holding);

        final result = await repository.isHighPledgeRisk(
          'TEST',
          threshold: RuleParams.highPledgeRatioThreshold,
        );

        expect(result, isFalse);
      });

      // ==========================================
      // 邊界案例測試
      // ==========================================

      test('returns true when pledge ratio exactly equals threshold', () async {
        // 剛好等於門檻
        final holding = _createInsiderHolding(
          symbol: 'TEST',
          date: DateTime(2026, 1, 15),
          pledgeRatio: RuleParams.highPledgeRatioThreshold, // 50.0
        );

        when(
          () => mockDb.getLatestInsiderHolding('TEST'),
        ).thenAnswer((_) async => holding);

        final result = await repository.isHighPledgeRisk(
          'TEST',
          threshold: RuleParams.highPledgeRatioThreshold,
        );

        expect(result, isTrue);
      });

      test('returns false when pledge ratio is zero', () async {
        final holding = _createInsiderHolding(
          symbol: 'TEST',
          date: DateTime(2026, 1, 15),
          pledgeRatio: 0.0,
        );

        when(
          () => mockDb.getLatestInsiderHolding('TEST'),
        ).thenAnswer((_) async => holding);

        final result = await repository.isHighPledgeRisk(
          'TEST',
          threshold: RuleParams.highPledgeRatioThreshold,
        );

        expect(result, isFalse);
      });
    });

    group('getWatchlistHighPledgeStocks', () {
      test('returns stocks with pledge ratio >= threshold', () async {
        final holdings = {
          'HIGH1': _createInsiderHolding(
            symbol: 'HIGH1',
            date: DateTime(2026, 1, 15),
            pledgeRatio: 55.0,
          ),
          'LOW1': _createInsiderHolding(
            symbol: 'LOW1',
            date: DateTime(2026, 1, 15),
            pledgeRatio: 30.0,
          ),
          'HIGH2': _createInsiderHolding(
            symbol: 'HIGH2',
            date: DateTime(2026, 1, 15),
            pledgeRatio: 60.0,
          ),
        };

        when(
          () =>
              mockDb.getLatestInsiderHoldingsBatch(['HIGH1', 'LOW1', 'HIGH2']),
        ).thenAnswer((_) async => holdings);

        final result = await repository.getWatchlistHighPledgeStocks([
          'HIGH1',
          'LOW1',
          'HIGH2',
        ], threshold: 50.0);

        expect(result.length, equals(2));
        expect(result.keys, containsAll(['HIGH1', 'HIGH2']));
        expect(result.keys, isNot(contains('LOW1')));
      });

      test('returns empty map when no stocks in watchlist', () async {
        final result = await repository.getWatchlistHighPledgeStocks([]);

        expect(result, isEmpty);
      });

      // ==========================================
      // 邊界案例測試
      // ==========================================

      test('handles stocks with null pledge ratios', () async {
        final holdings = {
          'HIGH1': _createInsiderHolding(
            symbol: 'HIGH1',
            date: DateTime(2026, 1, 15),
            pledgeRatio: 55.0,
          ),
          'NULL1': _createInsiderHolding(
            symbol: 'NULL1',
            date: DateTime(2026, 1, 15),
            pledgeRatio: null, // null 應被當作 0 處理
          ),
        };

        when(
          () => mockDb.getLatestInsiderHoldingsBatch(['HIGH1', 'NULL1']),
        ).thenAnswer((_) async => holdings);

        final result = await repository.getWatchlistHighPledgeStocks([
          'HIGH1',
          'NULL1',
        ], threshold: 50.0);

        expect(result.length, equals(1));
        expect(result.keys, contains('HIGH1'));
        expect(result.keys, isNot(contains('NULL1')));
      });

      test('returns empty map when all stocks below threshold', () async {
        final holdings = {
          'LOW1': _createInsiderHolding(
            symbol: 'LOW1',
            date: DateTime(2026, 1, 15),
            pledgeRatio: 30.0,
          ),
          'LOW2': _createInsiderHolding(
            symbol: 'LOW2',
            date: DateTime(2026, 1, 15),
            pledgeRatio: 40.0,
          ),
        };

        when(
          () => mockDb.getLatestInsiderHoldingsBatch(['LOW1', 'LOW2']),
        ).thenAnswer((_) async => holdings);

        final result = await repository.getWatchlistHighPledgeStocks([
          'LOW1',
          'LOW2',
        ], threshold: 50.0);

        expect(result, isEmpty);
      });

      test(
        'includes stock when pledge ratio exactly equals threshold',
        () async {
          final holdings = {
            'EXACT': _createInsiderHolding(
              symbol: 'EXACT',
              date: DateTime(2026, 1, 15),
              pledgeRatio: 50.0, // 剛好等於門檻
            ),
          };

          when(
            () => mockDb.getLatestInsiderHoldingsBatch(['EXACT']),
          ).thenAnswer((_) async => holdings);

          final result = await repository.getWatchlistHighPledgeStocks([
            'EXACT',
          ], threshold: 50.0);

          expect(result.length, equals(1));
          expect(result.keys, contains('EXACT'));
        },
      );
    });
  });
}

/// 建立測試用 InsiderHoldingEntry
InsiderHoldingEntry _createInsiderHolding({
  required String symbol,
  required DateTime date,
  double? insiderRatio,
  double? pledgeRatio,
  double? sharesIssued,
}) {
  return InsiderHoldingEntry(
    symbol: symbol,
    date: date,
    insiderRatio: insiderRatio,
    pledgeRatio: pledgeRatio,
    sharesIssued: sharesIssued,
  );
}
