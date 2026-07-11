# 出場條件 Replay Gate（Phase 1）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建 `tool/exit_validate.dart`——用歷史資料驗證三個出場條件（hardStop / trendBreak / timeStop）「觸發出場 vs 持有滿 60 交易日」是否有 edge，產出按 mode × 年切分的 gate 報告供 Neal 決定哪些條件上線。

**Architecture:** 復用 `ReplayCalibrator` 的 `scoreSink` hook 蒐集「mode 訊號日」樣本（需在 `ScoreSample` 加 `symbol` 欄位），再對樣本做純函數出場模擬（T+1 收盤進場、逐日檢查條件、首觸發日出場後 0 報酬），與 hold-60 對照。條件可個別開關 → 報告 4 個變體（三條全開 / 各單條）。

**Tech Stack:** Dart CLI tool（比照 `tool/` 既有模式）、flutter test wrapper 執行（drift→dart:ui 限制）、`AppDatabase.forToolFile`。

**Spec:** `docs/plans/2026-07-11-exit-thesis-invalidation-design.md`（§2 條件與邊界、§3 gate 設計為本計畫的 source of truth）

## Global Constraints

- 進場模擬 = 訊號日**次一交易日收盤**（T+1）；觸發判斷基準 = 訊號日收盤（T0 referencePrice）——兩者不可互換（spec §2）
- 同日 tie-break：HARD_STOP > TREND_BREAK > TIME_STOP（spec §2）
- MA60 資料不足（評估日前 < 60 根）→ trendBreak 不判定（spec §2）
- timeStop = 滿 40 交易日（價格列數計）且從未收高於 referencePrice（spec §2）
- (mode × 年) cell 樣本 < 30 → 標灰不計入結論（spec §3）
- Survivorship：無完整 60 日窗的樣本計數印報告、不靜默跳過（spec §3）
- 常數一律入 `ExitParams`，禁魔術數字（CLAUDE.md）
- TDD：每步先紅後綠；Conventional Commits 中文

---

### Task 1: ExitParams 常數

**Files:**
- Create: `lib/core/constants/exit_params.dart`
- Test: `test/core/constants/exit_params_test.dart`

**Interfaces:**
- Produces: `ExitParams.hardStopPct = 0.08`, `timeStopTradingDays = 40`, `ma60Window = 60`, `holdHorizonTradingDays = 60`, `minCellSample = 30`, `modeSignalScoreThreshold = 12`（= RuleParams.minScoreThreshold 引用）；enum `ExitReason { hardStop, trendBreak, timeStop }`（宣告順序即同日 tie-break 優先序）

- [ ] **Step 1: 失敗測試**

```dart
// test/core/constants/exit_params_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:afterclose/core/constants/exit_params.dart';
import 'package:afterclose/core/constants/rule_params.dart';

void main() {
  test('ExitParams 常數值（spec §2 起始值，gate 後可調）', () {
    expect(ExitParams.hardStopPct, 0.08);
    expect(ExitParams.timeStopTradingDays, 40);
    expect(ExitParams.ma60Window, 60);
    expect(ExitParams.holdHorizonTradingDays, 60);
    expect(ExitParams.minCellSample, 30);
    expect(ExitParams.modeSignalScoreThreshold, RuleParams.minScoreThreshold);
  });

  test('ExitReason 宣告順序 = 同日 tie-break 優先序', () {
    expect(ExitReason.values, [
      ExitReason.hardStop,
      ExitReason.trendBreak,
      ExitReason.timeStop,
    ]);
  });
}
```

- [ ] **Step 2: 跑測試確認 compile fail**（`flutter test test/core/constants/exit_params_test.dart` → Error: 找不到 exit_params.dart）
- [ ] **Step 3: 實作**

```dart
// lib/core/constants/exit_params.dart
import 'package:afterclose/core/constants/rule_params.dart';

/// 出場/論點失效參數（評分改進 #3）
///
/// 起始值為 spec §2 設計值；**最終值由 tool/exit_validate.dart 的
/// replay gate 定案**——沒 edge 的條件不進 app。
abstract final class ExitParams {
  /// 硬停損：收盤 < referencePrice × (1 - 此值)
  static const double hardStopPct = 0.08;

  /// 時間停損：釘選後滿此交易日數且從未收高於 referencePrice
  static const int timeStopTradingDays = 40;

  /// trendBreak 的均線窗
  static const int ma60Window = 60;

  /// gate 的持有對照窗（交易日）
  static const int holdHorizonTradingDays = 60;

  /// gate 報告 (mode × 年) cell 的最低樣本數，低於此標灰不計入結論
  static const int minCellSample = 30;

  /// mode 訊號日樣本門檻：該 mode 規則分數加總 ≥ 此值（訊號 tier proxy）
  static const int modeSignalScoreThreshold = RuleParams.minScoreThreshold;
}

/// 失效原因。**宣告順序即同日 tie-break 優先序**（spec §2）：
/// 同一天多條件為真時取 index 最小者。
enum ExitReason { hardStop, trendBreak, timeStop }
```

- [ ] **Step 4: 跑測試綠**
- [ ] **Step 5: Commit**（`feat(exit): ExitParams 常數 + ExitReason tie-break 順序`）

---

### Task 2: 純函數出場模擬 `simulateExit`

**Files:**
- Create: `tool/exit_validate.dart`（先只放純函數區塊）
- Test: `test/tool/exit_validate_test.dart`

**Interfaces:**
- Consumes: `ExitParams` / `ExitReason`（Task 1）
- Produces:

```dart
typedef ExitSimResult = ({
  double exitReturnPct,   // 出場版總報酬（%），出場後 0
  double holdReturnPct,   // 持有滿 60 交易日總報酬（%）
  int holdingDays,        // 出場版實際持有交易日數（未觸發 = horizon）
  ExitReason? reason,     // null = 全程未觸發
  double exitMddPct,      // 出場版最大回檔（%，負值）
  double holdMddPct,      // 持有版最大回檔
});

/// [closes]: 該股收盤序列（升序、可含 null）；[t0Index]: 訊號日 index。
/// 需 t0Index+1（T+1 進場）與 t0Index+1+horizon 皆在界內且非 null，
/// 否則回 null（caller 計入 survivorship counter）。
/// [enabled]: 本次模擬啟用的條件集（單條變體用）。
ExitSimResult? simulateExit({
  required List<double?> closes,
  required int t0Index,
  required Set<ExitReason> enabled,
});
```

- 內部規則（照 spec §2）：referencePrice = closes[t0Index]；逐日 d 從 t0Index+1 起：
  - hardStop：closes[d] < ref × (1 − hardStopPct)
  - trendBreak：d 往前（含 d）有 ≥60 根非 null 收盤才判定；closes[d] < 該窗平均
  - timeStop：d − t0Index ≥ 40 且 (t0Index, d] 間從未 closes > ref
  - 同日多真 → ExitReason.values 順序取先
  - 出場價 = closes[d]；報酬基準 = closes[t0Index + 1]（T+1 進場價）
  - MDD = 各日 closes[d]/entry − 1 的最小值（出場版計到出場日）

- [ ] **Step 1: 失敗測試（合成序列手算對照）**

```dart
// test/tool/exit_validate_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:afterclose/core/constants/exit_params.dart';
import '../../tool/exit_validate.dart';

/// 平坦 100 序列，指定位置覆寫
List<double?> flat(int len, {Map<int, double?> overrides = const {}}) =>
    [for (var i = 0; i < len; i++) overrides[i] ?? 100.0];

void main() {
  const all = {ExitReason.hardStop, ExitReason.trendBreak, ExitReason.timeStop};

  group('simulateExit — hardStop', () {
    test('T+3 收盤 91.9 (< 92) → hardStop 出場、報酬對 T+1 計算', () {
      // t0=70（前面 70 根供 MA60）、entry=closes[71]=100、d=73 跌到 91.9
      final closes = flat(140, overrides: {73: 91.9});
      final r = simulateExit(closes: closes, t0Index: 70, enabled: all)!;
      expect(r.reason, ExitReason.hardStop);
      expect(r.holdingDays, 2); // 71→73
      expect(r.exitReturnPct, closeTo(-8.1, 0.001)); // 91.9/100-1
      expect(r.holdReturnPct, closeTo(0.0, 0.001)); // 其餘平坦
    });

    test('恰等於 92（非 <）→ 不觸發', () {
      final closes = flat(140, overrides: {73: 92.0});
      final r = simulateExit(closes: closes, t0Index: 70, enabled: all)!;
      expect(r.reason, isNot(ExitReason.hardStop));
    });
  });

  group('simulateExit — trendBreak', () {
    test('收盤跌破 60 日均線 → trendBreak', () {
      // 平坦 100，d=75 跌到 99（MA60≈100，99 < 100、但 > 92 不觸發 hardStop）
      final closes = flat(140, overrides: {75: 99.0});
      final r = simulateExit(closes: closes, t0Index: 70, enabled: all)!;
      expect(r.reason, ExitReason.trendBreak);
      expect(r.holdingDays, 4);
    });

    test('MA60 資料不足（t0 前不滿 60 根）→ trendBreak 不判定', () {
      // 只有 30 根歷史 → 該條件永不觸發，其餘平坦 → 無觸發跑滿
      final closes = flat(100, overrides: {35: 99.0});
      final r = simulateExit(
        closes: closes,
        t0Index: 30,
        enabled: {ExitReason.trendBreak},
      )!;
      expect(r.reason, isNull);
    });
  });

  group('simulateExit — timeStop', () {
    test('40 交易日從未收高於 ref → timeStop、41 日者不追溯', () {
      final closes = flat(140); // 永遠 = ref，從未「高於」
      final r = simulateExit(
        closes: closes,
        t0Index: 70,
        enabled: {ExitReason.timeStop},
      )!;
      expect(r.reason, ExitReason.timeStop);
      expect(r.holdingDays, 40 - 1); // d-t0 ≥ 40 首日 = t0+40 → 持有 39 日（自 T+1）
    });

    test('中途曾收高於 ref → timeStop 不觸發', () {
      final closes = flat(140, overrides: {90: 101.0});
      final r = simulateExit(
        closes: closes,
        t0Index: 70,
        enabled: {ExitReason.timeStop},
      )!;
      expect(r.reason, isNull);
    });
  });

  group('simulateExit — tie-break 與邊界', () {
    test('同日 hardStop+trendBreak 皆真 → 取 hardStop（宣告序）', () {
      final closes = flat(140, overrides: {75: 80.0});
      final r = simulateExit(closes: closes, t0Index: 70, enabled: all)!;
      expect(r.reason, ExitReason.hardStop);
    });

    test('窗不足（t0+1+60 超界）→ null（survivorship 樣本）', () {
      expect(
        simulateExit(closes: flat(100), t0Index: 70, enabled: all),
        isNull,
      );
    });

    test('T+1 收盤 null（停牌）→ null', () {
      final closes = flat(140, overrides: {71: null});
      expect(
        simulateExit(closes: closes, t0Index: 70, enabled: all),
        isNull,
      );
    });

    test('全程未觸發 → reason null、兩臂同報酬、holdingDays = horizon', () {
      final closes = flat(140, overrides: {131: 110.0}); // 尾端漲（horizon 末）
      final r = simulateExit(
        closes: closes,
        t0Index: 70,
        enabled: {ExitReason.hardStop},
      )!;
      expect(r.reason, isNull);
      expect(r.exitReturnPct, r.holdReturnPct);
      expect(r.holdingDays, ExitParams.holdHorizonTradingDays);
    });

    test('MDD：出場版計到出場日、持有版計全窗', () {
      // d=75 跌 90（-10%）觸發 hardStop；d=100 再跌 80（持有版 MDD -20%）
      final closes = flat(140, overrides: {75: 90.0, 100: 80.0});
      final r = simulateExit(closes: closes, t0Index: 70, enabled: all)!;
      expect(r.exitMddPct, closeTo(-10.0, 0.01));
      expect(r.holdMddPct, closeTo(-20.0, 0.01));
    });
  });
}
```

- [ ] **Step 2: 跑測試確認 compile fail**
- [ ] **Step 3: 實作 simulateExit**

```dart
// tool/exit_validate.dart（節錄：純函數區塊）
ExitSimResult? simulateExit({
  required List<double?> closes,
  required int t0Index,
  required Set<ExitReason> enabled,
}) {
  final ref = closes[t0Index];
  final entryIndex = t0Index + 1;
  final endIndex = entryIndex + ExitParams.holdHorizonTradingDays;
  if (ref == null || endIndex >= closes.length) return null;
  final entry = closes[entryIndex];
  if (entry == null || entry <= 0) return null;

  double? ma60At(int d) {
    var sum = 0.0;
    var n = 0;
    for (var k = d; k >= 0 && n < ExitParams.ma60Window; k--) {
      final c = closes[k];
      if (c != null) {
        sum += c;
        n++;
      }
    }
    return n < ExitParams.ma60Window ? null : sum / n;
  }

  var everAboveRef = false;
  ExitReason? reason;
  var exitIndex = endIndex; // 未觸發 = 持有到 horizon 末
  for (var d = entryIndex; d <= endIndex; d++) {
    final c = closes[d];
    if (c == null) continue; // 停牌日跳過（timeStop 用 index 差計數）
    if (c > ref) everAboveRef = true;

    ExitReason? hit;
    if (enabled.contains(ExitReason.hardStop) &&
        c < ref * (1 - ExitParams.hardStopPct)) {
      hit = ExitReason.hardStop;
    } else if (enabled.contains(ExitReason.trendBreak)) {
      final ma = ma60At(d);
      if (ma != null && c < ma) hit = ExitReason.trendBreak;
    }
    if (hit == null &&
        enabled.contains(ExitReason.timeStop) &&
        d - t0Index >= ExitParams.timeStopTradingDays &&
        !everAboveRef) {
      hit = ExitReason.timeStop;
    }
    if (hit != null) {
      reason = hit;
      exitIndex = d;
      break;
    }
  }

  double retPct(int d) => (closes[d]! / entry - 1) * 100;
  var exitMdd = 0.0;
  var holdMdd = 0.0;
  for (var d = entryIndex; d <= endIndex; d++) {
    if (closes[d] == null) continue;
    final r = retPct(d);
    if (d <= exitIndex && r < exitMdd) exitMdd = r;
    if (r < holdMdd) holdMdd = r;
  }

  return (
    exitReturnPct: closes[exitIndex] != null ? retPct(exitIndex) : 0.0,
    holdReturnPct: retPct(endIndex),
    holdingDays: reason == null
        ? ExitParams.holdHorizonTradingDays
        : exitIndex - entryIndex,
    reason: reason,
    exitMddPct: exitMdd,
    holdMddPct: holdMdd,
  );
}
```

注意 tie-break 實作細節：hardStop 與 trendBreak 以 if/else-if 串接
（宣告序優先），timeStop 殿後——與 `ExitReason.values` 順序一致。
holdReturnPct 若 `closes[endIndex]` 為 null 需往前找最近非 null 收盤
（實作時補；測試以非 null 尾端為主）。
- [ ] **Step 4: 跑測試綠**（若手算預期與實作對不上，先驗算測試本身再改實作——邊界 `d − t0Index ≥ 40` 的 off-by-one 以測試值為準討論修正）
- [ ] **Step 5: Commit**（`feat(exit): simulateExit 純函數出場模擬（gate 核心）`）

---

### Task 3: ScoreSample 加 symbol（樣本蒐集前置）

**Files:**
- Modify: `tool/replay_calibrator.dart`（`ScoreSample` typedef + `_scoreSink` 呼叫處）
- Modify: `tool/score_validate.dart:149` 附近（既有 consumer 的 record 建構/解構）
- Test: `test/tool/replay_calibrator_test.dart`（既有 sink 測試若有）+ 編譯即驗證

**Interfaces:**
- Produces: `ScoreSample` 增 `String symbol` 欄位（record type 變更，所有建構點同步）

- [ ] **Step 1: 改 typedef 加 `String symbol,`；改 `_replaySymbol` 內 `_scoreSink((...))` 傳入 `symbol: symbol`**
- [ ] **Step 2: `flutter analyze` 找出所有 broken consumer（score_validate.dart 等）逐一補欄位**
- [ ] **Step 3: `flutter test test/tool/` 全綠**
- [ ] **Step 4: Commit**（`refactor(calibration): ScoreSample 加 symbol 供 exit gate 樣本蒐集`）

---

### Task 4: 樣本蒐集 + 出場模擬 pipeline

**Files:**
- Modify: `tool/exit_validate.dart`（加 `ExitValidator` class）
- Test: `test/tool/exit_validate_test.dart`（追加 group）

**Interfaces:**
- Consumes: `ReplayCalibrator`（scoreSink）、`simulateExit`（Task 2）
- Produces:

```dart
/// mode 訊號日樣本
typedef ExitSample = ({String symbol, DateTime date, String mode});

class ExitValidator {
  ExitValidator({required AppDatabase db, void Function(String)? logger});

  /// 1. 跑 ReplayCalibrator（excess 模式無所謂，sink 只取 mode sums）
  ///    收集樣本：modeMomentum/Strength/Pullback 加總 ≥
  ///    ExitParams.modeSignalScoreThreshold 的 (symbol, date, mode)。
  ///    同 symbol×mode **不重疊窗**：接受一筆後，跳過該 symbol×mode
  ///    在 T1+60 窗關閉前的後續樣本（防偽重複——同股連日觸發不代表
  ///    你會連日重複釘選）。
  /// 2. 對樣本 symbol 載入完整價格序列（db.getPriceHistory 升序），
  ///    找到 date 的 index → 對 4 個變體（全開/三個單條）各跑 simulateExit。
  /// 3. 回傳 per-變體 per-樣本結果 + survivorship counters。
  Future<ExitValidationResult> run();
}
```

- [ ] **Step 1: 失敗測試**（in-memory DB、mock RuleEngine 比照 `replay_calibrator_clustered_test.dart` 既有 fixture：seed 2 檔 200 天、mock 觸發一條 pullback-mode 規則分數 15 → 斷言 (a) 產生 pullback 樣本、(b) 同 symbol 不重疊窗只留第一筆、(c) 窗不足的尾端樣本進 survivorship counter 而非結果）
- [ ] **Step 2: 確認 RED**
- [ ] **Step 3: 實作 ExitValidator.run**（樣本蒐集 → 價格載入 → 4 變體模擬；mode 判定用 `ScoreSample.modeXxx ≥ threshold`，一個股票日可同時屬多個 mode）
- [ ] **Step 4: 跑測試綠**
- [ ] **Step 5: Commit**（`feat(exit): ExitValidator 樣本蒐集與 4 變體出場模擬`）

---

### Task 5: 聚合報告（mode × 年 × 變體）

**Files:**
- Modify: `tool/exit_validate.dart`（`buildReport` 純函數 + CLI main + flutter test wrapper）
- Create: `test/tool/run_exit_validate.dart`（CLI 載體，比照 `run_replay.dart`）
- Test: `test/tool/exit_validate_test.dart`（追加 group）

**Interfaces:**
- Produces: `String buildReport(ExitValidationResult result)` — markdown 文字，逐 cell：n、出場vs持有平均報酬差、勝率（出場≥持有比例）、平均持有日、兩臂 MDD；n < `ExitParams.minCellSample` 的 cell 標「(樣本不足)」；報告尾附 survivorship counters、漲跌停樣本數（`PriceLimit.isLimitUp/Down` 判 T0 與觸發日）、方法論限制段（0% 再部署假設警語，spec §3 原文）。CLI 印 stdout 並寫 `tool/exit-validate-report.md`。

- [ ] **Step 1: 失敗測試**（合成 `ExitValidationResult` → 斷言報告含：cell 標灰字樣、勝率數字、方法論警語關鍵句「不等於「紀律沒用」」）
- [ ] **Step 2: 確認 RED**
- [ ] **Step 3: 實作 buildReport + main + wrapper**（main 比照 `runReplayCalibratorCli` 模式：`--db` 參數、exit codes 0/2）
- [ ] **Step 4: 跑測試綠 + `flutter analyze` 乾淨**
- [ ] **Step 5: Commit**（`feat(exit): gate 報告聚合（mode×年×變體）+ CLI`）

---

### Task 6: 全套件回歸 + code review + 實跑 gate

- [ ] **Step 1: `flutter test` 全綠**
- [ ] **Step 2: code-reviewer 審查 Task 1-5 合併 diff**（行為敏感慣例），發現即修
- [ ] **Step 3: Commit + push**
- [ ] **Step 4: 對 `tool/calibration.db` 實跑**：`flutter test test/tool/run_exit_validate.dart --reporter=expanded`（背景，估 ~10 分鐘等級——與 replay 同量級）
- [ ] **Step 5: 整理報告交 Neal 決策**：哪些條件過 gate、參數是否需調（-8%/40 日被打臉則帶建議值）、Phase 2 是否全量或縮減上線

---

## Phase 2（不在本計畫）

Gate 結果經 Neal 核可後另立 `docs/plans/` 計畫：`pinned_thesis` 表 + migration、`ThesisInvalidationRules`（app 端與 `simulateExit` 共用語意但介面不同——輸入含釘選前 60 根）、`ThesisMonitorService`、UI（釘選鈕/追蹤區/警示 section）。spec §4-§6 為其 source of truth。
