# CLAUDE.md

本檔案為 Claude Code 提供專案開發指引。

---

## 專案概述

**AfterClose** — 本地優先盤後台股掃描 App。所有運算在裝置端完成，無雲端依賴。

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'primaryColor': '#4F46E5', 'primaryTextColor': '#fff', 'primaryBorderColor': '#3730A3', 'lineColor': '#6366F1', 'fontSize': '14px'}}}%%
flowchart LR
    subgraph Input["每日輸入"]
        API["公開 API"]
        RSS["RSS 新聞"]
    end

    subgraph Process["本地處理"]
        Sync["資料同步"]
        Rules["59 條規則"]
        Score["評分引擎"]
    end

    subgraph Output["產出"]
        Top20["Top 20 推薦"]
        Alert["異常警示"]
    end

    API --> Sync
    RSS --> Sync
    Sync --> Rules --> Score --> Top20
    Score --> Alert

    style Input fill:#DBEAFE,stroke:#3B82F6
    style Process fill:#D1FAE5,stroke:#10B981
    style Output fill:#FEF3C7,stroke:#F59E0B
```

---

## 常用指令

```bash
flutter pub get                    # 安裝依賴
flutter test                       # 執行測試
flutter test --coverage            # 執行測試並生成覆蓋率報告
flutter analyze                    # 靜態分析
dart format .                      # 格式化程式碼（pre-commit hook 要求）
dart run build_runner build --delete-conflicting-outputs  # Drift 程式碼生成
```

---

## 架構

### 分層結構

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'primaryColor': '#4F46E5', 'primaryTextColor': '#fff', 'primaryBorderColor': '#3730A3', 'lineColor': '#6366F1', 'fontSize': '13px'}}}%%
flowchart TB
    subgraph Core["core/"]
        Constants["constants/ (13 files)"]
        Exceptions["exceptions/ — AppException hierarchy"]
        Utils["utils/ — Logger, Result, Calendar"]
    end

    subgraph Data["data/"]
        Database["database/ — Drift SQLite (35 tables)"]
        Remote["remote/ — TWSE, TPEX, FinMind, RSS"]
        Repos["repositories/ — 15 concrete repos"]
    end

    subgraph Domain["domain/"]
        Models["models/ (14 files)"]
        RepoIF["repositories/ — 3 interfaces"]
        Services["services/ — Analysis, Scoring, Screening"]
        Update["services/update/ — 7 Syncers"]
        Rules["services/rules/ — 59 Rules"]
    end

    subgraph Presentation["presentation/"]
        Providers["providers/ — Riverpod Notifiers"]
        Screens["screens/ — 14 Screens"]
    end

    Core --> Data
    Core --> Domain
    Data --> Domain
    Domain --> Presentation

    style Core fill:#FEF3C7,stroke:#F59E0B
    style Data fill:#DBEAFE,stroke:#3B82F6
    style Domain fill:#D1FAE5,stroke:#10B981
    style Presentation fill:#EDE9FE,stroke:#8B5CF6
```

### 資料流

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'primaryColor': '#4F46E5', 'primaryTextColor': '#fff', 'primaryBorderColor': '#3730A3', 'lineColor': '#6366F1', 'fontSize': '14px'}}}%%
flowchart LR
    API["External APIs"]
    Repo["Repository"]
    DB[("Drift DB")]
    Provider["Riverpod"]
    UI["UI"]

    API -->|fetch| Repo
    Repo -->|write| DB
    DB -->|read| Provider
    Provider -->|notify| UI

    style API fill:#F3F4F6,stroke:#9CA3AF
    style Repo fill:#DBEAFE,stroke:#3B82F6
    style DB fill:#DBEAFE,stroke:#3B82F6
    style Provider fill:#EDE9FE,stroke:#8B5CF6
    style UI fill:#EDE9FE,stroke:#8B5CF6
```

---

## 關鍵路徑

| 路徑                                         | 說明                       |
|:-------------------------------------------|:-------------------------|
| `lib/core/constants/rule_params.dart`      | 規則引擎參數 (200+ 閾值)         |
| `lib/core/constants/app_routes.dart`       | 路由常數 (集中管理)              |
| `lib/core/exceptions/app_exception.dart`   | 例外階層 (sealed class)      |
| `lib/core/utils/request_deduplicator.dart` | Request Deduplication 機制 |
| `lib/core/utils/circuit_breaker.dart`      | Circuit Breaker 熔斷器      |
| `lib/core/utils/error_handler.dart`        | 細化錯誤處理 wrapper          |
| `lib/core/utils/performance_monitor.dart`  | 效能監測系統（P50/P95/P99）      |
| `lib/core/utils/validators.dart`           | 輸入驗證（防 SQL injection）    |
| `lib/domain/repositories/`                 | 3 個抽象介面                  |
| `lib/domain/services/rules/`               | 59 條規則 (12 檔案)           |
| `lib/domain/services/scoring_isolate.dart` | Isolate 評分 (型別安全)        |
| `lib/domain/services/isolate_pool.dart`    | Isolate 池重用機制            |
| `lib/domain/services/ohlcv_data.dart`      | OHLCV 提取 extension       |
| `lib/data/database/tables/`                | 35 張資料表 (10 檔案)          |

---

## Repository 介面

| 介面                     | 職責               |
|:-----------------------|:-----------------|
| `IAnalysisRepository`  | 分析結果存取、推薦紀錄      |
| `IPriceRepository`     | 價格資料、漲跌幅批次查詢     |
| `IScreeningRepository` | 自訂篩選 SQL 執行、批次載入 |

---

## Update Services

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'primaryColor': '#4F46E5', 'primaryTextColor': '#fff', 'primaryBorderColor': '#3730A3', 'lineColor': '#6366F1', 'fontSize': '14px'}}}%%
graph LR
    US["UpdateService<br/>(Coordinator)"]

    US --> SLS["StockListSyncer"]
    US --> HPS["HistoricalPriceSyncer"]
    US --> IS["InstitutionalSyncer"]
    US --> MDU["MarketDataUpdater"]
    US --> FS["FundamentalSyncer"]
    US --> NS["NewsSyncer"]
    US --> MIS["MarketIndexSyncer"]

    style US fill:#4F46E5,stroke:#3730A3,color:#fff
    style SLS fill:#DBEAFE,stroke:#3B82F6
    style HPS fill:#DBEAFE,stroke:#3B82F6
    style IS fill:#DBEAFE,stroke:#3B82F6
    style MDU fill:#DBEAFE,stroke:#3B82F6
    style FS fill:#DBEAFE,stroke:#3B82F6
    style NS fill:#DBEAFE,stroke:#3B82F6
    style MIS fill:#DBEAFE,stroke:#3B82F6
```

---

## 開發工作流程

### Pre-commit Hooks

專案使用自訂 pre-commit hooks，提交前自動執行：

1. **格式檢查** - `dart format --set-exit-if-changed .`
2. **靜態分析** - `flutter analyze --no-fatal-infos`

若檢查失敗，需手動修復：
```bash
dart format .              # 修復格式問題
flutter analyze            # 檢查分析錯誤
```

### 資料庫變更流程

修改資料表後必須重新生成程式碼：

```bash
# 1. 修改 lib/data/database/tables/*.dart
# 2. 執行 code generation
dart run build_runner build --delete-conflicting-outputs
# 3. 執行測試確認無迴歸
flutter test
```

### 測試要求

- 所有變更必須通過完整測試套件（1054+ 測試）
- 測試執行時間約 9 秒
- Critical 功能變更需補充對應測試

---

## 編碼標準

| 原則                        | 說明                                                                             |
|:--------------------------|:-------------------------------------------------------------------------------|
| **Repository Pattern**    | Domain 透過介面存取資料，Data 層提供實作                                                     |
| **錯誤處理**                  | `RateLimitException` / `NetworkException` 必須 rethrow，其餘包裝為 `DatabaseException` |
| **Request Deduplication** | Repository 層使用 `RequestDeduplicator` 避免重複 API 呼叫                               |
| **Circuit Breaker**       | API Client 使用 `CircuitBreaker` 實現熔斷保護（5 次失敗後開啟，60 秒冷卻）                          |
| **狀態管理**                  | `AsyncNotifier` / `StateNotifier`，避免 `StateProvider`                           |
| **Rule Engine**           | 純函數：輸入 `AnalysisContext` → 輸出 `TriggeredReason`                                |
| **配置集中**                  | 所有閾值放 `lib/core/constants/`，禁止魔術數字                                             |
| **路由**                    | 使用 `AppRoutes` 常數，禁止硬編碼路由字串                                                    |
| **Isolate 通訊**            | 使用 typed class (`IsolateReasonOutput`)，避免 `Map<String, dynamic>`               |
| **Isolate 池**             | 使用 `IsolatePool` 重用 worker，避免重複啟動開銷                                            |
| **OHLCV 提取**              | 使用 `prices.extractOhlcv()` extension，避免重複迴圈                                    |
| **效能監測**                  | 使用 `PerformanceMonitor.measure()` 追蹤關鍵操作耗時                                     |
| **輸入驗證**                  | 使用 `InputValidators` 驗證股票代碼、日期範圍等，防止 SQL injection                            |
| **Dart 3**                | Records, Pattern Matching, Sealed Classes                                      |

---

## 效能優化記錄

### 2026-02-13 改進

| 項目       | 改進內容                                                                       | 預期效果           |
|:---------|:---------------------------------------------------------------------------|:---------------|
| **API 優化** | Request Deduplication + Circuit Breaker                                   | 減少 30-50% API 呼叫 |
| **資料庫優化** | 4 個關鍵索引（`daily_analysis`, `daily_institutional`, `insider_holding`, `trading_warning`） | 查詢速度提升 30%      |
| **並行處理**  | Isolate 池重用機制                                                              | 減少 20-30% 啟動開銷  |
| **錯誤處理**  | 細化錯誤處理 wrapper 區分不同錯誤類型                                                    | 提升穩定性和診斷能力     |
| **安全性**   | 輸入驗證機制（股票代碼、日期範圍）                                                          | 防止 SQL injection |
| **可觀測性**  | PerformanceMonitor 追蹤關鍵操作耗時                                                | 識別效能瓶頸         |
| **CI/CD** | Codecov 測試覆蓋率上傳                                                           | 追蹤品質趨勢         |

---

## 關鍵文件

| 文件                                                                                                     | 說明              |
|:-------------------------------------------------------------------------------------------------------|:----------------|
| [docs/RULE_ENGINE.md](docs/RULE_ENGINE.md)                                                             | 規則引擎詳解 (59 條規則) |
| [RELEASE.md](RELEASE.md)                                                                               | 發布建置指南          |
| [.agent/skills/flutter-riverpod-architect/SKILL.md](.agent/skills/flutter-riverpod-architect/SKILL.md) | 架構模式指南          |
