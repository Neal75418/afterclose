// Unit tests for [RuleAccuracyService] covering Stage 2 LEAN scope:
//   Commit 1 (additive):
//     1. `holdingPeriods` constant includes 60D
//     2. Per-period success threshold parameterization (5D≥3%, 10D≥5%, 20D≥8%, 60D≥12%)
//     3. Fallback `returnRate >= 0` for periods without explicit threshold (1D/3D)
//
//   Commit 2 (Gap 1 fix — primary_rule_id bias):
//     4. `_computeUnbiasedRuleStats` aggregates from `daily_reason` directly
//     5. All ranks counted, not just rank 0 primary
//     6. Multi-symbol and multi-date aggregation
//     7. Missing prices gracefully skipped

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/utils/taiwan_calendar.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/rule_accuracy_service.dart';
import 'package:afterclose/core/constants/calibrated_scores/horizon.dart';

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
          scoreShort: const Value(50.0),
          scoreLong: const Value(50.0),
        ),
      );

      await db.insertRecommendations([
        DailyRecommendationCompanion.insert(
          symbol: symbol,
          date: entryDate,
          rank: 1,
          score: 50.0,
          horizon: Horizon.short.name,
        ),
      ]);

      await db.insertReasons([
        DailyReasonCompanion.insert(
          symbol: symbol,
          date: entryDate,
          reasonType: reasonType,
          rank: 0,
          evidenceJson: '{}',
          ruleScoreShort: const Value(25.0),
          ruleScoreLong: const Value(25.0),
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

  // ========================================================================
  // Gap 1 fix — unbiased rule stats via daily_reason data source swap
  // ========================================================================
  //
  // The new `_computeUnbiasedRuleStats` reads every triggered reason in
  // `daily_reason` (not just the rank-0 primary) and aggregates per rule.
  // These tests verify the new flow directly, bypassing `daily_recommendation`
  // entirely — we seed reasons + prices only, skip the Top 20 tables.

  group('Gap 1 fix: unbiased rule stats from daily_reason', () {
    /// Seed `daily_reason` + `daily_price` without touching `daily_recommendation`.
    /// Calling `backfillAllHistoricalRecommendations()` in this state runs an
    /// empty backfill loop but still triggers `_updateRuleAccuracyStats` at end,
    /// which now routes to `_computeUnbiasedRuleStats`.
    Future<void> seedReason({
      required String symbol,
      required DateTime entryDate,
      required String reasonType,
      required int rank,
      required int periodDays,
      required double returnRatePct,
    }) async {
      const entryPrice = 100.0;
      final exitPrice = entryPrice * (1 + returnRatePct / 100);
      final exitDate = TaiwanCalendar.addTradingDays(entryDate, periodDays);

      await db.upsertStocks([
        StockMasterCompanion.insert(
          symbol: symbol,
          name: 'Test $symbol',
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

      await db.insertReasons([
        DailyReasonCompanion.insert(
          symbol: symbol,
          date: entryDate,
          reasonType: reasonType,
          rank: rank,
          evidenceJson: '{}',
          ruleScoreShort: const Value(25.0),
          ruleScoreLong: const Value(25.0),
        ),
      ]);
    }

    Future<RuleAccuracyEntry?> fetchRuleAccuracy(
      String ruleId, {
      required String period,
    }) {
      return (db.select(db.ruleAccuracy)
            ..where((t) => t.ruleId.equals(ruleId) & t.period.equals(period)))
          .getSingleOrNull();
    }

    test(
      'all triggered ranks counted (rank 0, 1, 2) — not only rank 0 primary',
      () async {
        final entry = DateTime.utc(2026, 1, 5);

        // Three distinct rules triggered on the same stock + date at different
        // ranks. Old biased code would only count rank 0 (TECH_BREAKOUT).
        // New unbiased code counts all three.
        await seedReason(
          symbol: '2330',
          entryDate: entry,
          reasonType: 'TECH_BREAKOUT',
          rank: 0,
          periodDays: 5,
          returnRatePct: 4.0,
        );
        await seedReason(
          symbol: '2330',
          entryDate: entry,
          reasonType: 'VOLUME_SPIKE',
          rank: 1,
          periodDays: 5,
          returnRatePct: 4.0,
        );
        await seedReason(
          symbol: '2330',
          entryDate: entry,
          reasonType: 'REVERSAL_W2S',
          rank: 2,
          periodDays: 5,
          returnRatePct: 4.0,
        );

        await service.backfillAllHistoricalRecommendations();

        final rank0 = await fetchRuleAccuracy('TECH_BREAKOUT', period: '5D');
        final rank1 = await fetchRuleAccuracy('VOLUME_SPIKE', period: '5D');
        final rank2 = await fetchRuleAccuracy('REVERSAL_W2S', period: '5D');

        expect(rank0, isNotNull, reason: 'rank 0 primary must be counted');
        expect(
          rank1,
          isNotNull,
          reason: 'rank 1 non-primary must be counted (Gap 1 fix)',
        );
        expect(
          rank2,
          isNotNull,
          reason: 'rank 2 non-primary must be counted (Gap 1 fix)',
        );

        expect(rank0!.triggerCount, 1);
        expect(rank1!.triggerCount, 1);
        expect(rank2!.triggerCount, 1);

        // All three returns = 4% > 3% threshold → successCount = 1 each
        expect(rank0.successCount, 1);
        expect(rank1.successCount, 1);
        expect(rank2.successCount, 1);
      },
    );

    test('same rule across multiple symbols aggregated correctly', () async {
      final entry = DateTime.utc(2026, 1, 5);

      for (final symbol in ['2330', '2317', '2454']) {
        await seedReason(
          symbol: symbol,
          entryDate: entry,
          reasonType: 'VOLUME_SPIKE',
          rank: 0,
          periodDays: 5,
          returnRatePct: 5.0,
        );
      }

      await service.backfillAllHistoricalRecommendations();

      final stat = await fetchRuleAccuracy('VOLUME_SPIKE', period: '5D');
      expect(stat, isNotNull);
      expect(stat!.triggerCount, 3, reason: '3 symbols × 1 date = 3 triggers');
      expect(stat.successCount, 3, reason: '5% > 3% threshold for all 3');
      expect(stat.avgReturn, closeTo(5.0, 0.01));
    });

    test('ALL period is no longer written (removed 2026-04)', () async {
      // ALL period aggregation across holdingPeriods was removed because
      // 1D (threshold 0%) and 60D (threshold 12%) success_counts share a
      // denominator, producing a hit_rate that's mechanically inflated by
      // low-threshold samples and has no actionable interpretation.
      final entry = DateTime.utc(2026, 1, 5);

      await db.upsertStocks([
        StockMasterCompanion.insert(
          symbol: '2330',
          name: 'Test',
          market: 'TWSE',
        ),
      ]);
      await db.insertPrices([
        DailyPriceCompanion.insert(
          symbol: '2330',
          date: entry,
          close: const Value(100.0),
        ),
        DailyPriceCompanion.insert(
          symbol: '2330',
          date: TaiwanCalendar.addTradingDays(entry, 5),
          close: const Value(104.0),
        ),
        DailyPriceCompanion.insert(
          symbol: '2330',
          date: TaiwanCalendar.addTradingDays(entry, 60),
          close: const Value(115.0),
        ),
      ]);
      await db.insertReasons([
        DailyReasonCompanion.insert(
          symbol: '2330',
          date: entry,
          reasonType: 'TECH_BREAKOUT',
          rank: 0,
          evidenceJson: '{}',
        ),
      ]);

      await service.backfillAllHistoricalRecommendations();

      final fiveD = await fetchRuleAccuracy('TECH_BREAKOUT', period: '5D');
      final sixtyD = await fetchRuleAccuracy('TECH_BREAKOUT', period: '60D');
      final all = await fetchRuleAccuracy('TECH_BREAKOUT', period: 'ALL');

      expect(fiveD, isNotNull);
      expect(sixtyD, isNotNull);
      expect(all, isNull, reason: 'ALL period must not be written');
    });

    test('reason with no matching exit price does not corrupt stats', () async {
      final entry = DateTime.utc(2026, 1, 5);

      await db.upsertStocks([
        StockMasterCompanion.insert(
          symbol: '2330',
          name: 'Test',
          market: 'TWSE',
        ),
      ]);
      // Only entry price, no exit price → all periods should skip
      await db.insertPrices([
        DailyPriceCompanion.insert(
          symbol: '2330',
          date: entry,
          close: const Value(100.0),
        ),
      ]);
      await db.insertReasons([
        DailyReasonCompanion.insert(
          symbol: '2330',
          date: entry,
          reasonType: 'PATTERN_DOJI',
          rank: 0,
          evidenceJson: '{}',
        ),
      ]);

      await service.backfillAllHistoricalRecommendations();

      // No period has a valid exit price → PATTERN_DOJI should not appear
      // anywhere in rule_accuracy
      final allRows = await db.select(db.ruleAccuracy).get();
      final dojiRows = allRows
          .where((r) => r.ruleId == 'PATTERN_DOJI')
          .toList();
      expect(
        dojiRows,
        isEmpty,
        reason: 'No exit price → stats should be silently skipped',
      );
    });

    test(
      'empty daily_reason preserves existing rule_accuracy (empty guard)',
      () async {
        // Seed a valid pre-existing rule_accuracy row (as if from prior run)
        await db
            .into(db.ruleAccuracy)
            .insert(
              RuleAccuracyCompanion.insert(
                ruleId: 'EXISTING_RULE',
                period: '5D',
                triggerCount: const Value(50),
                successCount: const Value(30),
                avgReturn: const Value(4.5),
              ),
            );

        // Do NOT seed any daily_reason rows → empty state
        // This simulates "syncer failed / DB partially cleared" scenario

        await service.backfillAllHistoricalRecommendations();

        // Existing row must NOT be wiped by the empty-guard (Stage 2 code
        // review followup — see _computeUnbiasedRuleStats docstring).
        final existing = await fetchRuleAccuracy('EXISTING_RULE', period: '5D');
        expect(
          existing,
          isNotNull,
          reason:
              'empty daily_reason must preserve valid rule_accuracy; '
              'clearing it would destroy legitimately accumulated stats.',
        );
        expect(existing!.triggerCount, 50);
        expect(existing.successCount, 30);
        expect(existing.avgReturn, closeTo(4.5, 0.001));
      },
    );

    test('stale rule_accuracy rows cleared on recomputation', () async {
      // Manually insert a stale stat as if from old biased computation
      await db
          .into(db.ruleAccuracy)
          .insert(
            RuleAccuracyCompanion.insert(
              ruleId: 'STALE_RULE',
              period: '5D',
              triggerCount: const Value(999),
              successCount: const Value(999),
              avgReturn: const Value(99.9),
            ),
          );

      // Confirm it was inserted
      final before = await fetchRuleAccuracy('STALE_RULE', period: '5D');
      expect(before, isNotNull);
      expect(before!.triggerCount, 999);

      // Trigger recomputation with an unrelated, valid reason
      final entry = DateTime.utc(2026, 1, 5);
      await seedReason(
        symbol: '2330',
        entryDate: entry,
        reasonType: 'TECH_BREAKOUT',
        rank: 0,
        periodDays: 5,
        returnRatePct: 4.0,
      );
      await service.backfillAllHistoricalRecommendations();

      // Stale row should be gone
      final after = await fetchRuleAccuracy('STALE_RULE', period: '5D');
      expect(
        after,
        isNull,
        reason: 'Old biased stats must be cleared, not left to rot',
      );

      // New stats should exist
      final fresh = await fetchRuleAccuracy('TECH_BREAKOUT', period: '5D');
      expect(fresh, isNotNull);
      expect(fresh!.triggerCount, 1);
    });
  });

  // ==================================================
  // H1 regression: dual-horizon dailyRecommendation must filter to short
  // ==================================================
  //
  // Stage 5b 之後 daily_recommendation 每天可有 short + long 兩 rows（相同
  // symbol 也可能在兩個 horizon 都上榜）。_computeValidation 與
  // backfillAllHistoricalRecommendations 必須只取 short horizon — 否則
  // recommendation_validation 表 PK (date, symbol, holdingDays) 會被 long
  // row 覆蓋，UI 顯示的 primaryRuleId / returnRate 變成 last-write-wins
  // 不確定行為。
  group('H1 regression: short-only horizon filter on daily_recommendation', () {
    test(
      'long horizon recommendations are NOT validated even if same date',
      () async {
        final entry = DateTime.utc(2026, 1, 5);
        const entryPrice = 100.0;
        final exitDate = TaiwanCalendar.addTradingDays(entry, 5);

        await db.upsertStocks([
          StockMasterCompanion.insert(
            symbol: '2330',
            name: 'TSMC',
            market: 'TWSE',
          ),
          StockMasterCompanion.insert(
            symbol: '2454',
            name: 'MediaTek',
            market: 'TWSE',
          ),
        ]);

        await db.insertPrices([
          // 2330 entry/exit
          DailyPriceCompanion.insert(
            symbol: '2330',
            date: entry,
            close: const Value(entryPrice),
          ),
          DailyPriceCompanion.insert(
            symbol: '2330',
            date: exitDate,
            close: const Value(105.0), // +5% (above 5D 3% threshold → success)
          ),
          // 2454 entry/exit (long-only — should NOT show up in validation)
          DailyPriceCompanion.insert(
            symbol: '2454',
            date: entry,
            close: const Value(entryPrice),
          ),
          DailyPriceCompanion.insert(
            symbol: '2454',
            date: exitDate,
            close: const Value(110.0),
          ),
        ]);

        // 2330 上 short Top 20、2454 上 long Top 20 — 不同股票、同日。
        await db.insertRecommendations([
          DailyRecommendationCompanion.insert(
            symbol: '2330',
            date: entry,
            rank: 1,
            score: 80.0,
            horizon: Horizon.short.name,
          ),
          DailyRecommendationCompanion.insert(
            symbol: '2454',
            date: entry,
            rank: 1,
            score: 80.0,
            horizon: Horizon.long.name,
          ),
        ]);

        await service.backfillAllHistoricalRecommendations();

        // recommendation_validation 應該只看到 2330（short），2454（long）
        // 必須被 horizon filter 排除。
        final rows = await (db.select(
          db.recommendationValidation,
        )..where((t) => t.holdingDays.equals(5))).get();
        final symbols = rows.map((r) => r.symbol).toSet();
        expect(symbols, equals({'2330'}));
        expect(
          symbols.contains('2454'),
          isFalse,
          reason: 'long-horizon rec must not leak into validation table',
        );
      },
    );
  });
}
