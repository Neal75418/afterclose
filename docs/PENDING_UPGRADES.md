# 待完成的依賴升級任務

本文檔記錄尚未完成的 Major 版本升級，因涉及大量程式碼修改而需要獨立計劃。

---

## 已完成升級 (2026-02-13)

### 2026-02-13: Riverpod 3.x 生態系統升級 ✅

**升級套件**（10 個）:
- flutter_riverpod: 2.6.1 → 3.2.1 ✅
- riverpod_annotation: 2.6.1 → 4.0.2 ✅
- riverpod_generator: 2.6.4 → 4.0.3 ✅
- freezed: 2.5.8 → 3.2.5 ✅
- freezed_annotation: 2.4.4 → 3.1.0 ✅
- json_serializable: 6.9.5 → 6.12.0 ✅
- drift: 2.28.2 → 2.31.0 ✅
- drift_dev: 2.28.0 → 2.31.0 ✅
- build_runner: 2.5.4 → 2.11.1 ✅
- source_gen: 2.0.0 → 4.2.0 ✅

**程式碼變更**:
- 添加 `legacy.dart` import 到 14 個 provider 檔案（使用 StateNotifier）
- 使用 `dependency_overrides` 解決依賴衝突（analyzer: ^10.0.0, dart_style: ^3.1.5, io: ^1.0.3）

**測試結果**: 1069/1069 通過 ✅

**已移除的停用套件**:
- analyzer_plugin ❌
- build_resolvers ❌
- build_runner_core ❌
- custom_lint_core ❌
- custom_lint_visitor ❌

**解決問題**:
- 解決 source_gen 版本衝突
- 移除所有已停用套件依賴
- 解鎖後續 UI 套件升級路徑（go_router 17.x, fl_chart 1.x 等）

**實際工作量**: 約 3 小時（比預估的 8-12 小時快，因為使用 legacy.dart 避免了大量程式碼重寫）

---

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

## 建議升級順序

1. **第一階段**: ~~Riverpod 3.x 生態系統升級（P0）~~ ✅ **已完成 (2026-02-13)**
   - ✅ 已解決已停用套件問題
   - ✅ 已解鎖其他依賴升級

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
