# Rule Score Calibration

> 這份文件說明 `tool/recalibrate.dart` 如何把歷史 `rule_accuracy` 統計轉成 calibrated rule scores JSON 檔，以及人工 review 工作流程。
>
> **狀態**：pipeline + Stage 5 runtime loader 都已 ship — scoring 會透過 `calibrated_scores/` registry 消費 calibrated JSON，無資料時 fallback 到 `rule_scores.dart` 手調基礎分。目前 production JSON 多為 fallback（實質跑在手調分上，為設計非 bug）。

---

## 📋 目錄

- [何時該跑 calibration](#何時該跑-calibration)
- [如何執行](#如何執行)
- [Review workflow](#review-workflow)
- [公式：linear_map_v1](#公式linear_map_v1)
- [Cut 規則](#cut-規則)
- [JSON 輸出格式](#json-輸出格式)
- [Troubleshooting](#troubleshooting)

---

## 何時該跑 calibration

**每月一次**（預設節奏）。具體觸發時機：

1. 累積 ≥ 2 個月 daily_reason 資料之後 — 樣本數夠讓 cut threshold 有意義
2. 大版本上線前 — 確認 scoring 仍反映最新市場特性
3. 新增 rule 後 — 給新 rule 第一份 baseline 分數
4. 發現明顯誤判時 — 懷疑特定 rule 權重失準時手動驗證

**不要**：
- 剛上線第一天就跑（樣本數 < 30 → 全部 cut）
- 每天跑（沒必要，rule_accuracy 一天變化很小）
- 自動覆寫 production（永遠要人工 review gate）

---

## 如何執行

從 repo root 目錄：

```bash
# 兩個 horizon 都跑（預設）
dart run tool/recalibrate.dart

# 只跑短線（5D）或長線（60D）
dart run tool/recalibrate.dart --horizon short
dart run tool/recalibrate.dart --horizon long

# Dry run — 印出 candidate JSON 但不寫檔
dart run tool/recalibrate.dart --dry-run

# 自訂 DB 位置（若 auto-detect 失敗）
dart run tool/recalibrate.dart --db /path/to/afterclose.sqlite
```

### 輸出

工具會寫入 `assets/` 底下的 candidate 檔案：

```
assets/rule_scores_calibrated_short_candidate.json
assets/rule_scores_calibrated_long_candidate.json
```

**關鍵**：檔名有 `_candidate` 後綴。這不是 production 版本。需要人工 review 後手動 rename 才生效。

---

## Review workflow

### 1. 跑 recalibrate.dart

```bash
dart run tool/recalibrate.dart
```

確認 console 輸出：
- `✅ Wrote ...` 表示 candidate 產出成功
- `⚠️  rule_accuracy 沒有 XX 的統計資料 — skip` 表示資料不足，要等累積更多

### 2. 看 diff

```bash
git diff assets/rule_scores_calibrated_*_candidate.json
```

**檢查重點**：
- 分數變動幅度是否合理？（突然大增減要查）
- 新增 cut 的規則是否預期？（看 `cut_reason`）
- Active 的規則 score 分布是否合理？（不應該全部擠在 10 或 35）
- `samples` 欄位是否反映最近的資料量？

### 3. 判斷

**要 approve 當前 candidate**：
```bash
mv assets/rule_scores_calibrated_short_candidate.json \
   assets/rule_scores_calibrated_short.json

mv assets/rule_scores_calibrated_long_candidate.json \
   assets/rule_scores_calibrated_long.json
```

**要退回**：
```bash
rm assets/rule_scores_calibrated_*_candidate.json
```
然後檢查 DB 資料是否有異常，必要時等下個月再試。

### 4. Commit + push

```bash
git add assets/rule_scores_calibrated_short.json assets/rule_scores_calibrated_long.json
git commit -m "chore(calibration): monthly recalibration YYYY-MM"
git push origin main
```

Commit message 應該在 body 記錄 review 時的判斷與 anomaly observation。

---

## 公式：linear_map_v1

給定單一規則的統計 `(hit_rate, avg_return, trigger_count)`：

### Step 1 — Proportion z-test

判斷 `hit_rate` 是否統計顯著地超過 0.5（純機率）：

```
z = (hit_rate - 0.5) / sqrt(hit_rate × (1 - hit_rate) / n)
```

Degenerate cases (z = 0)：
- `n = 0`
- `hit_rate ∈ {0, 1}`（variance = 0，undefined）

這些 case 會落入 `sample_too_small` cut，不影響後續計算。

### Step 2 — Raw weight

```
raw_weight = hit_rate × avg_return × √n
```

**為什麼用 `√n`**：
- 樣本數越多權重越高（越可信）
- 但用 `√n` 而非 `n` 避免大樣本規則壓垮小樣本（sub-linear scaling，跟統計學中標準誤差呈反比成正比）
- 雙重保險：跟 `hit_rate × avg_return` 相乘，防止「低勝率但一次大賺」造成假高分

### Step 3 — Cut thresholds（見下一節）

### Step 4 — Min-max normalization

```
score = 10 + (raw_weight - minRaw) / (maxRaw - minRaw) × 25
```

其中 `minRaw` / `maxRaw` 是**倖存者**的 raw weight 範圍（cut 掉的規則**不計入**）。這防止被 cut 的 outlier 規則扭曲 active 規則的分數分布。

**邊界處理**：
- 只有 1 條倖存者 → 分數設為中點 (22)
- 所有倖存者 raw 相同 → 同上
- `raw < minRaw` 或 `raw > maxRaw`（浮點誤差）→ clamp 到 [10, 35]

---

## Cut 規則

規則會被判定為 `active: false` 並得分 0 的三種情況，check order 重要：

| # | 門檻 | `cut_reason` | 觸發條件 | 為什麼先檢查 |
|:---:|:---|:---|:---|:---|
| 1 | samples | `sample_too_small` | `triggerCount < 30` | 樣本太少，所有統計都不可信 |
| 2 | z-stat | `t_stat_below_threshold` | `z_stat < 1.5` | 顯著性測試失敗，效果可能是雜訊 |
| 3 | hit_rate | `hit_rate_below_threshold` | `hit_rate < 0.55` | 顯著但勝率太低，實戰價值不足 |

**Check order 的重要性**：檢查順序從「最嚴格 / 最通用」到「最細節」。樣本不足時無法做後續測試；z-stat 失敗時 hit_rate 數字本身不可靠。

### 邊界案例示意

| Scenario | hit_rate | samples | z-stat | Cut reason |
|:---|:---:|:---:|:---:|:---|
| 新規則，資料不足 | 0.65 | 25 | — | sample_too_small |
| 小樣本瞎貓撞死耗子 | 0.80 | 20 | — | sample_too_small |
| 中性訊號 | 0.51 | 50 | 0.14 | t_stat_below_threshold |
| 顯著但勝率邊緣 | 0.54 | 500 | 1.79 | hit_rate_below_threshold |
| 顯著且強勢 | 0.65 | 100 | 3.15 | **active** ✅ |

---

## JSON 輸出格式

```json
{
  "schema_version": 1,
  "generated_at": "2026-05-01T02:30:00.000Z",
  "horizon": "5d",
  "backtest": {
    "window_days": 504,
    "train_ratio": 0.7,
    "success_threshold_pct": 1.5,
    "formula": "linear_map_v1"
  },
  "rules": {
    "reversalW2S": {
      "score": 28,
      "hit_rate": 0.6523,
      "avg_return": 3.1247,
      "samples": 412,
      "t_stat": 6.2147,
      "active": true
    },
    "patternDoji": {
      "score": 0,
      "hit_rate": 0.5234,
      "avg_return": 1.1203,
      "samples": 89,
      "t_stat": 0.4425,
      "active": false,
      "cut_reason": "t_stat_below_threshold"
    }
  }
}
```

### 欄位說明

| 欄位 | 型別 | 說明 |
|:---|:---|:---|
| `schema_version` | int | 目前固定為 1。升級公式（例如切到 IC-based）時 bump |
| `generated_at` | ISO 8601 UTC string | 跑 `recalibrate.dart` 的時間戳 |
| `horizon` | `"5d"` \| `"60d"` | 此檔對應的時間尺度 |
| `backtest.window_days` | int | 回測天數（目前 504 = 2 trading years） |
| `backtest.train_ratio` | float | Train/test split ratio（目前 0.7，但 Stage 2 LEAN 未實作 out-of-sample validation） |
| `backtest.success_threshold_pct` | float | 對應 horizon 的 success 判定門檻。canonical 值由 [`CalibrationThresholds.successThresholds`](../lib/core/constants/calibration_thresholds.dart) 提供（5D=1.5%、60D=8.0%；drift guard 會把 JSON 對比 canonical 拒載失準版本）。 |
| `backtest.formula` | string | 公式版本識別子，目前 `linear_map_v1` |
| `rules.*.score` | int | 校準後分數（cut 為 0，active 為 [10, 35]） |
| `rules.*.hit_rate` | float (4 dp) | 命中率 |
| `rules.*.avg_return` | float (4 dp) | 平均報酬率（%） |
| `rules.*.samples` | int | 觸發次數 |
| `rules.*.t_stat` | float (4 dp) | Proportion z-test 值 |
| `rules.*.active` | bool | 是否通過 cut |
| `rules.*.cut_reason` | string (optional) | 只有 cut 規則有此欄位 |

---

## Troubleshooting

### ❌ `DB file 找不到`

Auto-detect 只知道 macOS Flutter container 的預設位置（`~/Library/Containers/com.neo.afterclose/Data/Documents/`）。若你的 DB 在別處：

```bash
find ~ -name "afterclose*.sqlite" 2>/dev/null
dart run tool/recalibrate.dart --db /path/found/above
```

### ⚠️ `rule_accuracy 沒有 XX 的統計資料`

`rule_accuracy` 表是空的或對應 period 沒資料。可能原因：

- App 從未跑過 post-update hook（`validatePastRecommendationsMultiPeriod` 或 `backfillAllHistoricalRecommendations`）
- `daily_reason` 本身沒資料（scoring pipeline 沒 persist reasons）
- 60D horizon 需要資料回溯至少 60 個交易日 + backtest window，pre-launch 根本不可能有

**解法**：跑 app，讓 daily scoring pipeline 生成資料，等幾週再重跑。

### 所有規則都被 cut

一次全砍通常代表：
1. **樣本數太少**（所有 rule `sample_too_small`）— 等資料累積
2. **資料格式問題**（`hit_rate` 全 0）— 看 `_computeValidation` 的 success threshold 是否合理
3. **backfill 沒跑完**（rule_accuracy 只有 partial 資料）— 重跑 `backfillAllHistoricalRecommendations`

### 分數分布異常（全擠 10 或 35）

表示**倖存者 raw weight 範圍**太窄：

- 全擠 10：`maxRaw - minRaw` 太小，所有 active 規則幾乎一樣強 → 正常，代表 rule set 同質性高
- 全擠 35：可能單一規則 raw 特別高，其他擠在 minRaw → 可能是資料異常，檢查該規則的樣本

### Candidate 比 production 差很多

**不要 approve**。查：
1. 是否剛經歷異常市場（如極端黑天鵝）？校準結果可能被污染
2. 是否 daily_reason 有 bug 多寫了假 trigger？
3. 是否 backfill 邏輯改過（例如 Stage 5 引入 dual-horizon）沒重跑？

**回退**：刪 `*_candidate.json`，保留目前 production，下個月再試。

---

## 設計背景

完整的 Stage 2 LEAN 設計文件在 [`docs/plans/2026-04-11-scoring-stage2-design.md`](plans/2026-04-11-scoring-stage2-design.md)。

關鍵決策（來自 2026-04-11 brainstorming session）：
- 公式選 **linear_map_v1**（interpretable），非 IC-based 或 logistic regression
- **雙 horizon** 策略：短 5D + 長 60D，每條規則在兩個 horizon 各有獨立分數
- Cut threshold **嚴格版**：t_stat<1.5 / hit_rate<55% / n<30
- **月度人工 review gate**：絕不自動覆寫 production
- Stage 2 只建 pipeline，**不消費** JSON（消費工作在 Stage 5，需真實資料驗證架構）
