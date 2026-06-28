# 產業領導 + 相對強度 RS — Design Spec

> 把選股從「個股層級」升級到專業動能系統的兩個核心面向：**產業領導（強股 × 強產業）** 與 **相對強度 RS（贏大盤 / 贏產業，而非絕對漲幅）**。
>
> **狀態**：
> - **Part 1 產業領導** = Design（待實作）。資料已備（官方產業類指數 + 個股歷史），可立即實作 + 過 backtest gate。
> - **Part 2 RS** = Design（parked）。卡在指數歷史深度，需 `market_index` 回補到 ~200+ 根（回補機制已於 `MarketIndexSyncer` 開啟，`_backfillThreshold=200`/`_backfillCalendarDays=365`），補滿後才實作 + shadow 驗證。
>
> 兩者皆為**選股排序**改動，遵守既有紀律：離線 backtest 驗證 → 人工 review gate → ship，production scoring 在驗證通過前不動。

---

## 1. 背景與動機

現行 Today 三模式（起漲 A / 強勢 B / 回檔 C）已是多維度選股（技術 + 基本面 + 籌碼），但以**專業動能分析師**角度仍有兩個缺口：

1. **產業領導缺席**：選股是純個股層級。Dashboard 有顯示產業表現，但 scoring / mode 排序**零產業因子**（已驗：`grep` 選股邏輯無 industry/sector）。專業做法是「強股 + 強產業」（sector rotation）—— 同樣型態，在領漲族群裡勝率顯著高。
2. **只有絕對動能、沒有相對強度**：Mode B 用「60D **絕對**報酬」當 RS proxy（`mode_recommendation_provider` 自承 proxy）。但專業 RS = **贏不贏大盤 / 產業**。一檔 60D 漲 20% 但大盤漲 25% 其實是**落後盤**，絕對 proxy 會誤判為強。這是 CAN SLIM RS Rating / Minervini RS line 的核心。

**目標**：
- Part 1：把「產業強弱」作為**加分 factor（soft tilt）**進選股排序，過 backtest 驗證後 ship。
- Part 2：把 Mode B 的排序鍵從「絕對 60D 報酬」升級為「**相對強度 RS**」；先出設計，待指數歷史補滿再實作。

**與既有 rule-score 校準的關係（避免混淆）**：`2026-06-22-rule-score-recalibration-design` 在 **rule-score 層**用橫斷面超額報酬讓「每條規則的分數」反映 alpha。本 spec 在 **selection-rank 層**改「清單怎麼排序」。兩者是不同層、互補不重複。

## 2. 非目標（Non-goals）

- 不做 per-股 beta 調整、多因子 IC 分解、完整顯著性檢定 — 對散戶本地 app 過度。
- 不改三模式的 reason→mode 分桶、eligibility 閘門（`isEligibleForMode` 的 biasMa20/todayPct gate 不動）。產業 tilt 只影響**排序**，不影響「誰進得來」。
- 不改 Mode C 回檔（純價格回檔語意，本期不套產業 tilt；日後可再評估）。
- 不自動 ship — selection 改動永遠保留人工 review + backtest gate。
- Part 2 RS 不在指數歷史補滿前實作（避免無法驗證的賭注）。

## 3. 架構與資料流

```
                    ┌──────────────── 既有 ────────────────┐
 daily_price ──┐    │  CandidateSelector → ScoringIsolate   │
 market_index ─┼──▶ │  → daily_analysis / daily_reason      │
 stock_master ─┘    │  → mode_recommendation_provider 排序   │
                    └───────────────────┬──────────────────┘
                                        │ STEP 6 排序（本 spec 介入點）
                     ┌──────────────────┴──────────────────┐
   NEW: SectorStrengthService            NEW: RelativeStrengthService (parked)
   產業 20D 報酬 → 百分位 sectorRank       個股 60D − benchmark 60D → RS
                     └──────────────────┬──────────────────┘
                          rank-blend：finalScore = (1−W)·baseRank + W·sectorRank
                                        ↓
                              離線 backtest 驗證（tool/）
                                        ↓
                              人工 review gate → ship
```

介入點集中在 **`lib/presentation/providers/mode_recommendation_provider.dart` 的 STEP 6（排序）**。新增兩個純函數 service，不動 scoring isolate、不動 DB schema。

---

## 4. Part 1：產業領導（待實作）

### 4a. 算族群強弱 — `SectorStrengthService`（新檔 `lib/domain/services/analysis/sector_strength_service.dart`）

```dart
/// 回傳「產業名 → 強弱百分位 [0,1]」。1.0 = 最強族群。
class SectorStrengthService {
  /// [industryReturns] 各產業 20D 報酬（來源見下）
  Map<String, double> rankSectors(Map<String, double> industryReturns) {
    // 百分位排名：最弱=0、最強=1（避免絕對報酬尺度問題）
    final sorted = industryReturns.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final n = sorted.length;
    return {
      for (var i = 0; i < n; i++)
        sorted[i].key: n > 1 ? i / (n - 1) : 0.5,
    };
  }
}
```

**產業 20D 報酬來源（兩段式，全覆蓋）**：
1. **優先官方產業類指數**：`market_index` 有半導體類/金融保險類/航運類/生技醫療類…。建 `產業名 → 指數名` 對照（如 `半導體業 → 半導體類指數`）。用指數 20D 報酬。
2. **fallback 成員股**：無對應官方指數的產業（41 產業中部分）→ 該產業成員股 20D 報酬的**中位數**（中位數比平均抗離群）。

**Look-ahead 防護**：20D 報酬只用 `date <= analysisDate` 的收盤；產業指數亦為當日收盤。無前視。

### 4b. 進選股 — rank-blend（你選的 soft tilt）

在 `mode_recommendation_provider` STEP 6，對 **Mode A + Mode B** 的排序鍵改為：

```dart
// baseRank：各 mode 原排序鍵的百分位（A: modeScoreShort / B: ret60d / 皆 [0,1]）
// sectorRank：該股所屬產業的 sectorStrength 百分位
final finalScore = (1 - W) * baseRank + W * sectorRank;   // DESC 排序
```

- **用 rank-blend 不用乘法**：60D 報酬會負，乘法在負值上行為錯亂；rank-blend 對負值 / 不同尺度都穩健。
- **`W` = 可調權重**，集中為具名常數（`lib/core/constants/rule_params_*.dart`，如 `SectorParams.tiltWeight`），**起始 0.25**，由 backtest 校準。
- 效果：強族群股往前、弱族群股往後，**清單數量不變**（soft，不砍股）。
- Mode C 不套（純價格回檔）。

### 4c.（可選潤飾）強產業 evidence chip

- 該股所屬產業 sectorRank ≥ 0.8（前 20% 族群）→ 卡片加「🔥 強產業」chip（資訊性，搭配 factor，不影響排序計算本身）。
- 屬 nice-to-have，可與核心分開 ship。

### 4d. 實作步驟（可直接執行）

1. 新 `SectorStrengthService` + 單元測試（百分位排名、tie、單一產業邊界、空輸入）。
2. 產業→指數對照表（具名常數 map；缺對應者走 fallback）。
3. `market_overview_dao` / 既有產業表現查詢延伸出「各產業 20D 報酬」（或新 query；重用 dashboard 既有計算避免重造）。
4. `mode_recommendation_provider` STEP 6：A/B 排序鍵改 rank-blend；`SectorParams.tiltWeight` 具名常數。
5. 單元測試：rank-blend 公式、W=0 時等同原排序（回歸保護）、強族群股上移驗證。
6. backtest 驗證（見 §5）→ 人工 review → ship。

---

## 5. Part 1 驗證（backtest gate — 核心）

selection 改動必過 backtest，遵循 `2026-06-22-rule-score-recalibration` 的方法論紀律：

1. **歷史族群強弱重建**：官方產業指數歷史仍薄（~81→回補中），故 backtest 期間用**個股歷史重建**各產業 20D 報酬（個股有 250+ 根）。
2. **對照組**：同一組 mode 候選，比較「有 sector tilt（W=0.25 等幾個值）」vs「無 tilt（W=0）」的 **forward 20D 報酬**。
3. **橫斷面超額**：forward 報酬減當日全市場均值（避免多頭 beta 充當 edge），與既有 calibration 方法論一致。
4. **Walk-forward / OOS**：rolling folds，含空頭/盤整樣本外，確認 tilt 在沒看過的 regime 不輸。
5. **判讀**：tilt 須在 OOS 提升超額報酬或勝率、且不顯著放大回檔，才 PASS。W 取 OOS 最佳且穩健者。
6. 全程離線於 `tool/`，production 不動。**人工 review PASS 報告才 ship**。

## 6. Part 2：相對強度 RS（parked 等指數補滿）

### 6a. 算 RS — `RelativeStrengthService`（新檔，待實作）

```dart
/// RS = 個股 60D 報酬 − benchmark 60D 報酬（贏多少）
/// benchmark：大盤（TAIEX）為主、所屬產業指數為輔
double relativeStrength(double stockRet60, double benchmarkRet60) =>
    stockRet60 - benchmarkRet60;
```

- 或做成**百分位 RS Rating 0–100**（全市場排名，IBD 風格）供顯示。
- benchmark 取 `發行量加權股價指數`（TWSE 免費）+（可選）所屬產業指數。

### 6b. 進選股 — 升級 Mode B 排序

- Mode B 現以「60D **絕對**報酬」DESC 排（`ret60ForB`）。改以 **RS（相對）** DESC 排。
- 直接把強勢觀察從「絕對動能」升級為「相對強度」= 專業標準。
- Mode A/C 不變（RS 屬「已漲強勢」語意，對應 Mode B）。

### 6c. 前置 gate + 上線紀律

- **資料 gate**：`market_index` 加權指數歷史 ≥ ~200 根（回補已開啟，每次更新逐日補免費 TWSE，不耗 FinMind）。
- **驗證**：補滿後，backtest「RS 排序 vs 絕對排序」在 Mode B 的 forward 報酬（同 §5 方法論）。
- **shadow-first ≥ 8 週**：RS 排序先 shadow 跑（不影響正式清單、只記錄），確認穩定且勝出再升正式。

## 7. 操作模式 / Review / Ship / Rollback

- **產業領導**：實作 → 離線 backtest →（PASS）→ `W` 定值 → ship（直接進 production 排序）。Rollback = `W=0`（等同關閉 tilt，零行為變更）。
- **RS**：等指數補滿 → 實作 RS service + Mode B shadow 排序 → 8 週 shadow → backtest OOS →（PASS）→ 切正式。Rollback = 切回絕對 60D 排序。
- 兩者皆**人工 gate**，不自動 ship。

## 8. 測試

- `SectorStrengthService`：百分位排名正確性、tie、單一/空產業、fallback 路徑。
- 產業→指數對照：缺對應走 fallback、不 crash。
- `mode_recommendation_provider` rank-blend：**W=0 回歸原排序**（保護現有行為）、強族群股上移、Mode C 不受影響。
- `RelativeStrengthService`（Part 2 實作時）：RS 計算、benchmark null fail-closed、Mode B 排序切換。
- backtest 腳本（`tool/`）：W sweep + walk-forward 報告產出。

## 9. 風險與已知限制

- **產業→指數對照不全**：41 產業 vs ~30 官方指數，部分走成員股 fallback（中位數）。fallback 對成份少的冷門產業雜訊較大 → backtest 時觀察是否該對冷門產業降權或排除。
- **產業指數歷史薄**：backtest 用個股重建（有深度），但 production 即時 factor 用官方指數（81→補中）；補滿前 production 的產業 20D 用 fallback 撐。
- **RS 依賴指數回補**：補滿前無法實作/驗證（已知，故 parked）。
- **W 過大風險**：tilt 太重會讓「弱股在強族群」勝過「強股在弱族群」，失去個股品質。backtest 須在 OOS 找穩健 W、寧小勿大。
- **survivorship / regime**：backtest 須含空頭樣本外，避免產業 rotation 只在多頭有效的假象。

## 10. 變更紀錄

- 2026-06-28：初版。產業領導（待實作）+ RS（parked 等指數補滿）。承接 `MarketIndexSyncer` 回補深度 45→365 的指數歷史準備。
