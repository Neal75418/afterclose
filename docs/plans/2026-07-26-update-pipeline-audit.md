# 更新流程稽核（2026-07-26）

以股票分析師視角審查整條盤後更新流程，找出會誤導決策的設計缺陷。
本文記錄**每一項的狀態、證據與決定**，未處理的項目一併列出，避免只留下
「修了幾個」而看不出還欠什麼。

## 實測基準

所有門檻選擇與影響評估都以正式 DB 的唯讀快照為準（`.backup` 出來後以
`immutable=1` 開啟，不寫入正式庫）。快照時點 2026-07-26。

| 事實 | 值 |
|:---|:---|
| `daily_price` 單日筆數（近 12 個交易日） | 2,113–2,129 |
| 2026-07-24 拆市場 | TWSE 1,225 / TPEx 904 |
| `daily_analysis` 單日列數 | 142–254 |
| `daily_institutional` 深度 | 17 個交易日（2026-07-01 ~ 07-24） |
| `daily_reason` | 4,352 列 / 60 種 reason_type / 8 天 |
| `update_run` status 分布 | SUCCESS 54 / PARTIAL 2 |
| `insider_holding` | 1,965 檔、**單一快照日** 2026-07-15 |

---

## 已修

### P1-6 法人連續買賣超天數被截斷 — `c5b6e7e` / `94b7977`

**證據**：`streakDays` 分布 4:82 / 5:58 / 6:49 / 7:41 / 8:39 / 9:17、**10 以上 0 筆**。
從 7/24 往回 10 個日曆日恰含 9 個交易日 —— 觀測到的最大值與窗大小完全吻合，
是硬牆而非自然分布。

**修法**：

1. 取數窗改用 `institutionalStreakLookbackDays`（90，與市場總覽徽章同源）。
   顯示用的 `institutionalLookbackDays` 維持 10。
2. streak 吃滿整個窗時以 `streakTruncated` 揭露，描述改為「N 日以上」。
   摘要層與兩個 locale 同步，避免規則說「9 日以上」而摘要說「9 天」。
3. 「當日無法人進出」的缺列補零。交易所對無進出的股票**不發列**（三法人
   全零的列 0 筆），每個交易日約 100–168 檔有價格列卻無法人列，而規則迴圈
   只走陣列不比對日期，會把不相鄰的兩天接成「連續」。

**影響實測**：45 檔觸發者觸發結果零變動，8 檔天數被修正（2357/2884/6414
由 9 日 → 17 日）。補零對兩個規則家族亦皆為 0 變動，且已驗證非「機制未生效」
的假零 —— 補零實際改動 251 檔的 `prevAvg`，只是全部落在 ±10 萬股判定門檻內。

**選在資料層補零而非在規則迴圈加日期檢查**：迴圈內無法區分「中間的缺口」
（該斷）與「窗的邊界」（該標 truncated），要區分就得把交易日曆塞進純函數
規則，而台股有臨時休市，日曆猜錯會把跨越該日的 streak 全部誤斷。

### P1-8 昨日 K 棒掛今日日期 — `c359d07` / `b2275af`

**證據**：`classifyCandidate` 只驗 null/empty、歷史長度、流動性，**從不比對
`prices.last.date` 與評分日**。而價格窗以 `endDate = 評分日` 收斂，DB 缺當日
bar 時 `prices.last` 自動退化成前一交易日。

**判準刻意不用 `rateLimitedAbort` 旗標**，三條理由皆實讀確認：

- 「兩市場皆空」是**正常回傳、不拋例外**，`dataDate` 為 null 使既有日期回滾
  條件不成立，旗標保持 false
- `NetworkException` 與 `RateLimitException` 同樣 rethrow，前者落進通用 catch，
  旗標同樣 false 但災情相同
- 旗標的十餘個設定點資料完整度天差地遠，晚期翻旗時價格其實完整

**修法**：

1. 資格檢查加入 `asOf`，最後一根 bar 不是評分日即回 `staleBar` 並計數
2. `marketUptrendOrNull` 加 `asOf`，只計入當日 bar 的股票（半市場日唯一
   真正被污染的橫斷面計算）
3. 今日頁三 mode 的日期錨由價格 MAX 改為 `findLatestAnalysisDate()`

**影響實測**：8 個交易日、1,568 列 `daily_analysis`，「當日無有效價格 bar」的
有 **0 列** —— 健康日為 no-op，零誤殺，只在故障路徑生效。

### P1-5 董監增持幅度單位混用 — `b538c41`

`buyingChange` 的單位是**百分點**（`insiderRatio` 的期間差），但
`buildInsiderMap` 曾以 `?? v.sharesChange` 回退，而 `sharesChange` 的單位是
**股**。回退一旦生效，「增持 5 萬股」會被當成「增持 50000 個百分點」，
輕鬆越過 5.0 門檻並顯示「董監增持 50000.0%」。

目前摸不到（閘門在快照少於 2 筆時恆為 false，且 `shares_change` 1,965 筆全為
NULL），正因為它「看起來像保險絲、實際雙重無效」才更該移除。

### 冷啟動自動更新以失敗的嘗試當新鮮度基準 — `ccc630d`

`data_freshness` 的 docstring 寫「距上次**成功** update_run」，但
`getLatestUpdateRun()` 不過濾 status —— 一次 PARTIAL / FAILED 會冒充「剛更新
過」把重試擋滿 6 小時。**更新失敗反而讓 app 更不會重試，方向是反的。**

修法把混在一起的兩件事拆開：資料新鮮度看**上次成功**（6h）、API 節流看
**上次嘗試**（60min），兩者皆成立才觸發。

### P1-10 營收快取判斷跨市場 — `19122f4`

全市場營收同步抓的是 `getAllMonthlyRevenue()`（**只有上市**），但快取判斷
數的是**全市場**筆數；上櫃營收由另一條流程寫入，會被算進這個判斷。

實測 2026/06：全市場 1,316 筆 = 上市 1,067 + 上櫃 249，門檻 1,000。
「上市抓齊了沒」有四分之一的判斷依據來自上櫃，而上市自身只有 6.7% 餘裕。
若某次同步只落地 940 筆上市，加上上櫃 249 = 1,189 仍過門檻 → 判定已快取
而跳過，該月上市永久少 12%。

目前無症狀（上市非 ETF 涵蓋率 1,065 / 1,084 = 98.2%），屬結構性脆弱。

### P1-9 命中率顯示相對隨機基準的 lift — `c0c43a2`

---

## 明確決定不修

### 半市場日的「全有全無」閘門

曾評估「全市場列數 < 1500 就整天不出榜」。**否決**，三條理由：

- 半市場產出的是「清單不完整」而非「排名被扭曲」：`getModeStockScores`
  無 LIMIT 無 top-N，每檔的 mode 分數是它自己規則分數的 SUM，與其他股票
  無關；配合 staleBar 檢查，每一列都由該股當日 bar 算出，個別訊號皆正確
- 該狀況已有通報管道：`emptyMarkets` 警告會在半市場日觸發，輸出
  「TPEx 當日價格為零筆，評分資料不完整」。再加整天不出榜是替使用者做決定
- 門檻須綁定當下市場規模（2,129 檔）。規模漂移後會開始靜默丟棄健康日的
  資料，是難以察覺的迴歸

改為只修 regime 的橫斷面污染 + UI 日期錨（見上）。

### 董監規則現階段不觸發

兩條董監規則（`INSIDER_SELLING_STREAK`、`INSIDER_SIGNIFICANT_BUYING`）在
`daily_reason` 4,352 列中**零觸發**。但根因不是 bug：董監持股是**每月**申報，
PK 為 `(symbol, date)` + `insertOrReplace`，快照本來就會累積，只是收集還不到
一個月。`insiderSellingStreakMonths = 3`，約需累積至 2026-09-15。

要提前啟用得做歷史回補，屬獨立工作。

### 上櫃資料涵蓋率

| 資料 | TWSE | TPEx |
|:---|---:|---:|
| 當沖 | 1,129 / 1,225 | **0 / 904** |
| 估值 | 1,080 / 1,225 | 249 / 904 |
| 月營收 | 1,065 / 1,225 | 249 / 904 |
| 外資持股（全市場僅 147 檔） | 59 | 88 |

- **TPEx 當沖結構性缺席**：`dayTrading` 在 remote client 只出現於
  `twse_client.dart`，從未實作 TPEx 端點。原註解宣稱「已由批次 TPEX API
  同步」與程式碼不符，已更正。後果：`dayTradingHigh` 已校準歸零故無影響，
  但 `dayTradingExtreme = -5` 仍有效，904 檔上櫃股結構性吃不到該扣分
  （TWSE 側 2026-06-05~07-24 觸發 39 次 / 18 檔，頻率低但方向系統性）。
  已在 `RuleScores.dayTradingExtreme` 記錄此不對稱。
- **基本面與外資持股涵蓋率**受 FinMind 配額綁定（`maxSyncCount = 20`，
  每次更新只補 20 檔上櫃），是設計取捨而非缺陷，但代價是外資持股規則實際
  只作用在不到 10% 的市場。

三者皆非改 code 能解決，需要新資料源或配額。

### 三項 UI 文案取捨

停牌股在自選頁的呈現、「連昨日也沒有」時今日頁的空狀態文案（現為
「目前沒有符合條件的股票」，但事實可能是「沒算」）、背景路徑要不要為限流
配長 backoff。皆無正確性問題，建議實際遇到再依真實情境決定。

---

## 原始 Finding 全集

13-agent 稽核的 **46 項原始輸出**（含 evidence / analystImpact /
recommendation / effort 逐字保留）存於
[2026-07-26-pipeline-review-findings.md](2026-07-26-pipeline-review-findings.md)。

處理狀態：✅ 已修 13 / 📋 已記錄未修 7 / ⚠️ 曾修後撤回 1 / ❓ 未查證 25。

本檔是**摘要與決策紀錄**，全集檔是**待辦與證據來源**。要接續工作請從全集
檔挑項目，並注意其中「未查證」者連真偽都尚未確認。

## 尚未查證

- **營收快取無「補報」機制**：`existingCount > threshold` 一旦成立，該月
  就不再重新同步。台股月營收於次月 10 日前公告，晚報或更正的公司不會被
  補進來。實測涵蓋率 98.2%（缺 19 檔，部分為新上市等正常情形），**尚未
  觀察到實際危害**，故只記錄不修 —— 要修需改為與「應報家數」比例判斷，
  屬推測性設計。
- **25 項未查證 finding**：見全集檔。原以為清單已隨 context 壓縮遺失、需
  重跑稽核，實際上 workflow journal 完整落檔，46 項全數復原——**未查證前
  就宣告「找不回來」本身也是一次未經查證的結論**。

---

## 規則命中率顯示（同日追加調查）

### 為什麼 `daily_reason` 只有 8 天

不是 app 還年輕。`daily_price` 回溯至 2025-06-10（275 個交易日），但
`daily_reason` 與 `daily_analysis` 都**恰好**始於 2026-07-15 —— 與 live DB
指紋字串 `stage5b-news-mention-daily-2026-07-15` 同一天。

該次 fingerprint bump 清掉了它們。價格活下來是因為 `HistoricalPriceSyncer`
會從 API 回補；**`daily_reason` / `daily_analysis` 沒有任何回補機制**
（`analysis_dao` 只有 per-date 的 `clearReasonsForDate`，`update/` 下無回補
路徑），只能往前累積，清掉即永久損失。

**影響**：`rule_accuracy` 的唯一資料來源只有 8 天；5D 前瞻只有最早三天的
觸發有結果。任何以此為基礎的統計都不可信。

### 已修：信心度判準改看「觸發日數」— `f8de299`

`CalibrationThresholds.minDistinctDates` 的 docstring 早已寫明「pooled n 因
同日橫斷面相關 + 持有窗重疊是偽重複，有效樣本量級是觸發日數」，但該認知
只落實在 calibration 決策層的 clustered t-stat，顯示層仍以 pooled
`triggerCount` 判斷。實測 `CONCENTRATION_HIGH` 的 761 筆觸發全部來自
**8 個交易日**，遠超門檻 30 → 以「完全有信心」的樣子顯示。

摘要改為一律標示「樣本 N 筆 / D 個觸發日」，信心度註記改看日數。

### 已修：加欄不得 bump fingerprint — `1eebd34`

`f8de299` 為了新增欄位而 bump `appSchemaFingerprint`。該機制 drop 全部
**非 whitelist** 表重建，而 `daily_price` 不在 whitelist。實測 live DB 儲存
的指紋仍是舊值 → wipe 已 armed，只差下次啟動。後果不只價格（275 天、
565,570 列、Phase 0 回補約需 19 次每日更新），還包括**無法回補**的
`daily_reason`。

改走 `_ensureDealerSelfNetColumn` 式的 idempotent `PRAGMA table_info` +
`ALTER TABLE ADD COLUMN`，並加守門測試。

### 已修：移除無法佐證的隨機基準 — `ca18a90`

同日稍早的 P1-9（`c0c43a2`）讓摘要顯示「命中率 X%（隨機基準 35%，Ypp）」。
實測後發現比較的兩端來自完全不同的市場環境：

| | 值 |
|:---|---:|
| 寫死基準（另一 dev DB、全期） | 34.61% |
| 本機全期實測 | 29.23% |
| **實際量測窗（07-15~17）實測** | **19.04%** |
| 逐日基準全期範圍 / 標準差 | 5.79%~66.20% / 13.06pp |

量測窗之後緊接 2026-07-17 全市場單日 −3.95%。後果是方向性的：以靜態基準
計，14 條有樣本的規則中 13 條顯示為負；以同窗基準計 11 條為正 ——
**10 條正負號翻轉**。顯示方向相反的比較比不顯示更糟，故移除。

`successProbabilityBaselines` / `defaultBaselineProbability` **未刪**：
`tool/recalibrate.dart` 的 absolute 路徑仍以它們為 H0。

### 未動：超額口徑與資產管線（有證據的待辦）

正解已存在於離線工具，只是沒接到 app：

- `tool/calibration.db`（1.6 GB）：`daily_price` 1,468 天（2017-05-11 起）、
  `daily_institutional` 1,463 天、`day_trading` 1,531,334 列 / 1,218 檔 /
  1,531 天
- 已隨 app 出貨的 `assets/rule_scores_calibrated_short.json` 每條規則帶
  `hit_rate` / `avg_return` / `samples` / `t_stat`，頂層 `backtest` 帶
  `return_mode: excess`、`baseline_hit_rate: 0.4235`、
  `stats_method: date_clustered_t_v1`
- 出自 2026-07-13 的完整 run：2,583 檔、**2,937,329 firings**、44 條規則、
  12m59s，log 的 `Universe baseline hit: 5D=0.4235` 與資產內數值吻合
- Look-ahead 防護齊全（規則輸入 `prices.sublist(0, i+1)`、entry 用隔日
  open、營收與財報依**公布日**過濾）
- app 目前只解析其中的 `score` 欄位，其餘全部丟棄

**但涵蓋率有缺口**，且缺的正是籌碼與基本面：

| 規則群 | 條數 | 狀態 |
|:---|---:|:---|
| 技術面 + 法人連續 | 41 | 有深度統計 |
| 當沖 | 2 | 資料在（1,531 天），缺接線 |
| 籌碼 / 警示 / 董監 | 10 | calibration.db 無資料 |
| 基本面 + 新聞 | 9 | 同上 |

兩個根因：

1. **`tool/replay_calibrator.dart` 建 context 時 `marketData: null`**，
   註解寫「4 condition-day-only rules 不會 fire」，**實際是 12 條**
   （`concentrationHigh`、`dayTradingHigh/Extreme`、
   `foreignShareholding*`、`foreignExodus`、`foreignConcentrationWarning`、
   `highPledgeRatio`、`insiderSellingStreak`、`insiderSignificantBuying`、
   `tradingWarning*`）—— 註解低報 3 倍。
2. **`calibration.db` 的對應資料未回補**：`shareholding` / `trading_warning` /
   `insider_holding` / `holding_distribution` 皆 **0 列**；
   `stock_valuation` 1,452 列但只有 **3 檔**、`financial_data` 343 列 /
   **3 檔**、`news_item` **0 筆**。

也就是說：即使修好 (1) 的接線，12 條裡也只有當沖那 2 條真的有資料。其餘
須先做資料回補（API 配額專案）。

**建議順序**：待 `daily_reason` 累積至 ≥ `minDistinctDates`（30）個觸發日後，
再評估是否把資產統計接進顯示層；接之前須先決定 41 條有深度統計、19 條只有
淺資料時，同一畫面如何呈現兩種可信度（目前的「樣本 N 筆 / D 個觸發日」
揭露已可承擔此角色）。

---

## 方法論註記

本輪所有修復均遵循：

1. **先驗證再動手**。稽核產出的 finding 誤報率不低，每一項都以 grep / DB
   查詢親自查證後才採信。本輪至少三次推翻了 finding 的關鍵前提
   （`scoringMinPriceRows = 500` 會放行半市場、「PARTIAL 是常態」與實測
   54:2 相反、Phase 0 會補今日 bar 與 syncer 迴圈起點不符）。
2. **每個測試做 mutation 驗證**：改壞被測的那一行，測試必須變紅。本輪抓到
   三個假測試——`getModeStockScores` 用 `any()` 一律回同一份資料使日期錨
   測試恆綠、主執行緒 `asOf` 接線無人守、冷啟動 gate 首版測試在週末因
   `isTradingDay(DateTime.now())` 早退而恆為假紅。
3. **量測本身也要反測**。得到「影響為 0」時，先確認不是機制沒生效造成的
   假零（例：補零實際改動 251 檔 `prevAvg`，證明機制有動、結果才可信）。
4. **改 schema 前先算 wipe 的代價**。`appSchemaFingerprint` bump 會 drop 全部
   非 whitelist 表；`daily_price` 不在 whitelist，而 `daily_reason` 連回補
   路徑都沒有。純附加欄位一律走 `_ensureDealerSelfNetColumn` 式的 idempotent
   `ALTER TABLE ADD COLUMN`。本輪曾為一個欄位 armed 一次全量 wipe。
5. **顯示一個方向相反的比較，比不顯示更糟**。基準與量測必須來自同一市場
   環境；做不到就不要宣稱基準，只給裸數字加樣本標示。
6. **先查專案既有做法再設計**。本輪三次提案被既有實作取代（matched baseline
   → 超額模式已存在；自訂最小 universe → `kMinSymbolsForCompleteTradingDay`
   已存在；自訂日數門檻 → `minDistinctDates` 已存在）。註解與常數 docstring
   往往已寫著正解。
