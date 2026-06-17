import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/tpex_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/data/repositories/warning_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

class MockTpexClient extends Mock implements TpexClient {}

class MockTwseClient extends Mock implements TwseClient {}

void main() {
  late MockAppDatabase mockDb;
  late MockTpexClient mockTpexClient;
  late MockTwseClient mockTwseClient;
  late WarningRepository repository;

  setUp(() {
    mockDb = MockAppDatabase();
    mockTpexClient = MockTpexClient();
    mockTwseClient = MockTwseClient();
    repository = WarningRepository(
      database: mockDb,
      tpexClient: mockTpexClient,
      twseClient: mockTwseClient,
    );
  });

  group('WarningRepository', () {
    group('getWatchlistWarnings', () {
      test('returns only warnings for symbols in watchlist', () async {
        // 全市場有多筆警示，但只有部分在自選股中
        final allWarnings = [
          _createWarning(symbol: 'AAA', warningType: 'ATTENTION'),
          _createWarning(symbol: 'BBB', warningType: 'DISPOSAL'),
          _createWarning(symbol: 'CCC', warningType: 'ATTENTION'),
          _createWarning(symbol: 'DDD', warningType: 'ATTENTION'),
        ];

        when(
          () => mockDb.getAllActiveWarnings(),
        ).thenAnswer((_) async => allWarnings);

        final result = await repository.getWatchlistWarnings(['AAA', 'CCC']);

        expect(result.length, equals(2));
        expect(result.keys, containsAll(['AAA', 'CCC']));
        expect(result.keys, isNot(contains('BBB')));
        expect(result.keys, isNot(contains('DDD')));
      });

      test('DISPOSAL takes priority over ATTENTION for same symbol', () async {
        // 同一股票同時有注意和處置警示，處置優先
        final allWarnings = [
          _createWarning(symbol: 'TEST', warningType: 'ATTENTION'),
          _createWarning(symbol: 'TEST', warningType: 'DISPOSAL'),
        ];

        when(
          () => mockDb.getAllActiveWarnings(),
        ).thenAnswer((_) async => allWarnings);

        final result = await repository.getWatchlistWarnings(['TEST']);

        expect(result.length, equals(1));
        expect(result['TEST']!.warningType, equals('DISPOSAL'));
      });

      test('returns empty map when watchlist is empty', () async {
        final result = await repository.getWatchlistWarnings([]);

        expect(result, isEmpty);
        verifyNever(() => mockDb.getAllActiveWarnings());
      });

      test('returns empty map when no warnings match watchlist', () async {
        final allWarnings = [
          _createWarning(symbol: 'AAA', warningType: 'ATTENTION'),
          _createWarning(symbol: 'BBB', warningType: 'DISPOSAL'),
        ];

        when(
          () => mockDb.getAllActiveWarnings(),
        ).thenAnswer((_) async => allWarnings);

        final result = await repository.getWatchlistWarnings([
          'XXX',
          'YYY',
          'ZZZ',
        ]);

        expect(result, isEmpty);
      });
    });

    group('getDisposalStocksBatch', () {
      test('returns set of disposal symbols', () async {
        final disposalSet = {'AAA', 'CCC'};

        when(
          () => mockDb.getDisposalStocksBatch(['AAA', 'BBB', 'CCC']),
        ).thenAnswer((_) async => disposalSet);

        final result = await repository.getDisposalStocksBatch([
          'AAA',
          'BBB',
          'CCC',
        ]);

        expect(result, equals(disposalSet));
        expect(result.contains('AAA'), isTrue);
        expect(result.contains('BBB'), isFalse);
        expect(result.contains('CCC'), isTrue);
      });
    });

    group('getActiveAttentionStocks', () {
      test('delegates to database with ATTENTION type', () async {
        final warnings = [
          _createWarning(symbol: 'TEST', warningType: 'ATTENTION'),
        ];

        when(
          () => mockDb.getActiveWarningsByType('ATTENTION'),
        ).thenAnswer((_) async => warnings);

        final result = await repository.getActiveAttentionStocks();

        expect(result, equals(warnings));
        verify(() => mockDb.getActiveWarningsByType('ATTENTION')).called(1);
      });
    });

    group('getActiveDisposalStocks', () {
      test('delegates to database with DISPOSAL type', () async {
        final warnings = [
          _createWarning(symbol: 'TEST', warningType: 'DISPOSAL'),
        ];

        when(
          () => mockDb.getActiveWarningsByType('DISPOSAL'),
        ).thenAnswer((_) async => warnings);

        final result = await repository.getActiveDisposalStocks();

        expect(result, equals(warnings));
        verify(() => mockDb.getActiveWarningsByType('DISPOSAL')).called(1);
      });
    });
  });
}

/// 建立測試用 TradingWarningEntry
TradingWarningEntry _createWarning({
  required String symbol,
  required String warningType,
  String? reasonCode,
  String? reasonDescription,
  String? disposalMeasures,
  DateTime? disposalStartDate,
  DateTime? disposalEndDate,
  bool isActive = true,
}) {
  return TradingWarningEntry(
    symbol: symbol,
    date: DateTime.now(),
    warningType: warningType,
    reasonCode: reasonCode,
    reasonDescription: reasonDescription,
    disposalMeasures: disposalMeasures,
    disposalStartDate: disposalStartDate,
    disposalEndDate: disposalEndDate,
    isActive: isActive,
  );
}
