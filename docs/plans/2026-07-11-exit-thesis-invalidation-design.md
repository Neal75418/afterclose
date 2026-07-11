# 出場層：釘選論點失效追蹤 — Design Spec

> 評分改進 #3（八項中最後一項）。App 只有進場推薦、沒有出場紀律——
> 損益大半由出場決定。本設計把「推薦」升級為可追蹤的「論點」：
> 釘選 → 每日檢查失效條件 → 失效進警示頁。
>
> **狀態**：Design 定案（2026-07-11，與 Neal 三輪問答收斂）。
> 實作順序：**先 replay gate 驗證出場條件有 edge，才寫 app 端**。

---

## 1. 需求收斂（使用者決策紀錄）

| 決策點 | 定案 | 理由 |
|---|---|---|
| 偵測對象 | **釘選推薦**（pinned thesis） | Neal 不在 app 記持倉；自選股缺進場論點快照，失效無從定義。釘選 = 論點快照 + 紙上驗證跟單紀律 |
| 失效條件 | **通用三條起步** | 可回測、可解釋；per-mode 客製留 v2 |
| 提醒方式 | **接警示頁** | 盤後節奏 = 更新後看一輪，不需推播 |

## 2. 失效條件（先過 gate 才上線）

以「參考價」= 釘選資料日收盤（**僅供顯示與條件基準**，不代表可成交價）：

1. **hardStop** — 收盤 < 參考價 × (1 − `ExitParams.hardStopPct` 8%)
2. **trendBreak** — 收盤 < MA60（regime 證據最強的趨勢線）
3. **timeStop** — 釘選後滿 `ExitParams.timeStopTradingDays` 40 個**交易日**
   （以該股價格列數計，非日曆差），且**從未**收高於參考價
   （語意 = 論點從未實現；rolling「連續 N 日未創 peak」版留 v2 由 gate 評估）

先觸發者定 `invalidatedReason`；參數起始值由 replay gate 結果最終定案。

**紀律語意（寫死）**：
- 一旦 INVALIDATED **不自動復活**——價格回升不翻回 ACTIVE。重新看多請
  重新釘選（新記錄、新參考價）。
- 同一 symbol 同時只允許一筆 ACTIVE。

## 3. Replay gate（tool/exit_validate.dart，實作前置）

- **樣本**：既有 replay 基礎設施的 mode 主訊號 firing 日。
- **進場模擬**：**訊號日次一交易日收盤**（盤後 app 買不到訊號日收盤——
  與 calibration look-ahead 修正同一原則）。
- **對照**：「條件出場（出場後 0 報酬）」vs「持有滿 60 交易日」同窗總報酬。
- **指標**：平均超額報酬差、勝率、最大回檔、平均持有天數。
- **報告切面**：**按 mode 分組**（Mode A 剛突破離 MA60 近，trendBreak 可能
  過敏，不可一刀切）+ **逐年拆**（穩定性，防全期挑參數過擬合——tilt 教訓）。
- **上線標準**：某條件出場版平均超額 ≥ 持有版，或最大回檔顯著改善且報酬
  不明顯犧牲。沒 edge 的條件不進 app；參數被打臉就修或砍。跑一次認帳。

## 4. 資料模型

新表 `pinned_thesis`（Drift）：

| 欄位 | 型別 | 說明 |
|---|---|---|
| id | int PK | autoIncrement |
| symbol | text FK stock_master | |
| pinnedDate | datetime | **快照資料日**（dataDate，非點擊時刻） |
| referencePrice | real | 釘選資料日收盤 |
| mode | text | 釘選當下路由 mode（momentum/strength/pullback） |
| triggeredRules | text JSON | 當日觸發規則碼快照 |
| scoreShort / scoreLong | real | 分數快照 |
| status | text | ACTIVE / INVALIDATED / ARCHIVED |
| invalidatedDate | datetime? | |
| invalidatedReason | text? | HARD_STOP / TREND_BREAK / TIME_STOP |
| createdAt / updatedAt | datetime | |

**不存 peak/增量狀態**：monitor 每次跑對每筆 ACTIVE 從 pinnedDate
**全量重算**三條件（釘選數 × ≤250 收盤，量極小）——冪等，App 跳幾天
不更新也不會錯。

## 5. 偵測服務（方案 A：更新管線整合）

- `ThesisInvalidationRules`（純函數）：輸入 (thesis, **含釘選日前 ≥60 根**
  的收盤序列)——trendBreak 對每個評估日需要該日往前 60 根算 MA60；
  逐日檢查、首個觸發日即失效日 → `InvalidationResult?`（reason + 觸發日）。
- `ThesisMonitorService`：每日更新完成後 fail-safe 執行（與
  `RuleAccuracyService` post-update 同模式；錯誤不中斷更新流程）。
  逐筆 ACTIVE 檢查 → 失效者更新 status/invalidatedDate/reason。
- 常數集中 `lib/core/constants/exit_params.dart`（`ExitParams`）。

被否決的替代方案：Provider 端即時計算（無歷史、警示頁無從顯示）、
併入 scoring isolate（使用者資料不進批次評分、耦合過重）。

## 6. UI

- **釘選入口**：今日頁推薦卡片 + 個股詳情 header 的 📌 按鈕
  （已有 ACTIVE 釘選 → 顯示已釘選狀態，不可重複）。
- **釘選追蹤區**：今日頁下方新 section——卡片顯示釘選日、參考價 vs
  現價、狀態徽章（ACTIVE 綠 / INVALIDATED 紅 + reason）。
- **警示頁**：新「論點失效」section，讀 `status = INVALIDATED` 的釘選
  （不動 PriceAlert 表——那是使用者自訂價格提醒，語意不同）。
- **封存**：失效卡片一鍵 ARCHIVED（保留紀錄、離開警示頁）。

## 7. 測試

全程 TDD：失效規則純函數單元測試（三條件邊界 + 交易日計數）、
ThesisMonitorService in-memory DB 測試（冪等、fail-safe、不復活）、
UI widget 測試（釘選鈕狀態、追蹤卡、警示 section）、exit_validate
比照 tool 測試慣例（synthetic 序列驗證出場模擬數學）。

## 8. 實作順序

1. `tool/exit_validate.dart` + gate 報告 → **Neal 核可條件與參數**
2. 表 + migration + `ExitParams`（gate 定案值）
3. `ThesisInvalidationRules` + `ThesisMonitorService`
4. UI（釘選鈕 → 追蹤區 → 警示 section）
5. 文件同步（CLAUDE.md 關鍵路徑 / update-pipeline.md）

## 9. 風險

- Gate 可能判「全部條件都沒 edge」——有效結論：只上「狀態追蹤不出訊號」
  的釘選功能（保留快照與紙上驗證價值），出場條件不上。
- Mode A 樣本若 trendBreak 過敏，per-mode 門檻提前到 v1.5 而非 v2。
