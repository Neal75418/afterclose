# Scoring Overhaul Stage 5b — Dual-Horizon Scoring Pipeline Design

**Date**: 2026-04-11
**Scope**: Stage 5b of the scoring overhaul — dual-horizon scoring pipeline + schema migration
**Status**: Design locked via `/brainstorming`, ready for implementation
**Related**: [`rule_engine.dart`](../../lib/domain/services/rule_engine.dart), [`scoring_isolate.dart`](../../lib/domain/services/scoring_isolate.dart), [`analysis_tables.dart`](../../lib/data/database/tables/analysis_tables.dart), [Stage 5a design](2026-04-11-stage5a-runtime-loader-design.md)

---

## 1. Context & Motivation

Stage 5a landed (commits `a140643`, `d1fe17b`, `4f6647a` on `origin/main`) and delivered the runtime loader infrastructure:

- `CalibratedScoresRegistry` singleton with `loadFromAssets()` at app startup
- `CalibratedScoresTable` immutable data structure with `parseJson()` Q4 policy
- `ReasonType.scoreFor(Horizon)` extension (main-isolate only)
- Placeholder JSON stubs with empty `rules: {}`

**The gap**: Stage 5a's loader is **only accessible in the main isolate**. The scoring isolate (`scoring_isolate.dart`) still uses `ReasonType.score` getter (hardcoded), and produces a single `int score` per stock. The entire scoring pipeline is single-horizon.

**Stage 5b delivers**: End-to-end dual-horizon scoring. Each stock on each day gets both a `scoreShort` and `scoreLong`, computed in a single evaluation pass using calibrated scores passed through the isolate boundary. Database schema migrates to support two independent Top 20 lists per day (short + long horizon pivot). Existing UI continues to display the short-horizon view as default until Stage 5c adds tab switching.

### Explicitly out of scope (pushed to Stage 5c)

- **UI tab switching** for short/long Top 20 views
- **`selectedHorizonProvider`** Riverpod state
- **`analysis_summary_service` horizon-awareness** (Stage 5b hardcodes `ruleScoreShort` for all call sites)
- **Per-horizon cooldown tracking** (Stage 5b uses global cooldown lookup)
- **Split `dailyTopN` / `minScoreThreshold` / `cooldownPenalty` per horizon** (Stage 5b keeps shared)

---

## 2. Locked Decisions

Five questions were resolved during brainstorming (2026-04-11):

| # | Question | Decision | Rationale |
|---|---|---|---|
| Q1 | Computation strategy | **方案 A** — single pass, aggregate-layer recompute | Rules stay untouched (62 files); `calculateScore` becomes horizon-aware; mutex dedup still runs once; lowest blast radius |
| Q2 | Isolate transport | **方案 Z** — `CalibratedScoreContext` typed DTO, single field in `ScoringIsolateInput` | Matches CLAUDE.md "Isolate 通訊: 使用 typed DTO" convention; cleaner than paired raw maps; reuses semantic boundary |
| Q3 | Schema strategy | **方案 B + Q-easy** — `daily_recommendation` horizon pivot (40 rows/day); `daily_analysis`/`daily_reason` clean break to `score_short`/`score_long` columns | Two independent Top 20 lists is semantically correct; pre-launch = no migration needed; Q-easy avoids ambiguous legacy alias |
| Q4 | Pipeline structure | **方案 I + S + G** — single evaluation, shared params, global cooldown | Avoid 2x compute (rule eval is expensive); no YAGNI splitting of parameters; cooldown "seen in either tab = seen" matches user mental model |
| Q5 | UI migration scope | **方案 A** — minimal changes, DAO gets `Horizon` parameter, all call sites hardcode `Horizon.short` as Stage 5b default | Q-easy forces UI layer rename; minimal avoids duplicating Stage 5c's work; placeholder JSON = zero user-visible change |

---

## 3. Architecture

### 3.1 File layout & blast radius

```
lib/core/constants/calibrated_scores/
├── horizon.dart                          (unchanged — Stage 5a)
├── calibrated_scores_table.dart          (+ scoresSnapshot() method)
├── calibrated_scores_registry.dart       (+ snapshotForIsolate() method)
└── calibrated_score_context.dart         [NEW] typed DTO for isolate transport

lib/data/database/
├── tables/analysis_tables.dart           (* 3 tables: DailyAnalysis, DailyReason, DailyRecommendation)
├── dao/analysis_dao.dart                 (* horizon-aware queries + inserts)
└── app_database.dart                     (unchanged — schemaVersion stays 1)

lib/domain/services/
├── rule_engine.dart                      (* calculateScore signature change)
├── scoring_isolate.dart                  (* Input/Output DTOs + _evaluateStocksIsolated body)
├── scoring_service.dart                  (* dual topN sort + per-horizon insert)
└── analysis_summary_service.dart         (* 10 ruleScore refs → ruleScoreShort)

lib/data/repositories/
└── analysis_repository.dart              (* insert/query paths pass Horizon)

lib/presentation/
├── providers/today_provider.dart         (* RecommendationWithDetails rename)
├── screens/today/today_screen.dart       (* field reference update)
├── screens/analysis/recommendation_performance_screen.dart (* field rename)
└── services/export_service.dart          (* 2 ruleScore refs → ruleScoreShort)

test/
├── core/constants/calibrated_scores/calibrated_score_context_test.dart [NEW]
├── domain/services/rule_engine_test.dart (* new horizon cases)
├── domain/services/scoring_service_test.dart (* dual-score tests)
├── data/database/dao/analysis_dao_test.dart (* horizon-aware tests)
├── data/repositories/analysis_repository_test.dart (* dual-score writes)
└── (+ ~20 test files with ruleScore → ruleScoreShort mechanical rename)

* = modified
[NEW] = added
```

**Total estimate**: ~20 lib/ files modified, 1 new lib/ file, ~10-15 test files modified, 1 new test file, ~29 new test cases.

### 3.2 Data flow (post-Stage 5b)

```
main isolate startup
  └─ CalibratedScoresRegistry.instance.loadFromAssets(knownRuleIds: ...)
         ↓
scoring pipeline run (triggered by update_service)
  └─ scoring_service.scoreStocksInIsolate(...)
         ├─ build ScoringIsolateInput with:
         │    calibratedScores: registry.snapshotForIsolate()
         │      → CalibratedScoreContext(shortScores: {...}, longScores: {...})
         ↓
Isolate.run(_evaluateStocksIsolated)
  └─ for each candidate stock:
       ├─ reasons = ruleEngine.evaluateStock(context, stockData)   [once]
       ├─ scoreShort = ruleEngine.calculateScore(                   [twice]
       │    reasons, horizon: Horizon.short,
       │    calibratedScores: input.calibratedScores,
       │    wasRecentlyRecommended: wasRecent)
       ├─ scoreLong  = ruleEngine.calculateScore(
       │    reasons, horizon: Horizon.long,
       │    calibratedScores: input.calibratedScores,
       │    wasRecentlyRecommended: wasRecent)
       └─ output: ScoringIsolateOutput(symbol, scoreShort, scoreLong, ...)
         ↓
main isolate receives batch
  └─ scoring_service:
       ├─ topShort = outputs.sortBy(scoreShort).take(dailyTopN)
       ├─ topLong  = outputs.sortBy(scoreLong).take(dailyTopN)
       ├─ repository.insertRecommendations(date, topShort, Horizon.short)
       ├─ repository.insertRecommendations(date, topLong,  Horizon.long)
       └─ daily_analysis entries written with both (scoreShort, scoreLong)
         ↓
UI
  └─ today_provider reads daily_recommendation WHERE horizon = 'short' ORDER BY rank
     (Stage 5c replaces 'short' with ref.watch(selectedHorizonProvider))
```

### 3.3 Invariants

- **Schema version stays 1** — pre-launch, Drift auto-recreates tables on schema diff
- **Rules 62 files unchanged** — Q1 方案 A core promise
- **Stage 5a's `ReasonType.scoreFor(Horizon)` unchanged** — that's main-isolate API; Stage 5b builds a parallel mechanism inside the isolate via DTO
- **User-visible behavior is zero-change** — placeholder JSON has `rules: {}`, so `calibratedScores.lookup(h, id) == null` always → fallback to `reason.score` (hardcoded embedded) → scoreShort == scoreLong == pre-Stage-5b score
- **`TriggeredReason.score` becomes a fallback layer** — no longer the primary source, but retained as defensive fallback when calibrated data is missing

---

## 4. Components

### 4.1 `CalibratedScoreContext` typed DTO (new)

```dart
// lib/core/constants/calibrated_scores/calibrated_score_context.dart
@immutable
class CalibratedScoreContext {
  const CalibratedScoreContext({
    required this.shortScores,
    required this.longScores,
  });

  final Map<String, int> shortScores;
  final Map<String, int> longScores;

  factory CalibratedScoreContext.empty() =>
      const CalibratedScoreContext(shortScores: {}, longScores: {});

  /// Horizon-aware lookup; returns null if rule is not calibrated for this horizon.
  /// Caller falls back to hardcoded score via TriggeredReason.score.
  int? lookup(Horizon h, String ruleId) => switch (h) {
    Horizon.short => shortScores[ruleId],
    Horizon.long => longScores[ruleId],
  };

  Map<String, dynamic> toMap() => {
    'shortScores': shortScores,
    'longScores': longScores,
  };

  factory CalibratedScoreContext.fromMap(Map<String, dynamic> map) =>
      CalibratedScoreContext(
        shortScores: Map<String, int>.from((map['shortScores'] ?? {}) as Map),
        longScores: Map<String, int>.from((map['longScores'] ?? {}) as Map),
      );
}
```

### 4.2 `CalibratedScoresRegistry.snapshotForIsolate()` (new method)

```dart
// lib/core/constants/calibrated_scores/calibrated_scores_registry.dart
CalibratedScoreContext snapshotForIsolate() {
  return CalibratedScoreContext(
    shortScores: _short?.scoresSnapshot() ?? const {},
    longScores: _long?.scoresSnapshot() ?? const {},
  );
}
```

`CalibratedScoresTable.scoresSnapshot()` returns `Map<String, int>` via `Map.unmodifiable(_scores)` — safe cross-isolate transport without exposing mutation.

### 4.3 `rule_engine.calculateScore()` — horizon-aware signature

```dart
// lib/domain/services/rule_engine.dart
int calculateScore(
  List<TriggeredReason> reasons, {
  required Horizon horizon,
  required CalibratedScoreContext calibratedScores,
  bool wasRecentlyRecommended = false,
}) {
  // 1. Mutex group dedup (unchanged from Stage 1)
  final deduped = _applyMutexGroups(reasons);

  // 2. Sum scores with horizon-aware calibrated lookup + per-rule fallback
  var score = 0;
  for (final reason in deduped) {
    final calibrated = calibratedScores.lookup(horizon, reason.type.code);
    score += calibrated ?? reason.score;  // fallback to hardcoded embedded
  }

  // 3. Cooldown + clamp (unchanged)
  if (wasRecentlyRecommended) score -= RuleParams.cooldownPenalty;
  return score.clamp(0, RuleScores.maxScore);
}
```

### 4.4 `ScoringIsolateInput` — add `calibratedScores` field

```dart
class ScoringIsolateInput {
  const ScoringIsolateInput({
    // ... existing 17 fields
    required this.calibratedScores,
  });

  final CalibratedScoreContext calibratedScores;

  Map<String, dynamic> toMap() => {
    // ... existing keys
    'calibratedScores': calibratedScores.toMap(),
  };

  factory ScoringIsolateInput.fromMap(Map<String, dynamic> map) {
    return ScoringIsolateInput(
      // ... existing fields
      calibratedScores: map['calibratedScores'] != null
          ? CalibratedScoreContext.fromMap(
              Map<String, dynamic>.from(map['calibratedScores'] as Map),
            )
          : CalibratedScoreContext.empty(),
    );
  }
}
```

Non-nullable with `empty()` fallback matches Stage 5a's philosophy: empty context means "fall back to hardcoded", callers never need null-check.

### 4.5 `ScoringIsolateOutput` — dual score fields

```dart
class ScoringIsolateOutput {
  const ScoringIsolateOutput({
    required this.symbol,
    required this.scoreShort,  // was: score
    required this.scoreLong,   // new
    required this.turnover,
    required this.trendState,
    required this.reversalState,
    this.supportLevel,
    this.resistanceLevel,
    required this.reasons,
  });

  final int scoreShort;
  final int scoreLong;
  // ... other fields unchanged
}
```

### 4.6 `IsolateReasonOutput` — dual score fields

```dart
class IsolateReasonOutput {
  const IsolateReasonOutput({
    required this.type,
    required this.scoreShort,  // was: score
    required this.scoreLong,   // new
    required this.description,
    required this.evidenceJson,
  });

  final int scoreShort;
  final int scoreLong;
}
```

`_reasonToOutput()` helper computes both scores at output time using the isolate-local `CalibratedScoreContext`:

```dart
IsolateReasonOutput _reasonToOutput(
  TriggeredReason reason,
  CalibratedScoreContext ctx,
) {
  return IsolateReasonOutput(
    type: reason.type.code,
    scoreShort: ctx.lookup(Horizon.short, reason.type.code) ?? reason.score,
    scoreLong: ctx.lookup(Horizon.long, reason.type.code) ?? reason.score,
    description: reason.description,
    evidenceJson: reason.evidenceJson != null
        ? jsonEncode(reason.evidenceJson)
        : '{}',
  );
}
```

---

## 5. Database Schema Migration

### 5.1 `DailyAnalysis` — Q-easy clean break

```dart
// Before
RealColumn get score => real().withDefault(const Constant(0))();

// After
RealColumn get scoreShort => real().withDefault(const Constant(0))();
RealColumn get scoreLong => real().withDefault(const Constant(0))();
```

**Indexes**:
- `idx_daily_analysis_date` (unchanged)
- `idx_daily_analysis_score_short` (replaces `idx_daily_analysis_score`)
- `idx_daily_analysis_score_long` (new)
- `idx_daily_analysis_symbol_date` (unchanged)
- `idx_daily_analysis_date_score_short` (replaces `idx_daily_analysis_date_score`)
- `idx_daily_analysis_date_score_long` (new)

PK `(symbol, date)` unchanged. Technical analysis fields (trendState/reversalState/support/resistance) are horizon-agnostic — only `score` splits.

### 5.2 `DailyReason` — Q-easy clean break

```dart
// Before
RealColumn get ruleScore => real().withDefault(const Constant(0))();

// After
RealColumn get ruleScoreShort => real().withDefault(const Constant(0))();
RealColumn get ruleScoreLong => real().withDefault(const Constant(0))();
```

PK `(symbol, date, rank)` unchanged. `reasonType`/`evidenceJson` are horizon-agnostic — same rule fires regardless of horizon, only contribution differs.

### 5.3 `DailyRecommendation` — 方案 B horizon pivot

```dart
@DataClassName('DailyRecommendationEntry')
@TableIndex(name: 'idx_daily_recommendation_date_horizon', columns: {#date, #horizon})
@TableIndex(name: 'idx_daily_recommendation_symbol', columns: {#symbol})
@TableIndex(
  name: 'idx_daily_recommendation_date_horizon_symbol',
  columns: {#date, #horizon, #symbol},
)
class DailyRecommendation extends Table {
  DateTimeColumn get date => dateTime()();

  /// Horizon 'short' | 'long' (Stage 5b pivot column)
  TextColumn get horizon => text()();

  /// Rank within this horizon (1..dailyTopN)
  IntColumn get rank => integer()();

  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// Score for this horizon (single column — row is already per-horizon)
  RealColumn get score => real()();

  @override
  Set<Column> get primaryKey => {date, horizon, rank};

  @override
  List<Set<Column>> get uniqueKeys => [
    {date, horizon, symbol},
  ];
}
```

Up to 40 rows per day (20 short + 20 long, horizons independent).

### 5.4 Unchanged tables

- **`RuleAccuracy`** — already per-rule per-period, horizon-agnostic at row level
- **`RecommendationValidation`** — per-symbol-date-holdingDays, validation semantics are horizon-agnostic in Stage 5b (Stage 4 may revisit when running real calibration)

### 5.5 Drift rebuild

```bash
dart run build_runner build --delete-conflicting-outputs
```

This regenerates `analysis_tables.g.dart` + `app_database.g.dart`. Build must happen inside Commit 2 (see §7.2) before modifying DAO and call sites, otherwise the intermediate state is uncompilable.

### 5.6 Schema reset behavior

Pre-launch schemaVersion stays 1. On first app launch after merging Stage 5b, Drift detects the schema diff and auto drops + recreates the three modified tables. This wipes existing `daily_price`, `daily_analysis`, `daily_reason`, `daily_recommendation` data on the developer machine. Per the Stage 2 agreement ("產品尚未上線前使用 version 1, derived data 可隨時清除"), this is expected behavior — next `flutter run` will re-sync historical data.

---

## 6. DAO & Repository Changes

### 6.1 `analysis_dao.dart` — horizon-aware methods

**Query**:
```dart
Future<List<DailyRecommendationEntry>> getRecommendationsForDate(
  DateTime date, {
  required Horizon horizon,  // required, no default
}) {
  return (select(dailyRecommendation)
        ..where((t) =>
            t.date.equals(date) & t.horizon.equals(horizon.name))
        ..orderBy([(t) => OrderingTerm.asc(t.rank)]))
      .get();
}
```

**Insert**:
```dart
Future<void> insertRecommendationsForHorizon(
  DateTime date,
  Horizon horizon,
  List<DailyRecommendationCompanion> recs,
) async {
  await batch((b) {
    // Clear existing rows for this (date, horizon) combination
    b.deleteWhere(
      dailyRecommendation,
      (t) => t.date.equals(date) & t.horizon.equals(horizon.name),
    );
    b.insertAll(dailyRecommendation, recs);
  });
}
```

### 6.2 `analysis_repository.dart` — pass Horizon through

The scoring pipeline write path (`analysis_repository.dart:115`):

```dart
// Before
ruleScore: Value(reason.score.toDouble()),

// After
ruleScoreShort: Value(reason.scoreShort.toDouble()),
ruleScoreLong: Value(reason.scoreLong.toDouble()),
```

And the Top 20 insert splits into two calls:
```dart
await dao.insertRecommendationsForHorizon(date, Horizon.short, shortRecs);
await dao.insertRecommendationsForHorizon(date, Horizon.long, longRecs);
```

UI read paths (e.g., `today_provider`) hardcode `Horizon.short` as Stage 5b default:
```dart
final recs = await dao.getRecommendationsForDate(
  date,
  horizon: Horizon.short,  // Stage 5c replaces with ref.watch(selectedHorizonProvider)
);
```

---

## 7. Implementation Sequence

### 7.1 Commit 1 — `CalibratedScoreContext` DTO (pure additive)

**Message**: `feat(scoring): add CalibratedScoreContext DTO for isolate transport`

**Changes**:
- New file `lib/core/constants/calibrated_scores/calibrated_score_context.dart`
- `CalibratedScoresTable.scoresSnapshot()` method (returns `Map.unmodifiable(_scores)`)
- `CalibratedScoresRegistry.snapshotForIsolate()` method
- New test file `test/core/constants/calibrated_scores/calibrated_score_context_test.dart` (~5 cases: empty / lookup short/long / toMap round-trip / registry snapshot / immutability)

**Untouched**: scoring pipeline, schema, DAO, UI

**Expected test count**: 2329 → 2334 (+5)

### 7.2 Commit 2 — Drift schema migration + call site rename (atomic)

**Message**: `refactor(db): migrate to dual-horizon schema with Drift rebuild`

**Sub-steps within the commit**:
1. Modify `analysis_tables.dart` (3 tables + indexes)
2. Run `dart run build_runner build --delete-conflicting-outputs`
3. Update `analysis_dao.dart` (horizon-aware query/insert methods)
4. Update `analysis_repository.dart` (pass Horizon through; temporarily write `scoreShort = scoreLong = score` since pipeline is still single-score)
5. Update `analysis_summary_service.dart` (10 `ruleScore` refs → `ruleScoreShort`)
6. Update `export_service.dart` (2 refs)
7. Update `today_provider.dart`, `today_screen.dart`, `recommendation_performance_screen.dart`
8. Update ~20 test files (`ruleScore` → `ruleScoreShort` mechanical rename, helper API update)

**Why atomic**: Drift's codegen forces all column references to match the regenerated `.g.dart`. Any intermediate state between `build_runner` and the last call-site update is uncompilable. Splitting this commit is not possible.

**Expected test count**: 2334 → 2334-2336 (~0 net new, mostly renames; may add 1-2 schema validation tests)

**Risk**: Blast radius is large (~10-12 lib/ files + ~10-15 test files). Mitigation: commit message will clearly list "schema changes" vs "call site renames" sections.

### 7.3 Commit 3 — Dual-horizon scoring pipeline (core logic)

**Message**: `feat(scoring): dual-horizon scoring with calibrated context`

**Changes**:
- `rule_engine.calculateScore()` signature change (horizon + calibratedScores required params)
- `ScoringIsolateInput` adds `calibratedScores` field
- `ScoringIsolateOutput` dual-score fields (`scoreShort`, `scoreLong`)
- `IsolateReasonOutput` dual-score fields
- `_evaluateStocksIsolated` calls `calculateScore` twice per stock with isolate-local `CalibratedScoreContext`
- `scoring_service` does two sort+topN passes, calls `insertRecommendationsForHorizon` twice
- Rule engine tests (~8 new cases covering horizon-aware happy path + fallback + calibrated override)
- Scoring service tests (~6 new cases covering dual-score output + dual topN)
- Repository tests (~3 cases for per-horizon writes)
- DAO tests (~5 cases for horizon-filtered queries)

**Expected test count**: 2334-2336 → ~2358 (+22-24)

### 7.4 Commit 4 — Code-reviewer findings followup (if needed)

After Commit 3 completes, run `pr-review-toolkit:code-reviewer` on the full Stage 5b diff. Expected findings: 1 real bug + 2-4 polish items (similar scale to Stage 5a). Followup commit addresses all must-fix items.

**Message**: `fix(scoring): address Stage 5b code-reviewer findings`

---

## 8. Test Strategy

### 8.1 Layer-by-layer coverage

| Layer | Test file | New cases | Focus |
|---|---|---|---|
| DTO | `calibrated_score_context_test.dart` (new) | ~5 | Construction, lookup, serialization round-trip, immutability |
| Rule engine | `rule_engine_test.dart` (existing) | ~8 | Horizon-aware scoring with calibrated + fallback, mutex unchanged across horizons, cooldown both horizons |
| Scoring pipeline | `scoring_service_test.dart` (existing) | ~6 | Dual-score output, dual topN sorting, isolate serialization round-trip |
| DAO | `analysis_dao_test.dart` (existing) | ~5 | Horizon-filtered queries, 40-row insert, UNIQUE constraint |
| Repository | `analysis_repository_test.dart` (existing) | ~3 | Per-horizon write paths |
| Schema | `app_database_test.dart` (existing) | ~2 | Table schema + index creation |

**Total estimated new cases**: ~29
**Total estimated test count after Stage 5b**: ~2358

### 8.2 Critical regression test

**"Empty context preserves Stage 5a behavior"**:
```dart
test('empty CalibratedScoreContext produces score identical to old calculateScore', () {
  // Given: same reasons input as pre-Stage-5b
  // When: calculateScore with CalibratedScoreContext.empty()
  // Then: resulting int matches what the old calculateScore would return
  //       (i.e., sum of reason.score + cooldown + clamp)
});
```

This test anchors the invariant that Stage 5b introduces zero user-visible change when the calibrated JSON is empty.

### 8.3 Code-reviewer gate focus

Run after Commit 3, before push:
1. `calculateScore` fallback logic correctness (calibrated miss → `reason.score` path)
2. Isolate boundary serialization (`CalibratedScoreContext.fromMap` with null/empty/wrong-type)
3. Schema PK correctness — `DailyRecommendation (date, horizon, rank)` insert conflict behavior
4. Test coverage of dual-horizon corner cases
5. `snapshotForIsolate()` thread safety (`Map.unmodifiable` across isolate boundary)

---

## 9. Known Limitations & Non-Goals

- **`analysis_summary_service` is horizon-agnostic** — all 10 call sites hardcoded to `ruleScoreShort` in Stage 5b. Stage 5c must revisit this service to add `Horizon` parameter.
- **UI shows short horizon only** — `today_provider` hardcoded `Horizon.short`. Stage 5c introduces `selectedHorizonProvider` and tab switching.
- **Cooldown is global** — if a stock was recently in either short or long Top 20, it's "recently recommended" for both horizons. Per-horizon cooldown split is Stage 5c+ if needed.
- **`dailyTopN` / `minScoreThreshold` / `cooldownPenalty` shared** — not split per horizon. YAGNI until real data suggests otherwise.
- **Pre-launch = zero behavior change** — placeholder JSON has empty rules; every `scoreShort`/`scoreLong` equals the pre-Stage-5b hardcoded `score`. All 2329 existing tests are expected to remain green modulo field renames.
- **Dev machine DB reset** — Drift auto drop+recreate on schema diff wipes `daily_price` / `daily_analysis` / `daily_reason` / `daily_recommendation`. Requires re-running `flutter run` to let syncers repopulate.

---

## 10. Stage Transitions

| Stage | Requires | Delivers |
|---|---|---|
| **5a** (shipped) | — | Runtime loader + `ReasonType.scoreFor(Horizon)` main-isolate API |
| **5b** (this doc) | 5a | Dual-horizon scoring pipeline + schema pivot + minimal UI rename |
| **5c** (next) | 5b | `selectedHorizonProvider` Riverpod state; tab UI; `analysis_summary_service` horizon-aware; remove `Horizon.short` hardcoded defaults |
| **3** (optional) | — | Historical backfill via TWSE/FinMind |
| **4** (post-launch) | launch + 2-3mo data | First real calibration run via `tool/recalibrate.dart` |

Stage 5b is a **backend-heavy delivery** that enables Stage 5c's UI work. After Stage 5b merges, the entire dual-horizon scoring pipeline is live and writing to DB, but users see only the short-horizon view until Stage 5c adds tab switching.
