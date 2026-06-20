import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/core/constants/calibrated_scores/horizon.dart';

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
            scoreShort: const Value(80.0),
            scoreLong: const Value(80.0),
          ),
        );
        await db.insertAnalysis(
          DailyAnalysisCompanion.insert(
            symbol: '2317',
            date: today,
            trendState: 'DOWN',
            scoreShort: const Value(30.0),
            scoreLong: const Value(30.0),
          ),
        );
        await db.insertAnalysis(
          DailyAnalysisCompanion.insert(
            symbol: '2454',
            date: today,
            trendState: 'UP',
            scoreShort: const Value(50.0),
            scoreLong: const Value(50.0),
          ),
        );

        final analyses = await db.getAnalysisForDate(
          today,
          horizon: Horizon.short,
        );

        expect(analyses.length, 3);
        expect(analyses[0].symbol, '2330');
        expect(analyses[1].symbol, '2454');
        expect(analyses[2].symbol, '2317');
      });

      test('returns empty list for date with no data', () async {
        final analyses = await db.getAnalysisForDate(
          today,
          horizon: Horizon.short,
        );

        expect(analyses, isEmpty);
      });
    });

    group('getAnalysis', () {
      test('returns analysis for specific symbol and date', () async {
        await db.insertAnalysis(
          DailyAnalysisCompanion.insert(
            symbol: '2330',
            date: today,
            trendState: 'UP',
            scoreShort: const Value(80.0),
            scoreLong: const Value(80.0),
          ),
        );

        final analysis = await db.getAnalysis('2330', today);

        expect(analysis, isNotNull);
        expect(analysis!.trendState, 'UP');
        expect(analysis.scoreShort, 80.0);
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
            scoreShort: const Value(50.0),
            scoreLong: const Value(50.0),
          ),
        );
        await db.insertAnalysis(
          DailyAnalysisCompanion.insert(
            symbol: '2330',
            date: today,
            trendState: 'DOWN',
            scoreShort: const Value(30.0),
            scoreLong: const Value(30.0),
          ),
        );

        final analysis = await db.getAnalysis('2330', today);

        expect(analysis!.trendState, 'DOWN');
        expect(analysis.scoreShort, 30.0);
      });
    });

    group('getAnalysesBatch', () {
      test('returns map of symbol to analysis', () async {
        await db.insertAnalysis(
          DailyAnalysisCompanion.insert(
            symbol: '2330',
            date: today,
            trendState: 'UP',
            scoreShort: const Value(80.0),
            scoreLong: const Value(80.0),
          ),
        );
        await db.insertAnalysis(
          DailyAnalysisCompanion.insert(
            symbol: '2317',
            date: today,
            trendState: 'DOWN',
            scoreShort: const Value(30.0),
            scoreLong: const Value(30.0),
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
            scoreShort: const Value(80.0),
            scoreLong: const Value(80.0),
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
            scoreShort: const Value(80.0),
            scoreLong: const Value(80.0),
          ),
        );
        await db.insertAnalysis(
          DailyAnalysisCompanion.insert(
            symbol: '2317',
            date: today,
            trendState: 'DOWN',
            scoreShort: const Value(30.0),
            scoreLong: const Value(30.0),
          ),
        );

        final deleted = await db.clearAnalysisForDate(today);

        expect(deleted, 2);

        final remaining = await db.getAnalysisForDate(
          today,
          horizon: Horizon.short,
        );
        expect(remaining, isEmpty);
      });

      test('does not affect other dates', () async {
        await db.insertAnalysis(
          DailyAnalysisCompanion.insert(
            symbol: '2330',
            date: today,
            trendState: 'UP',
            scoreShort: const Value(80.0),
            scoreLong: const Value(80.0),
          ),
        );
        await db.insertAnalysis(
          DailyAnalysisCompanion.insert(
            symbol: '2330',
            date: yesterday,
            trendState: 'UP',
            scoreShort: const Value(70.0),
            scoreLong: const Value(70.0),
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
            ruleScoreShort: const Value(18.0),
            ruleScoreLong: const Value(18.0),
            rank: 2,
          ),
          DailyReasonCompanion.insert(
            symbol: '2330',
            date: today,
            reasonType: 'PRICE_BREAKOUT',
            evidenceJson: '{}',
            ruleScoreShort: const Value(20.0),
            ruleScoreLong: const Value(20.0),
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
            ruleScoreShort: const Value(18.0),
            ruleScoreLong: const Value(18.0),
            rank: 1,
          ),
          DailyReasonCompanion.insert(
            symbol: '2317',
            date: today,
            reasonType: 'PRICE_BREAKOUT',
            evidenceJson: '{}',
            ruleScoreShort: const Value(20.0),
            ruleScoreLong: const Value(20.0),
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
            ruleScoreShort: const Value(10.0),
            ruleScoreLong: const Value(10.0),
            rank: 1,
          ),
        ]);

        await db.replaceReasons('2330', today, [
          DailyReasonCompanion.insert(
            symbol: '2330',
            date: today,
            reasonType: 'NEW_REASON_A',
            evidenceJson: '{"key": "value"}',
            ruleScoreShort: const Value(25.0),
            ruleScoreLong: const Value(25.0),
            rank: 1,
          ),
          DailyReasonCompanion.insert(
            symbol: '2330',
            date: today,
            reasonType: 'NEW_REASON_B',
            evidenceJson: '{}',
            ruleScoreShort: const Value(15.0),
            ruleScoreLong: const Value(15.0),
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
            ruleScoreShort: const Value(10.0),
            ruleScoreLong: const Value(10.0),
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
            ruleScoreShort: const Value(10.0),
            ruleScoreLong: const Value(10.0),
            rank: 1,
          ),
          DailyReasonCompanion.insert(
            symbol: '2317',
            date: today,
            reasonType: 'B',
            evidenceJson: '{}',
            ruleScoreShort: const Value(10.0),
            ruleScoreLong: const Value(10.0),
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
            horizon: Horizon.short.name,
          ),
          DailyRecommendationCompanion.insert(
            date: today,
            symbol: '2330',
            score: 80.0,
            rank: 1,
            horizon: Horizon.short.name,
          ),
        ]);

        final recommendations = await db.getRecommendations(
          today,
          horizon: Horizon.short,
        );

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
            horizon: Horizon.short.name,
          ),
        ]);

        await db.replaceRecommendations(today, Horizon.short, [
          DailyRecommendationCompanion.insert(
            date: today,
            symbol: '2317',
            score: 60.0,
            rank: 1,
            horizon: Horizon.short.name,
          ),
        ]);

        final recommendations = await db.getRecommendations(
          today,
          horizon: Horizon.short,
        );

        expect(recommendations.length, 1);
        expect(recommendations.first.symbol, '2317');
      });
    });
  });
}
