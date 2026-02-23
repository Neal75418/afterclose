# 測試覆蓋率計劃

---

## 當前狀況

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'primaryColor': '#4F46E5', 'primaryTextColor': '#fff', 'primaryBorderColor': '#3730A3', 'pieOuterStrokeWidth': '2px', 'fontSize': '14px'}}}%%
pie showData title 測試進度（2460+ cases）
    "Domain 層" : 900
    "Data 層" : 600
    "Presentation 層" : 960
```

| 指標               | 數值    |
|:-----------------|:------|
| 測試總數             | 2460+ |
| 執行時間             | ~33 秒 |
| Domain 覆蓋率       | 85%+  |
| Data 覆蓋率         | 85%+  |
| Presentation 覆蓋率 | 70%+  |

---

## 完成進度

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'primaryColor': '#4F46E5', 'primaryTextColor': '#fff', 'primaryBorderColor': '#3730A3', 'lineColor': '#6366F1', 'fontSize': '14px'}}}%%
flowchart LR
    P1["Phase 1\nProvider 測試"]
    P2["Phase 2\nWidget 測試"]
    P3["Phase 3\n服務測試"]

    P1 -->|✅ 完成| P2
    P2 -->|✅ 完成| P3

    style P1 fill:#10B981,stroke:#065F46,color:#fff
    style P2 fill:#10B981,stroke:#065F46,color:#fff
    style P3 fill:#F59E0B,stroke:#92400E,color:#fff
```

---

## 待完成：Phase 3 — 大型服務測試

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'primaryColor': '#4F46E5', 'primaryTextColor': '#fff', 'primaryBorderColor': '#3730A3', 'lineColor': '#6366F1', 'fontSize': '14px'}}}%%
flowchart TB
    US["UpdateService\n整合測試"]
    AS["AnalysisService\n子服務測試"]
    Edge["邊界情況\n補充"]

    AS --> TD["TrendDetection"]
    AS --> RD["ReversalDetection"]
    AS --> CA["CandlestickAnalysis"]
    AS --> IC["IndicatorCalculation"]
    AS --> CO["Coordinator"]

    style US fill:#DBEAFE,stroke:#3B82F6
    style AS fill:#DBEAFE,stroke:#3B82F6
    style Edge fill:#DBEAFE,stroke:#3B82F6
    style TD fill:#F3F4F6,stroke:#9CA3AF
    style RD fill:#F3F4F6,stroke:#9CA3AF
    style CA fill:#F3F4F6,stroke:#9CA3AF
    style IC fill:#F3F4F6,stroke:#9CA3AF
    style CO fill:#F3F4F6,stroke:#9CA3AF
```

### UpdateService 整合測試

| 項目 | 說明                                              |
|:---|:------------------------------------------------|
| 檔案 | `test/domain/services/update_service_test.dart` |
| 範圍 | 同步流程協調、錯誤處理重試、進度追蹤、Rate Limit、Syncer 呼叫順序       |

### AnalysisService 子服務測試

| 項目 | 說明                                                |
|:---|:--------------------------------------------------|
| 檔案 | `test/domain/services/analysis_service_test.dart` |
| 範圍 | 趨勢檢測、反轉檢測、K 線型態、指標計算、邊界條件                         |
| 備註 | 已拆分為 5 個子服務，可分別測試                                 |

### 邊界情況補充

| 類別     | 測試項目                        |
|:-------|:----------------------------|
| 空列表    | 空自選股、空搜尋結果、無歷史資料            |
| Null 值 | 缺失價格 / 基本面 / 技術指標資料         |
| 極端數值   | 股價 >10000 或 <1、成交量 0 或極大值   |
| 時間     | 假日 / 停牌、開盤前後、資料延遲           |
| 網路     | API timeout、連線中斷、Rate Limit |

---

## 測試慣例

詳見 [CLAUDE.md](../CLAUDE.md) 的「Widget 測試慣例」章節。

---

*最後更新: 2026-02-22*
