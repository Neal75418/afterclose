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

import 'package:afterclose/core/constants/calibration_thresholds.dart';
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
  // Survivorship bias fix — stale-price symbol excluded (audit finding #7a)
  // ========================================================================
  //
  // 舊行為：missing-exit-price 只在單一 reason × period 粒度靜默 continue，
  // 只排除「剛好落在下市點附近」的訊號，卻留下該股下市前仍算得出的（較早、
  // 較正常）訊號——winner 全留、崩盤前夕靜默消失的存活者偏差。新行為：
  // symbol 最新價格早於 dataset max date 超過 stalePriceThresholdDays（30
  // 天）→ 整個 symbol 排除，不挑好留壞。

  group(
    'Survivorship bias fix — stale-price symbol excluded (audit finding #7a)',
    () {
      test('symbol whose latest price is stale (>30 calendar days behind '
          'dataset max date) is excluded entirely, even with a flattering '
          'return', () async {
        // STALE：只到 2026-01-12 附近就沒有更新價格（模擬下市 / 長停）。
        // 刻意給高報酬——若排除機制沒生效，這筆會製造一個假命中。
        await seedReason(
          symbol: 'STALE',
          entryDate: DateTime.utc(2026, 1, 5),
          reasonType: 'STALE_RULE',
          rank: 0,
          periodDays: 5,
          returnRatePct: 10.0,
        );

        // FRESH：entryDate 晚 STALE 出場日超過 30 天，把 dataset 的
        // max(daily_price.date) 推到夠新，讓 STALE 的最新價格顯得過期。
        await seedReason(
          symbol: 'FRESH',
          entryDate: DateTime.utc(2026, 3, 1),
          reasonType: 'FRESH_RULE',
          rank: 0,
          periodDays: 5,
          returnRatePct: 5.0,
        );

        await service.updateRuleAccuracyStats();

        final allRows = await db.select(db.ruleAccuracy).get();
        expect(
          allRows.where((r) => r.ruleId == 'STALE_RULE'),
          isEmpty,
          reason:
              'STALE 最新價格遠早於 dataset max date（模擬下市/長停）→ '
              '整個 symbol 應被排除，不能因為單筆報酬漂亮就留下',
        );
        expect(
          allRows.where((r) => r.ruleId == 'FRESH_RULE'),
          isNotEmpty,
          reason: 'FRESH 是 dataset 當前最新資料來源，不應被誤判為 stale',
        );
      });

      test(
        'symbol with fresh-enough price (within threshold) still counts',
        () async {
          // 兩檔股票資料最新日只差幾天（< 30 天門檻）——都不該被排除。
          await seedReason(
            symbol: 'A',
            entryDate: DateTime.utc(2026, 1, 5),
            reasonType: 'RULE_A',
            rank: 0,
            periodDays: 5,
            returnRatePct: 5.0,
          );
          await seedReason(
            symbol: 'B',
            entryDate: DateTime.utc(2026, 1, 8),
            reasonType: 'RULE_B',
            rank: 0,
            periodDays: 5,
            returnRatePct: 5.0,
          );

          await service.updateRuleAccuracyStats();

          final allRows = await db.select(db.ruleAccuracy).get();
          expect(
            allRows.where((r) => r.ruleId == 'RULE_A'),
            isNotEmpty,
            reason: '兩檔資料新舊差距 < 30 天門檻，都不該被判定為 stale',
          );
          expect(allRows.where((r) => r.ruleId == 'RULE_B'), isNotEmpty);
        },
      );
    },
  );

  // ========================================================================
  // Zero-price guard — divide-by-zero false hit (blocking review finding)
  // ========================================================================
  //
  // Entry 運算式 `open ?? close` 只在 open 為 **null** 時才 fallback 到 close
  // —— FinMind 部分價格列 open=0.0（非 null；calibration.db 實測 19,030 筆 /
  // 0.61%，其中 358 筆 close>0）。舊 guard 只查 `entryPrice == null`，讓
  // entry=0 通過 → returnRate = ((exitClose-0)/0)*100 = +Infinity，而
  // `Infinity >= threshold` 恆真 → false hit，把該 (rule, period) 的
  // avgReturn 污染成 +Infinity/NaN（UI 顯示「平均5日報酬 +Infinity%」）。
  // Exit 端同型 bug：exit=0（停牌/異常列，非缺值）舊 guard 只查 null，會被
  // 當成 -100% 真實虧損記錄，其實只是資料缺陷。兩者修法一致：guard 從
  // `== null` 擴充為 `== null || <= 0`，計入 skippedNoEntryPrice /
  // skippedNoExitPrice 同一計數器（沿用既有語意，不新增第三種分類）。

  group('Zero-price guard — divide-by-zero false hit (blocking review '
      'finding)', () {
    test('entry price of exactly 0.0 (open=0.0, FinMind bad row) is excluded, '
        'not treated as a valid entry (would divide-by-zero to +Infinity '
        'return and a false hit)', () async {
      final entryDate = DateTime.utc(2026, 1, 5);
      final nextTradingDate = TaiwanCalendar.addTradingDays(entryDate, 1);
      final exitDate = TaiwanCalendar.addTradingDays(entryDate, 5);

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
          date: entryDate,
          close: const Value(100.0),
        ),
        // FinMind 異常列：open=0.0（非 null！）`open ?? close` 不會 fallback。
        DailyPriceCompanion.insert(
          symbol: '2330',
          date: nextTradingDate,
          open: const Value(0.0),
          close: const Value(100.0),
        ),
        DailyPriceCompanion.insert(
          symbol: '2330',
          date: exitDate,
          close: const Value(105.0),
        ),
      ]);
      await db.insertReasons([
        DailyReasonCompanion.insert(
          symbol: '2330',
          date: entryDate,
          reasonType: 'ZERO_OPEN_RULE',
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
        allRows.where((r) => r.ruleId == 'ZERO_OPEN_RULE'),
        isEmpty,
        reason:
            'entry=0.0 必須視為缺值排除；未修前會算出 (105-0)/0*100 = '
            '+Infinity，Infinity >= threshold 恆真 → false hit 污染 '
            'avgReturn 為 +Infinity/NaN',
      );
    });

    test('exit price of exactly 0.0 (halted/bad row) is excluded, not '
        'recorded as a -100% loss', () async {
      final entryDate = DateTime.utc(2026, 1, 5);
      final nextTradingDate = TaiwanCalendar.addTradingDays(entryDate, 1);
      final exitDate = TaiwanCalendar.addTradingDays(entryDate, 5);

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
          date: entryDate,
          close: const Value(100.0),
        ),
        DailyPriceCompanion.insert(
          symbol: '2330',
          date: nextTradingDate,
          open: const Value(100.0),
          close: const Value(100.0),
        ),
        // 出場日 close=0.0：停牌/異常列，非「無資料」。
        DailyPriceCompanion.insert(
          symbol: '2330',
          date: exitDate,
          close: const Value(0.0),
        ),
      ]);
      await db.insertReasons([
        DailyReasonCompanion.insert(
          symbol: '2330',
          date: entryDate,
          reasonType: 'ZERO_EXIT_RULE',
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
      final zeroExitRows = allRows
          .where((r) => r.ruleId == 'ZERO_EXIT_RULE')
          .toList();

      // Exit guard 是 (reason × period) 粒度，不像 entry 影響整個 reason
      // ——1D 的出場日剛好等於 nextTradingDate（同一列，close=100，未受
      // 汙染的合法資料），該筆合法觀測不應被牽連排除。
      final oneDay = zeroExitRows.where((r) => r.period == '1D');
      expect(
        oneDay,
        isNotEmpty,
        reason:
            '1D 出場價落在 nextTradingDate（close=100，未受影響）——'
            '不應被 5D 那筆的 exit=0 牽連排除',
      );

      // 5D 出場日 close=0.0（本測試刻意構造的停牌/異常列）必須被排除。
      final fiveDay = zeroExitRows.where((r) => r.period == '5D');
      expect(
        fiveDay,
        isEmpty,
        reason:
            'exit=0.0 必須視為缺值排除；未修前會算出 (0-100)/100*100 = '
            '-100%，把資料缺陷誤記為真實最大虧損',
      );
    });
  });

  // ========================================================================
  // getRuleStats / getRuleSummaryText read-path
  // ========================================================================

  group('觸發日數統計（clustered 有效樣本）', () {
    // 讀取路徑的測試直接塞 rule_accuracy 列，碰不到累加器 —— mutation 實測：
    // 把 `_dates.add(entryDate)` 整行刪掉，讀取路徑測試仍全綠。此 group
    // 走真實計算路徑（seedReason → updateRuleAccuracyStats）補上該缺口。
    test('🚨 同日多檔觸發只算一個觸發日', () async {
      final entry = DateTime.utc(2026, 1, 5);
      for (final symbol in ['2330', '2317', '2454']) {
        await seedReason(
          symbol: symbol,
          entryDate: entry,
          reasonType: 'TECH_BREAKOUT',
          rank: 0,
          periodDays: 5,
          returnRatePct: 4.0,
        );
      }

      await service.updateRuleAccuracyStats();
      final stats = await service.getRuleStats('TECH_BREAKOUT', period: '5D');

      expect(stats!.triggerCount, 3);
      expect(stats.distinctDates, 1, reason: '三檔同日觸發共用同一個市場因子，有效樣本是 1 天不是 3 筆');
    });

    test('不同日觸發各自計入', () async {
      for (final day in [5, 6, 7]) {
        await seedReason(
          symbol: '2330',
          entryDate: DateTime.utc(2026, 1, day),
          reasonType: 'TECH_BREAKOUT',
          rank: 0,
          periodDays: 5,
          returnRatePct: 4.0,
        );
      }

      await service.updateRuleAccuracyStats();
      final stats = await service.getRuleStats('TECH_BREAKOUT', period: '5D');

      expect(stats!.triggerCount, 3);
      expect(stats.distinctDates, 3);
    });
  });

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

    // ====================================================================
    // 有效樣本是「觸發日」數，不是 pooled 觸發筆數
    //
    // CalibrationThresholds.minDistinctDates 的 docstring 已寫明：
    // 「pooled n 因同日橫斷面相關 + 持有窗重疊是偽重複，有效樣本量級是
    // 觸發日數」。但該認知只落實在 calibration 決策層（clustered t-stat），
    // app 內的顯示層仍以 pooled triggerCount 對 sampleSizeCutThreshold
    // 判斷信心度。
    //
    // 實測後果（production DB）：CONCENTRATION_HIGH 761 筆觸發全部來自
    // **8 個交易日**，其中 5D 前瞻報酬只有最早三天的觸發有結果，而那三天
    // 之後緊接著 7/17 單日 −3.95% 的崩盤。761 遠高於門檻 30 → 以「完全
    // 有信心」的樣子顯示，底下其實是 8 個高度相關的觀測。
    // ====================================================================

    test('🚨 觸發日數不足時必須揭露，即使 pooled 筆數很多', () async {
      await db
          .into(db.ruleAccuracy)
          .insert(
            RuleAccuracyCompanion.insert(
              ruleId: 'CONCENTRATION_HIGH',
              period: '5D',
              triggerCount: const Value(761),
              successCount: const Value(173),
              avgReturn: const Value(-1.13),
              distinctDates: const Value(8),
            ),
          );

      final text = await service.getRuleSummaryText('CONCENTRATION_HIGH');

      expect(text, isNotNull);
      expect(text, contains('8'), reason: '必須讓使用者看到「761 筆只來自 8 天」');
      expect(
        text,
        contains('信心度較低'),
        reason: 'pooled 761 遠超門檻 30，但有效樣本只有 8 個觸發日',
      );
    });

    test('觸發日數足夠時不加註記', () async {
      await db
          .into(db.ruleAccuracy)
          .insert(
            RuleAccuracyCompanion.insert(
              ruleId: 'TECH_BREAKOUT',
              period: '5D',
              triggerCount: const Value(400),
              successCount: const Value(200),
              avgReturn: const Value(1.5),
              distinctDates: const Value(45),
            ),
          );

      final text = await service.getRuleSummaryText('TECH_BREAKOUT');

      expect(text, isNot(contains('信心度較低')));
      expect(text, contains('45'));
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

    test('getRuleSummaryText formats hit rate + avg return (no caveat when '
        'sample ≥ sampleSizeCutThreshold)', () async {
      await db
          .into(db.ruleAccuracy)
          .insert(
            RuleAccuracyCompanion.insert(
              ruleId: 'TECH_BREAKOUT',
              period: '5D',
              triggerCount: const Value(35),
              successCount: const Value(25),
              avgReturn: const Value(2.34),
              // 日數固定在通過值，讓本測試只驗「筆數」門檻這一個維度
              distinctDates: const Value(40),
            ),
          );

      final text = await service.getRuleSummaryText('TECH_BREAKOUT');
      expect(
        text,
        '命中率 71%（隨機基準 35%，+36pp），平均 5 日報酬 +2.3%'
        '（樣本 35 筆 / 40 個觸發日）',
      );
    });

    // ======================================================================
    // 相對隨機基準的 lift（P1-9）
    //
    // `successProbabilityBaselines` 是實測的 per-period 隨機基準
    // （5D=0.3461），過去**只被 calibration 消費、UI 零引用**，使用者看到的
    // 是裸命中率。實測後果（使用者 production DB，5D）：
    //   CONCENTRATION_HIGH 22.8%(n=276) / INSTITUTIONAL_BUY_STREAK 33.3%(n=111)
    // 前者讀起來像「差但堪用」，實際低於隨機 12pp；後者讀起來像「很爛」，
    // 實際只是持平。兩個方向的誤讀都直接改變部位配置。
    // ======================================================================

    test('🚨 低於隨機基準時必須顯示負 lift（否則會被誤讀為堪用）', () async {
      // 23% vs 5D 基準 34.6% → −12pp
      await db
          .into(db.ruleAccuracy)
          .insert(
            RuleAccuracyCompanion.insert(
              ruleId: 'CONCENTRATION_HIGH',
              period: '5D',
              triggerCount: const Value(276),
              successCount: const Value(63),
              avgReturn: const Value(-0.8),
            ),
          );

      final text = await service.getRuleSummaryText('CONCENTRATION_HIGH');
      expect(text, contains('隨機基準 35%'));
      expect(text, contains('-12pp'), reason: '低於基準必須顯示為負，不能只給裸命中率');
    });

    test('持平於基準時 lift 近 0（不該讀成「很爛」）', () async {
      // 33.3% vs 34.6% → −1pp
      await db
          .into(db.ruleAccuracy)
          .insert(
            RuleAccuracyCompanion.insert(
              ruleId: 'INSTITUTIONAL_BUY_STREAK',
              period: '5D',
              triggerCount: const Value(111),
              successCount: const Value(37),
              avgReturn: const Value(-1.05),
            ),
          );

      final text = await service.getRuleSummaryText('INSTITUTIONAL_BUY_STREAK');
      expect(text, contains('-2pp'));
    });

    test('未列入 baseline 的 period 走 0.5 保守 fallback', () async {
      await db
          .into(db.ruleAccuracy)
          .insert(
            RuleAccuracyCompanion.insert(
              ruleId: 'TECH_BREAKOUT',
              period: '1D',
              triggerCount: const Value(40),
              successCount: const Value(24),
              avgReturn: const Value(0.5),
            ),
          );

      final text = await service.getRuleSummaryText(
        'TECH_BREAKOUT',
        holdingDays: 1,
      );
      expect(text, contains('隨機基準 50%'));
    });

    // ======================================================================
    // Low-confidence caveat (audit finding #7b) — getRuleSummaryText is the
    // one UI-facing consumer of rule_accuracy; unlike the bias telemetry
    // (only AppLogger.info'd, never surfaced), a small-sample rule's summary
    // must itself carry a caveat instead of presenting the number as if it
    // were as trustworthy as a well-sampled rule.
    // ======================================================================

    test(
      'getRuleSummaryText appends low-confidence caveat when sample n is '
      'below CalibrationThresholds.sampleSizeCutThreshold (audit finding #7b)',
      () async {
        await db
            .into(db.ruleAccuracy)
            .insert(
              RuleAccuracyCompanion.insert(
                ruleId: 'TECH_BREAKOUT',
                period: '5D',
                triggerCount: const Value(10), // < 30 cut threshold
                successCount: const Value(7),
                avgReturn: const Value(2.34),
              ),
            );

        final text = await service.getRuleSummaryText('TECH_BREAKOUT');
        expect(text, isNotNull);
        expect(
          text,
          contains('命中率 70%（隨機基準 35%，+35pp），平均 5 日報酬 +2.3%'),
          reason: '核心數字不因低信心註記而消失',
        );
        expect(text, contains('10'), reason: '低信心註記須帶出實際樣本數，而非只是模糊警語');
        expect(
          text!.length,
          greaterThan('命中率 70%（隨機基準 35%，+35pp），平均 5 日報酬 +2.3%'.length),
          reason: 'n=10 < sampleSizeCutThreshold(30) → 必須附加低信心註記',
        );
      },
    );

    test('getRuleSummaryText boundary: n == sampleSizeCutThreshold has no '
        'caveat, n one below does', () async {
      Future<String?> textForN(int n) async {
        await db.delete(db.ruleAccuracy).go();
        await db
            .into(db.ruleAccuracy)
            .insert(
              RuleAccuracyCompanion.insert(
                ruleId: 'BOUNDARY_RULE',
                period: '5D',
                triggerCount: Value(n),
                successCount: Value(n ~/ 2),
                avgReturn: const Value(1.0),
                // 同上：固定日數，隔離出「筆數」這一個維度
                distinctDates: const Value(40),
              ),
            );
        return service.getRuleSummaryText('BOUNDARY_RULE');
      }

      final atThreshold = await textForN(
        CalibrationThresholds.sampleSizeCutThreshold,
      );
      final belowThreshold = await textForN(
        CalibrationThresholds.sampleSizeCutThreshold - 1,
      );

      expect(
        atThreshold!.length,
        lessThan(belowThreshold!.length),
        reason:
            'n == threshold（含）不該有註記；n = threshold-1 應該有 → '
            '前者字串較短',
      );
    });
  });
}
