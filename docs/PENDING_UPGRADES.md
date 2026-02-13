# 待完成的依賴升級任務

本文檔記錄尚未完成的 Major 版本升級，因涉及大量程式碼修改而需要獨立計劃。

---

## 已完成升級 (2026-02-13)

### Patch & Minor 版本升級 ✅
- **dio**: 5.9.0 → 5.9.1
- **drift**: 2.27.0 → 2.28.2
- **csv**: 6.0.0 → 7.1.0 (含 breaking changes 修復)
- **workmanager**: 0.5.2 → 0.9.0+3 (含 breaking changes 修復)
- **flutter_slidable**: 3.1.0 → 3.1.2
- **fl_chart**: 0.69.0 → 0.69.2
- **k_chart_plus**: 1.0.1 → 1.0.3
- **timezone**: 0.10.0 → 0.10.1
- **share_plus**: 10.1.0 → 10.1.4
- **go_router**: 15.1.2 → 15.1.3

### Breaking Changes 修復 ✅
- **csv 7.x**: `ListToCsvConverter` → `CsvEncoder`
- **workmanager 0.9.x**:
  - 移除 `isInDebugMode` 參數
  - `ExistingWorkPolicy` → `ExistingPeriodicWorkPolicy`

---

## 待升級項目（需要獨立計劃）

### 🔴 優先度 P0: Riverpod 3.x 生態系統升級

**影響範圍**: 整個狀態管理層 (200+ 檔案)

**升級套件清單**:
- `flutter_riverpod`: 2.6.1 → 3.2.1
- `riverpod_annotation`: 2.6.1 → 4.0.2
- `riverpod_generator`: 2.6.4 → 4.0.3
- `freezed`: 2.5.8 → 3.2.5
- `freezed_annotation`: 2.4.4 → 3.1.0
- `json_serializable`: 6.9.5 → 6.12.0
- `drift_dev`: 2.28.0 → 2.31.0
- `build_runner`: 2.5.4 → 2.11.1

**Riverpod 3.0 Breaking Changes** ([Migration Guide](https://riverpod.dev/docs/3.0_migration)):

1. **Ref Type Parameter 移除**
   - `ProviderRef.state` → `Notifier.state`
   - `Ref.listenSelf` → `Notifier.listenSelf`
   - `FutureProviderRef.future` → `AsyncNotifier.future`

2. **AutoDispose 語法改變**
   - 移除所有 `AutoDispose` 關鍵字
   - Notifier API 已統一處理

3. **Family Notifiers 移除**
   - `FamilyNotifier` → `Notifier`
   - `FamilyAsyncNotifier` → `AsyncNotifier`
   - `FamilyStreamNotifier` → `StreamNotifier`

4. **錯誤處理**
   - 所有 provider 失敗會被包裝為 `ProviderException`
   - Provider 預設自動重試機制

5. **ProviderObserver 介面變更**
   - 改用單一 `ProviderObserverContext` 物件

6. **通知過濾**
   - 使用 `==` 來過濾通知（影響 StreamProvider/StreamNotifier）

7. **Legacy Providers**
   - `StateProvider`, `StateNotifierProvider`, `ChangeNotifierProvider` 移至 `legacy.dart`

**依賴鏈衝突原因**:
- Riverpod 2.x 使用 `source_gen 2.x`
- Riverpod 3.x/4.x 需要 `source_gen 3.x+`
- 新版 freezed, drift_dev, build_runner 也需要 `source_gen 3.x+`
- **無法單獨升級，必須全部一起升級**

**預估工作量**: 8-12 小時
- 程式碼修改: 6-8 小時
- 測試驗證: 2-3 小時
- 文檔更新: 1 小時

**實作步驟**:
1. 更新 pubspec.yaml 所有相關套件
2. 執行 code generation: `dart run build_runner build --delete-conflicting-outputs`
3. 修復編譯錯誤（按 migration guide）
4. 更新所有使用 `ProviderRef.state` 的程式碼
5. 移除所有 `AutoDispose` 關鍵字
6. 更新 Family Notifier 用法
7. 執行完整測試套件
8. 更新 CLAUDE.md 和 README.md

---

### 🟠 優先度 P1: UI 套件升級

#### fl_chart: 0.69.2 → 1.1.1

**Breaking Changes**: [fl_chart 1.0.0 Changelog](https://pub.dev/packages/fl_chart/changelog)
- API 可能有重大變更
- 需要審查所有圖表元件 (約 5 個檔案)

**工作量**: 2-3 小時

---

#### go_router: 15.1.3 → 17.1.0

**影響範圍**: 路由配置和導航邏輯
- 需要審查 `app_routes.dart` 和所有導航呼叫

**工作量**: 2-3 小時

---

#### flutter_slidable: 3.1.2 → 4.0.3

**影響範圍**: Watchlist 和其他滑動操作元件

**工作量**: 1-2 小時

---

### 🟡 優先度 P2: 其他 Major 升級

#### flutter_local_notifications: 18.0.1 → 20.1.0

**工作量**: 1-2 小時

---

#### flutter_secure_storage: 9.2.4 → 10.0.0

**工作量**: 1-2 小時

---

#### share_plus: 10.1.4 → 12.0.1

**工作量**: 30 分鐘 - 1 小時

---

## 已停用套件狀態

以下套件已停用但為 transitive dependencies（間接依賴），無法直接移除：

- **js** (0.6.7) - 來自舊版依賴，已被 `dart:js_interop` 取代
- **build_resolvers** - 來自 `build_runner 2.x`
- **build_runner_core** - 來自 `build_runner 2.x`

**處理方式**: 升級到 Riverpod 3.x 生態系統後，這些停用套件應該會被新版本替換。

---

## 建議升級順序

1. **第一階段**: Riverpod 3.x 生態系統升級（P0）
   - 這會解決已停用套件問題
   - 解鎖其他依賴升級

2. **第二階段**: UI 套件升級（P1）
   - fl_chart 1.x
   - go_router 17.x
   - flutter_slidable 4.x

3. **第三階段**: 其他 Major 升級（P2）
   - flutter_local_notifications 20.x
   - flutter_secure_storage 10.x
   - share_plus 12.x

---

## 參考資源

- [Riverpod 3.0 Migration Guide](https://riverpod.dev/docs/3.0_migration)
- [Riverpod 3.0 What's New](https://riverpod.dev/docs/whats_new)
- [Workmanager Changelog](https://pub.dev/packages/workmanager/changelog)
- [CSV Package Documentation](https://pub.dev/packages/csv)

---

**最後更新**: 2026-02-13
**下次審查**: Riverpod 3.x 升級完成後
