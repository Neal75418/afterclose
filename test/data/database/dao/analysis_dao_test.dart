import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;

import 'package:afterclose/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  final today = DateTime.utc(2025, 6, 15);
  final yesterday = DateTime.utc(2025, 6, 14);

  setUp(() {
    db = AppDatabase.forTesting();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertTestStocks() async {
    await db.upsertStocks([
      StockMasterCompanion.insert(symbol: '2330', name: '台積電', market: 'TWSE'),
      StockMasterCompanion.insert(symbol: '2317', name: '鴻海', market: 'TWSE'),
      StockMasterCompanion.insert(symbol: '2454', name: '聯發科', market: 'TWSE'),
    ]);
  }

  group('AnalysisDao', () {
    setUp(() async {
      await insertTestStocks();
    });

    group('getAnalysisForDate', () {
      test('returns analyses sorted by score descending', () async {
        await db.insertAnalysis(
          DailyAnalysisCompanion.insert(
            symbol: '2330',
            date: today,
            trendState: 'UP',
            score: const Value(80.0),
          ),
        );
        await db.insertAnalysis(
          DailyAnalysisCompanion.insert(
            symbol: '2317',
            date: today,
            trendState: 'DOWN',
            score: const Value(30.0),
          ),
        );
        await db.insertAnalysis(
          DailyAnalysisCompanion.insert(
            symbol: '2454',
            date: today,
            trendState: 'UP',
            score: const Value(50.0),
          ),
        );

        final analyses = await db.getAnalysisForDate(today);

        expect(analyses.length, 3);
        expect(analyses[0].symbol, '2330');
        expect(analyses[1].symbol, '2454');
        expect(analyses[2].symbol, '2317');
      });

      test('returns empty list for date with no data', () async {
        final analyses = await db.getAnalysisForDate(today);

        expect(analyses, isEmpty);
      });
    });

    group('getAnalysisForDatePaginated', () {
      test('paginates results with positive scores only', () async {
        await db.insertAnalysis(
          DailyAnalysisCompanion.insert(
            symbol: '2330',
            date: today,
            trendState: 'UP',
            score: const Value(80.0),
          ),
        );
        await db.insertAnalysis(
          DailyAnalysisCompanion.insert(
            symbol: '2317',
            date: today,
            trendState: 'DOWN',
            score: const Value(0.0),
          ),
        );
        await db.insertAnalysis(
          DailyAnalysisCompanion.insert(
            symbol: '2454',
            date: today,
            trendState: 'UP',
            score: const Value(50.0),
          ),
        );

        // Page 1: limit=1, offset=0
        final page1 = await db.getAnalysisForDatePaginated(
          today,
          limit: 1,
          offset: 0,
        );

        expect(page1.length, 1);
        expect(page1.first.symbol, '2330');

        // Page 2: limit=1, offset=1
        final page2 = await db.getAnalysisForDatePaginated(
          today,
          limit: 1,
          offset: 1,
        );

        expect(page2.length, 1);
        expect(page2.first.symbol, '2454');

        // Page 3: no more positive-score entries
        final page3 = await db.getAnalysisForDatePaginated(
          today,
          limit: 1,
          offset: 2,
        );

        expect(page3, isEmpty);
      });

      test('excludes zero and negative scores', () async {
        await db.insertAnalysis(
          DailyAnalysisCompanion.insert(
            symbol: '2330',
            date: today,
            trendState: 'NEUTRAL',
            score: const Value(0.0),
          ),
        );
        await db.insertAnalysis(
          DailyAnalysisCompanion.insert(
            symbol: '2317',
            date: today,
            trendState: 'DOWN',
            score: const Value(-10.0),
          ),
        );

        final result = await db.getAnalysisForDatePaginated(
          today,
          limit: 10,
          offset: 0,
        );

        expect(result, isEmpty);
      });
    });

    group('getAnalysisCountForDate', () {
      test('counts only positive-score analyses', () async {
        await db.insertAnalysis(
          DailyAnalysisCompanion.insert(
            symbol: '2330',
            date: today,
            trendState: 'UP',
            score: const Value(80.0),
          ),
        );
        await db.insertAnalysis(
          DailyAnalysisCompanion.insert(
            symbol: '2317',
            date: today,
            trendState: 'NEUTRAL',
            score: const Value(0.0),
          ),
        );
        await db.insertAnalysis(
          DailyAnalysisCompanion.insert(
            symbol: '2454',
            date: today,
            trendState: 'UP',
            score: const Value(50.0),
          ),
        );

        final count = await db.getAnalysisCountForDate(today);

        expect(count, 2);
      });

      test('returns 0 for empty date', () async {
        final count = await db.getAnalysisCountForDate(today);

        expect(count, 0);
      });
    });

    group('getAnalysis', () {
      test('returns analysis for specific symbol and date', () async {
        await db.insertAnalysis(
          DailyAnalysisCompanion.insert(
            symbol: '2330',
            date: today,
            trendState: 'UP',
            score: const Value(80.0),
          ),
        );

        final analysis = await db.getAnalysis('2330', today);

        expect(analysis, isNotNull);
        expect(analysis!.trendState, 'UP');
        expect(analysis.score, 80.0);
      });

      test('returns null for non-existent entry', () async {
        final analysis = await db.getAnalysis('2330', today);

        expect(analysis, isNull);
      });
    });

    group('insertAnalysis', () {
      test('upserts on conflict', () async {
        await db.insertAnalysis(
          DailyAnalysisCompanion.insert(
            symbol: '2330',
            date: today,
            trendState: 'UP',
            score: const Value(50.0),
          ),
        );
        await db.insertAnalysis(
          DailyAnalysisCompanion.insert(
            symbol: '2330',
            date: today,
            trendState: 'DOWN',
            score: const Value(30.0),
          ),
        );

        final analysis = await db.getAnalysis('2330', today);

        expect(analysis!.trendState, 'DOWN');
        expect(analysis.score, 30.0);
      });
    });

    group('getAnalysesBatch', () {
      test('returns map of symbol to analysis', () async {
        await db.insertAnalysis(
          DailyAnalysisCompanion.insert(
            symbol: '2330',
            date: today,
            trendState: 'UP',
            score: const Value(80.0),
          ),
        );
        await db.insertAnalysis(
          DailyAnalysisCompanion.insert(
            symbol: '2317',
            date: today,
            trendState: 'DOWN',
            score: const Value(30.0),
          ),
        );

        final result = await db.getAnalysesBatch(['2330', '2317'], today);

        expect(result.length, 2);
        expect(result['2330']!.trendState, 'UP');
        expect(result['2317']!.trendState, 'DOWN');
      });

      test('returns empty map for empty symbols', () async {
        final result = await db.getAnalysesBatch([], today);

        expect(result, isEmpty);
      });

      test('ignores symbols without data', () async {
        await db.insertAnalysis(
          DailyAnalysisCompanion.insert(
            symbol: '2330',
            date: today,
            trendState: 'UP',
            score: const Value(80.0),
          ),
        );

        final result = await db.getAnalysesBatch(['2330', '2317'], today);

        expect(result.length, 1);
        expect(result['2330'], isNotNull);
        expect(result['2317'], isNull);
      });
    });

    group('clearAnalysisForDate', () {
      test('removes all analyses for a date', () async {
        await db.insertAnalysis(
          DailyAnalysisCompanion.insert(
            symbol: '2330',
            date: today,
            trendState: 'UP',
            score: const Value(80.0),
          ),
        );
        await db.insertAnalysis(
          DailyAnalysisCompanion.insert(
            symbol: '2317',
            date: today,
            trendState: 'DOWN',
            score: const Value(30.0),
          ),
        );

        final deleted = await db.clearAnalysisForDate(today);

        expect(deleted, 2);

        final remaining = await db.getAnalysisForDate(today);
        expect(remaining, isEmpty);
      });

      test('does not affect other dates', () async {
        await db.insertAnalysis(
          DailyAnalysisCompanion.insert(
            symbol: '2330',
            date: today,
            trendState: 'UP',
            score: const Value(80.0),
          ),
        );
        await db.insertAnalysis(
          DailyAnalysisCompanion.insert(
            symbol: '2330',
            date: yesterday,
            trendState: 'UP',
            score: const Value(70.0),
          ),
        );

        await db.clearAnalysisForDate(today);

        final yesterdayData = await db.getAnalysis('2330', yesterday);
        expect(yesterdayData, isNotNull);
      });
    });

    group('Reason operations', () {
      test('getReasons returns reasons sorted by rank', () async {
        await db.insertReasons([
          DailyReasonCompanion.insert(
            symbol: '2330',
            date: today,
            reasonType: 'VOLUME_SPIKE',
            evidenceJson: '{}',
            ruleScore: const Value(18.0),
            rank: 2,
          ),
          DailyReasonCompanion.insert(
            symbol: '2330',
            date: today,
            reasonType: 'PRICE_BREAKOUT',
            evidenceJson: '{}',
            ruleScore: const Value(20.0),
            rank: 1,
          ),
        ]);

        final reasons = await db.getReasons('2330', today);

        expect(reasons.length, 2);
        expect(reasons[0].reasonType, 'PRICE_BREAKOUT');
        expect(reasons[1].reasonType, 'VOLUME_SPIKE');
      });

      test('getReasonsBatch groups by symbol', () async {
        await db.insertReasons([
          DailyReasonCompanion.insert(
            symbol: '2330',
            date: today,
            reasonType: 'VOLUME_SPIKE',
            evidenceJson: '{}',
            ruleScore: const Value(18.0),
            rank: 1,
          ),
          DailyReasonCompanion.insert(
            symbol: '2317',
            date: today,
            reasonType: 'PRICE_BREAKOUT',
            evidenceJson: '{}',
            ruleScore: const Value(20.0),
            rank: 1,
          ),
        ]);

        final result = await db.getReasonsBatch(['2330', '2317'], today);

        expect(result['2330']?.length, 1);
        expect(result['2317']?.length, 1);
      });

      test('getReasonsBatch returns empty map for empty input', () async {
        final result = await db.getReasonsBatch([], today);

        expect(result, isEmpty);
      });

      test('replaceReasons atomically replaces', () async {
        await db.insertReasons([
          DailyReasonCompanion.insert(
            symbol: '2330',
            date: today,
            reasonType: 'OLD_REASON',
            evidenceJson: '{}',
            ruleScore: const Value(10.0),
            rank: 1,
          ),
        ]);

        await db.replaceReasons('2330', today, [
          DailyReasonCompanion.insert(
            symbol: '2330',
            date: today,
            reasonType: 'NEW_REASON_A',
            evidenceJson: '{"key": "value"}',
            ruleScore: const Value(25.0),
            rank: 1,
          ),
          DailyReasonCompanion.insert(
            symbol: '2330',
            date: today,
            reasonType: 'NEW_REASON_B',
            evidenceJson: '{}',
            ruleScore: const Value(15.0),
            rank: 2,
          ),
        ]);

        final reasons = await db.getReasons('2330', today);

        expect(reasons.length, 2);
        expect(reasons[0].reasonType, 'NEW_REASON_A');
        expect(reasons[1].reasonType, 'NEW_REASON_B');
      });

      test('replaceReasons with empty list clears reasons', () async {
        await db.insertReasons([
          DailyReasonCompanion.insert(
            symbol: '2330',
            date: today,
            reasonType: 'SOME_REASON',
            evidenceJson: '{}',
            ruleScore: const Value(10.0),
            rank: 1,
          ),
        ]);

        await db.replaceReasons('2330', today, []);

        final reasons = await db.getReasons('2330', today);
        expect(reasons, isEmpty);
      });

      test('clearReasonsForDate removes all reasons for a date', () async {
        await db.insertReasons([
          DailyReasonCompanion.insert(
            symbol: '2330',
            date: today,
            reasonType: 'A',
            evidenceJson: '{}',
            ruleScore: const Value(10.0),
            rank: 1,
          ),
          DailyReasonCompanion.insert(
            symbol: '2317',
            date: today,
            reasonType: 'B',
            evidenceJson: '{}',
            ruleScore: const Value(10.0),
            rank: 1,
          ),
        ]);

        final deleted = await db.clearReasonsForDate(today);

        expect(deleted, 2);
      });
    });

    group('Recommendation operations', () {
      test('getRecommendations returns sorted by rank', () async {
        await db.insertRecommendations([
          DailyRecommendationCompanion.insert(
            date: today,
            symbol: '2317',
            score: 40.0,
            rank: 2,
          ),
          DailyRecommendationCompanion.insert(
            date: today,
            symbol: '2330',
            score: 80.0,
            rank: 1,
          ),
        ]);

        final recommendations = await db.getRecommendations(today);

        expect(recommendations.length, 2);
        expect(recommendations[0].symbol, '2330');
        expect(recommendations[1].symbol, '2317');
      });

      test('replaceRecommendations atomically replaces', () async {
        await db.insertRecommendations([
          DailyRecommendationCompanion.insert(
            date: today,
            symbol: '2330',
            score: 80.0,
            rank: 1,
          ),
        ]);

        await db.replaceRecommendations(today, [
          DailyRecommendationCompanion.insert(
            date: today,
            symbol: '2317',
            score: 60.0,
            rank: 1,
          ),
        ]);

        final recommendations = await db.getRecommendations(today);

        expect(recommendations.length, 1);
        expect(recommendations.first.symbol, '2317');
      });

      test('wasSymbolRecommendedInRange returns correct result', () async {
        await db.insertRecommendations([
          DailyRecommendationCompanion.insert(
            date: yesterday,
            symbol: '2330',
            score: 80.0,
            rank: 1,
          ),
        ]);

        final was = await db.wasSymbolRecommendedInRange(
          '2330',
          startDate: DateTime.utc(2025, 6, 10),
          endDate: today,
        );
        expect(was, isTrue);

        final wasNot = await db.wasSymbolRecommendedInRange(
          '2317',
          startDate: DateTime.utc(2025, 6, 10),
          endDate: today,
        );
        expect(wasNot, isFalse);
      });

      test('getRecommendedSymbolsInRange returns all symbols', () async {
        await db.insertRecommendations([
          DailyRecommendationCompanion.insert(
            date: yesterday,
            symbol: '2330',
            score: 80.0,
            rank: 1,
          ),
          DailyRecommendationCompanion.insert(
            date: today,
            symbol: '2317',
            score: 60.0,
            rank: 1,
          ),
        ]);

        final symbols = await db.getRecommendedSymbolsInRange(
          startDate: DateTime.utc(2025, 6, 10),
          endDate: today,
        );

        expect(symbols, containsAll(['2330', '2317']));
      });

      test('getRecommendedSymbolsInRange returns empty for no data', () async {
        final symbols = await db.getRecommendedSymbolsInRange(
          startDate: DateTime.utc(2025, 6, 10),
          endDate: today,
        );

        expect(symbols, isEmpty);
      });
    });
  });
}
