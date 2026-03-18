# Market Dashboard Enhancements Design

> Date: 2026-03-18
> Status: Approved
> Goal: 提升散戶在盤後快速掌握市場全貌的效率

## Overview

為大盤總覽新增 4 個功能模組，按複雜度遞增排序實施：

| # | 功能 | 複雜度 | 新 Widget | 新 DAO 方法 |
|---|------|--------|-----------|------------|
| A | 歷史趨勢迷你圖 | 低 | 1 (MiniBarChart) | 2 新增 + 1 修改 |
| B | 市場情緒儀表板 | 中 | 1 (SentimentGauge) | 0 (復用 A 的資料) |
| C | 推薦績效看板 | 中 | 1 (PerformanceBoard) | 2 新增 |
| D | 籌碼異動摘要 | 高 | 1 (ChipAnomalyRow) | 新 Service + 多表查詢 |

---

## A. 歷史趨勢迷你圖

### 目的

將現有「今日快照」widget 升級為「今日 + 30 日趨勢」，讓使用者從單點數據看到動態走勢。

### 資料層變更

#### DAO 新增/修改 (`market_overview_dao.dart`)

1. **新增** `getRecentMarginTradingByMarket(DateTime date, {int days = 30})`
   - 回傳 `Map<String, List<({DateTime date, double marginBalance, double shortBalance})>>`
   - Query: 對 `margin_trading` JOIN `stock_master` 依 market 分組，取最近 N 個交易日的 SUM
   - 排序: date DESC

2. **新增** `getRecentAdvanceDeclineByMarket(DateTime date, {int days = 30})`
   - 回傳 `Map<String, List<({DateTime date, int advance, int decline, int unchanged})>>`
   - Query: 對 `daily_price` JOIN `stock_master` 依 market 分組，COUNT(CASE WHEN ...) 分類
   - 排序: date DESC

3. **修改** `getRecentTurnoverByMarket(date, {int days = 5})` → 預設值改為 `days = 30`
   - 現有呼叫點 (`_loadTurnoverComparisonByMarket`) 明確傳 `days: 5` 不受影響

#### State 新增欄位 (`MarketOverviewState`)

```dart
// 30日歷史趨勢資料（Key: 'TWSE' / 'TPEx'）
Map<String, List<({DateTime date, double foreignNet, double trustNet, double dealerNet})>> institutionalHistoryByMarket;
Map<String, List<({DateTime date, double marginBalance, double shortBalance})>> marginHistoryByMarket;
Map<String, List<({DateTime date, double turnover})>> turnoverHistoryByMarket;
Map<String, List<({DateTime date, int advance, int decline, int unchanged})>> advanceDeclineHistoryByMarket;
```

#### Provider 新增載入方法

- `_loadInstitutionalHistoryByMarket()` — 直接暴露已有的 streak 計算用資料
- `_loadMarginHistoryByMarket()` — 呼叫新 DAO
- `_loadTurnoverHistoryByMarket()` — 呼叫 `getRecentTurnoverByMarket(date, days: 30)`
- `_loadAdvanceDeclineHistoryByMarket()` — 呼叫新 DAO

4 個均與現有 12 個 Future 並行執行。

### UI 層變更

#### 新元件: `MiniBarChart`

位置: `lib/presentation/screens/stock_detail/widgets/mini_bar_chart.dart`
（與 `MiniTrendChart` 同層）

```dart
class MiniBarChart extends StatelessWidget {
  const MiniBarChart({
    required this.dataPoints,    // List<double>，正值=上方柱、負值=下方柱
    this.height = 40,
    this.positiveColor,          // 預設 AppTheme.upColor
    this.negativeColor,          // 預設 AppTheme.downColor
    this.barWidth = 3.0,
    this.barSpacing = 1.5,
  });
}
```

使用 `CustomPainter` 繪製，零線在中間，柱體向上/向下延伸。

#### Widget 修改

| Widget | 新增內容 | 圖表類型 | 資料 |
|--------|---------|---------|------|
| `institutional_flow_chart.dart` | 卡片底部加 40px MiniBarChart | Bar chart | 30日 totalNet |
| `trading_turnover_row.dart` | 下方加 40px MiniBarChart | Bar chart | 30日成交量（全正值，高於均量=強調色） |
| `margin_compact_row.dart` | 融資/融券各加 40px MiniTrendChart | Sparkline | 30日餘額趨勢 |
| `advance_decline_gauge.dart` | gauge 下方加 40px MiniTrendChart | Sparkline | 30日漲跌比 (advance/total) |

---

## B. 市場情緒儀表板

### 目的

綜合多項市場指標為單一「市場溫度計」分數 (0-100)，一眼判斷多空氛圍。

### 計分模型

#### 子指標（6 項）

| 指標 | 權重 | 資料來源 | 正規化方式 |
|------|------|---------|-----------|
| 漲跌比 | 25% | `advanceDeclineHistoryByMarket` | 線性: 0.2→0, 0.5→50, 0.8→100 |
| 法人動向 | 25% | `institutionalHistoryByMarket` | 近10日淨額 Z-score → 0-100 |
| 成交量動能 | 15% | `turnoverHistoryByMarket` | 量比: 0.5→0, 1.0→50, 2.0→100 |
| 融資變化 | 15% | `marginHistoryByMarket` | 近5日融資變動方向+幅度 |
| 漲停跌停比 | 10% | `limitUpDownByMarket` | limitUp/(limitUp+limitDown) 線性 |
| 產業廣度 | 10% | `industrySummaryByMarket` | 上漲產業數/總產業數 × 100 |

#### 分數區間

| 分數 | 等級 | 顏色 |
|------|------|------|
| 0-20 | 極度恐懼 | `Color(0xFF1B5E20)` (深綠) |
| 20-40 | 恐懼 | `AppTheme.downColor` |
| 40-60 | 中性 | `AppTheme.neutralColor` |
| 60-80 | 貪婪 | `AppTheme.upColor` |
| 80-100 | 極度貪婪 | `Color(0xFFB71C1C)` (深紅) |

### Service 層

新增 `MarketSentimentService`：

```dart
class MarketSentimentService {
  /// 計算市場情緒分數
  MarketSentiment calculate({
    required AdvanceDecline advanceDecline,
    required List<({DateTime date, double foreignNet, double trustNet, double dealerNet})> institutionalHistory,
    required List<({DateTime date, double turnover})> turnoverHistory,
    required List<({DateTime date, double marginBalance, double shortBalance})> marginHistory,
    required LimitUpDown limitUpDown,
    required List<IndustrySummary> industries,
  });
}

class MarketSentiment {
  final double score;           // 0-100
  final String level;           // 極度恐懼 ~ 極度貪婪
  final Map<String, double> subScores;  // 各子指標分數
}
```

### UI 設計

新元件: `SentimentGaugeSection`

位置: `lib/presentation/widgets/market_dashboard/sentiment_gauge_section.dart`

佈局:
1. 大數字 (`headlineLarge`) + 等級標籤（帶顏色）
2. 水平漸層 bar (綠→灰→紅)，三角形指標標示位置
3. 6 個子指標 mini badge (2×3 grid)，名稱 + 分數

高度: ~160-180px

放置位置: Hero 指數與分類指數列之間，desktop 模式跨雙欄（全市場指標）。

---

## C. 推薦績效看板

### 目的

展示 rule engine 的歷史績效，建立使用者對推薦系統的信任。

### DAO 新增 (`recommendation_dao.dart` 或新建)

1. `getRecentValidations({int days = 30})`
   - 回傳 `List<RecommendationValidationEntry>` (含 symbol, date, return_rate, success)
   - 排序: validation_date DESC

2. `getTopRulesByWinRate({int limit = 3, int minTriggers = 5})`
   - 回傳 `List<RuleAccuracyEntry>` (rule_id, trigger_count, success_count, avg_return)
   - 篩選: trigger_count >= minTriggers
   - 排序: (success_count / trigger_count) DESC

### State 新增

```dart
class RecommendationPerformance {
  final List<bool> recentResults;     // 近30筆勝負序列
  final double winRate;               // 勝率 %
  final double avgReturn;             // 平均報酬 %
  final int totalCount;               // 推薦總筆數
  final List<TopRule> topRules;       // 勝率最高的 3 條規則
}

class TopRule {
  final String ruleId;
  final String displayName;           // 從 i18n 翻譯
  final double winRate;
  final double avgReturn;
}
```

### UI 設計

新元件: `RecommendationPerformanceRow`

位置: `lib/presentation/widgets/market_dashboard/recommendation_performance_row.dart`

佈局:
1. **勝負走勢 dot strip**: 30 個小圓點排列，紅=獲利、綠=虧損
2. **統計摘要列**: 勝率 / 平均報酬 / 總筆數（3 個 stat badge）
3. **最強規則 top 3**: 規則名 + 勝率 + 報酬率

高度: ~120-140px

放置位置: dashboard 最底部（市場數據之後，因為是 app 自身績效）

### 空狀態

驗證資料不足（< 5 筆）時，顯示「推薦績效累積中，需至少 5 筆驗證資料」。

---

## D. 籌碼異動摘要

### 目的

彙整當日市場中的重大籌碼異動事件，提供「今天該特別注意什麼」的風險訊號。

### 異動偵測規則

| 類型 | 資料來源 | 門檻條件 | 嚴重度 |
|------|---------|---------|--------|
| 質押率飆升 | `insider_holding` | 質押率 > 50% **或** 月增 > 10 百分點 | 高 (🔴) |
| 內部人轉讓 | `insider_transfer` | 當月有申報轉讓記錄 | 中 (🟡) |
| 外資逼近上限 | `shareholding` | 外資持股比 > 外資上限 × 90% | 中 (🟡) |
| 融券暴增 | `margin_trading` | 當日融券增 > 近5日均量 × 3 | 中 (🟡) |
| 法人集中大買/賣 | `daily_institutional` | 單日淨額 > 30日均量 ± 3σ | 高 (🔴) |

### Service 層

新增 `ChipAnomalyService`:

```dart
class ChipAnomalyService {
  /// 偵測當日籌碼異動
  Future<List<ChipAnomaly>> detectAnomalies(DateTime date);
}

class ChipAnomaly {
  final ChipAnomalyType type;      // enum: highPledge, insiderTransfer, foreignNearLimit, shortSurge, institutionalSurge
  final ChipSeverity severity;     // enum: high, medium
  final String symbol;
  final String stockName;
  final String description;        // 人類可讀描述
  final Map<String, dynamic> data; // 原始數據（質押率、張數等）
}
```

**快取策略**: 同一日只計算一次，結果存入 `MarketOverviewState`。

### State 新增

```dart
Map<String, List<ChipAnomaly>> chipAnomaliesByMarket;  // Key: 'TWSE' / 'TPEx'
```

### UI 設計

新元件: `ChipAnomalyRow`

位置: `lib/presentation/widgets/market_dashboard/chip_anomaly_row.dart`

佈局:
1. **標題列**: 「今日籌碼異動」+ 筆數 badge
2. **異動列表**: 每筆一行 — 嚴重度圖示 + 類型 tag + 股名(代碼) + 關鍵數字
3. **空狀態**: 「今日無重大籌碼異動 ✓」

高度: 動態（每筆約 48px，最多顯示 5 筆 + 「查看更多」）

放置位置: `warnings_summary_row` 下方（同為風險警訊性質）

---

## Dashboard 最終佈局順序

### Mobile (Tab: 上市 / 上櫃)

```
1. Hero 指數 (TAIEX 或 TPEX)
2. ★ 市場情緒儀表板 (B) — 新增
3. 分類指數列
4. 漲跌家數 gauge + ★ 趨勢線 (A)
5. 三大法人買賣超 + ★ 趨勢柱 (A)
6. 融資融券 + ★ 趨勢線 (A)
7. 成交量 + ★ 趨勢柱 (A)
8. 注意/處置股
9. ★ 籌碼異動摘要 (D) — 新增
10. 產業表現
11. ★ 推薦績效看板 (C) — 新增
```

### Desktop (並排: 上市 | 上櫃)

```
跨欄:
  ★ 市場情緒儀表板 (B)

左欄 (上市)          |  右欄 (上櫃)
1. Hero TAIEX        |  1. Hero TPEX
2. 分類指數列         |  2. (無)
3. 漲跌家數+趨勢     |  3. 漲跌家數+趨勢
4. 法人+趨勢         |  4. 法人+趨勢
5. 融資融券+趨勢     |  5. 融資融券+趨勢
6. 成交量+趨勢       |  6. 成交量+趨勢
7. 注意/處置股       |  7. 注意/處置股
8. 籌碼異動(D)       |  8. 籌碼異動(D)
9. 產業表現          |  9. 產業表現

跨欄:
  ★ 推薦績效看板 (C)
```

---

## 實施順序

### Phase 1: 歷史趨勢迷你圖 (A)
- DAO: 2 新方法 + 1 修改
- State: 4 新欄位
- Provider: 4 新載入方法
- Widget: 1 新元件 (MiniBarChart) + 4 現有 widget 修改
- 測試: DAO 單元測試 + widget golden test

### Phase 2: 市場情緒儀表板 (B)
- Service: MarketSentimentService (純計算，好測試)
- Widget: SentimentGaugeSection
- 測試: Service 單元測試（各種極端情境）+ widget 測試

### Phase 3: 推薦績效看板 (C)
- DAO: 2 新方法
- State: RecommendationPerformance
- Widget: RecommendationPerformanceRow
- 測試: DAO 測試 + widget 測試

### Phase 4: 籌碼異動摘要 (D)
- Service: ChipAnomalyService (最複雜，多表查詢)
- Widget: ChipAnomalyRow
- 測試: Service 測試（各異動類型 + 邊界值）+ widget 測試

---

## 風險與注意事項

1. **效能**: 新增 4 個並行 Future 到 provider，總共 16 個。需確認 SQLite 連線不會成為瓶頸。
2. **成交量 DAO**: `getRecentTurnoverByMarket` 從 5 天擴到 30 天，因為用 `SUM(close × volume)` 計算，30 天可能稍慢。如有效能問題可考慮 pre-computed 欄位。
3. **情緒分數校準**: 初始權重是啟發式的，上線後需觀察是否合理，可能需要微調。
4. **推薦績效**: 需要累積足夠驗證資料（至少 5 筆）才有意義，新用戶會看到空狀態。
5. **籌碼異動**: 門檻值需要在真實資料上測試，避免太多 false positive 造成使用者疲勞。
