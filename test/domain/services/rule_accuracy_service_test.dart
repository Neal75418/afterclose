// Unit tests for [RuleAccuracyService] covering Stage 2 Commit 1 scope:
//   1. `holdingPeriods` constant includes 60D
//   2. Per-period success threshold parameterization (5D≥3%, 10D≥5%, 20D≥8%, 60D≥12%)
//   3. Fallback `returnRate >= 0` for periods without explicit threshold (1D/3D)
//
// Gap 1 fix (primary_rule_id bias) is Stage 2 Commit 2 — tested separately there.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/utils/taiwan_calendar.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/rule_accuracy_service.dart';

void main() {
  late AppDatabase db;
  late RuleAccuracyService service;

  setUp(() {
    db = AppDatabase.forTesting();
    service = RuleAccuracyService(database: db);
  });

  tearDown(() async {
    await db.close();
  });

  // ========================================================================
  // holdingPeriods constant — Stage 2 adds 60D for long-horizon calibration
  // ========================================================================

  group('holdingPeriods constant', () {
    test('includes 60D for long-horizon calibration', () {
      expect(RuleAccuracyService.holdingPeriods, contains(60));
    });

    test('preserves legacy 1/3/5/10/20 periods', () {
      expect(
        RuleAccuracyService.holdingPeriods,
        containsAll([1, 3, 5, 10, 20]),
      );
    });

    test('exact ordering [1, 3, 5, 10, 20, 60]', () {
      expect(
        RuleAccuracyService.holdingPeriods,
        orderedEquals([1, 3, 5, 10, 20, 60]),
      );
    });
  });

  // ========================================================================
  // Parameterized success threshold — verify via backfill end-to-end
  // ========================================================================

  group('Per-period success threshold', () {
    /// Seed DB with one stock, one recommendation, entry + exit prices that
    /// produce the requested [returnRatePct] over [period] trading days.
    Future<void> seedScenario({
      required String symbol,
      required DateTime entryDate,
      required int period,
      required double returnRatePct,
      String reasonType = 'TECH_BREAKOUT',
    }) async {
      const entryPrice = 100.0;
      final exitPrice = entryPrice * (1 + returnRatePct / 100);
      final exitDate = TaiwanCalendar.addTradingDays(entryDate, period);

      await db.upsertStocks([
        StockMasterCompanion.insert(
          symbol: symbol,
          name: 'Test',
          market: 'TWSE',
        ),
      ]);

      await db.insertPrices([
        DailyPriceCompanion.insert(
          symbol: symbol,
          date: entryDate,
          close: const Value(entryPrice),
        ),
        DailyPriceCompanion.insert(
          symbol: symbol,
          date: exitDate,
          close: Value(exitPrice),
        ),
      ]);

      await db.insertAnalysis(
        DailyAnalysisCompanion.insert(
          symbol: symbol,
          date: entryDate,
          trendState: 'UP',
          score: const Value(50.0),
        ),
      );

      await db.insertRecommendations([
        DailyRecommendationCompanion.insert(
          symbol: symbol,
          date: entryDate,
          rank: 1,
          score: 50.0,
        ),
      ]);

      await db.insertReasons([
        DailyReasonCompanion.insert(
          symbol: symbol,
          date: entryDate,
          reasonType: reasonType,
          rank: 0,
          evidenceJson: '{}',
          ruleScore: const Value(25.0),
        ),
      ]);
    }

    /// Query the single validation row for the given period.
    Future<RecommendationValidationEntry?> fetchValidation(int period) {
      return (db.select(
        db.recommendationValidation,
      )..where((t) => t.holdingDays.equals(period))).getSingleOrNull();
    }

    // ---- 5D threshold = 3% ----

    test(
      '5D: returnRate 2.9% does NOT count as success (below 3% threshold)',
      () async {
        await seedScenario(
          symbol: '2330',
          entryDate: DateTime.utc(2026, 1, 5),
          period: 5,
          returnRatePct: 2.9,
        );

        await service.backfillAllHistoricalRecommendations();

        final row = await fetchValidation(5);
        expect(row, isNotNull);
        expect(row!.returnRate, closeTo(2.9, 0.001));
        expect(
          row.isSuccess,
          isFalse,
          reason: '2.9% < 3% threshold → not a success',
        );
      },
    );

    test(
      '5D: returnRate 3.0% counts as success (boundary, inclusive)',
      () async {
        await seedScenario(
          symbol: '2330',
          entryDate: DateTime.utc(2026, 1, 5),
          period: 5,
          returnRatePct: 3.0,
        );

        await service.backfillAllHistoricalRecommendations();

        final row = await fetchValidation(5);
        expect(row, isNotNull);
        expect(row!.returnRate, closeTo(3.0, 0.001));
        expect(
          row.isSuccess,
          isTrue,
          reason: '3.0% ≥ 3% threshold (inclusive) → success',
        );
      },
    );

    // ---- 60D threshold = 12% ----

    test('60D: returnRate 11.9% does NOT count as success', () async {
      await seedScenario(
        symbol: '2330',
        entryDate: DateTime.utc(2026, 1, 5),
        period: 60,
        returnRatePct: 11.9,
      );

      await service.backfillAllHistoricalRecommendations();

      final row = await fetchValidation(60);
      expect(row, isNotNull);
      expect(row!.returnRate, closeTo(11.9, 0.001));
      expect(
        row.isSuccess,
        isFalse,
        reason: '11.9% < 12% threshold → not a success',
      );
    });

    test(
      '60D: returnRate 12.0% counts as success (boundary, inclusive)',
      () async {
        await seedScenario(
          symbol: '2330',
          entryDate: DateTime.utc(2026, 1, 5),
          period: 60,
          returnRatePct: 12.0,
        );

        await service.backfillAllHistoricalRecommendations();

        final row = await fetchValidation(60);
        expect(row, isNotNull);
        expect(row!.returnRate, closeTo(12.0, 0.001));
        expect(
          row.isSuccess,
          isTrue,
          reason: '12.0% ≥ 12% threshold (inclusive) → success',
        );
      },
    );

    // ---- Fallback: 1D uses non-negative baseline (no explicit threshold) ----

    test(
      '1D fallback: returnRate 0.1% counts as success (≥ 0 baseline)',
      () async {
        await seedScenario(
          symbol: '2330',
          entryDate: DateTime.utc(2026, 1, 5),
          period: 1,
          returnRatePct: 0.1,
        );

        await service.backfillAllHistoricalRecommendations();

        final row = await fetchValidation(1);
        expect(row, isNotNull);
        expect(
          row!.isSuccess,
          isTrue,
          reason: '1D falls back to ≥ 0 baseline → 0.1% is success',
        );
      },
    );

    test('1D fallback: returnRate -0.1% does NOT count as success', () async {
      await seedScenario(
        symbol: '2330',
        entryDate: DateTime.utc(2026, 1, 5),
        period: 1,
        returnRatePct: -0.1,
      );

      await service.backfillAllHistoricalRecommendations();

      final row = await fetchValidation(1);
      expect(row, isNotNull);
      expect(
        row!.isSuccess,
        isFalse,
        reason: 'Negative return fails ≥ 0 baseline',
      );
    });
  });
}
