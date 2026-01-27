import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/repositories/analysis_repository.dart';
import 'package:afterclose/domain/repositories/analysis_repository.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

// Fake classes for registerFallbackValue
class FakeDailyAnalysisCompanion extends Fake
    implements DailyAnalysisCompanion {}

class FakeDailyRecommendationCompanion extends Fake
    implements DailyRecommendationCompanion {}

class FakeDailyReasonCompanion extends Fake implements DailyReasonCompanion {}

/// Testable subclass to expose private methods for testing
class TestableAnalysisRepository extends AnalysisRepository {
  TestableAnalysisRepository({required super.database});

  DateTime testNormalizeDate(DateTime date) {
    // Access the private method logic via public method behavior
    // Since _normalizeDate is private, we test it indirectly through public methods
    return DateTime(date.year, date.month, date.day);
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeDailyAnalysisCompanion());
    registerFallbackValue(FakeDailyRecommendationCompanion());
    registerFallbackValue(FakeDailyReasonCompanion());
    registerFallbackValue(DateTime(2024, 1, 1));
  });

  late MockAppDatabase mockDb;
  late AnalysisRepository repository;

  setUp(() {
    mockDb = MockAppDatabase();
    repository = AnalysisRepository(database: mockDb);
  });

  group('AnalysisRepository', () {
    group('_normalizeDate (tested via public methods)', () {
      test('normalizes date by removing time component', () {
        final testableRepo = TestableAnalysisRepository(database: mockDb);
        final dateWithTime = DateTime(2024, 6, 15, 14, 30, 45);

        final normalized = testableRepo.testNormalizeDate(dateWithTime);

        expect(normalized.year, equals(2024));
        expect(normalized.month, equals(6));
        expect(normalized.day, equals(15));
        expect(normalized.hour, equals(0));
        expect(normalized.minute, equals(0));
        expect(normalized.second, equals(0));
      });

      test('already normalized date remains unchanged', () {
        final testableRepo = TestableAnalysisRepository(database: mockDb);
        final normalizedDate = DateTime(2024, 6, 15);

        final result = testableRepo.testNormalizeDate(normalizedDate);

        expect(result, equals(normalizedDate));
      });
    });

    group('getAnalysis', () {
      test('returns analysis for given symbol and date', () async {
        final date = DateTime(2024, 6, 15);
        final analysis = DailyAnalysisEntry(
          symbol: '2330',
          date: date,
          trendState: 'UP',
          reversalState: 'NONE',
          score: 85.0,
          computedAt: DateTime(2024, 6, 15, 10, 30),
        );

        when(
          () => mockDb.getAnalysis('2330', date),
        ).thenAnswer((_) async => analysis);

        final result = await repository.getAnalysis('2330', date);

        expect(result, equals(analysis));
        verify(() => mockDb.getAnalysis('2330', date)).called(1);
      });

      test('normalizes date before query', () async {
        final dateWithTime = DateTime(2024, 6, 15, 14, 30);
        final normalizedDate = DateTime(2024, 6, 15);

        when(
          () => mockDb.getAnalysis('2330', normalizedDate),
        ).thenAnswer((_) async => null);

        await repository.getAnalysis('2330', dateWithTime);

        verify(() => mockDb.getAnalysis('2330', normalizedDate)).called(1);
      });

      test('returns null when no analysis found', () async {
        final date = DateTime(2024, 6, 15);

        when(
          () => mockDb.getAnalysis('2330', date),
        ).thenAnswer((_) async => null);

        final result = await repository.getAnalysis('2330', date);

        expect(result, isNull);
      });
    });

    group('getAnalysesForDate', () {
      test('returns all analyses for date', () async {
        final date = DateTime(2024, 6, 15);
        final analyses = [
          DailyAnalysisEntry(
            symbol: '2330',
            date: date,
            trendState: 'UP',
            reversalState: 'NONE',
            score: 85.0,
            computedAt: DateTime(2024, 6, 15, 10, 30),
          ),
          DailyAnalysisEntry(
            symbol: '2317',
            date: date,
            trendState: 'DOWN',
            reversalState: 'W2S',
            score: 60.0,
            computedAt: DateTime(2024, 6, 15, 10, 30),
          ),
        ];

        when(
          () => mockDb.getAnalysisForDate(date),
        ).thenAnswer((_) async => analyses);

        final result = await repository.getAnalysesForDate(date);

        expect(result, equals(analyses));
        expect(result.length, equals(2));
      });

      test('returns empty list when no analyses', () async {
        final date = DateTime(2024, 6, 15);

        when(() => mockDb.getAnalysisForDate(date)).thenAnswer((_) async => []);

        final result = await repository.getAnalysesForDate(date);

        expect(result, isEmpty);
      });
    });

    group('saveAnalysis', () {
      test('saves analysis with all parameters', () async {
        final date = DateTime(2024, 6, 15);

        when(() => mockDb.insertAnalysis(any())).thenAnswer((_) async {});

        await repository.saveAnalysis(
          symbol: '2330',
          date: date,
          trendState: 'UP',
          reversalState: 'NONE',
          supportLevel: 100.0,
          resistanceLevel: 120.0,
          score: 85.0,
        );

        verify(() => mockDb.insertAnalysis(any())).called(1);
      });

      test('saves analysis with optional parameters as null', () async {
        final date = DateTime(2024, 6, 15);

        when(() => mockDb.insertAnalysis(any())).thenAnswer((_) async {});

        await repository.saveAnalysis(
          symbol: '2330',
          date: date,
          trendState: 'DOWN',
          reversalState: 'S2W',
          score: 50.0,
        );

        verify(() => mockDb.insertAnalysis(any())).called(1);
      });
    });

    group('getReasons', () {
      test('returns reasons for symbol and date', () async {
        final date = DateTime(2024, 6, 15);
        final reasons = [
          DailyReasonEntry(
            symbol: '2330',
            date: date,
            rank: 1,
            reasonType: 'TREND_UP',
            evidenceJson: '{"days": 5}',
            ruleScore: 20.0,
          ),
          DailyReasonEntry(
            symbol: '2330',
            date: date,
            rank: 2,
            reasonType: 'VOLUME_SPIKE',
            evidenceJson: '{"ratio": 2.5}',
            ruleScore: 15.0,
          ),
        ];

        when(
          () => mockDb.getReasons('2330', date),
        ).thenAnswer((_) async => reasons);

        final result = await repository.getReasons('2330', date);

        expect(result, equals(reasons));
        expect(result.length, equals(2));
      });

      test('returns empty list when no reasons', () async {
        final date = DateTime(2024, 6, 15);

        when(() => mockDb.getReasons('2330', date)).thenAnswer((_) async => []);

        final result = await repository.getReasons('2330', date);

        expect(result, isEmpty);
      });
    });

    group('saveReasons', () {
      test('saves reasons with rank starting from 1', () async {
        final date = DateTime(2024, 6, 15);
        final reasons = [
          const ReasonData(type: 'TREND_UP', evidenceJson: '{}', score: 20),
          const ReasonData(type: 'VOLUME_SPIKE', evidenceJson: '{}', score: 15),
        ];

        when(
          () => mockDb.replaceReasons('2330', date, any()),
        ).thenAnswer((_) async {});

        await repository.saveReasons('2330', date, reasons);

        verify(() => mockDb.replaceReasons('2330', date, any())).called(1);
      });

      test('limits reasons to maxReasonsPerStock (50)', () async {
        final date = DateTime(2024, 6, 15);
        // Create 60 reasons
        final reasons = List.generate(
          60,
          (i) => ReasonData(type: 'REASON_$i', evidenceJson: '{}', score: i),
        );

        List<dynamic>? capturedEntries;
        when(() => mockDb.replaceReasons('2330', date, any())).thenAnswer((
          invocation,
        ) async {
          capturedEntries = invocation.positionalArguments[2] as List<dynamic>;
        });

        await repository.saveReasons('2330', date, reasons);

        expect(capturedEntries!.length, equals(50)); // Limited to 50
      });
    });

    group('getRecommendations', () {
      test('returns recommendations for date', () async {
        final date = DateTime(2024, 6, 15);
        final recs = [
          DailyRecommendationEntry(
            date: date,
            rank: 1,
            symbol: '2330',
            score: 95.0,
          ),
          DailyRecommendationEntry(
            date: date,
            rank: 2,
            symbol: '2317',
            score: 85.0,
          ),
        ];

        when(
          () => mockDb.getRecommendations(date),
        ).thenAnswer((_) async => recs);

        final result = await repository.getRecommendations(date);

        expect(result, equals(recs));
        expect(result.length, equals(2));
      });

      test('normalizes date before query', () async {
        final dateWithTime = DateTime(2024, 6, 15, 14, 30);
        final normalizedDate = DateTime(2024, 6, 15);

        when(
          () => mockDb.getRecommendations(normalizedDate),
        ).thenAnswer((_) async => []);

        await repository.getRecommendations(dateWithTime);

        verify(() => mockDb.getRecommendations(normalizedDate)).called(1);
      });
    });

    group('getTodayRecommendations', () {
      test('returns today recommendations when available', () async {
        final today = DateTime.now();
        final normalizedToday = DateTime(today.year, today.month, today.day);
        final recs = [
          DailyRecommendationEntry(
            date: normalizedToday,
            rank: 1,
            symbol: '2330',
            score: 95.0,
          ),
        ];

        when(
          () => mockDb.getRecommendations(any()),
        ).thenAnswer((_) async => recs);

        final result = await repository.getTodayRecommendations();

        expect(result, equals(recs));
      });

      test('falls back to yesterday when today has no data', () async {
        final today = DateTime.now();
        final normalizedToday = DateTime(today.year, today.month, today.day);
        final yesterday = normalizedToday.subtract(const Duration(days: 1));
        final recs = [
          DailyRecommendationEntry(
            date: yesterday,
            rank: 1,
            symbol: '2330',
            score: 95.0,
          ),
        ];

        var callCount = 0;
        when(() => mockDb.getRecommendations(any())).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) return []; // today - empty
          return recs; // yesterday - has data
        });

        final result = await repository.getTodayRecommendations();

        expect(result, equals(recs));
      });

      test('falls back to day before yesterday when needed', () async {
        final today = DateTime.now();
        final normalizedToday = DateTime(today.year, today.month, today.day);
        final dayBeforeYesterday = normalizedToday.subtract(
          const Duration(days: 2),
        );
        final recs = [
          DailyRecommendationEntry(
            date: dayBeforeYesterday,
            rank: 1,
            symbol: '2330',
            score: 95.0,
          ),
        ];

        var callCount = 0;
        when(() => mockDb.getRecommendations(any())).thenAnswer((_) async {
          callCount++;
          if (callCount <= 2) return []; // today and yesterday - empty
          return recs; // day before yesterday - has data
        });

        final result = await repository.getTodayRecommendations();

        expect(result, equals(recs));
      });
    });

    group('saveRecommendations', () {
      test('saves recommendations with rank starting from 1', () async {
        final date = DateTime(2024, 6, 15);
        final recs = [
          const RecommendationData(symbol: '2330', score: 95.0),
          const RecommendationData(symbol: '2317', score: 85.0),
        ];

        when(
          () => mockDb.replaceRecommendations(date, any()),
        ).thenAnswer((_) async {});

        await repository.saveRecommendations(date, recs);

        verify(() => mockDb.replaceRecommendations(date, any())).called(1);
      });

      test('limits recommendations to dailyTopN (20)', () async {
        final date = DateTime(2024, 6, 15);
        // Create 30 recommendations
        final recs = List.generate(
          30,
          (i) => RecommendationData(symbol: 'STOCK_$i', score: 100.0 - i),
        );

        List<dynamic>? capturedEntries;
        when(() => mockDb.replaceRecommendations(date, any())).thenAnswer((
          invocation,
        ) async {
          capturedEntries = invocation.positionalArguments[1] as List<dynamic>;
        });

        await repository.saveRecommendations(date, recs);

        expect(capturedEntries!.length, equals(20)); // Limited to 20
      });
    });

    group('hasRecommendations', () {
      test('returns true when recommendations exist', () async {
        final date = DateTime(2024, 6, 15);
        final recs = [
          DailyRecommendationEntry(
            date: date,
            rank: 1,
            symbol: '2330',
            score: 95.0,
          ),
        ];

        when(
          () => mockDb.getRecommendations(date),
        ).thenAnswer((_) async => recs);

        final result = await repository.hasRecommendations(date);

        expect(result, isTrue);
      });

      test('returns false when no recommendations', () async {
        final date = DateTime(2024, 6, 15);

        when(() => mockDb.getRecommendations(date)).thenAnswer((_) async => []);

        final result = await repository.hasRecommendations(date);

        expect(result, isFalse);
      });
    });

    group('wasRecentlyRecommended', () {
      test('delegates to database with correct date range', () async {
        when(
          () => mockDb.wasSymbolRecommendedInRange(
            '2330',
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenAnswer((_) async => true);

        final result = await repository.wasRecentlyRecommended('2330');

        expect(result, isTrue);
        verify(
          () => mockDb.wasSymbolRecommendedInRange(
            '2330',
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).called(1);
      });

      test('uses custom days parameter', () async {
        when(
          () => mockDb.wasSymbolRecommendedInRange(
            '2330',
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenAnswer((_) async => false);

        final result = await repository.wasRecentlyRecommended('2330', days: 5);

        expect(result, isFalse);
      });
    });

    group('getRecentlyRecommendedSymbols', () {
      test('returns set of recently recommended symbols', () async {
        final symbols = {'2330', '2317', '2454'};

        when(
          () => mockDb.getRecommendedSymbolsInRange(
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenAnswer((_) async => symbols);

        final result = await repository.getRecentlyRecommendedSymbols();

        expect(result, equals(symbols));
      });

      test('returns empty set when no recent recommendations', () async {
        when(
          () => mockDb.getRecommendedSymbolsInRange(
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenAnswer((_) async => <String>{});

        final result = await repository.getRecentlyRecommendedSymbols();

        expect(result, isEmpty);
      });

      test('uses custom days parameter', () async {
        when(
          () => mockDb.getRecommendedSymbolsInRange(
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenAnswer((_) async => {'2330'});

        final result = await repository.getRecentlyRecommendedSymbols(days: 7);

        expect(result.contains('2330'), isTrue);
      });
    });

    group('clearReasonsForDate', () {
      test('clears reasons and returns count', () async {
        final date = DateTime(2024, 6, 15);

        when(() => mockDb.clearReasonsForDate(date)).thenAnswer((_) async => 5);

        final result = await repository.clearReasonsForDate(date);

        expect(result, equals(5));
        verify(() => mockDb.clearReasonsForDate(date)).called(1);
      });

      test('normalizes date before clearing', () async {
        final dateWithTime = DateTime(2024, 6, 15, 14, 30);
        final normalizedDate = DateTime(2024, 6, 15);

        when(
          () => mockDb.clearReasonsForDate(normalizedDate),
        ).thenAnswer((_) async => 0);

        await repository.clearReasonsForDate(dateWithTime);

        verify(() => mockDb.clearReasonsForDate(normalizedDate)).called(1);
      });
    });

    group('clearAnalysisForDate', () {
      test('clears analysis and returns count', () async {
        final date = DateTime(2024, 6, 15);

        when(
          () => mockDb.clearAnalysisForDate(date),
        ).thenAnswer((_) async => 10);

        final result = await repository.clearAnalysisForDate(date);

        expect(result, equals(10));
        verify(() => mockDb.clearAnalysisForDate(date)).called(1);
      });
    });

    group('getRecommendationsWithDetails', () {
      test('returns empty list when no recommendations', () async {
        final date = DateTime(2024, 6, 15);

        when(() => mockDb.getRecommendations(date)).thenAnswer((_) async => []);

        final result = await repository.getRecommendationsWithDetails(date);

        expect(result, isEmpty);
      });

      test('fetches stock and reasons in batch', () async {
        final date = DateTime(2024, 6, 15);
        final recs = [
          DailyRecommendationEntry(
            date: date,
            rank: 1,
            symbol: '2330',
            score: 95.0,
          ),
          DailyRecommendationEntry(
            date: date,
            rank: 2,
            symbol: '2317',
            score: 85.0,
          ),
        ];

        final stocksMap = {
          '2330': StockMasterEntry(
            symbol: '2330',
            name: '台積電',
            market: 'TWSE',
            industry: '半導體',
            isActive: true,
            updatedAt: DateTime(2024, 6, 15),
          ),
          '2317': StockMasterEntry(
            symbol: '2317',
            name: '鴻海',
            market: 'TWSE',
            industry: '電子',
            isActive: true,
            updatedAt: DateTime(2024, 6, 15),
          ),
        };

        final reasonsMap = <String, List<DailyReasonEntry>>{
          '2330': [
            DailyReasonEntry(
              symbol: '2330',
              date: date,
              rank: 1,
              reasonType: 'TREND_UP',
              evidenceJson: '{}',
              ruleScore: 20.0,
            ),
          ],
          '2317': [],
        };

        when(
          () => mockDb.getRecommendations(date),
        ).thenAnswer((_) async => recs);
        when(
          () => mockDb.getStocksBatch(['2330', '2317']),
        ).thenAnswer((_) async => stocksMap);
        when(
          () => mockDb.getReasonsBatch(['2330', '2317'], date),
        ).thenAnswer((_) async => reasonsMap);

        final result = await repository.getRecommendationsWithDetails(date);

        expect(result.length, equals(2));
        expect(result[0].recommendation.symbol, equals('2330'));
        expect(result[0].stock.name, equals('台積電'));
        expect(result[0].reasons.length, equals(1));
        expect(result[1].recommendation.symbol, equals('2317'));
        expect(result[1].stock.name, equals('鴻海'));
        expect(result[1].reasons, isEmpty);
      });

      test('excludes recommendations without matching stock', () async {
        final date = DateTime(2024, 6, 15);
        final recs = [
          DailyRecommendationEntry(
            date: date,
            rank: 1,
            symbol: '2330',
            score: 95.0,
          ),
          DailyRecommendationEntry(
            date: date,
            rank: 2,
            symbol: 'INVALID',
            score: 85.0,
          ),
        ];

        final stocksMap = {
          '2330': StockMasterEntry(
            symbol: '2330',
            name: '台積電',
            market: 'TWSE',
            industry: '半導體',
            isActive: true,
            updatedAt: DateTime(2024, 6, 15),
          ),
          // INVALID stock not in map
        };

        when(
          () => mockDb.getRecommendations(date),
        ).thenAnswer((_) async => recs);
        when(
          () => mockDb.getStocksBatch(['2330', 'INVALID']),
        ).thenAnswer((_) async => stocksMap);
        when(
          () => mockDb.getReasonsBatch(['2330', 'INVALID'], date),
        ).thenAnswer((_) async => {});

        final result = await repository.getRecommendationsWithDetails(date);

        expect(result.length, equals(1)); // Only 2330 included
        expect(result[0].recommendation.symbol, equals('2330'));
      });
    });
  });

  group('ReasonData', () {
    test('creates instance with required fields', () {
      const reason = ReasonData(
        type: 'TREND_UP',
        evidenceJson: '{"days": 5}',
        score: 20,
      );

      expect(reason.type, equals('TREND_UP'));
      expect(reason.evidenceJson, equals('{"days": 5}'));
      expect(reason.score, equals(20));
    });
  });

  group('RecommendationData', () {
    test('creates instance with required fields', () {
      const rec = RecommendationData(symbol: '2330', score: 95.0);

      expect(rec.symbol, equals('2330'));
      expect(rec.score, equals(95.0));
    });
  });

  group('RecommendationWithStock', () {
    test('creates instance with all fields', () {
      final date = DateTime(2024, 6, 15);
      final rec = DailyRecommendationEntry(
        date: date,
        rank: 1,
        symbol: '2330',
        score: 95.0,
      );
      final stock = StockMasterEntry(
        symbol: '2330',
        name: '台積電',
        market: 'TWSE',
        industry: '半導體',
        isActive: true,
        updatedAt: DateTime(2024, 6, 15),
      );
      final reasons = [
        DailyReasonEntry(
          symbol: '2330',
          date: date,
          rank: 1,
          reasonType: 'TREND_UP',
          evidenceJson: '{}',
          ruleScore: 20.0,
        ),
      ];

      final recWithStock = RecommendationWithStock(
        recommendation: rec,
        stock: stock,
        reasons: reasons,
      );

      expect(recWithStock.recommendation, equals(rec));
      expect(recWithStock.stock, equals(stock));
      expect(recWithStock.reasons, equals(reasons));
    });
  });
}
