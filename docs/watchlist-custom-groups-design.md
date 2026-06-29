# Watchlist 自訂分組 (Custom Groups) — Design

## 目標
讓使用者把自選股分到**自訂、可命名**的分組(資料夾模式:**一檔一組**),用來分流不同性質的標的(例:低風險核心 / 高風險觀察)。

## 範圍
- **做**:自由命名分組、一檔歸一組、沿用現有分組顯示機制。
- **不做(留未來)**:一檔多標籤(tags / 多對多)、改動現有 `none/status/trend` 自動分組。

## 資料模型
新表 `WatchlistGroups`(`lib/data/database/tables/user_tables.dart`):
- `id` IntColumn autoIncrement
- `name` TextColumn(min 1、max 50)
- `sortOrder` IntColumn default 0
- `createdAt` DateTimeColumn default now

`Watchlist` 表新增欄位:
- `groupId` IntColumn nullable，`references(WatchlistGroups, #id, onDelete: KeyAction.setNull)`

**Schema 套用方式(零資料損失,不重置)**:沿用 `app_database.dart` 既有的 idempotent pattern（`_ensureDealerSelfNetColumn` 就是先例:在既有 DB 上 `ALTER TABLE ADD COLUMN` 並保留全部資料）。在 `beforeOpen` 加兩段:
- `CREATE TABLE IF NOT EXISTS WatchlistGroups`（缺才建）
- 以 `PRAGMA table_info('watchlist')` 判斷後 `ALTER TABLE watchlist ADD COLUMN group_id`（缺才加）
- **不 bump `_schemaFingerprint`** → 不觸發 reset → watchlist（在 `_userInputTableNames` 白名單內,本來就受保護）與行情資料全部保留。新表空、新欄對既有列為 null。

## 分組顯示(90% 沿用現有)
- `WatchlistGroup` enum(`watchlist_types.dart`)新增值 `category`。
- `WatchlistItemData` 新增 `int? groupId`、`String? groupName`。
- `watchlist_provider.dart` 新增 `groupedByCategory`(依 groupId 分組；null → 「未分組」)。
- `watchlist_screen.dart` 的 `_buildListContent` switch 新增 `case WatchlistGroup.category` → 直接用現有 `_buildGroupedList`。
- ⋮ 更多選單會**自動**顯示新選項(它跑 `WatchlistGroup.values`)。

## 指定股票到分組
- `stock_preview_sheet.dart`(股票長按彈出)新增「移到分組 ▸」動作。
- 開啟 picker:現有分組清單(標示目前所屬)+「➕ 新增分組」(建立並當場指定)+「移出分組」(groupId = null)。
- DAO(`user_dao.dart`):`assignWatchlistGroup(symbol, groupId?)`。

## 管理分組
- ⋮ 更多選單新增「管理分組」→ sheet:分組清單 + 改名(inline)+ 刪除(確認；成員變未分組)+「➕ 新增分組」+ 排序(選做)。
- DAO:`createWatchlistGroup(name)`、`renameWatchlistGroup(id, name)`、`deleteWatchlistGroup(id)`、`reorderWatchlistGroups`(選做)。

## 細節決定
- **不預設任何分組**(開空，使用者自建)。
- 未歸類股票 → 「未分組」標題(僅在 group by category 時顯示)。
- 刪除分組 → 成員 `groupId` 設 null(**不刪股票**)。

## 要改 / 新增的檔
| 檔 | 動作 |
|---|---|
| `lib/data/database/tables/user_tables.dart` | 新表 `WatchlistGroups` + `Watchlist.groupId` |
| `lib/data/database/dao/user_dao.dart` | 分組 CRUD + `assignWatchlistGroup` |
| `lib/presentation/providers/watchlist_types.dart` | enum `category` + `WatchlistItemData.groupId/groupName` |
| `lib/presentation/providers/watchlist_provider.dart` | `groupedByCategory` + CRUD 串接 |
| `lib/presentation/screens/watchlist/watchlist_screen.dart` | `category` case + 管理分組入口 |
| `lib/presentation/widgets/stock_preview_sheet.dart` | 「移到分組」動作 |
| 新增元件 | 分組 picker + 管理分組 sheet |
| `assets/translations/{en,zh-TW}.json` | i18n keys（groupCategory / ungrouped / moveToGroup / manageGroups / newGroup …）|
| `dart run build_runner build` | 重新產 drift 程式碼 |
| 測試 | DAO + provider 分組邏輯 |

## 風險(實際偏低)
1. **Schema 套用**:用既有 `_ensureDealerSelfNetColumn` 的 idempotent pattern 即可,**零資料損失、不重置**(watchlist 本就在 `_userInputTableNames` 白名單)。唯一要記得:**不要 bump fingerprint**(bump 會 wipe derived 行情表,雖可重 sync 但沒必要)。
2. **groupId FK + setNull** 行為需測(刪分組後成員確實變未分組、不被連帶刪)。
