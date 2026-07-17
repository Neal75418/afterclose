// Unit tests for [RuleAccuracyService] covering the rule_accuracy keep-path
// after the recommendation_validation feature was retired (Step 2):
//   1. `holdingPeriods` constant includes 60D
//   2. Per-period success threshold parameterization
//      (5D≥1.5%, 60D≥8% — evidence-based 校正值; 1D/3D fall back to ≥0)
//   3. `updateRuleAccuracyStats` → `_computeUnbiasedRuleStats` aggregates from
//      `daily_reason` directly (all ranks counted, multi-symbol aggregation,
//      missing prices skipped, empty guard, stale-row clearing)
//
// `_computeUnbiasedRuleStats` also has end-to-end coverage in
// `test/tool/replay_calibrator_test.dart`; these tests focus on the public
// `updateRuleAccuracyStats` entry point + the threshold / empty-guard contract.

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

  /// Seed `daily_reason` + `daily_price` (signal day + next-day open entry +
  /// exit) for a single rule trigger that yields [returnRatePct] over
  /// [periodDays] trading days. Routes through `updateRuleAccuracyStats` →
  /// `_computeUnbiasedRuleStats`.
  ///
  /// Entry price is the **next trading day's open** (lookahead bias fix,
  /// audit finding #6) — set equal to [entryPrice] so [returnRatePct] keeps
  /// its documented meaning regardless of which price the engine reads as
  /// entry. When `periodDays == 1` the next trading day *is* the exit day,
  /// so both open (entry) and close (exit) are written on that single row.
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
    final nextTradingDate = TaiwanCalendar.addTradingDays(entryDate, 1);
    final exitDate = TaiwanCalendar.addTradingDays(entryDate, periodDays);

    await db.upsertStocks([
      StockMasterCompanion.insert(
        symbol: symbol,
        name: 'Test $symbol',
        market: 'TWSE',
      ),
    ]);

    final priceRows = <DailyPriceCompanion>[
      // 訊號當日 close：規則觸發賴以判斷的輸入，不再是 entry 價，仍寫入避免
      // 其他路徑誤讀 null。
      DailyPriceCompanion.insert(
        symbol: symbol,
        date: entryDate,
        close: const Value(entryPrice),
      ),
    ];
    if (nextTradingDate == exitDate) {
      // periodDays == 1：進場（隔日 open）與出場（同日 close）落在同一列。
      priceRows.add(
        DailyPriceCompanion.insert(
          symbol: symbol,
          date: nextTradingDate,
          open: const Value(entryPrice),
          close: Value(exitPrice),
        ),
      );
    } else {
      priceRows.add(
        DailyPriceCompanion.insert(
          symbol: symbol,
          date: nextTradingDate,
          open: const Value(entryPrice),
          close: const Value(entryPrice),
        ),
      );
      priceRows.add(
        DailyPriceCompanion.insert(
          symbol: symbol,
          date: exitDate,
          close: Value(exitPrice),
        ),
      );
    }
    await db.insertPrices(priceRows);

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

    // signal-tier daily_analysis：校準只學 ≥ minScoreThreshold 的股；少了這列，
    // 其 reason 會被新的 signal-tier 過濾擋掉、不進校準樣本。
    await db.insertAnalysis(
      DailyAnalysisCompanion.insert(
        symbol: symbol,
        date: entryDate,
        trendState: 'UP',
        scoreShort: const Value(99.0),
        scoreLong: const Value(99.0),
      ),
    );
  }

  Future<RuleAccuracyEntry?> fetchRuleAccuracy(
    String ruleId, {
    required String period,
  }) {
    return (db.select(db.ruleAccuracy)
          ..where((t) => t.ruleId.equals(ruleId) & t.period.equals(period)))
        .getSingleOrNull();
  }

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
  // Per-period success threshold — verify via rule_accuracy successCount
  // ========================================================================

  group('Per-period success threshold', () {
    // ---- 5D threshold = 1.5% ----

    test(
      '5D: returnRate 1.4% does NOT count as success (below 1.5% threshold)',
      () async {
        await seedReason(
          symbol: '2330',
          entryDate: DateTime.utc(2026, 1, 5),
          reasonType: 'TECH_BREAKOUT',
          rank: 0,
          periodDays: 5,
          returnRatePct: 1.4,
        );

        await service.updateRuleAccuracyStats();

        final row = await fetchRuleAccuracy('TECH_BREAKOUT', period: '5D');
        expect(row, isNotNull);
        expect(row!.triggerCount, 1);
        expect(row.avgReturn, closeTo(1.4, 0.01));
        expect(
          row.successCount,
          0,
          reason: '1.4% < 1.5% threshold → not a success',
        );
      },
    );

    test('5D: returnRate 1.51% counts as success (above boundary)', () async {
      // Boundary 用 1.51% 而非剛好 1.5%，因為內部用浮點算 entry/exit price，
      // 恰好 1.5% 可能落在 1.499... 微小於 threshold。取 1.51% 確保穩定通過
      // inclusive boundary 測試而不仰賴精度。
      await seedReason(
        symbol: '2330',
        entryDate: DateTime.utc(2026, 1, 5),
        reasonType: 'TECH_BREAKOUT',
        rank: 0,
        periodDays: 5,
        returnRatePct: 1.51,
      );

      await service.updateRuleAccuracyStats();

      final row = await fetchRuleAccuracy('TECH_BREAKOUT', period: '5D');
      expect(row, isNotNull);
      expect(row!.triggerCount, 1);
      expect(row.avgReturn, closeTo(1.51, 0.01));
      expect(row.successCount, 1, reason: '1.51% ≥ 1.5% threshold → success');
    });

    // ---- 60D threshold = 8% ----

    test('60D: returnRate 7.9% does NOT count as success', () async {
      await seedReason(
        symbol: '2330',
        entryDate: DateTime.utc(2026, 1, 5),
        reasonType: 'TECH_BREAKOUT',
        rank: 0,
        periodDays: 60,
        returnRatePct: 7.9,
      );

      await service.updateRuleAccuracyStats();

      final row = await fetchRuleAccuracy('TECH_BREAKOUT', period: '60D');
      expect(row, isNotNull);
      expect(row!.triggerCount, 1);
      expect(row.avgReturn, closeTo(7.9, 0.01));
      expect(
        row.successCount,
        0,
        reason: '7.9% < 8% threshold → not a success',
      );
    });

    test(
      '60D: returnRate 8.0% counts as success (boundary, inclusive)',
      () async {
        await seedReason(
          symbol: '2330',
          entryDate: DateTime.utc(2026, 1, 5),
          reasonType: 'TECH_BREAKOUT',
          rank: 0,
          periodDays: 60,
          returnRatePct: 8.0,
        );

        await service.updateRuleAccuracyStats();

        final row = await fetchRuleAccuracy('TECH_BREAKOUT', period: '60D');
        expect(row, isNotNull);
        expect(row!.triggerCount, 1);
        expect(row.avgReturn, closeTo(8.0, 0.01));
        expect(
          row.successCount,
          1,
          reason: '8.0% ≥ 8% threshold (inclusive) → success',
        );
      },
    );

    // ---- Fallback: 1D uses non-negative baseline (no explicit threshold) ----

    test(
      '1D fallback: returnRate 0.1% counts as success (≥ 0 baseline)',
      () async {
        await seedReason(
          symbol: '2330',
          entryDate: DateTime.utc(2026, 1, 5),
          reasonType: 'TECH_BREAKOUT',
          rank: 0,
          periodDays: 1,
          returnRatePct: 0.1,
        );

        await service.updateRuleAccuracyStats();

        final row = await fetchRuleAccuracy('TECH_BREAKOUT', period: '1D');
        expect(row, isNotNull);
        expect(
          row!.successCount,
          1,
          reason: '1D falls back to ≥ 0 baseline → 0.1% is success',
        );
      },
    );

    test('1D fallback: returnRate -0.1% does NOT count as success', () async {
      await seedReason(
        symbol: '2330',
        entryDate: DateTime.utc(2026, 1, 5),
        reasonType: 'TECH_BREAKOUT',
        rank: 0,
        periodDays: 1,
        returnRatePct: -0.1,
      );

      await service.updateRuleAccuracyStats();

      final row = await fetchRuleAccuracy('TECH_BREAKOUT', period: '1D');
      expect(row, isNotNull);
      expect(
        row!.successCount,
        0,
        reason: 'Negative return fails ≥ 0 baseline',
      );
    });
  });

  // ========================================================================
  // Gap 1 fix — unbiased rule stats via daily_reason data source
  // ========================================================================
  //
  // `_computeUnbiasedRuleStats` reads every triggered reason in `daily_reason`
  // (not just the rank-0 primary) and aggregates per rule. These tests verify
  // the new flow directly via the public `updateRuleAccuracyStats` entry point.

  group('Gap 1 fix: unbiased rule stats from daily_reason', () {
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

        await service.updateRuleAccuracyStats();

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

        // All three returns = 4% > 1.5% threshold → successCount = 1 each
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

      await service.updateRuleAccuracyStats();

      final stat = await fetchRuleAccuracy('VOLUME_SPIKE', period: '5D');
      expect(stat, isNotNull);
      expect(stat!.triggerCount, 3, reason: '3 symbols × 1 date = 3 triggers');
      expect(stat.successCount, 3, reason: '5% > 1.5% threshold for all 3');
      expect(stat.avgReturn, closeTo(5.0, 0.01));
    });

    test('ALL period is no longer written (removed 2026-04)', () async {
      // ALL period aggregation across holdingPeriods was removed because
      // 1D (threshold 0%) and 60D (threshold 8%) success_counts share a
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
        // 隔日 open（lookahead bias fix 的 entry 來源）：與訊號當日 close 同值，
        // 讓下方 exit 報酬算法維持原意。
        DailyPriceCompanion.insert(
          symbol: '2330',
          date: TaiwanCalendar.addTradingDays(entry, 1),
          open: const Value(100.0),
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
      await db.insertAnalysis(
        DailyAnalysisCompanion.insert(
          symbol: '2330',
          date: entry,
          trendState: 'UP',
          scoreShort: const Value(99.0),
          scoreLong: const Value(99.0),
        ),
      );

      await service.updateRuleAccuracyStats();

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

      await service.updateRuleAccuracyStats();

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

        await service.updateRuleAccuracyStats();

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
      await service.updateRuleAccuracyStats();

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

  // ========================================================================
  // Lookahead bias fix — entry uses next-day open (audit finding #6)
  // ========================================================================
  //
  // 修前：entry = 訊號當日 close（規則觸發賴以判斷的輸入之一）。真實使用者
  // 只能隔日進場。修後：entry = 訊號隔日 open（缺值 fallback close；隔日
  // 完全無資料 → 視為未成熟樣本排除，不得退回同日 close）。

  group('Lookahead bias fix — entry uses next-day open (audit finding #6)', () {
    test(
      'next-day-open entry flips a same-day-close "win" into a loss',
      () async {
        final entryDate = DateTime.utc(2026, 1, 5);
        final nextOpenDate = TaiwanCalendar.addTradingDays(entryDate, 1);
        final exitDate = TaiwanCalendar.addTradingDays(entryDate, 5);

        await db.upsertStocks([
          StockMasterCompanion.insert(
            symbol: '2330',
            name: 'Test',
            market: 'TWSE',
          ),
        ]);
        await db.insertPrices([
          // 訊號當日 close = 100 —— 規則賴以觸發的輸入，不是進場價。
          DailyPriceCompanion.insert(
            symbol: '2330',
            date: entryDate,
            close: const Value(100.0),
          ),
          // 隔日跳空高開 open = 101.6 —— 真實使用者的進場價。
          DailyPriceCompanion.insert(
            symbol: '2330',
            date: nextOpenDate,
            open: const Value(101.6),
            close: const Value(101.6),
          ),
          // 5D 出場 close = 101.52。
          DailyPriceCompanion.insert(
            symbol: '2330',
            date: exitDate,
            close: const Value(101.52),
          ),
        ]);
        await db.insertReasons([
          DailyReasonCompanion.insert(
            symbol: '2330',
            date: entryDate,
            reasonType: 'TECH_BREAKOUT',
            rank: 0,
            evidenceJson: '{}',
          ),
        ]);
        await db.insertAnalysis(
          DailyAnalysisCompanion.insert(
            symbol: '2330',
            date: entryDate,
            trendState: 'UP',
            scoreShort: const Value(99.0),
            scoreLong: const Value(99.0),
          ),
        );

        await service.updateRuleAccuracyStats();

        final row = await fetchRuleAccuracy('TECH_BREAKOUT', period: '5D');
        expect(row, isNotNull);
        expect(row!.triggerCount, 1);
        // 同日 close entry（舊算法）：(101.52-100)/100 = +1.52% ≥ 1.5% 門檻
        // → 誤判為命中。隔日 open entry（新算法）：
        // (101.52-101.6)/101.6 ≈ -0.079% < 1.5% 門檻 → 正確判定為虧損。
        expect(
          row.successCount,
          0,
          reason:
              'entry 必須用隔日 open(101.6) 而非訊號當日 close(100)；同日 '
              'close entry 算法會誤判此筆為命中，隔日 open entry 正確算出虧損',
        );
        expect(row.avgReturn, closeTo(-0.0787, 0.01));
      },
    );

    test('signal with no next-trading-day price is excluded as immature '
        '(not backfilled with same-day close)', () async {
      final entryDate = DateTime.utc(2026, 1, 5);

      await db.upsertStocks([
        StockMasterCompanion.insert(
          symbol: '2330',
          name: 'Test',
          market: 'TWSE',
        ),
      ]);
      // 只有訊號當日的價格 —— 沒有隔日資料（例如最新一筆訊號，隔日尚未發生）。
      await db.insertPrices([
        DailyPriceCompanion.insert(
          symbol: '2330',
          date: entryDate,
          close: const Value(100.0),
        ),
      ]);
      await db.insertReasons([
        DailyReasonCompanion.insert(
          symbol: '2330',
          date: entryDate,
          reasonType: 'IMMATURE_RULE',
          rank: 0,
          evidenceJson: '{}',
        ),
      ]);
      await db.insertAnalysis(
        DailyAnalysisCompanion.insert(
          symbol: '2330',
          date: entryDate,
          trendState: 'UP',
          scoreShort: const Value(99.0),
          scoreLong: const Value(99.0),
        ),
      );

      await service.updateRuleAccuracyStats();

      final allRows = await db.select(db.ruleAccuracy).get();
      expect(
        allRows.where((r) => r.ruleId == 'IMMATURE_RULE'),
        isEmpty,
        reason: '沒有隔日價格 → 視為未成熟樣本排除，不可退回同日 close 充當進場價',
      );
    });
  });

  // ========================================================================
  // getRuleStats / getRuleSummaryText read-path
  // ========================================================================

  group('getRuleStats / getRuleSummaryText', () {
    test('getRuleStats returns null for unknown rule', () async {
      final stats = await service.getRuleStats('NO_SUCH_RULE', period: '5D');
      expect(stats, isNull);
    });

    test('getRuleStats computes hitRate from trigger/success counts', () async {
      await db
          .into(db.ruleAccuracy)
          .insert(
            RuleAccuracyCompanion.insert(
              ruleId: 'TECH_BREAKOUT',
              period: '5D',
              triggerCount: const Value(10),
              successCount: const Value(6),
              avgReturn: const Value(2.3),
            ),
          );

      final stats = await service.getRuleStats('TECH_BREAKOUT', period: '5D');
      expect(stats, isNotNull);
      expect(stats!.hitRate, closeTo(60.0, 0.001));
      expect(stats.avgReturn, closeTo(2.3, 0.001));
      expect(stats.triggerCount, 10);
    });

    test('getRuleSummaryText returns null below 5-sample minimum', () async {
      await db
          .into(db.ruleAccuracy)
          .insert(
            RuleAccuracyCompanion.insert(
              ruleId: 'TECH_BREAKOUT',
              period: '5D',
              triggerCount: const Value(4),
              successCount: const Value(3),
              avgReturn: const Value(2.3),
            ),
          );

      final text = await service.getRuleSummaryText('TECH_BREAKOUT');
      expect(text, isNull, reason: 'triggerCount < 5 → no summary');
    });

    test('getRuleSummaryText formats hit rate + avg return', () async {
      await db
          .into(db.ruleAccuracy)
          .insert(
            RuleAccuracyCompanion.insert(
              ruleId: 'TECH_BREAKOUT',
              period: '5D',
              triggerCount: const Value(10),
              successCount: const Value(7),
              avgReturn: const Value(2.34),
            ),
          );

      final text = await service.getRuleSummaryText('TECH_BREAKOUT');
      expect(text, '命中率 70%，平均 5 日報酬 +2.3%');
    });
  });
}
