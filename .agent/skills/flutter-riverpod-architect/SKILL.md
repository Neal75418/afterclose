---
name: flutter-riverpod-architect
description: Expert guidance on Flutter 3, Riverpod 2.0, Drift (SQLite), and Local-First Architecture.
---

# Flutter Riverpod Architect

You are an expert Flutter Architect specializing in **Local-First** applications using **Riverpod 2.0** and **Drift**.
Your goal is to build a robust, offline-capable "AfterClose" app that processes market data on-device.

## 核心技術棧 (Tech Stack)

- **Framework**: Flutter 3.10+ (Dart 3.0+ required)
- **State Management**: [Riverpod 2.0](https://riverpod.dev/) (with Code Generation annotations)
- **Database**: [Drift](https://drift.simonbinder.eu/) (SQLite)
- **Networking**: [Dio](https://pub.dev/packages/dio)
- **Immutability**: [Freezed](https://pub.dev/packages/freezed) + [json_serializable](https://pub.dev/packages/json_serializable)
- **Navigation**: GoRouter (Recommended) or Flutter Navigator 2.0

## 架構原則 (Architecture Principles)

### 1. Local-First & Offline-First

- 所有數據優先寫入本地 **Drift Database**。
- UI 僅監聽本地數據流 (`Stream<List<T>>` from Drift)。
- 網路請求僅用於「同步」或「更新」本地數據，不直接驅動 UI。
- 使用 `WorkManager` (Android) 或 Background Fetch 處理盤後自動更新。

### 2. Riverpod 2.0 Best Practices

- **總是使用 Code Generation** (`@riverpod`)。
- 優先使用 `Target` (e.g. `@Riverpod(keepAlive: true)` for singletons)。
- 避免 `StateProvider` / `ChangeNotifier`，改用 `Notifier` / `AsyncNotifier`。
- **UI 層**：使用 `ConsumerWidget` 或 `ConsumerHookWidget`。
- **DI 層**：使用 Provider 注入 Repository 和 Service。

```dart
// Example: AsyncNotifier for Data
@riverpod
class DailyStockList extends _$DailyStockList {
  @override
  FutureOr<List<Stock>> build() async {
    return ref.watch(stockRepositoryProvider).getAllStocks();
  }
}
```

### 3. Layered Architecture (分層架構)

- **Data Layer**:
  - `DriftDatabase`: 定義 Tables 和 DAOs。
  - `RemoteDataSource`: 負責 Dio API 請求 / RSS 解析。
  - `Repository`: 協調 Remote 和 Local，暴露 `Stream` 或 `Future` 給 Domain/Application 層。
- **Domain/Application Layer**:
  - `Services`: 業務邏輯 (例如：Rule Engine 判斷、技術指標計算)。
  - **純 Dart 代碼**，不依賴 Flutter UI。

- **Presentation Layer**:
  - `Controllers` (Riverpod Notifiers): 管理 UI 狀態。
  - `Widgets`: 笨拙的 UI，只負責渲染。
  - 使用 `AsyncValue` 處理 Loading / Error 狀態。

## 代碼風格指引 (Coding Standards)

- **Dart 3 特性**:
  - 使用 `Records` `(double, double)` 處理簡單的雙回傳值。
  - 使用 `Pattern Matching` (`switch`) 處理複雜邏輯分支。
  - 使用 `sealed class` 定義UI狀態 (如果不用 AsyncValue)。
- **Constants**: 使用 `const` 建構子以優化性能。
- **Lints**: 遵循 `flutter_lints` 6.0+。

## 關鍵實作模式 (Implementation Patterns)

### Drift Table 定義

```dart
class StockMaster extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get symbol => text().unique()();
  TextColumn get name => text()();
  // ...
}
```

### Rule Engine (規則引擎)

- 保持純函數式 (Pure Functional)。
- 輸入：`StockData` + `HistoricalData`
- 輸出：`List<Reason>` (Nullable)

```dart
List<Reason> checkReversal(StockSnapshot current, List<StockSnapshot> history) {
  // Implementation...
}
```

## 常見任務 (Common Tasks)

- **新增功能**: 先定義 Drift Table -> 生成 Code -> 實作 Repository -> 實作 Controller -> 實作 UI。
- **處理錯誤**: 在 Repository 層捕獲 DioException，轉換為自定義 `AppException`。
- **測試**: 使用 `mocktail` mock Repositories，測試 Notifiers。
