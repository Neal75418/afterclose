# Scoring Overhaul Stage 5a — Runtime Calibrated Scores Loader Design

**Date**: 2026-04-11
**Scope**: Stage 5a of the scoring overhaul — runtime JSON loader for calibrated rule scores
**Status**: Design locked via `/brainstorming`, ready for implementation
**Related**: [`rule_scores.dart`](../../lib/core/constants/rule_scores.dart), [`reason_type.dart`](../../lib/core/constants/reason_type.dart), [`main.dart`](../../lib/main.dart), [Stage 2 design](2026-04-11-scoring-stage2-design.md)

---

## 1. Context & Motivation

Stage 2 LEAN landed (commits `e562519`, `61fa95d`, `a5a9fa0`, `63a95ae` on `origin/main`) and built the calibration pipeline:

- `rule_accuracy_service.dart` now sources per-rule stats from `daily_reason` (fixes primary_rule_id bias)
- 60D horizon + parameterized success thresholds (5D ≥ 3%, 60D ≥ 12%)
- `tool/recalibrate.dart` writes candidate JSON to `assets/rule_scores_calibrated_{short,long}_candidate.json`
- Placeholder stubs at `assets/rule_scores_calibrated_{short,long}.json` with empty `rules: {}`

**The gap**: `RuleScores` (62 `static const int` scores in [`rule_scores.dart`](../../lib/core/constants/rule_scores.dart)) is still hardcoded. Nothing reads the calibrated JSON files at runtime.

**Stage 5a delivers**: A fallback-safe loader that parses the calibrated JSON at app startup, exposes horizon-aware score lookup via a new `ReasonType.scoreFor(Horizon)` method, and falls back to hardcoded `RuleScores` whenever the calibrated data is missing, malformed, or unavailable.

### Explicitly out of scope (pushed to Stage 5b/5c)

- **Wiring the loader into `scoring_isolate.dart`** — requires `ScoringIsolateInput` schema changes and dual-horizon scoring pipeline
- **Migrating existing `ReasonType.score` getter to use the loader** — Stage 5a keeps the getter untouched; `scoreFor(Horizon)` is a new parallel API
- **`daily_analysis` / `daily_recommendation` schema changes** for dual-horizon scores
- **UI tabs** for short/long Top 20

---

## 2. Locked Decisions

Five questions were resolved during brainstorming (2026-04-11):

| # | Question | Decision | Rationale |
|---|---|---|---|
| Q1 | Stage 5a scope | **方案 C** — loader + new `ReasonType.scoreFor(Horizon)` method; keep existing `score` getter untouched | Minimize blast radius; avoid touching 129 call sites; provide a future-facing API for Stage 5b migration without breaking existing code |
| Q2 | Loader lifecycle | **方案 X** — main-isolate-only singleton; Stage 5a does not modify `ScoringIsolateInput` | Separation of concerns: Stage 5a owns the loader, Stage 5b owns isolate plumbing. Pre-launch JSON is empty so scoring-isolate code path is unaffected. |
| Q3 | Horizon type | **方案 Q** — enhanced enum with metadata, 2 fixed values (`short`, `long`) | Dart 3 idiomatic; single source of truth for `tradingDays` / `successThresholdPct` / `assetPath`; compile-time const |
| Q4 | Fallback policy | **方案 III** — structure strict, content lenient; clamp scores to `[-50, 80]` | Reject malformed structure (hard fail) but accept partial/evolving rule coverage (per-rule fallback). Clamp protects runtime from calibration outliers. |
| Q5 | Test strategy | **方案 β** + **semantic C** — 3-layer testing with idempotent load + `resetForTesting` escape hatch | Layer 1 (parser) + Layer 2 (asset smoke) + Layer 3 (singleton lifecycle) covers the full surface without over-engineering |

---

## 3. Architecture

### 3.1 File layout

```
lib/core/constants/
├── rule_scores.dart                       (unchanged — Q1 promise)
├── reason_type.dart                        (+ ReasonTypeCalibratedScore extension)
└── calibrated_scores/                      (new)
    ├── horizon.dart                        (Horizon enum with metadata)
    ├── calibrated_scores_table.dart        (immutable table + pure parseJson)
    └── calibrated_scores_registry.dart     (main-isolate singleton)

lib/main.dart                                (+ 1 line: await loadFromAssets)

test/core/constants/calibrated_scores/
└── calibrated_scores_test.dart              (new — 30 cases, 3 layers)
```

**Dependency DAG** (single-direction, no cycles):

```
reason_type.dart
  └→ calibrated_scores_registry.dart
       └→ calibrated_scores_table.dart
            └→ horizon.dart
```

Placing the loader under `core/constants/calibrated_scores/` follows the CLAUDE.md "配置集中" principle — the loader is a runtime replacement for hardcoded constants, not a business service.

### 3.2 Lifecycle

```
main() [main isolate, startup]
  ├─ WidgetsFlutterBinding.ensureInitialized()
  ├─ (existing initializers: orientation, localization, notifications, ...)
  ├─ await initOnboardingStatus()
  ├─ await CalibratedScoresRegistry.instance.loadFromAssets()    ← NEW
  │     ├─ _loadOne(Horizon.short)
  │     │    ├─ rootBundle.loadString('assets/rule_scores_calibrated_short.json')
  │     │    ├─ CalibratedScoresTable.parseJson(jsonStr, horizon: short)
  │     │    │    → (table, warnings)
  │     │    └─ warnings (capped at 10) → AppLogger.warning
  │     └─ _loadOne(Horizon.long)
  ├─ cache warmup (non-blocking, unchanged)
  └─ Sentry.init → runApp
```

Expected startup latency: **<5ms** at the placeholder state (empty `rules: {}`), well below observable threshold.

### 3.3 Query path

```
UI / debug / future consumer
  ↓
reasonType.scoreFor(Horizon.short)
  ↓
CalibratedScoresRegistry.instance.lookup(Horizon.short, reasonType.code)
  ↓
short-horizon table.lookup('REVERSAL_W2S')    [Map<String, int> O(1)]
  ↓
  ├─ registry not loaded  → null → fallback to reasonType.score (hardcoded)
  ├─ key not in table     → null → fallback to reasonType.score (hardcoded)
  └─ key present          → int → return calibrated value
```

All queries are **synchronous** and non-blocking. The `scoring_isolate.dart` code path is unchanged in Stage 5a; it continues to use the existing `reasonType.score` getter (hardcoded).

---

## 4. Components

### 4.1 `horizon.dart`

```dart
enum Horizon {
  short(
    tradingDays: 5,
    successThresholdPct: 3.0,
    assetPath: 'assets/rule_scores_calibrated_short.json',
  ),
  long(
    tradingDays: 60,
    successThresholdPct: 12.0,
    assetPath: 'assets/rule_scores_calibrated_long.json',
  );

  const Horizon({
    required this.tradingDays,
    required this.successThresholdPct,
    required this.assetPath,
  });

  final int tradingDays;
  final double successThresholdPct;
  final String assetPath;
}
```

### 4.2 `calibrated_scores_table.dart`

```dart
typedef CalibratedScoresParseResult = ({
  CalibratedScoresTable table,
  List<String> warnings,
});

@immutable
class CalibratedScoresTable {
  const CalibratedScoresTable({
    required this.horizon,
    required this.schemaVersion,
    required this.generatedAt,
    required Map<String, int> scores,
  }) : _scores = scores;

  final Horizon horizon;
  final int schemaVersion;
  final DateTime? generatedAt;
  final Map<String, int> _scores;

  /// Returns null if the rule is not in the calibrated table.
  /// Caller must fall back to hardcoded `RuleScores` via `ReasonType.score`.
  int? lookup(String ruleId) => _scores[ruleId];

  int get ruleCount => _scores.length;

  /// Pure parser — does NOT depend on Flutter binding, safe for unit test.
  /// Policy: Q4 方案 III (structure strict, content lenient, clamp [-50, 80]).
  static CalibratedScoresParseResult parseJson(
    String jsonStr, {
    required Horizon horizon,
  }) {
    // See §5 for the full error policy table.
  }

  /// Safe fallback used when JSON is malformed or asset is missing.
  static CalibratedScoresTable empty(Horizon horizon) => CalibratedScoresTable(
        horizon: horizon,
        schemaVersion: 0,
        generatedAt: null,
        scores: const {},
      );
}
```

### 4.3 `calibrated_scores_registry.dart`

```dart
/// Main-isolate singleton. Do NOT use inside scoring isolate (Stage 5b).
class CalibratedScoresRegistry {
  CalibratedScoresRegistry._();
  static final CalibratedScoresRegistry instance = CalibratedScoresRegistry._();

  CalibratedScoresTable? _short;
  CalibratedScoresTable? _long;
  bool _loaded = false;

  /// Idempotent: safe to call multiple times (supports hot reload).
  Future<void> loadFromAssets() async {
    if (_loaded) return;
    _short = await _loadOne(Horizon.short);
    _long = await _loadOne(Horizon.long);
    _loaded = true;
  }

  int? lookup(Horizon h, String ruleId) => switch (h) {
        Horizon.short => _short?.lookup(ruleId),
        Horizon.long => _long?.lookup(ruleId),
      };

  @visibleForTesting
  void resetForTesting() {
    _short = null;
    _long = null;
    _loaded = false;
  }

  @visibleForTesting
  void bindForTesting({
    CalibratedScoresTable? short,
    CalibratedScoresTable? long,
  }) {
    _short = short;
    _long = long;
    _loaded = true;
  }

  Future<CalibratedScoresTable> _loadOne(Horizon h) async {
    try {
      final jsonStr = await rootBundle.loadString(h.assetPath);
      final (:table, :warnings) = CalibratedScoresTable.parseJson(
        jsonStr,
        horizon: h,
      );
      _logCappedWarnings(h, warnings);
      return table;
    } catch (e, st) {
      AppLogger.error(
        'CalibratedScoresRegistry',
        'Failed to load ${h.assetPath}',
        e,
        st,
      );
      return CalibratedScoresTable.empty(h);
    }
  }

  void _logCappedWarnings(Horizon h, List<String> warnings) {
    const maxPerHorizon = 10;
    final toLog = warnings.take(maxPerHorizon);
    for (final msg in toLog) {
      AppLogger.warning('CalibratedScoresRegistry', '[${h.name}] $msg');
    }
    if (warnings.length > maxPerHorizon) {
      AppLogger.warning(
        'CalibratedScoresRegistry',
        '[${h.name}] ${warnings.length - maxPerHorizon} more warnings suppressed',
      );
    }
  }
}
```

### 4.4 `ReasonType.scoreFor` extension

```dart
extension ReasonTypeCalibratedScore on ReasonType {
  /// Horizon-aware score lookup with fallback.
  ///
  /// - If registry has a calibrated value for this rule → returns calibrated
  /// - Otherwise → returns `reasonType.score` (hardcoded RuleScores fallback)
  ///
  /// **NOTE**: Main isolate only. Scoring isolate continues to use the
  /// existing `score` getter (Stage 5b will wire dual-horizon scoring).
  int scoreFor(Horizon horizon) {
    final calibrated = CalibratedScoresRegistry.instance.lookup(horizon, code);
    return calibrated ?? score;
  }
}
```

### 4.5 `main.dart` delta

```dart
await initOnboardingStatus();

// Stage 5a: 載入 calibrated scores JSON（pre-launch placeholder 為空，
// 所有查詢走 RuleScores hardcoded fallback；上線後由 Stage 4 recalibrate 填入）
await CalibratedScoresRegistry.instance.loadFromAssets();

// 快取預熱（非阻塞）
container.read(cacheWarmupServiceProvider).warmup()...
```

---

## 5. Error Policy (Q4 方案 III)

`parseJson` handles 15 distinct scenarios. Structure errors return `empty(horizon)` + warnings; content errors skip the offending rule + warning; unknown rule IDs are skipped with a warning for debuggability.

| # | Scenario | Behavior | Warning message (or outcome) |
|---|---|---|---|
| 1 | Malformed JSON (`FormatException`) | Return `empty(horizon)` | `malformed JSON: <exception>` |
| 2 | Root is not a Map | Return `empty(horizon)` | `root must be object, got <type>` |
| 2a | `schema_version` missing / non-int | Return `empty(horizon)` | `schema_version missing or invalid` |
| 2b | `schema_version != 1` | Return `empty(horizon)` | `unsupported schema_version: <n>` |
| 2c | `rules` field missing | Return `empty(horizon)` | `rules field missing` |
| 2d | `rules` is not a Map | Return `empty(horizon)` | `rules must be object, got <type>` |
| 3 | `rules: {}` (placeholder state) | Return empty table | — (expected, no warning) |
| 4 | `rules` partially covers ReasonType | Return partial table | — (per-rule fallback is normal) |
| 5a | Single rule entry not an object | Skip + warning | `rule <id>: entry not object` |
| 5b | Rule `score` field missing | Skip + warning | `rule <id>: score field missing` |
| 5c | Rule `score` not numeric | Skip + warning | `rule <id>: score not numeric` |
| 6a | `score > 80` | Clamp to 80 + warning | `rule <id>: score <n> clamped to 80` |
| 6b | `score < -50` | Clamp to -50 + warning | `rule <id>: score <n> clamped to -50` |
| 7 | `rule_id` not in `ReasonType.values` | Skip + warning | `rule <id>: unknown ReasonType code, ignored (possibly removed or typo)` |
| 8 | `ReasonType` exists but JSON missing | Natural fallback (not handled in parser) | — (table.lookup returns null, caller falls back) |

**Design notes**:

- Clamp boundaries `[-50, 80]` are derived from current hardcoded `RuleScores` range: `maxScore = 80` (already exists), `minScore = -50` (derived from `tradingWarningDisposal = -50`, the most negative hardcoded constant). A new `RuleScores.minScore = -50` constant will be added in Commit 1.
- Scenario 7 warns instead of silent-ignoring. While codebase evolution (rule removal/rename) is an expected cause, the warning also catches real bugs (manual JSON edit typos, recalibrate.dart drift). One warning line per unknown rule is cheap; silently dropping calibration data is expensive.
- Scenario 8 is **not a parser concern** — the parser only produces the table. When `ReasonType.scoreFor(h)` queries a rule not in the table, the table's `lookup` returns null and the caller falls back naturally.
- Warnings are capped at **10 per horizon** at the registry log layer to prevent log spam. The underlying list (returned by parseJson) is unbounded so tests can assert on the full content.

---

## 6. Test Strategy (Q5 方案 β + semantic C)

Single test file `test/core/constants/calibrated_scores/calibrated_scores_test.dart`, organized via `group()` into three layers:

### Layer 1 — Pure parser tests (22 cases, no Flutter binding)

**Happy path (6 cases)**:

1. `happy_path_both_horizons_full` — 62 rules fully covered, all scores in [-50, 80]
2. `empty_rules_returns_empty_table` — `rules: {}` → empty table, 0 warnings
3. `partial_rules_returns_partial_table` — 3 rules present, others absent
4. `schema_version_1_accepted`
5. `generatedAt_parsed_correctly` — ISO 8601 parsing
6. `extra_unknown_top_level_fields_ignored` — `_note`, `backtest` metadata tolerated

**Structural errors (5 cases, scenarios 1–2d)**:

7. `malformed_json_returns_empty`
8. `root_not_object`
9. `schema_version_missing`
10. `schema_version_unsupported` (e.g., `2`)
11. `rules_missing_or_wrong_type`

**Per-rule content errors (7 cases, scenarios 5a–6b + 7)**:

12. `rule_entry_not_object` (e.g., `"REVERSAL_W2S": 25`)
13. `rule_score_missing`
14. `rule_score_not_numeric`
15. `rule_score_above_max_clamped_to_80` (`score: 999` → 80 + warning)
16. `rule_score_below_min_clamped_to_-50` (`score: -999` → -50 + warning)
17. `rule_score_at_boundary_not_clamped` (`score: 80` / `-50` → no warning)
18. `unknown_rule_id_skipped_with_warning` (`"FAKE_RULE": {...}`)

**Mixed scenarios (2 cases)**:

19. `mixed_valid_and_invalid_rules` — 10 valid + 3 invalid → table has 10, 3 warnings
20. `clamp_coexists_with_skip`

**Warning content assertions (2 cases)**:

21. `warning_messages_include_rule_id`
22. `warning_count_accumulates_correctly`

### Layer 2 — Registry asset smoke tests (2 cases, need `TestWidgetsFlutterBinding`)

23. `loadFromAssets_short_placeholder_succeeds` — real asset, `schemaVersion == 1`, `ruleCount == 0`, any lookup returns null
24. `loadFromAssets_long_placeholder_succeeds` — same for long

### Layer 3 — Singleton lifecycle tests (3 cases)

25. `lookup_before_load_returns_null`
26. `loadFromAssets_is_idempotent` — 3 consecutive calls execute load once
27. `resetForTesting_clears_state`

### Layer 3.5 — `ReasonType.scoreFor` end-to-end (3 cases)

28. `scoreFor_without_registry_load_uses_hardcoded` — equals `RuleScores.reversalW2S`
29. `scoreFor_with_bindForTesting_uses_calibrated` — fake table → calibrated value
30. `scoreFor_unknown_rule_in_fake_table_falls_back` — fake has only `REVERSAL_W2S`, query `TECH_BREAKOUT` returns hardcoded

**Total: 30 test cases.**

---

## 7. Implementation Sequence

### Commit 1 — Loader infrastructure (no wiring)

**Message**: `feat(scoring): add CalibratedScoresRegistry with fallback-safe JSON loader`

**Files added**:
- `lib/core/constants/calibrated_scores/horizon.dart`
- `lib/core/constants/calibrated_scores/calibrated_scores_table.dart`
- `lib/core/constants/calibrated_scores/calibrated_scores_registry.dart`
- `test/core/constants/calibrated_scores/calibrated_scores_test.dart` (Layers 1, 2, 3 — 27 cases)

**Files modified**:
- `lib/core/constants/rule_scores.dart` (+ `static const int minScore = -50;`)

**Untouched**:
- `reason_type.dart`, `main.dart`, `scoring_isolate.dart`, all scoring pipeline code

**Test count after commit**: 2292 → 2319 (+27)

### Commit 2 — Wire `ReasonType.scoreFor` + startup load

**Message**: `feat(scoring): wire ReasonType.scoreFor and startup JSON load`

**Files modified**:
- `lib/core/constants/reason_type.dart` (+ `ReasonTypeCalibratedScore` extension)
- `lib/main.dart` (+ 1 await line after `initOnboardingStatus()`)
- `test/core/constants/calibrated_scores/calibrated_scores_test.dart` (+ Layer 3.5 — 3 cases)

**Test count after commit**: 2319 → 2322 (+3)

### Code review gate

After Commit 2, before push:

- Run `pr-review-toolkit:code-reviewer` on the Stage 5a changes (`lib/core/constants/calibrated_scores/**`, `reason_type.dart`, `main.dart`, `rule_scores.dart`, test file)
- Expected focus: parser edge case completeness, error handling paths, singleton lifecycle correctness
- Address any must-fix in a followup commit

---

## 8. Known Limitations & Non-Goals

- **Main isolate only** — `ReasonType.scoreFor` is unsafe in the scoring isolate (singleton state is isolate-local and uninitialized there). Stage 5b will address this.
- **No schema migration path** — if `schema_version` ever changes, Stage 5a rejects with `unsupported schema_version`. A future stage can add migration logic.
- **No runtime observability for fallback rate** — Stage 5a does not track "how many queries hit calibrated vs fallback". A future metric layer can add this if Stage 4 calibration quality needs monitoring.
- **Pre-launch = zero behavior change** — with the empty placeholder JSON, every `scoreFor` query falls back to hardcoded. All 2292 existing tests remain unaffected.

---

## 9. Stage Transitions

| Stage | Requires | Delivers |
|---|---|---|
| **5a** (this doc) | — | Runtime loader + `ReasonType.scoreFor(Horizon)` API + main-isolate singleton |
| **5b** (future) | Stage 4 calibration output OR Stage 5a + decision to migrate | `ScoringIsolateInput` schema ext; dual-horizon scoring pipeline; `daily_analysis` / `daily_recommendation` schema additions |
| **5c** (future) | Stage 5b | UI tabs for short/long Top 20 lists |

Stage 5a is a **standalone deliverable**. It can ship and sit dormant until Stage 4 runs (post-launch) and populates the JSON with real calibrated values. At that point, any main-isolate consumer calling `ReasonType.scoreFor(h)` will automatically pick up the new values without further code changes.
