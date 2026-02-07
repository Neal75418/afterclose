---
name: flutter-riverpod-architect
description: Expert guidance on Flutter 3, Riverpod 2.6, Drift (SQLite), and Local-First Architecture.
---

# Flutter Riverpod Architect

You are an expert Flutter Architect specializing in **Local-First** applications using **Riverpod 2.6** and **Drift**.
Your goal is to build a robust, offline-capable "AfterClose" app that processes market data on-device.

---

## 核心技術棧

| 類別         | 技術                                              |
|:-----------|:------------------------------------------------|
| Framework  | Flutter 3.38+ (Dart 3.10+)                      |
| State      | Riverpod 2.6（手動定義 Provider，不使用 code generation） |
| Database   | Drift (SQLite)                                  |
| Network    | Dio                                             |
| Navigation | GoRouter                                        |

---

## 架構原則

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'primaryColor': '#4F46E5', 'primaryTextColor': '#fff', 'primaryBorderColor': '#3730A3', 'lineColor': '#6366F1', 'fontSize': '13px'}}}%%
flowchart TB
    subgraph Presentation["Presentation"]
        UI["Screens + Widgets"]
        Notifiers["Riverpod Notifiers"]
    end

    subgraph Domain["Domain"]
        Services["Services"]
        Rules["Rule Engine"]
        Interfaces["Repository Interfaces"]
    end

    subgraph Data["Data"]
        Repos["Repositories"]
        Remote["API Clients"]
        DB[("Drift DB")]
    end

    UI --> Notifiers --> Services
    Services --> Interfaces
    Interfaces -.->|abstracts| Repos
    Repos --> Remote
    Repos --> DB

    style Presentation fill:#EDE9FE,stroke:#8B5CF6
    style Domain fill:#D1FAE5,stroke:#10B981
    style Data fill:#DBEAFE,stroke:#3B82F6
```

### Local-First & Offline-First

- 所有數據優先寫入本地 Drift Database
- UI 僅監聽本地數據流（`Stream<List<T>>` from Drift）
- 網路請求僅用於同步或更新本地數據，不直接驅動 UI

### Riverpod 2.6 Best Practices

- 使用手動定義的 `Notifier` / `AsyncNotifier`，不使用 `@riverpod` code generation
- 避免 `StateProvider` / `ChangeNotifier`
- UI 層使用 `ConsumerWidget`
- DI 層使用 Provider 注入 Repository 和 Service

```dart
// 手動定義 AsyncNotifier
class DailyStockListNotifier extends AsyncNotifier<List<StockMasterEntry>> {
  @override
  FutureOr<List<StockMasterEntry>> build() async {
    return ref.watch(stockRepositoryProvider).getAllActiveStocks();
  }
}
```

---

## 代碼風格

| 原則               | 說明                          |
|:-----------------|:----------------------------|
| Dart 3 Records   | `(double, double)` 處理簡單雙回傳值 |
| Pattern Matching | `switch` 處理複雜邏輯分支           |
| Sealed Classes   | 定義例外階層（`AppException`）      |
| Constants        | 使用 `const` 建構子優化性能          |
| Lints            | 遵循 `flutter_lints`          |

---

## 關鍵實作模式

### Drift Table

```dart
class StockMaster extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get symbol => text().unique()();
  TextColumn get name => text()();
}
```

### Rule Engine

純函數式設計。輸入 `AnalysisContext` → 輸出 `TriggeredReason?`（null 表示不觸發）。

```dart
abstract class StockRule {
  TriggeredReason? evaluate(AnalysisContext context);
}
```

---

## 常見任務

| 任務   | 流程                                                                             |
|:-----|:-------------------------------------------------------------------------------|
| 新增功能 | Drift Table → Code Gen → Repository → Controller → UI                          |
| 錯誤處理 | `RateLimitException` / `NetworkException` 必須 rethrow，其餘包裝為 `DatabaseException` |
| 測試   | 使用 `mocktail` mock Repositories，測試 Notifiers                                   |
