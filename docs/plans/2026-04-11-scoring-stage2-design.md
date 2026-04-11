# Scoring Overhaul Stage 2 — Design Doc

**Date**: 2026-04-11
**Scope**: Stage 2 LEAN of the 5-stage scoring overhaul
**Status**: Design locked via `/brainstorming`, ready for implementation
**Related**: [`rule_engine.dart`](../../lib/domain/services/rule_engine.dart), [`rule_accuracy_service.dart`](../../lib/domain/services/rule_accuracy_service.dart)

---

## 1. Context & Motivation

The 62-rule scoring engine has several structural issues. Stage 1 (commits `cc255d4` + `db1f6ce`, merged to `origin/main`) fixed 3 self-evident bugs:

- Removed bonus double-count in `calculateScore`
- Added mutex group for overlapping `momentum_breakout` signals
- Corrected `filterMeta` divergence translations to match rule implementation

Stage 2 builds the **calibration-ready infrastructure** so that once post-launch data accumulates, a monthly calibration run can automatically translate per-rule statistics into data-driven rule scores. **Stage 2 does NOT run calibration** — the app is pre-launch, there is no historical data to calibrate against yet.

### Known gaps this stage addresses

| # | Gap | Fix |
|:---:|:---|:---|
| 4 | `rule_accuracy_service` only tracks rank-0 (`primary_rule_id`) rule per recommendation, so rules that never rank first get zero samples | Fix via data-source swap (see §4) |
| 5 | `isSuccess = returnRate > 0` is too lax (rewards any non-negative return) | Parameterize per-horizon threshold |
| 6 | `holdingPeriods` missing `60` for long-horizon analysis | Additive `[1, 3, 5, 10, 20, 60]` |

### Explicitly out of scope (pushed to Stage 5)

- **Runtime loading of calibrated JSON into `rule_scores.dart`** — requires isolate-safe late-binding, complex to do right without real data to validate.
- **Dual-horizon scoring pipeline** — running scoring twice (or producing two scores per stock), UI tabs for two Top 20 lists, schema changes to `daily_analysis` / `daily_recommendation`. Large architectural work; needs its own brainstorming.

Rationale: `rule_scores.dart` stays hardcoded through Stage 2. Stage 5 (post Stage 4 first real calibration) will build the runtime loader and dual-horizon pipeline with real data to validate against.

---

## 2. Locked Decisions (from brainstorming 2026-04-11)

| # | Question | Decision | Why |
|:---:|:---|:---|:---|
| Q1 | Calibration formula | **Linear map v1**: `raw = hit_rate × avg_return × √n`, scaled to `[10, 35]` | Interpretable, small-sample safe, t-stat derivable via proportion z-test |
| Q2 | Per-triggered-rule storage | **Reuse `rule_accuracy` table, swap data source** from `daily_recommendation→primary_rule_id` to `daily_reason→all_reasons` | Zero schema change, preserves UI consumers, minimal code churn |
| Q3 | Schema migration | **No schema change** | Q2 obviates it; `recommendation_validation` stays for UI display |
| Q4 | JSON schema | Two files per horizon, `schema_version` + `backtest` metadata + `rules` dict with `active` / `cut_reason` flags | Clean separation, audit trail, git-diffable |
| Q4a | Fallback when JSON missing | **A2**: hardcoded fallback + AppLogger.warning | Safe pre-launch, observable post-launch |
| Q4b | Diff between versions | **B1**: no diff in JSON, rely on git diff | YAGNI |
| Q5 | Sequencing | **Sequence A**: `60D+threshold` → `Gap 1 fix` → `recalibrate.dart` (3 commits) | Additive-first reduces risk; biggest refactor (Gap 1) is standalone commit |

---

## 3. Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  EXISTING — unchanged                                           │
│  ┌──────────────┐        ┌──────────────┐                       │
│  │ daily_reason │        │ daily_price  │                       │
│  │ (all triggered│       │ (forward     │                       │
│  │  rules, score │       │  returns)    │                       │
│  │  ≥ 25)        │       │              │                       │
│  └───────┬──────┘        └───────┬──────┘                       │
└──────────┼───────────────────────┼──────────────────────────────┘
           │                       │
           ▼                       ▼
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 2 LEAN — refactor + new tool                             │
│  ┌──────────────────────────────────────────┐                   │
│  │ rule_accuracy_service                    │                   │
│  │ Commits 1+2:                             │                   │
│  │  • add 60D period                        │                   │
│  │  • parameterize success threshold        │                   │
│  │  • swap data source (Gap 1 fix)          │                   │
│  └──────────────────┬───────────────────────┘                   │
│                     ▼                                           │
│  ┌──────────────────────────────────────────┐                   │
│  │ rule_accuracy table (schema unchanged)   │                   │
│  │ (ruleId, period, triggerCount,           │                   │
│  │  successCount, avgReturn)                │                   │
│  └──────────────────┬───────────────────────┘                   │
│                     ▼                                           │
│  ┌──────────────────────────────────────────┐                   │
│  │ tool/recalibrate.dart (Commit 3)         │                   │
│  │  • linear_map_v1 formula                 │                   │
│  │  • cut thresholds (t-stat, hit, n)       │                   │
│  └──────────────────┬───────────────────────┘                   │
└─────────────────────┼───────────────────────────────────────────┘
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│  OUTPUT — static asset files (not consumed until Stage 5)       │
│  assets/rule_scores_calibrated_short_candidate.json             │
│  assets/rule_scores_calibrated_long_candidate.json              │
└─────────────────────────────────────────────────────────────────┘
```

### Architectural principles

1. **`rule_accuracy` table schema unchanged** — only the data source and aggregation logic change
2. **`recommendation_validation` table untouched** — still serves `getStockValidationRecords()` for UI
3. **Pipeline is offline** — `tool/recalibrate.dart` is CLI-triggered, nothing in app runtime depends on calibrated JSON in Stage 2
4. **No feature flags** — old biased code path is replaced, not toggled

---

## 4. Components

### 4.1 `lib/domain/services/rule_accuracy_service.dart` — refactor

**Add:**

```dart
/// Per-period success threshold (returnRate ≥ X% counts as success).
/// 1D / 3D fall back to > 0 baseline; 5D / 10D / 20D / 60D use tightened criteria.
static const Map<int, double> _successThresholds = {
  5:  3.0,   // 5D ≥ 3%
  10: 5.0,   // 10D ≥ 5%
  20: 8.0,   // 20D ≥ 8%
  60: 12.0,  // 60D ≥ 12%
};

/// Extended holding periods — 60 added for long-horizon calibration.
static const List<int> holdingPeriods = [1, 3, 5, 10, 20, 60];
```

**Change `_computeValidation()`:**

```dart
// OLD: final isSuccess = returnRate > 0;
// NEW:
final threshold = _successThresholds[daysAgo] ?? 0.0;
final isSuccess = returnRate >= threshold;
```

**Add new method `_computeUnbiasedRuleStats()`** — replaces the body of `_updateRuleAccuracyStats()`:

```dart
/// Compute unbiased per-rule statistics by iterating all triggered reasons
/// in daily_reason (not just Top 20 primaries) and joining with daily_price
/// for forward returns.
Future<void> _computeUnbiasedRuleStats() async {
  // 1. Fetch daily_reason rows within backtest window
  final reasons = await (_db.select(_db.dailyReason)
        ..where((t) => t.date.isBiggerOrEqualValue(windowStart)))
      .get();

  // 2. Pre-build price lookup: {symbol: {date: close}}
  final allSymbols = reasons.map((r) => r.symbol).toSet().toList();
  final priceMap = await _buildPriceLookup(allSymbols);

  // 3. Accumulate stats per (ruleId, period)
  final accumulators = <(String, int), _StatsAccumulator>{};

  for (final reason in reasons) {
    final entryClose = priceMap[reason.symbol]?[_dateKey(reason.date)];
    if (entryClose == null) continue;

    for (final period in holdingPeriods) {
      final exitDate = TaiwanCalendar.addTradingDays(reason.date, period);
      final exitClose = priceMap[reason.symbol]?[_dateKey(exitDate)];
      if (exitClose == null) continue;

      final returnRate = (exitClose - entryClose) / entryClose * 100;
      final threshold = _successThresholds[period] ?? 0.0;
      final isSuccess = returnRate >= threshold;

      final key = (reason.reasonType, period);
      accumulators
          .putIfAbsent(key, _StatsAccumulator.new)
          .add(returnRate, isSuccess);
    }
  }

  // 4. Write aggregated stats (single transaction)
  await _db.transaction(() async {
    for (final entry in accumulators.entries) {
      final (ruleId, period) = entry.key;
      final acc = entry.value;
      await _db.into(_db.ruleAccuracy).insertOnConflictUpdate(
            RuleAccuracyCompanion.insert(
              ruleId: ruleId,
              period: '${period}D',
              triggerCount: Value(acc.count),
              successCount: Value(acc.successCount),
              avgReturn: Value(acc.avgReturnPct),
            ),
          );
    }
  });
}
```

**Modify `_updateRuleAccuracyStats()`** to delegate to the new method. Preserve the public method name so the post-update hook in `UpdateService` doesn't need changes.

### 4.2 `tool/recalibrate.dart` — new CLI tool

**Responsibilities:**
- Read `rule_accuracy` table via `sqlite3` package (same pattern as `tool/check_db_range.dart`)
- Apply `linear_map_v1` formula per (ruleId, horizon) pair
- Apply cut thresholds (`t_stat < 1.5`, `hit_rate < 55%`, `n < 30`)
- Write candidate JSON files to `assets/rule_scores_calibrated_{short,long}_candidate.json`
- **Never overwrite production files** — user manually renames after review

**CLI flags:**
- `--db <path>` — DB file location (same as `check_db_range.dart`)
- `--horizon <short|long|both>` — which JSON to produce
- `--dry-run` — print what would be written without touching disk

**Formula module (`Calibrator` class):**

```dart
class Calibrator {
  /// Linear map v1: raw = hit_rate × avg_return × √n, scaled to [10, 35]
  static CalibratedRule compute(RuleStats stats, _GlobalStats globalStats) {
    // 1. Proportion z-test for statistical significance
    final p = stats.hitRate;
    final n = stats.triggerCount;
    if (n == 0) {
      return CalibratedRule.cut(stats, 'zero_samples');
    }
    if (n < 30) {
      return CalibratedRule.cut(stats, 'sample_too_small');
    }
    final stderr = sqrt(p * (1 - p) / n);
    final zStat = stderr == 0 ? 0.0 : (p - 0.5) / stderr;

    // 2. Cut thresholds
    if (zStat < 1.5) {
      return CalibratedRule.cut(stats, 't_stat_below_threshold');
    }
    if (p < 0.55) {
      return CalibratedRule.cut(stats, 'hit_rate_below_threshold');
    }

    // 3. Linear map to [10, 35]
    final rawWeight = p * stats.avgReturn * sqrt(n);
    final normalized = 10 +
        ((rawWeight - globalStats.minRaw) /
                (globalStats.maxRaw - globalStats.minRaw)) *
            25;

    return CalibratedRule.active(stats, zStat, normalized.round());
  }
}
```

### 4.3 JSON output schema

```json
{
  "schema_version": 1,
  "generated_at": "2026-04-11T14:30:00+08:00",
  "horizon": "5d",
  "backtest": {
    "window_days": 504,
    "train_ratio": 0.7,
    "success_threshold_pct": 3.0,
    "formula": "linear_map_v1"
  },
  "rules": {
    "reversalW2S": {
      "score": 28,
      "hit_rate": 0.52,
      "avg_return": 0.031,
      "samples": 412,
      "t_stat": 2.15,
      "active": true
    },
    "newsRelated": {
      "score": 0,
      "hit_rate": 0.48,
      "avg_return": 0.002,
      "samples": 89,
      "t_stat": 0.80,
      "active": false,
      "cut_reason": "t_stat_below_threshold"
    }
  }
}
```

### 4.4 `lib/core/constants/rule_scores.dart` — UNCHANGED

Stage 2 does not touch `rule_scores.dart`. Scoring pipeline continues to use hardcoded constants. Runtime JSON loading is deferred to Stage 5.

---

## 5. Data Flow

```
Daily scoring pipeline (app runtime, unchanged)
  scoring_service → rule_engine.evaluateStock
    → daily_reason rows (all triggered, per-stock)
    → daily_analysis (per-stock score)
    → daily_recommendation (Top 20)

Post-update hook (non-blocking, unchanged API)
  update_service → rule_accuracy_service._updateRuleAccuracyStats
    → (NEW) _computeUnbiasedRuleStats
    → reads daily_reason + daily_price
    → writes rule_accuracy table

Monthly manual calibration (offline, new in Stage 2)
  dart run tool/recalibrate.dart --db <path> --horizon both
    → reads rule_accuracy table
    → applies linear_map_v1 + cut thresholds
    → writes assets/rule_scores_calibrated_{short,long}_candidate.json

Manual review (human)
  git diff assets/rule_scores_calibrated_*_candidate.json
    → review deltas from previous month
    → approve: rename _candidate.json → production filename
    → commit

Stage 5 (post-launch, out of scope here)
  App startup → rule_scores.dart loads production JSON → scoring uses calibrated values
```

---

## 6. Error Handling

### Three risk tiers

**Tier 1 — Data risks (common, non-fatal):**
- Missing entry/exit price → `continue;` + increment `skippedMissingPrice` counter + debug log
- Rule trigger count < 30 → keep in stats; cut decision deferred to `recalibrate.dart`
- `hit_rate ∈ {0, 1}` (z-test undefined) → special case: `zStat = 0` → cut as `sample_too_small`
- Missing `daily_price` for specific symbol on specific date → skip that (symbol, date, period) combination

**Principle**: Data incompleteness is normal. Skip, don't crash. Log counters for observability.

**Tier 2 — System risks (rare, fail fast):**
- `sqlite3.open(dbPath)` fails → `stderr.writeln` + `exit(1)` (same pattern as `check_db_range.dart`)
- `rule_accuracy` table missing → fail fast with hint: `💡 run the app once to initialize schema`
- JSON write fails (filesystem, permissions) → **write to temp file + atomic rename**; never leave partial file
- Drift transaction fails mid-write → auto-rollback preserves `rule_accuracy` last-good state

**Principle**: System errors surface immediately with clear messages. Don't mask infrastructure problems.

**Tier 3 — Concurrency:**
- Scenario: `recalibrate.dart` runs while app's post-update hook triggers `_updateRuleAccuracyStats()`
- Mitigation: `recalibrate.dart` only **reads** `rule_accuracy` (writes JSON); SQLite WAL mode handles reader-writer concurrency cleanly
- `_computeUnbiasedRuleStats()` writes within transaction for atomicity

**Implementation note**: Drift `_db.transaction()` semantics need verification during implementation — specifically, whether a crash mid-iteration rolls back cleanly or leaves partial state.

---

## 7. Testing Strategy

### Layer 1 — Formula unit tests (`test/tool/recalibrate_test.dart`)

Pure arithmetic, no DB. Fixtures are `RuleStats` instances:

```dart
test('linear_map_v1 happy path', () {
  final stats = RuleStats(
    ruleId: 'reversalW2S',
    hitRate: 0.65,
    avgReturn: 2.5,
    triggerCount: 100,
  );
  final globalStats = _GlobalStats(minRaw: 5.0, maxRaw: 50.0);
  final result = Calibrator.compute(stats, globalStats);

  expect(result.active, isTrue);
  expect(result.score, closeTo(22, 1));  // derived via reference table
});

test('cut: t_stat < 1.5', () { /* ... */ });
test('cut: hit_rate < 0.55', () { /* ... */ });
test('cut: n < 30', () { /* ... */ });
test('edge: hit_rate = 0 → cut as sample_too_small', () { /* ... */ });
test('edge: hit_rate = 1.0 → z-test undefined → cut', () { /* ... */ });
```

**TODO at impl time**: derive expected values in `closeTo(22, 1)` via Python reference script + commit as constants.

### Layer 2 — Service unit tests (extend `rule_accuracy_service_test.dart`)

Drift in-memory DB + synthetic `daily_reason` + `daily_price` fixtures:

```dart
test('60D period stats computed', () { /* add 60D row to fixture, assert present */ });

test('threshold parameterization: 5D returnRate=2.0 → not success', () {
  // 5D threshold = 3.0; returnRate 2.0 falls below
  // Assert successCount does NOT increment
});

test('Gap 1 fix: non-primary reasons counted', () async {
  // Fixture: 2 stocks, each with 3 triggered rules (rank 0/1/2)
  // Assert rule_accuracy has stats for rank 1 / rank 2 rules (6 distinct rules total)
});
```

### Layer 3 — Integration smoke test

End-to-end: synthetic DB → `_computeUnbiasedRuleStats()` → `tool/recalibrate.dart` → JSON output → assert presence of expected keys and ballpark values.

### Out of scope

- Performance / memory profiling (pre-launch, manual verification)
- Real data regression (no real data)
- Scoring pipeline integration (Stage 2 doesn't consume JSON)

---

## 8. Implementation Sequence

### Commit 1 — `feat(rule-accuracy): add 60D horizon and parameterize success threshold`

**Scope**:
- Add `60` to `holdingPeriods`
- Add `_successThresholds` const map
- Update `_computeValidation()` to use threshold lookup
- Update `rule_accuracy_service_test.dart` with 60D + threshold tests

**Why first**: Additive, smallest risk, unblocks later commits.

### Commit 2 — `refactor(rule-accuracy): fix primary_rule_id bias by sourcing stats from daily_reason`

**Scope**:
- Add `_computeUnbiasedRuleStats()` method
- Modify `_updateRuleAccuracyStats()` to delegate to new method
- Deprecate internal references to `primary_rule_id` aggregation
- Update `rule_accuracy_service_test.dart` with Gap 1 fix test
- Run full test suite

**Why second**: This is the core refactor and highest-risk commit. With Commit 1 groundwork, this commit has only one responsibility.

### Commit 3 — `feat(tool): add recalibrate CLI to generate candidate rule_scores JSON`

**Scope**:
- Create `tool/recalibrate.dart`
- Create `test/tool/recalibrate_test.dart` with Layer 1 formula tests
- Create `docs/CALIBRATION.md` explaining formula + workflow

**Why last**: Depends on `rule_accuracy` table being populated with unbiased stats from commits 1+2. Self-contained new file, no collisions.

### Gate: `pr-review-toolkit:code-reviewer` agent

After all three commits land (same pattern as Stage 1 gate), launch the code-reviewer agent to review the complete diff. Expected focus areas:
- Correctness of unbiased stats computation
- Formula implementation vs reference table
- Error handling completeness
- Test coverage adequacy
- No regression in existing `recommendation_validation` flow

---

## 9. Known Limitations

1. **Sample selection bias from `minScoreThreshold = 25`**: `daily_reason` only contains stocks that scored ≥ 25. Rules that *only* fire on weak stocks never get samples. Acceptable because such rules inherently lack operational value, but must be documented.

2. **Memory footprint of price lookup map**: For 2 years × 2000+ symbols, `priceMap` may consume 50–100 MB during `_computeUnbiasedRuleStats()`. Pre-launch acceptable; post-launch may need batched processing.

3. **Drift transaction semantics**: Behavior of `_db.transaction()` under mid-iteration crash needs verification at implementation time.

4. **`daily_reason` `maxReasonsPerStock = 60` cap**: Although permissive, a stock triggering >60 unique rules would silently truncate. Rare in practice.

5. **No out-of-sample validation** in `recalibrate.dart` v1: train/test split is mentioned in locked decisions but deferred to Stage 4 (requires real data to meaningfully validate).

---

## 10. Stage Transitions

```
Stage 1 ✅ (merged)
  ↓
Stage 2 LEAN (this doc)  ← YOU ARE HERE
  ↓
Stage 3 — historical backfill (optional, can run in parallel with Stage 2)
  ↓
Stage 4 — run first real recalibration post-launch
  ↓
Stage 5 (new) — runtime JSON loader + dual-horizon scoring pipeline + UI tabs
```

Stage 2 **does not unblock anything user-visible on its own**; its value is:
- ✅ `rule_accuracy` UI (e.g. `getRuleSummaryText` "命中率 65%") becomes honest (unbiased stats)
- ✅ Calibration pipeline is ready to execute when data exists
- ✅ 60D horizon supported in backfill

User-visible scoring improvements from calibrated values come in Stage 5.
