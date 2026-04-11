# Scoring Overhaul Stage 5c — Dual-Horizon UI Switch

**Date**: 2026-04-11
**Scope**: Stage 5c of the scoring overhaul — expose the dual-horizon scoring pipeline to users via a UI switch
**Status**: Design locked via `/brainstorming`, ready for implementation
**Related**: [Stage 5b design](2026-04-11-stage5b-dual-horizon-design.md), [`selected_horizon_provider.dart`](../../lib/presentation/providers/selected_horizon_provider.dart) (to be created)

---

## 1. Context & Motivation

Stage 5b shipped (commits `7a7345a`, `08ada96`, `ea8811d`, `7a87672` on `origin/main`) and delivered the end-to-end dual-horizon scoring pipeline:

- `rule_engine.calculateScore(..., {required Horizon horizon, ...})` computes per-horizon scores
- Scoring isolate writes both `scoreShort` + `scoreLong` into `daily_analysis` / `daily_reason`
- `daily_recommendation` has a horizon pivot; up to `2 * dailyTopN` rows/day (20 short + 20 long)
- Every UI read path hardcodes `Horizon.short` as a placeholder, making Stage 5b a zero-user-visible rollout

**The gap**: users cannot see the long-horizon recommendations or summaries. Every surface still shows short-horizon data by virtue of the hardcoded placeholder.

**Stage 5c delivers**: a single global horizon toggle that flips every affected screen — Today Top 20, stock detail summary, and comparison summary — between short and long views. Short remains the default. The switch does not persist across app launches (Stage 5d+ concern).

### Explicitly out of scope (pushed to later)

- **Persistence** of selected horizon across app launches (would need `AppSettings` schema + async init)
- **Per-horizon cooldown tracking** (still uses global cooldown as in Stage 5b)
- **`dailyTopN` / `minScoreThreshold` per horizon** (still shared)
- **`recommendation_performance_screen.dart` horizon-awareness** (separate backtest data path, unaffected by selected horizon)
- **Tab-style UI with swipe gestures** (Stage 5c uses `SegmentedButton`; see §2 Q1 rationale)

---

## 2. Locked Decisions

Five questions were resolved during brainstorming (2026-04-11):

| # | Question | Decision | Rationale |
|---|---|---|---|
| Q1 | UI switcher shape | **B** — `SegmentedButton<Horizon>` above the Top 20 list | Short/long lists have identical visual structure; `TabBarView` would duplicate Sliver layout unnecessarily. AfterClose already uses `SegmentedButton` in `recommendation_performance_screen.dart`, so this matches convention. |
| Q2 | Horizon state scope | **X** — global `StateProvider<Horizon>`, non-persistent, defaults to `Horizon.short` | One source of truth for "what horizon am I viewing" across screens. Stock detail summary and Today list must agree. Persistence deferred — pre-launch usage patterns not yet known. |
| Q3 | `TodayNotifier` reactivity | **P** — `ref.listen(selectedHorizonProvider)` + new `_reloadForHorizon` command method | TodayNotifier holds priceChange cache + updateRun subscription + progress state; `ref.watch` would rebuild the entire notifier on horizon switch, wasting non-horizon-related work. `ref.listen` only swaps `state.recommendations`. |
| Q4 | `analysis_summary_service` horizon input | **α** — `generate()` gains `required Horizon horizon` parameter; service branches internally on 4 hardcode points | Mirrors Stage 5b `calculateScore` signature convention. Minimal blast radius (4 body edits + 2 caller updates). Horizon is a domain concept, not an implementation detail — the service legitimately owns it. |
| Q4b | Stock detail / comparison reactivity | **Asymmetric** — those providers use `ref.watch(selectedHorizonProvider)` (full rebuild), while `TodayNotifier` uses `ref.listen` (command reload) | Reflects real state-complexity difference. Stock detail is short-lived (open → load → close); rebuild cost is zero. Today is long-lived with multiple non-horizon caches. Both patterns are Riverpod-official; AfterClose already mixes them. |
| Q5 | Commit sequencing | **ii** — two atomic commits: "reactivity wave" then "today UI" | C1 = backend reactivity (zero user-visible change). C2 = UI switch + Today reload. Matches Stage 5b's infra-first pattern. Revert safety: C2 failure does not touch C1's service refactor. |

---

## 3. Architecture

### 3.1 File layout & blast radius

```
lib/presentation/providers/
├── selected_horizon_provider.dart             [NEW] global StateProvider<Horizon>
├── stock_detail_provider.dart                 (* ref.watch + pass horizon)
├── comparison_provider.dart                   (* ref.watch + pass horizon)
└── today_provider.dart                        (* ref.listen + _reloadForHorizon)

lib/domain/services/
└── analysis_summary_service.dart              (* signature + 4 hardcode points)

lib/domain/repositories/
└── analysis_repository.dart                   (* getRecommendations signature: add required Horizon)

lib/data/repositories/
└── analysis_repository.dart                   (* drop Stage 5b Horizon.short placeholder)

lib/presentation/screens/today/
└── today_screen.dart                          (* SegmentedButton widget above list)

test/
├── presentation/providers/selected_horizon_provider_test.dart  [NEW] ~3 cases
├── domain/services/analysis_summary_service_test.dart          (* horizon param fallthrough tests)
├── presentation/providers/stock_detail_provider_test.dart      (* horizon watch rebuild test)
├── presentation/providers/comparison_provider_test.dart        (* horizon watch rebuild test)
├── presentation/providers/today_provider_test.dart             (* _reloadForHorizon command test)
├── data/repositories/analysis_repository_test.dart             (* getRecommendations new signature)
└── presentation/screens/today/today_screen_test.dart           (* SegmentedButton widget test)

* = modified
[NEW] = added
```

**Total estimate**: ~7 lib/ files modified, 1 new lib/ file, ~6 test files modified, 1 new test file, ~10 new test cases.

### 3.2 Data flow (post-Stage-5c)

```
user taps SegmentedButton(long) in today_screen
  └─ ref.read(selectedHorizonProvider.notifier).state = Horizon.long
         ↓
  ┌──────────────────────────────────────┐
  │ selectedHorizonProvider = Horizon.long │
  └──────────────────────────────────────┘
         ↓
  ├── TodayNotifier (ref.listen callback fires)
  │     └─ _reloadForHorizon(Horizon.long)
  │          └─ _analysisRepo.getRecommendationsWithDetails(date, horizon: long)
  │               └─ state = state.copyWith(recommendations: [...long Top 20...])
  │
  ├── stockDetailProvider (ref.watch triggers rebuild)
  │     └─ build() re-runs with new horizon
  │          └─ analysis_summary_service.generate(..., horizon: long)
  │               └─ reads analysis.scoreLong + r.ruleScoreLong
  │
  └── comparisonProvider (ref.watch triggers rebuild)
        └─ build() re-runs with new horizon
             └─ analysis_summary_service.generate(..., horizon: long)
```

### 3.3 Invariants

- **Default remains `Horizon.short`** — app launches showing the same list as Stage 5b
- **Placeholder JSON still empty** — every `calibratedScores.lookup` returns null → `scoreShort == scoreLong` for every stock → switching horizons is a **visually-no-op** until real calibration data exists
- **`AnalysisRepository.getRecommendations` loses its default argument** — callers must pass horizon explicitly. This intentionally removes the Stage 5b placeholder that was flagged as "Stage 5c 會改為 `ref.watch(selectedHorizonProvider)`"
- **`analysis_summary_service` has no Riverpod dependency** — it stays in `domain/services/`, takes horizon as a pure parameter, zero import from `package:flutter_riverpod`

---

## 4. Components

### 4.1 `selectedHorizonProvider` (new)

```dart
// lib/presentation/providers/selected_horizon_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afterclose/core/constants/calibrated_scores/horizon.dart';

/// 當前使用者選擇的 horizon（全域單一來源）
///
/// Stage 5c：由 `today_screen` 的 `SegmentedButton` 寫入，
/// 由 `TodayNotifier` / `stockDetailProvider` / `comparisonProvider` 讀取。
///
/// 預設為 `Horizon.short`（盤後看短線），無持久化 — 重開 app 回到預設。
/// Stage 5d+ 若要跨 session 記住，改為 `AsyncNotifier` 讀 `AppSettings`。
final selectedHorizonProvider = StateProvider<Horizon>((ref) => Horizon.short);
```

### 4.2 `analysis_summary_service.generate()` — horizon-aware signature

```dart
// lib/domain/services/analysis_summary_service.dart
SummaryData generate({
  required DailyAnalysisEntry? analysis,
  required List<DailyReasonEntry> reasons,
  required DailyPriceEntry? latestPrice,
  required double? priceChange,
  required List<DailyInstitutionalEntry> institutionalHistory,
  required List<FinMindRevenue> revenueHistory,
  required FinMindPER? latestPER,
  required Horizon horizon,
}) {
  // Internal: 4 hardcode points become horizon-aware
  //
  // Line 217, 408: score read
  //   analysis?.scoreShort.toInt()  →  switch (horizon) { short => scoreShort, long => scoreLong }.toInt()
  //
  // Line 246, 284: reason filter + sort
  //   r.ruleScoreShort > 0          →  _ruleScoreFor(r, horizon) > 0
  //   .ruleScoreShort (sort key)    →  _ruleScoreFor(r, horizon)
  //
  // Private helper to avoid 4 copy-pastes:
  double _scoreFor(DailyAnalysisEntry a) =>
      horizon == Horizon.short ? a.scoreShort : a.scoreLong;
  double _ruleScoreFor(DailyReasonEntry r) =>
      horizon == Horizon.short ? r.ruleScoreShort : r.ruleScoreLong;

  // ... rest of method unchanged
}
```

### 4.3 `stockDetailProvider` / `comparisonProvider` — reactive rebuild

```dart
// stock_detail_provider.dart (pattern; comparison_provider is identical)
Future<StockDetailState> build(String symbol) async {
  final horizon = ref.watch(selectedHorizonProvider);  // NEW
  // ... existing data loads ...
  final summary = _summaryService.generate(
    analysis: analysis,
    reasons: reasons,
    // ... existing args ...
    horizon: horizon,  // NEW
  );
  return StockDetailState(/* ... */, summary: summary);
}
```

When `selectedHorizonProvider` changes, Riverpod invalidates `stockDetailProvider`'s cache → `build()` re-runs with the new horizon → UI shows the new summary. The rebuild is cheap because stock detail is a short-lived screen and reloading its data sources is the normal code path when a user opens it.

### 4.4 `TodayNotifier` — command-based reload

```dart
// today_provider.dart
class TodayNotifier extends Notifier<TodayState> {
  @override
  TodayState build() {
    // NEW: listen to horizon changes, trigger reload
    ref.listen<Horizon>(
      selectedHorizonProvider,
      (prev, next) {
        if (prev != next) {
          _reloadForHorizon(next);
        }
      },
    );
    // ... existing init ...
  }

  /// Reload only the recommendations slice for a new horizon.
  ///
  /// Preserves priceChange cache, updateRun state, and progress indicators —
  /// only `state.recommendations` is swapped.
  Future<void> _reloadForHorizon(Horizon horizon) async {
    final date = state.currentDate;
    final recs = await _analysisRepo.getRecommendationsWithDetails(
      date,
      horizon: horizon,
    );
    state = state.copyWith(recommendations: recs);
  }

  // Existing loadData() also needs to pass ref.read(selectedHorizonProvider)
  // at initial load so the first render honors the current horizon.
}
```

### 4.5 `analysis_repository.getRecommendations` — signature change

```dart
// lib/domain/repositories/analysis_repository.dart
/// Stage 5c: required horizon (no default) — removes the Stage 5b placeholder.
Future<List<DailyRecommendationEntry>> getRecommendations(
  DateTime date, {
  required Horizon horizon,
});

Future<List<RecommendationWithStock>> getRecommendationsWithDetails(
  DateTime date, {
  required Horizon horizon,
});
```

```dart
// lib/data/repositories/analysis_repository.dart — impl
@override
Future<List<DailyRecommendationEntry>> getRecommendations(
  DateTime date, {
  required Horizon horizon,
}) {
  return _db.getRecommendations(DateContext.normalize(date), horizon: horizon);
}

@override
Future<List<RecommendationWithStock>> getRecommendationsWithDetails(
  DateTime date, {
  required Horizon horizon,
}) async {
  final recs = await getRecommendations(date, horizon: horizon);
  // ... rest unchanged ...
}
```

Every caller of these two methods must be updated. Known callers:
- `TodayNotifier.loadData()` + `_reloadForHorizon()`
- `TodayNotifier.getTodayRecommendations()` path (if it exists)

### 4.6 `today_screen.dart` — SegmentedButton widget

```dart
// lib/presentation/screens/today/today_screen.dart (pseudocode)
SliverToBoxAdapter(
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Consumer(
      builder: (context, ref, _) {
        final horizon = ref.watch(selectedHorizonProvider);
        return SegmentedButton<Horizon>(
          segments: [
            ButtonSegment(
              value: Horizon.short,
              label: Text('today.horizon.short'.tr()),  // 「短線 5D」
            ),
            ButtonSegment(
              value: Horizon.long,
              label: Text('today.horizon.long'.tr()),   // 「長線 60D」
            ),
          ],
          selected: {horizon},
          onSelectionChanged: (set) {
            ref.read(selectedHorizonProvider.notifier).state = set.first;
          },
        );
      },
    ),
  ),
),
```

Placement: immediately above the "Top 10" section header (line ~463 in current `today_screen.dart`). The SegmentedButton lives in its own `SliverToBoxAdapter` so it does not interfere with the existing Sliver list layout.

**i18n keys needed**: `today.horizon.short` → "短線", `today.horizon.long` → "長線". Add to the relevant `assets/translations/*.json` files.

---

## 5. Implementation Sequence

### 5.1 Commit 1 — Reactivity wave (no user-visible change)

**Message**: `feat(ui): add selectedHorizonProvider and make summary service horizon-aware`

**Changes**:
- New file `lib/presentation/providers/selected_horizon_provider.dart`
- `analysis_summary_service.generate()` gains `required Horizon horizon` param; 4 hardcode points → horizon-aware via private `_scoreFor` / `_ruleScoreFor` helpers
- `stock_detail_provider.dart`: `ref.watch(selectedHorizonProvider)` + pass to `generate()`
- `comparison_provider.dart`: same
- New test: `selected_horizon_provider_test.dart` (~3 cases: default value, write/read, provider-scoped override)
- Existing tests: `analysis_summary_service_test.dart` adds horizon param (default to `Horizon.short` where relevant; add ~2-3 cases verifying long-horizon reads `scoreLong` / `ruleScoreLong`); `stock_detail_provider_test.dart` + `comparison_provider_test.dart` add horizon rebuild test (~1 each)

**Untouched in C1**: `today_provider.dart`, `today_screen.dart`, `analysis_repository.dart` interface

**User-visible change**: **none**. `selectedHorizonProvider` exists and defaults to `Horizon.short`; no UI writes to it; all reads produce the same result as Stage 5b.

**Expected test count**: 2360 → ~2365 (+5)

### 5.2 Commit 2 — Today UI switch + reload

**Message**: `feat(ui): today screen horizon segmented button + TodayNotifier reload`

**Changes**:
- `analysis_repository.dart` interface: `getRecommendations` + `getRecommendationsWithDetails` gain `required Horizon horizon`, drop Stage 5b `Horizon.short` placeholder
- `analysis_repository.dart` impl: match new signature
- `today_provider.dart`: `ref.listen(selectedHorizonProvider)` in `build()`, new `_reloadForHorizon` method, `loadData()` reads current horizon via `ref.read(selectedHorizonProvider)` at initial load
- `today_screen.dart`: SegmentedButton widget above Top 10 section
- i18n keys: `today.horizon.short` / `today.horizon.long` in `assets/translations/*.json`
- Existing tests: `today_provider_test.dart` adds `_reloadForHorizon` command test; `analysis_repository_test.dart` updates `getRecommendations` call sites
- New widget test: `today_screen_test.dart` verifies SegmentedButton renders, selection updates provider, list rebuilds on switch

**Expected test count**: ~2365 → ~2372 (+7)

### 5.3 Commit 3 — Code-reviewer findings (if any)

Run `pr-review-toolkit:code-reviewer` on the full Stage 5c diff after Commit 2. Expected: 0-2 real findings. Followup commit addresses must-fix items.

**Message**: `fix(ui): address Stage 5c code-reviewer findings`

---

## 6. Test Strategy

### 6.1 Layer-by-layer coverage

| Layer | Test file | New cases | Focus |
|---|---|---|---|
| Provider | `selected_horizon_provider_test.dart` (new) | ~3 | Default value, mutation, scope |
| Service | `analysis_summary_service_test.dart` (existing) | ~3 | `horizon: long` reads `scoreLong` + filters by `ruleScoreLong`; short unchanged |
| Provider reactivity | `stock_detail_provider_test.dart` (existing) | ~1 | Horizon flip triggers rebuild with new summary |
| Provider reactivity | `comparison_provider_test.dart` (existing) | ~1 | Same |
| Notifier command | `today_provider_test.dart` (existing) | ~2 | `_reloadForHorizon` swaps recommendations only; `priceChange` cache preserved |
| Repo | `analysis_repository_test.dart` (existing) | ~2 | `getRecommendations` requires horizon; both horizons routable |
| Widget | `today_screen_test.dart` (existing) | ~2 | SegmentedButton renders; tap updates provider; list re-renders |

**Total estimated new cases**: ~14
**Total estimated test count after Stage 5c**: ~2374

### 6.2 Critical regression test

**"Switching horizon with empty calibration produces identical list"**:
```dart
test('short and long Top 20 are visually identical when placeholder JSON is empty', () async {
  // Given: scoring pipeline has run with empty CalibratedScoreContext
  // When: user flips selectedHorizonProvider from short to long
  // Then: today list contents are identical (same symbols, same scores, same order)
  //       because scoreShort == scoreLong for every row
});
```

This anchors the Stage 5b → 5c invariant: zero calibration data means zero visual change on switch. Once real calibration lands post-launch, this test will naturally break on the "same scores" assertion and must be rewritten to verify the switch produces the *expected* divergence.

### 6.3 Code-reviewer gate focus

Run after Commit 2, before push:
1. `ref.listen` vs `ref.watch` consistency — did I apply the asymmetric pattern correctly?
2. `analysis_repository.getRecommendations` — no forgotten callers still using the default
3. `TodayNotifier._reloadForHorizon` — does it guard against stale date state (user switches while `loadData` is in-flight)?
4. SegmentedButton accessibility labels + i18n keys present
5. `_scoreFor` / `_ruleScoreFor` helpers in service — are they `static` or instance? (instance is fine since they close over `horizon`)

---

## 7. Known Limitations & Non-Goals

- **No persistence**: horizon resets to `short` on app restart. Stage 5d+ concern if usage data suggests users want this.
- **No per-screen horizon**: all screens share one global horizon. If usage shows users want "compare in long mode while Today stays short", revisit in Stage 5d.
- **Placeholder-era invisibility**: until real calibration JSON ships, switching horizons does nothing user-visible because `scoreShort == scoreLong`. This is expected and documented in the regression test.
- **`recommendation_performance_screen` unchanged**: that screen operates on historical backtest data from `rule_accuracy_service`, which is horizon-agnostic in Stage 5c. Post-Stage-4 it will need its own horizon-aware refactor.
- **No swipe gestures**: `SegmentedButton` does not support swipe-to-switch. If user research shows strong demand, upgrade to `TabBar`/`TabBarView` in a future stage.
- **`today_screen.dart` widget tests may already widen viewport** — check `widenViewport` helper per CLAUDE.md convention before adding SegmentedButton tests.

---

## 8. Stage Transitions

| Stage | Requires | Delivers |
|---|---|---|
| **5b** (shipped) | — | Dual-horizon scoring pipeline + schema pivot + hardcoded UI placeholder |
| **5c** (this doc) | 5b | Global horizon toggle, Today / stock detail / comparison reactive to switch, service horizon-aware |
| **5d** (future) | 5c + usage data | Horizon persistence, per-screen horizon if justified, possibly tab-style UI |
| **3** (optional) | — | Historical backfill via TWSE/FinMind |
| **4** (post-launch) | launch + 2-3mo data | First real calibration via `tool/recalibrate.dart`; `recommendation_performance_screen` horizon-aware |

Stage 5c is a **frontend-focused delivery** that finally exposes Stage 5b's backend work to users. After 5c merges, the entire dual-horizon system is end-to-end visible; the only missing piece is real calibration data (Stage 4, post-launch blocked).
