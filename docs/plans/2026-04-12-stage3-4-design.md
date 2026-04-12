# Scoring Overhaul Stage 3 + Stage 4 — Historical Backfill & First Real Calibration

**Date**: 2026-04-12
**Scope**: Stage 3 (2-year historical backfill) + Stage 4 (first real calibration run) — the final two stages of the scoring overhaul, delivered together
**Status**: Design locked via `/brainstorming`, ready for implementation
**Related**: [Stage 5c design](2026-04-11-stage5c-horizon-switch-design.md), [`tool/recalibrate.dart`](../../tool/recalibrate.dart), [`rule_accuracy_service.dart`](../../lib/domain/services/rule_accuracy_service.dart)

---

## 1. Context & Motivation

Stage 5b/5c shipped (commits through `0c98f47` on `origin/main`) and delivered end-to-end dual-horizon scoring infrastructure:

- `rule_engine.calculateScore` consults per-horizon calibrated scores via `CalibratedScoreContext`
- `daily_recommendation` writes both short + long Top 20 lists each update
- `today_screen` SegmentedButton lets users toggle between them
- `tool/recalibrate.dart` is a working CLI with the Calibrator class + `linear_map_v1` formula + cut thresholds + dry-run + horizon flag

**The gap**: `assets/rule_scores_calibrated_{short,long}.json` still have `rules: {}` — the placeholder from Stage 5a. With empty JSON, every `calibratedScores.lookup` returns null, every score falls back to hardcoded `reason.score`, and `scoreShort == scoreLong` for every stock. **Stage 5c's SegmentedButton is visually a no-op** until real calibration data ships.

**Stage 3 + Stage 4 deliver**: a one-time developer-machine run that (a) fetches 2 years of historical data from TWSE + FinMind into a dedicated calibration DB, (b) replays rule firings over that history to populate the `rule_accuracy` table, (c) runs the existing `tool/recalibrate.dart` to produce populated `rule_scores_calibrated_{short,long}.json`, and (d) commits those JSON files as assets so end-users ship with calibrated scores from day 1.

### Why Stage 3 + Stage 4 are delivered together

They're conceptually distinct (Stage 3 = data layer, Stage 4 = statistical layer) but operationally coupled: Stage 4 calibration is useless without Stage 3 data, and Stage 3 backfill has no purpose without Stage 4 consuming it. Splitting delivery across separate brainstorming rounds would duplicate planning. The 4-commit structure (§5) still preserves the stage boundary in git history.

### Explicitly out of scope

- **Persistent user-side historical data** — users get calibrated JSON but not 2 years of raw history in their local DB. If future features need long per-user history, that's a separate decision.
- **SQLite dump shipping** — rejected in brainstorming Q1 for bundle-size reasons.
- **On-device first-launch backfill** — rejected in brainstorming Q1 for UX/rate-limit reasons.
- **Automated monthly recalibration pipeline** — manual `tool/recalibrate.dart` run + human review remains the canonical workflow. Automation is Stage 5d+ if ever needed.
- **Calibration for 4 current-day-only data sources** — `day_trading`, `margin_trading`, `trading_warning`, `holding_distribution` rules cannot be backfilled (APIs only return today's data). They will naturally be cut by `sample_size < 30` in recalibrate and fall back to hardcoded baseline until post-launch natural accumulation.

---

## 2. Locked Decisions

Four questions were resolved during brainstorming (2026-04-12):

| # | Question | Decision | Rationale |
|---|---|---|---|
| Q1 | Execution venue + ship strategy | **P** — Pure CLI on developer machine, ship calibrated JSON only (not SQLite dump, not on-device backfill) | Calibration is centralized knowledge, not per-user state. `rule_scores_calibrated_*.json` as shipped asset is Stage 5a's original design. Human-in-loop monthly review gate is incompatible with on-device automation. SQLite dump bundle would be 50-200MB. |
| Q2 | Backfill data source scope | **B** — Full: `daily_price`, `daily_institutional`, `monthly_revenue`, `financial_data`, `stock_valuation`, `dividend_history` (6 sources) | Partial backfill (Minimal) produces mixed `cut_reason` signals in the output JSON, breaking human review. Script runs once overnight; 3h vs 9h is irrelevant in absolute terms. |
| Q3 | Calibration replay strategy | **Y** — New `tool/replay_calibrator.dart` that calls `rule_engine.evaluateStock` directly on every stock × every historical day, bypassing `scoring_service` + `daily_recommendation` | `rule_accuracy_service`'s production path only samples Top 20 recommendations → massive selection bias against negative-signal rules (they never reach Top 20 by definition). Direct iteration produces unbiased samples. Keeps production code paths untouched. |
| Q4 | Commit sequencing | **iii** — 4 commits: design doc → backfill CLI → replay calibrator CLI → shipped JSON | Backfill and replay are independently testable with disjoint mock fixtures. Operational bug fixes during runs converge on clear commits. Stage 3 vs Stage 4 distinction preserved in git history. Shipped JSON is a ceremonial milestone commit. |

---

## 3. Architecture

### 3.1 File layout & blast radius

```
tool/
├── backfill.dart                               [NEW] Stage 3 — fetches historical data from TWSE + FinMind
├── backfill/                                   [NEW] Stage 3 helpers (if main file grows)
│   ├── fetch_plan.dart                         resumable iteration state
│   └── progress_reporter.dart                  stdout UX
├── replay_calibrator.dart                      [NEW] Stage 4 — iterates rule firings, computes forward returns
├── replay_calibrator/                          [NEW] Stage 4 helpers
│   ├── firing_aggregator.dart                  in-memory rule firing map
│   └── forward_return_calc.dart                price[t+N] / price[t] - 1 with edge handling
└── recalibrate.dart                            (existing — consumes rule_accuracy table)

assets/
├── rule_scores_calibrated_short.json           (* populated by Stage 4 run)
└── rule_scores_calibrated_long.json            (* populated by Stage 4 run)

test/tool/
├── backfill_test.dart                          [NEW] mock TwseClient + FinMindClient
├── replay_calibrator_test.dart                 [NEW] synthetic in-memory DB fixture
└── recalibrate_test.dart                       (existing — unchanged)

docs/plans/
└── 2026-04-12-stage3-4-design.md               [NEW] this document

* = modified content (not code)
[NEW] = added
```

**Total estimate**: 2 new CLI scripts (~300-500 lines each with helpers), 2 new test files (~200 lines each), 2 populated JSON asset files (produced by running the CLIs, not hand-written), 1 design doc. **Zero production lib/ changes** — all new code lives in `tool/` and `test/tool/`, completely isolated from runtime code paths.

### 3.2 Data flow (Stage 3 + Stage 4 pipeline)

```
Developer machine (pre-launch, one-time)
  │
  ├─ [C0] Write + commit design doc
  │
  ├─ [C1] Write tool/backfill.dart + tests
  │
  ├─ (operational) Run backfill:
  │     export FINMIND_TOKEN=<token>
  │     dart run tool/backfill.dart --db tool/calibration.db --years 2
  │     ↓
  │     ┌─────────────────────────────────────────────────────┐
  │     │ tool/calibration.db (new Drift DB, isolated from    │
  │     │ app's dev DB, schema matches lib/data/database)     │
  │     │                                                     │
  │     │ daily_price            ~1300 symbols × 500 days     │
  │     │ daily_institutional    ~1300 symbols × 500 days     │
  │     │ monthly_revenue        ~1300 symbols × 24 months    │
  │     │ financial_data         ~1300 symbols × 8 quarters   │
  │     │ stock_valuation        ~1300 symbols × 500 days     │
  │     │ dividend_history       ~1300 symbols × 10 years     │
  │     │ stock_master           ~1300 rows                   │
  │     └─────────────────────────────────────────────────────┘
  │     Duration: ~9 hours overnight (FinMind 600/hr throttled)
  │
  ├─ [C2] Write tool/replay_calibrator.dart + tests
  │
  ├─ (operational) Run replay:
  │     dart run tool/replay_calibrator.dart --db tool/calibration.db
  │     ↓
  │     For each trading day D in backfill window:
  │       Load price lookback for all stocks up to D
  │       For each stock S with sufficient history:
  │         context = AnalysisService.buildContext(prices_up_to_D)
  │         reasons = RuleEngine().evaluateStock(context, stockData_for_D)
  │         For each reason R in reasons:
  │           firings[R.type.code].add((date: D, symbol: S))
  │     ↓
  │     For each rule_id in firings:
  │       For horizon in [short(5d), long(60d)]:
  │         samples = []
  │         For each (date, symbol) in firings[rule_id]:
  │           entry = price[date]
  │           exit  = price[date + horizon.tradingDays]
  │           if entry & exit both valid:
  │             samples.add(exit/entry - 1)
  │         write to rule_accuracy table:
  │           (rule_id, period=horizon, trigger_count, success_count,
  │            avg_return, success_threshold)
  │     Duration: ~30-60 minutes
  │
  ├─ (operational) Run existing recalibrate:
  │     dart run tool/recalibrate.dart --db tool/calibration.db
  │     ↓
  │     assets/rule_scores_calibrated_short_candidate.json  (produced)
  │     assets/rule_scores_calibrated_long_candidate.json   (produced)
  │
  ├─ (operational) Human review:
  │     Open candidate JSON files, sanity check:
  │       - Which rules are active vs cut?
  │       - Are scores roughly monotonic with hit_rate × avg_return?
  │       - Any surprising cuts? (e.g. a rule you expected to work got cut)
  │       - Any suspiciously high scores? (possible backfill data quality issue)
  │     Decision: approve, retune cut thresholds, or flag data quality issue
  │
  ├─ (operational) Rename candidate → production:
  │     mv assets/rule_scores_calibrated_short_candidate.json \
  │        assets/rule_scores_calibrated_short.json
  │     mv assets/rule_scores_calibrated_long_candidate.json \
  │        assets/rule_scores_calibrated_long.json
  │
  └─ [C3] Commit the populated JSON files + memory/plan updates
```

### 3.3 Invariants

- **Production `lib/` untouched** — Stage 3+4 is entirely tool/ + assets. Zero risk of regressing runtime behavior.
- **Calibration DB is disposable** — `tool/calibration.db` is .gitignored (not committed). If developer wants to re-run calibration, they re-run backfill. It's a cache, not an artifact.
- **`rule_accuracy_service` unchanged** — the production multi-period validation service continues to operate on Top 20 recommendations for runtime feedback (what it was designed for). Stage 4 does not touch it.
- **`tool/recalibrate.dart` unchanged** — the existing Calibrator + CLI is the final stage of the pipeline, consumed as-is.
- **The 4 current-day-only rules fall through to hardcoded baseline** — calibration output will mark them cut, runtime `calculateScore` sees `lookup() == null` and uses `reason.score`. No special handling needed.

---

## 4. Components

### 4.1 `tool/backfill.dart` — Stage 3 CLI

**CLI signature**:
```
dart run tool/backfill.dart \
  --db <path>                   # default: tool/calibration.db
  --years <N>                   # default: 2
  --finmind-token <token>       # or FINMIND_TOKEN env var
  --symbols <csv>               # optional whitelist; default: all TWSE + TPEx
  --skip-existing               # default: true — skip already-populated symbol/month
  --dry-run                     # print plan, don't fetch
```

**Execution phases**:

1. **Setup**: Open/create `calibration.db` via `AppDatabase.forCalibration(path)` (new factory to be added, mirrors `forTesting` but uses a file path). Schema is created via the standard Drift `createAll()` path.

2. **Stock master**: Call `StockListSyncer` (or equivalent) to populate `stock_master` with all TWSE + TPEx listed companies. This is a single API call to TWSE list endpoint.

3. **Per-source fetch loop**: For each of 6 data sources, iterate symbols × time windows:

   | Source | API | Cadence | Call count estimate |
   |---|---|---|---|
   | `daily_price` | TWSE + TPEx historical | month × symbol | ~1300 × 24 = 31200 |
   | `daily_institutional` | TWSE 3法人 historical | month × symbol | ~1300 × 24 = 31200 |
   | `monthly_revenue` | FinMind | per symbol full history | ~1300 |
   | `financial_data` | FinMind (EPS/ROE) | per symbol full history | ~1300 |
   | `stock_valuation` | FinMind (PER/PBR) | per symbol full history | ~1300 |
   | `dividend_history` | FinMind | per symbol full history | ~1300 |

4. **Rate limiting**: reuse existing `MarketClientMixin._delay()` (300ms between TWSE calls) + FinMind's 600/hr throttle (await `Duration(seconds: 6)` between FinMind calls to stay under 600/hr). Total: ~9 hours wall clock for full run.

5. **Resumability**: Before each fetch, query the DB `WHERE symbol=? AND date BETWEEN month_start AND month_end`. If row count matches expected (≥ 18 trading days for a month), skip. This lets the script be killed mid-run and resumed without redoing work.

6. **Progress reporting**: stdout every N symbols — `[12h30m remaining] Phase 3/6 (monthly_revenue): 423/1300 symbols (32%)`. Include a `SIGINT` handler that flushes current progress + commits pending writes before exiting.

7. **Error handling**:
   - Individual symbol failures: log + continue, record in `failed_symbols.txt` for post-run review
   - `RateLimitException`: abort immediately with clear error message about needing to wait / rotate token
   - `NetworkException`: retry with exponential backoff (reuse existing mixin logic)
   - `DatabaseException`: abort — indicates schema mismatch, needs manual intervention

**Dependencies**: reuses existing `TwseClient`, `TpexClient`, `FinMindClient` from `lib/data/remote/`. No modification to those clients — just constructs them with `token` param from env.

### 4.2 `tool/replay_calibrator.dart` — Stage 4 CLI

**CLI signature**:
```
dart run tool/replay_calibrator.dart \
  --db <path>                   # default: tool/calibration.db
  --start-date <YYYY-MM-DD>     # default: 2 years before --end-date
  --end-date <YYYY-MM-DD>       # default: today
  --horizons {short|long|both}  # default: both
  --dump-csv <path>             # optional: also write per-firing debug CSV
  --min-history-days <N>        # default: RuleParams.swingWindow
```

**Execution phases**:

1. **Load all data once**: Read entire `daily_price` + `daily_institutional` + `monthly_revenue` + `financial_data` + `stock_valuation` + `dividend_history` for all symbols in backfill window into memory Maps keyed by symbol. For 1300 symbols × 500 days × ~20 fields ≈ ~150MB in-memory footprint. Feasible.

2. **Iterate trading days**: For each trading day D in `[start_date, end_date]`:
   - Skip non-trading days (use `TaiwanCalendar.isTradingDay(D)`)
   - For each symbol S:
     - Reconstruct the analysis context for day D using the same pipeline as `_evaluateStocksIsolated` — `AnalysisService.analyzeStock(prices_up_to_D)`, `buildContext`, etc.
     - Build `StockData(symbol, prices_up_to_D, institutional_up_to_D, ...)`
     - Call `RuleEngine().evaluateStock(context, stockData)` — pure function, reusable
     - For each `TriggeredReason` in result:
       - Record `firings.putIfAbsent(reason.type.code, () => []).add((D, S))`

3. **Forward return computation**: After iteration complete:
   - For each `rule_id` → list of `(date, symbol)` firings:
     - For each `horizon` in `[short, long]`:
       - `samples = []`
       - For each `(date, symbol)` firing:
         - `entry = prices[symbol].firstWhere(p => p.date >= date).close`
         - `exit = prices[symbol].firstWhere(p => p.date >= date + horizon.tradingDays).close`
         - If both valid: `samples.add((exit / entry - 1) * 100)`  # percent
       - Aggregate:
         - `sample_size = samples.length`
         - `avg_return = samples.average`
         - `success_threshold = horizon == short ? 3.0 : 12.0` (matches `_thresholdShort` / `_thresholdLong` in recalibrate.dart:269-270)
         - `success_count = samples.where((r) => r >= success_threshold).length`
         - `hit_rate = success_count / sample_size`

4. **Write to `rule_accuracy` table**: For each `(rule_id, horizon)` aggregate, `INSERT OR REPLACE INTO rule_accuracy (rule_id, period, trigger_count, success_count, avg_return, ...)` with `period` set to `'5D'` or `'60D'` to match `_periodShort` / `_periodLong` constants that `tool/recalibrate.dart` reads from.

5. **Optional CSV dump**: If `--dump-csv` provided, write `firings.csv` with `date,symbol,rule_id,forward_return_5d,forward_return_60d` rows. This is the human-debuggable artifact for manual review of "did this rule fire at the times we expected".

**Memory management**: The in-memory firings Map can grow to ~1.25M entries. Each entry is `(String ruleId, List<(DateTime date, String symbol)>)`. Estimated ~60MB total. Dart VM handles this easily. If memory pressure becomes a concern (e.g. expanding to 5 years of history), switch to streaming — write firings to a temporary SQLite table as they're produced, then aggregate via SQL. For 2 years, in-memory is simpler.

### 4.3 `AppDatabase.forCalibration(String path)` factory

Small addition to `lib/data/database/app_database.dart`:

```dart
/// Calibration tool 用 — 開啟指定路徑的 SQLite 作為獨立的 calibration DB。
///
/// Stage 3+4 tool 專用。不用於 runtime app。
@visibleForTesting
AppDatabase.forCalibration(String path)
  : super(NativeDatabase(File(path)));
```

Technically this is a `lib/` change, but it's a 3-line constructor that only tool/ consumes. Could alternatively live in a new `lib/data/database/app_database_calibration.dart` extension file to avoid touching the main class — to be decided during C1. The `@visibleForTesting` annotation is mildly abused (it's not a test, it's a tool), but semantically it conveys "production runtime shouldn't call this".

### 4.4 What NOT to modify

- `lib/domain/services/scoring_service.dart` — untouched. Production scoring unchanged.
- `lib/domain/services/rule_accuracy_service.dart` — untouched. Runtime validation still operates on Top 20.
- `lib/data/repositories/analysis_repository.dart` — untouched.
- `lib/domain/services/update/historical_price_syncer.dart` — untouched. The existing syncer handles in-app daily update backfill; calibration backfill is a parallel path in tool/.

---

## 5. Implementation Sequence

### 5.1 Commit C0 — design doc

**Message**: `docs(plans): Stage 3+4 design — historical backfill + first real calibration`

**Changes**: this file, nothing else.

**Purpose**: lock decisions in writing before implementation, mirror Stage 5b/5c's doc-first pattern.

### 5.2 Commit C1 — `tool/backfill.dart` + tests

**Message**: `feat(tool): Stage 3 historical backfill CLI`

**Changes**:
- New `tool/backfill.dart` with full CLI + fetch loop + resumability
- Optional helper modules under `tool/backfill/`
- New `test/tool/backfill_test.dart` with mocked `TwseClient` / `FinMindClient` asserting:
  - CLI arg parsing happy + error paths
  - Resumability (skip-existing logic)
  - Rate limit exception handling (immediate abort)
  - Individual symbol failure isolation (continue loop)
  - Dry-run output formatting
- Possibly `AppDatabase.forCalibration(path)` factory (see §4.3)

**Untouched**: lib/ production code, existing tests, other tool/ scripts

**Expected test count delta**: 2370 → ~2380 (~10 new cases for the CLI + fetch loop logic)

### 5.3 Operational run 1 — backfill

**Not a commit**. Developer runs:

```bash
export FINMIND_TOKEN=<token>
dart run tool/backfill.dart --db tool/calibration.db --years 2 2>&1 | tee backfill.log
```

**Duration**: ~9 hours wall clock. Recommend running overnight.

**Expected outcome**: `tool/calibration.db` contains ~1300 symbols × 6 data sources × 2 years of data. `backfill.log` contains progress + any per-symbol failures.

**If bugs surface**: fix in follow-up commits to C1 before proceeding to C2. Iterate until backfill completes cleanly.

### 5.4 Commit C2 — `tool/replay_calibrator.dart` + tests

**Message**: `feat(tool): Stage 4 replay calibrator CLI`

**Changes**:
- New `tool/replay_calibrator.dart` with load → iterate → aggregate → write pipeline
- Optional helper modules under `tool/replay_calibrator/`
- New `test/tool/replay_calibrator_test.dart` with synthetic in-memory DB (~10 stocks × 100 days × known rule triggers) asserting:
  - Unbiased iteration (rules that fire on non-Top-20 stocks are still counted)
  - Forward return math correctness (hand-computed fixtures)
  - Horizon differentiation (short uses 5-day return, long uses 60-day return)
  - Missing-data edge cases (stock delisted mid-window, insufficient forward history at window end)
  - CSV dump format

**Untouched**: lib/ production code, `tool/backfill.dart`, existing recalibrate.dart

**Expected test count delta**: ~2380 → ~2395 (~15 new cases)

### 5.5 Operational run 2 — replay + recalibrate + review

**Not a commit**. Developer runs:

```bash
dart run tool/replay_calibrator.dart \
  --db tool/calibration.db \
  --dump-csv firings.csv 2>&1 | tee replay.log

dart run tool/recalibrate.dart --db tool/calibration.db
```

**Duration**: ~30-60 minutes for replay, seconds for recalibrate.

**Output**: `assets/rule_scores_calibrated_short_candidate.json` + `assets/rule_scores_calibrated_long_candidate.json`.

**Human review checklist** (in review session, not code):
- [ ] How many rules are `active` vs `cut` per horizon? (expected: ~30-50 active out of 62)
- [ ] Do the 4 current-day-only rules appear as cut with `no_data` or `insufficient_samples`? (expected yes)
- [ ] Are active rule scores roughly in [10, 35]? (matches `linear_map_v1` output range)
- [ ] Any score > 30 that surprises you? (possible data quality issue — check `firings.csv` for that rule)
- [ ] Any score < 12 that should be higher? (possible conservative cut threshold — consider rerun with relaxed threshold)
- [ ] Short vs long: do the rankings differ meaningfully? (if they're identical, something's wrong — the whole point of dual horizon is divergence)
- [ ] `backtest.samples_total` field — is it ≥ 30 × active_rule_count? (≤ means some rules are borderline)

**If review rejects**: adjust cut thresholds in `tool/recalibrate.dart`, re-run recalibrate (fast, no need to redo replay), re-review. Backfill + replay are stable at this point.

**When review passes**:

```bash
mv assets/rule_scores_calibrated_short_candidate.json \
   assets/rule_scores_calibrated_short.json
mv assets/rule_scores_calibrated_long_candidate.json \
   assets/rule_scores_calibrated_long.json
```

### 5.6 Commit C3 — shipped calibrated JSON + plan updates

**Message**: `feat(scoring): Stage 4 — first real calibration shipped`

**Changes**:
- `assets/rule_scores_calibrated_short.json` (content change, from `rules: {}` to populated)
- `assets/rule_scores_calibrated_long.json` (content change, from `rules: {}` to populated)
- `docs/plans/2026-04-12-stage3-4-design.md` — append post-run notes section with actual numbers (active/cut counts, sample sizes, observations)
- `CHANGELOG.md` — note Stage 3+4 completion
- Memory update: `~/.claude/projects/.../memory/afterclose_scoring_overhaul_plan.md` marking full overhaul complete

**Result**: First `flutter run` after this commit shows Stage 5c's SegmentedButton producing visibly different short vs long Top 20 lists. Stage 5c becomes a live feature instead of placeholder infrastructure.

**Expected test count delta**: ~2395 → ~2395 (no code changes, existing tests validate JSON parses). Running `flutter test test/core/constants/calibrated_scores/` after this commit should still pass — the parser tested with synthetic populated rules in Stage 5a/5b is now exercised against real data, and failure here would indicate a JSON format regression.

---

## 6. Test Strategy

### 6.1 Stage 3 CLI tests (`backfill_test.dart`)

Mock the 3 remote clients; assert fetch loop behavior without hitting real APIs:

| Case | Mock Setup | Assertion |
|---|---|---|
| Happy path — 2 symbols × 2 months | TwseClient returns 2 months of OHLCV for both | DB has 40 `daily_price` rows |
| Skip existing | Seed DB with month-1 data; run fetch | Month-1 not re-fetched; month-2 fetched |
| Rate limit abort | TwseClient throws `RateLimitException` on call 3 | Script exits with code 2 + clear stderr msg |
| Individual symbol failure | TwseClient throws `NetworkException` for symbol B only | Symbol A complete; symbol B logged to failed_symbols; script exits 0 |
| Dry run | All mocks return data | No DB writes; stdout contains fetch plan |
| Finmind token missing | no env var, no flag | Abort with clear error about token requirement |
| Resumability after SIGINT | Start fetch, simulate interrupt, restart | Completed portion not re-fetched |

### 6.2 Stage 4 CLI tests (`replay_calibrator_test.dart`)

Use synthetic in-memory DB with hand-crafted fixtures:

| Case | Fixture | Assertion |
|---|---|---|
| Unbiased sampling | 10 stocks, only 1 makes Top 20, all 10 trigger TECH_BREAKOUT | `rule_accuracy.TECH_BREAKOUT.trigger_count == 10` (not 1) |
| Forward return math — short | Stock S triggers rule on day D, price[D]=100, price[D+5]=105 | `avg_return` contribution is `5.0` |
| Forward return math — long | price[D]=100, price[D+60]=118 | `avg_return` contribution is `18.0` |
| Hit rate short | 10 firings, 4 return ≥ 3% | `hit_rate == 0.4` |
| Missing forward data | Firing on day D, backfill ends on D+3 (short needs D+5) | Sample skipped, not counted as failure |
| Horizon isolation | Same firings for short + long | `rule_accuracy` has 2 rows per rule (period='5D' + period='60D') |
| Stock delisted mid-window | Prices exist for D to D+30, none after | Short samples count firings on D to D+25 (enough forward history); long samples count none |
| CSV dump | `--dump-csv out.csv` | File exists with expected header + rows |
| Min history filter | Stock with only 10 days history | No firings recorded (below `min-history-days` threshold) |

### 6.3 Integration test — full pipeline end-to-end

A single new test (`test/tool/stage34_integration_test.dart`, ~1 case) that:

1. Creates tiny synthetic `calibration.db` with 3 stocks × 100 days × known prices
2. Runs the replay_calibrator main function directly (not via subprocess)
3. Runs the recalibrate main function
4. Asserts output JSON has expected schema + at least 1 active rule

This is the smoke test for "the whole pipeline doesn't crash". Not meant to validate statistical correctness (unit tests cover that).

### 6.4 Zero test for Stage 3 live execution

We intentionally do **not** write a test that runs backfill against real TWSE/FinMind APIs — those tests would be slow, flaky (network + rate limit), and would burn the API quota we need for the actual production run. The mocked CLI tests + operational run logs are the QA path.

---

## 7. Operational Runbook

### 7.1 Prerequisites

- Developer machine with Dart 3.x + Flutter installed
- FinMind API token (register free at https://finmindtrade.com)
- ~10 hours wall clock for full backfill (overnight)
- ~500MB free disk for `tool/calibration.db`
- Stable internet connection

### 7.2 Step-by-step

```bash
# 1. Environment setup
export FINMIND_TOKEN=<your token>
cd /Users/nealchen/IdeaProjects/afterclose

# 2. Verify tooling
dart run tool/backfill.dart --help
dart run tool/replay_calibrator.dart --help

# 3. Dry run to see the plan
dart run tool/backfill.dart --db tool/calibration.db --years 2 --dry-run

# 4. Real backfill (overnight)
nohup dart run tool/backfill.dart --db tool/calibration.db --years 2 \
  > backfill.log 2>&1 &
echo $! > backfill.pid  # save PID for monitoring

# 5. Monitor progress
tail -f backfill.log
# Expected: ~9 hours to completion

# 6. Verify backfill
sqlite3 tool/calibration.db "SELECT COUNT(*) FROM daily_price;"
# Expected: ~1300 * 500 = ~650k rows

# 7. Replay calibrator
dart run tool/replay_calibrator.dart \
  --db tool/calibration.db \
  --dump-csv firings.csv \
  > replay.log 2>&1
# Duration: 30-60 minutes

# 8. Run recalibrate
dart run tool/recalibrate.dart --db tool/calibration.db
# Outputs: assets/rule_scores_calibrated_{short,long}_candidate.json

# 9. Human review
open assets/rule_scores_calibrated_short_candidate.json
open assets/rule_scores_calibrated_long_candidate.json
# Use §5.5 checklist

# 10. Approve and rename
mv assets/rule_scores_calibrated_short_candidate.json \
   assets/rule_scores_calibrated_short.json
mv assets/rule_scores_calibrated_long_candidate.json \
   assets/rule_scores_calibrated_long.json

# 11. Verify in running app
flutter run
# Open Today screen, toggle short/long — should see different Top 20s now

# 12. Commit
git add assets/rule_scores_calibrated_short.json \
       assets/rule_scores_calibrated_long.json \
       docs/plans/2026-04-12-stage3-4-design.md \
       CHANGELOG.md
git commit -m "feat(scoring): Stage 4 — first real calibration shipped"
git push origin main
```

### 7.3 Rollback

If the calibrated JSON turns out to be wrong in production, two options:

1. **Fast rollback**: `git revert <C3 hash>` — restores `rules: {}` placeholder, Stage 5c switch returns to zero-effect state. App continues working via hardcoded fallback.
2. **Fix + re-ship**: adjust cut thresholds in recalibrate, re-run from step 7 (replay + recalibrate + review), commit new JSON.

The calibration.db artifact stays on developer machine and can be re-used for quick re-calibration without re-running the 9-hour backfill.

### 7.4 Future recalibration cadence

Post-launch, Stage 4 calibration should be re-run approximately monthly as new production data accumulates. Workflow:

1. Export production DB snapshot from TestFlight / App Store installations (via dev device, manual)
2. Run replay_calibrator + recalibrate against the fresh snapshot
3. Review diff vs shipped JSON — are any rules showing material drift?
4. If yes: ship new calibrated JSON as an app update
5. If no: skip the update

This is manual by design — Stage 4's "monthly human review gate" decision was locked in Stage 2 brainstorming for good reason (statistical judgments are not automatable without risk).

---

## 8. Known Limitations & Non-Goals

- **4 current-day-only rules uncalibrated** — `day_trading`, `margin_trading`, `trading_warning`, `holding_distribution`. They remain on hardcoded baseline until 2+ months of post-launch data accumulates naturally. Documented as expected behavior, not a bug.
- **Calibration snapshot is ~2 years old at ship time** — by the time the app is on the store, the "most recent" training data is already 1-3 months stale. This is acceptable because rule statistics change slowly (rules are structural, not timing-sensitive). Post-launch monthly recalibration addresses drift.
- **Selection bias on `dividend_history`** — only companies that have paid dividends have rows in this table. Rules that check dividend history (e.g. `highDividendYield`) are only calibrated for historically-dividend-paying stocks. Post-launch data will naturally expand this.
- **No cross-validation** — `tool/recalibrate.dart` uses 70/30 train/test split but only runs one split. Full k-fold CV is Stage 5d+ concern if rule scores show instability.
- **No stock-level survivor bias correction** — delisted stocks are not in the current `stock_master` table, so they're excluded from backfill. This underestimates risk-rules' hit rates (they never see the "this stock went to zero" examples). Acceptable for v1.
- **News rules uncalibrated** — news data is ephemeral (RSS feeds expire). Can't backfill historical news. News-based rules fall through to hardcoded baseline.

---

## 9. Stage Transitions

| Stage | Requires | Delivers | Status |
|---|---|---|---|
| **5b** | — | Dual-horizon scoring pipeline + schema | shipped ✅ |
| **5c** | 5b | Global horizon toggle + UI switch | shipped ✅ |
| **3** (this doc) | 5c + FinMind token | 2 years historical data on dev machine | pending |
| **4** (this doc) | 3 + pre-launch review | First populated `rule_scores_calibrated_*.json` shipped as assets | pending |
| **5d** (future, optional) | 4 + 2-3 months production data | Automated monthly recalibration + OTA JSON updates | blocked on post-launch |

After Stage 3+4 ships:
- Stage 5c's SegmentedButton becomes a live feature (no longer placeholder)
- Short vs long Top 20 visibly diverge based on real statistics
- The scoring overhaul project is **complete** as originally scoped
- `tool/backfill.dart` + `tool/replay_calibrator.dart` + `tool/recalibrate.dart` form a stable pipeline reusable for Stage 5d (if/when we want OTA calibration updates)

---

## 10. Operational Prerequisites (not in any commit)

**FinMind API token**: developer must register at https://finmindtrade.com and set `FINMIND_TOKEN` environment variable. **Note**: there is a pre-existing bug where the app's in-UI FinMind token setting does not persist across restarts. This bug is tracked separately and does not affect Stage 3+4 operational path because `tool/backfill.dart` reads the token from env var / CLI flag, not from `AppSettings`.

**`tool/calibration.db` path**: gitignored, disposable. Regenerate by re-running backfill. Separate from developer's app-dev SQLite to avoid cross-contamination with in-progress feature work.

**Disk space**: ~500MB for calibration.db at peak (before VACUUM). Post-replay, `rule_accuracy` table adds ~500KB. Total footprint negligible.

**Time budget**: 9h backfill + 1h replay/recalibrate/review + 30min commit/push + 30min smoke test = **~11 hours wall clock, ~2 hours active developer time**. Most of the wall clock is unattended overnight.
