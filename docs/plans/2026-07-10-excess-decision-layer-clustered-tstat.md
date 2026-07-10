# Calibration 決策層超額化 + 日聚類 t-stat — Design Spec

> 完成 2026-06-22 重校準設計刻意留下的 follow-up：當時只修「輸入統計」
> （橫斷面超額報酬 + look-ahead），把「決策層（cut 規則）不動」列為 non-goal。
> 結果是**超額語意的統計流進絕對語意的決策邏輯**，兩者不一致。本次補完。

## 1. 現狀問題（實證）

1. **baseline 錯配**：`recalibrate.dart` 對 excess 模式產的 `rule_accuracy`
   套用絕對模式的 `successProbabilityBaselines`（如 5D≥1.5% → 0.3461）。
   超額模式下 hit = P(excess ≥ 0)，真實 baseline ≈ 0.45–0.5（依報酬右偏程度），
   用 0.3461 當 H0 會系統性膨脹 z-stat。
2. **雙路 drift**：`walkforward_validate._calibrateFromReplay` 對同一份超額
   統計用 baseline 0.5，CLI `recalibrate` 用 0.3461 —— 同資料、兩種校準結果。
3. **hit-rate cut 語意錯**：0.55 絕對門檻在絕對模式（baseline 0.35–0.40）是
   「+15–20pp lift」，在超額模式（baseline ≈ 0.47）只是「+8pp」——同一常數
   兩種嚴格度。`calibration_thresholds.dart` docstring 自己已標註此為 known flaw。
4. **偽重複樣本**：`rule_accuracy` 只存 pooled 聚合（n、hits、avg），同日
   橫斷面相關 + 持有窗重疊讓名目 n（十萬級）遠大於有效樣本，pooled
   proportion z-test 的 t 值天文數字（|t|>200）毫無意義。
5. **模式不可知**：`rule_accuracy` 表不記錄自己是哪個模式產的，recalibrate
   只能盲猜。

## 2. 目標

- 超額模式下的**單一、統計一致**的決策層：CLI 與 walk-forward 用同一條路。
- t-stat 改 **date-clustered**（Fama-MacBeth 式）：每個觸發日先取橫斷面
  平均超額，再對「日均值序列」做 one-sample t —— 消除偽重複。
- hit-rate cut 改 **baseline-relative lift**：`hitRate ≥ 實證 baseline + 0.05`，
  baseline 從同一次 replay 的全 universe 實測而來，不再硬編碼。
- replay 把模式與 baseline **持久化進 DB**，recalibrate 不猜。

## 3. 非目標

- 不動 runtime scoring / app 內 `rule_accuracy_service`（其絕對報酬統計
  服務於個股詳情顯示，語意獨立）。
- 不動 `linearMapScore` 的 min-max → [10,35] 映射。
- 不動絕對模式（`--no-excess`）的舊路徑 —— 保留供對比。
- 不自動 promote production JSON —— 人工 review gate 照舊。

## 4. 設計

### 4a. replay_calibrator（資料層）

- `RuleHorizonStats.addSample(returnPct, threshold, date)` 增收 `date`，
  另累加 per-date `(n, sum)`；新 getter `dailyMeans`（每觸發日的平均超額
  序列）與 `distinctDates`。
- `_computeUniverseMeanReturns` 之後加第二遍掃描：對全部 stock-day 計
  P(excess ≥ excessSuccessThreshold) → **universe baseline hit**（5D/60D
  各一）。只在 excess 模式算。
- `ReplayResult` 增 `universeBaselineHit5` / `universeBaselineHit60`
  （absolute 模式為 null）。
- 持久化（raw SQL、不進 app Drift schema）：
  ```sql
  CREATE TABLE IF NOT EXISTS rule_daily_stats (
    rule_id TEXT NOT NULL, period TEXT NOT NULL, date TEXT NOT NULL,
    n INTEGER NOT NULL, mean_return REAL NOT NULL,
    PRIMARY KEY (rule_id, period, date));
  CREATE TABLE IF NOT EXISTS calibration_run_meta (
    key TEXT PRIMARY KEY, value TEXT NOT NULL);
  ```
  meta keys：`return_mode`（excess|absolute）、`excess_success_threshold`、
  `universe_baseline_hit_5d`、`universe_baseline_hit_60d`、`generated_at`。
  每次 replay 全刪重寫（與 rule_accuracy 同語意）。

### 4b. recalibrate（決策層）

- `RuleStats` 增 `dailyMeans`（`List<double>`，預設 `const []`）。
- 新純函數 `Calibrator.clusteredTStat(List<double> dailyMeans)`：
  D<2 或 sd=0 → 0；否則 `mean / (sd / sqrt(D))`，sd 用樣本標準差（÷(D−1)）。
- 新入口 `Calibrator.calibrateAllClustered(allStats, {required baselineHit})`，
  cut 順序（first match wins）：
  1. `sample_too_small` — triggerCount < 30（沿用）
  2. `dates_too_few` — distinctDates < 30（新，`CalibrationThresholds.minDistinctDates`）
  3. `t_stat_below_threshold` — clusteredT < 1.5（同一常數、新統計量）
  4. `hit_rate_below_threshold` — hitRate < baselineHit + 0.05
     （`CalibrationThresholds.hitRateLiftThreshold`）
- 倖存者 raw weight = `hitRate × mean(dailyMeans) × sqrt(distinctDates)`
  （linear_map_v1 形狀不變，輸入改聚類量 —— 頻繁觸發規則不再靠偽重複的
  `sqrt(百萬n)` 撐權重）。
- CLI 流程：讀 `calibration_run_meta`。`return_mode=excess` → 從
  `rule_daily_stats` 建 dailyMeans、用存檔 baseline 走 clustered 路徑；
  meta 缺失或 absolute → 走舊路徑並警告。
- JSON `backtest` 區塊增（additive、schema_version 不變）：`return_mode`、
  `stats_method: 'date_clustered_t_v1'`、`baseline_hit_rate`；excess 模式下
  `success_threshold_pct` 改記實際超額門檻（0.0），不再誤標 8.0。

### 4c. walkforward_validate

- `_calibrateFromReplay` 改用 `calibrateAllClustered`，baseline 取 train
  replay 的 `universeBaselineHit*`，dailyMeans 從 in-memory
  `RuleHorizonStats` 直取 —— 與 CLI 同一條決策路。
- SWE 指標與 gate 準則不變。

### 4d. 常數（calibration_thresholds.dart）

```dart
static const double hitRateLiftThreshold = 0.05; // excess: baseline + 5pp
static const int minDistinctDates = 30;          // clustered t 的日數下限
```

## 5. 驗證計畫

1. 全單元測試（TDD，先紅後綠）。
2. 對 `tool/calibration.db` 重跑 replay（excess 預設）→ recalibrate →
   candidate JSON；與現行 production diff、逐條列 cut/active 變化與理由。
3. walk-forward gate（leave-one-year-out，2022 空頭折重點）——**跑一次認帳**，
   不對測試集調參。
4. 報告交使用者決定是否 rename promote（人工 gate）。

## 6. 風險

- 新 cut 更嚴（有效樣本縮到日數級），可能 0 active → 全 fallback 硬編碼分數。
  這是誠實結果非失敗；JSON 仍照常產出，cut_reason 可稽核。
- `rule_daily_stats` 體積：66 rules × 2 periods × ~1250 天 ≈ 16 萬列，無虞。
