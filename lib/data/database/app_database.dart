import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'package:afterclose/core/utils/logger.dart';

import 'package:afterclose/data/database/tables/stock_master.dart';
import 'package:afterclose/data/database/tables/daily_price.dart';
import 'package:afterclose/data/database/tables/daily_institutional.dart';
import 'package:afterclose/data/database/tables/news_tables.dart';
import 'package:afterclose/data/database/tables/analysis_tables.dart';
import 'package:afterclose/data/database/tables/user_tables.dart';
import 'package:afterclose/data/database/tables/market_data_tables.dart';
import 'package:afterclose/data/database/tables/portfolio_tables.dart';
import 'package:afterclose/data/database/tables/event_tables.dart';
import 'package:afterclose/data/database/tables/market_index_tables.dart';

// Drift modular generated code
import 'package:afterclose/data/database/app_database.drift.dart';

// Re-export generated types for backward compatibility
export 'package:afterclose/data/database/app_database.drift.dart';
export 'package:afterclose/data/database/tables/stock_master.drift.dart';
export 'package:afterclose/data/database/tables/daily_price.drift.dart';
export 'package:afterclose/data/database/tables/daily_institutional.drift.dart';
export 'package:afterclose/data/database/tables/news_tables.drift.dart';
export 'package:afterclose/data/database/tables/analysis_tables.drift.dart';
export 'package:afterclose/data/database/tables/user_tables.drift.dart';
export 'package:afterclose/data/database/tables/market_data_tables.drift.dart';
export 'package:afterclose/data/database/tables/portfolio_tables.drift.dart';
export 'package:afterclose/data/database/tables/event_tables.drift.dart';
export 'package:afterclose/data/database/tables/market_index_tables.drift.dart';

// DAO files (standalone)
import 'package:afterclose/data/database/dao/analysis_dao.dart';
import 'package:afterclose/data/database/dao/calibration_cache_dao.dart';
import 'package:afterclose/data/database/dao/day_trading_dao.dart';
import 'package:afterclose/data/database/dao/dividend_dao.dart';
import 'package:afterclose/data/database/dao/event_dao.dart';
import 'package:afterclose/data/database/dao/financial_data_dao.dart';
import 'package:afterclose/data/database/dao/holding_distribution_dao.dart';
import 'package:afterclose/data/database/dao/insider_holding_dao.dart';
import 'package:afterclose/data/database/dao/insider_transfer_dao.dart';
import 'package:afterclose/data/database/dao/institutional_dao.dart';
import 'package:afterclose/data/database/dao/margin_trading_dao.dart';
import 'package:afterclose/data/database/dao/market_index_dao.dart';
import 'package:afterclose/data/database/dao/market_overview_dao.dart';
import 'package:afterclose/data/database/dao/news_dao.dart';
import 'package:afterclose/data/database/dao/portfolio_dao.dart';
import 'package:afterclose/data/database/dao/price_dao.dart';
import 'package:afterclose/data/database/dao/revenue_dao.dart';
import 'package:afterclose/data/database/dao/shareholding_dao.dart';
import 'package:afterclose/data/database/dao/stock_dao.dart';
import 'package:afterclose/data/database/dao/trading_warning_dao.dart';
import 'package:afterclose/data/database/dao/thesis_dao.dart';
import 'package:afterclose/data/database/dao/user_dao.dart';
import 'package:afterclose/data/database/dao/valuation_dao.dart';

@DriftDatabase(
  tables: [
    // 主檔資料
    StockMaster,
    // 每日市場資料
    DailyPrice,
    DailyInstitutional,
    // 新聞
    NewsItem,
    NewsStockMap,
    // 分析結果
    DailyAnalysis,
    DailyReason,
    DailyRecommendation,
    // 規則準確度追蹤
    RuleAccuracy,
    RecommendationValidation,
    // 使用者資料
    // WatchlistGroups 必須排在 Watchlist 之前：Watchlist.groupId 以 FK 參照
    // WatchlistGroups，createAll 依序建表時 parent 必須先存在。
    WatchlistGroups,
    Watchlist,
    UpdateRun,
    AppSettings,
    PriceAlert,
    PinnedThesis,
    // 擴充市場資料（Phase 1）
    Shareholding,
    DayTrading,
    FinancialData,
    HoldingDistribution,
    // 基本面資料（Phase 3）
    MonthlyRevenue,
    StockValuation,
    // 股利歷史
    DividendHistory,
    // 融資融券資料（Phase 4）
    MarginTrading,
    // 風險控管資料（Killer Features）
    TradingWarning,
    InsiderHolding,
    // 內部人股權轉讓（Feature 4）
    InsiderTransfer,
    // 自訂選股策略（Phase 2.2）
    ScreeningStrategyTable,
    // 投資組合（Phase 4.4）
    PortfolioPosition,
    PortfolioTransaction,
    // 事件行事曆（Phase 4.3）
    StockEvent,
    // 大盤指數歷史（Phase 5.2）
    MarketIndex,
  ],
)
class AppDatabase extends $AppDatabase
    with
        StockDaoMixin,
        PriceDaoMixin,
        ThesisDaoMixin,
        AnalysisDaoMixin,
        InstitutionalDaoMixin,
        UserDaoMixin,
        PortfolioDaoMixin,
        EventDaoMixin,
        MarketIndexDaoMixin,
        NewsDaoMixin,
        ShareholdingDaoMixin,
        DayTradingDaoMixin,
        MarginTradingDaoMixin,
        FinancialDataDaoMixin,
        RevenueDaoMixin,
        ValuationDaoMixin,
        DividendDaoMixin,
        HoldingDistributionDaoMixin,
        TradingWarningDaoMixin,
        InsiderHoldingDaoMixin,
        InsiderTransferDaoMixin,
        MarketOverviewDaoMixin,
        CalibrationCacheDaoMixin {
  /// 純 Dart constructor — caller 注入 [QueryExecutor]
  ///
  /// **C 方案 refactor 2026-06-19**：移除原本 `AppDatabase() : super(_openConnection())`
  /// 把 `drift_flutter` 鏈拉進整個檔的 default 構造。`drift_flutter` →
  /// `path_provider` → `package:flutter/foundation.dart` → `dart:ui`，
  /// 連鎖讓所有 import AppDatabase 的純 Dart CLI 無法 `dart run`
  /// （包括 `tool/backfill.dart`、`tool/replay_calibrator.dart`）。
  ///
  /// Flutter 路徑（runtime app / WorkManager isolate）改顯式呼叫
  /// `openDriftFlutterConnection()` from `app_database_flutter.dart`：
  ///
  /// ```dart
  /// final db = AppDatabase(openDriftFlutterConnection());
  /// ```
  ///
  /// 純 Dart 路徑改用 [AppDatabase.forToolFile] / [AppDatabase.forTesting]。
  AppDatabase(super.executor);

  /// 測試用 - 建立記憶體內 Database
  AppDatabase.forTesting() : super(NativeDatabase.memory());

  /// Tool / CLI 用 — 開啟指定路徑的 SQLite 檔案作為獨立 DB
  ///
  /// 用途：
  /// - macOS launchd CLI（`tool/daily_update.dart`）直接讀寫 GUI app sandbox
  ///   的 DB
  /// - Stage 3+4 backfill + calibration（`tool/backfill.dart`、
  ///   `tool/replay_calibrator.dart`、`tool/recalibrate.dart`）走獨立
  ///   `tool/calibration.db` 路徑避免污染正式 dev DB
  ///
  /// 若 [path] 不存在會自動建立，schema 透過既有的 `onCreate` +
  /// fingerprint 機制建好。**純 Dart**：不經 `drift_flutter`，可在
  /// `dart run` 環境正常運作。
  AppDatabase.forToolFile(String path) : super(NativeDatabase(File(path)));

  /// 產品尚未上線前使用 version 1，所有 table 和 index 在 onCreate 一次建好。
  /// 正式上線後，每次 schema 變更遞增 version 並在 onUpgrade 加 migration。
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    beforeOpen: (details) async {
      // Pre-launch schema drift auto-reset: 在啟用 FK 前執行，讓 DROP TABLE
      // 不會因為 CASCADE 連鎖觸發非預期刪除。若偵測到 fingerprint mismatch，
      // 會把所有 Drift managed table drop 後由 Migrator 重建。
      await _ensureSchemaFingerprint();
      await _ensureDealerSelfNetColumn();
      await _ensureWatchlistGroupsSchema();
      await _ensurePinnedThesisSchema();
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Pre-launch idempotent 建表：為既有 DB 補上 `pinned_thesis`（出場層
  /// Phase 2），零資料損失、可安全重跑——沿用 [_ensureWatchlistGroupsSchema]
  /// 的先例（Drift [Migrator.createTable] 內建 CREATE TABLE IF NOT EXISTS，
  /// 既有 DB 已建過 no-op、全新安裝由 createAll 先建好這裡也 no-op）。
  Future<void> _ensurePinnedThesisSchema() async {
    await Migrator(this).createTable(pinnedThesis);
  }

  /// Pre-launch idempotent 加欄：在「不」bump schema fingerprint（不 wipe 既有
  /// derived 資料）的前提下，為既有 DB 補上 `daily_institutional.dealer_self_net`。
  ///
  /// - 全新安裝：`createAll` 已依表定義建出此欄，這裡 PRAGMA 查到便 no-op。
  /// - 既有 DB：fingerprint 未變→不 wipe，這裡偵測缺欄並 `ALTER TABLE ADD COLUMN`，
  ///   既有 47 天法人資料與其餘 derived 表全部保留。
  /// - 未來若有人 bump fingerprint 觸發 wipe：createAll 重建已含此欄，這裡 no-op。
  ///
  /// SQLite 的 `ALTER TABLE ADD COLUMN` 不支援 `IF NOT EXISTS`，故先以
  /// `PRAGMA table_info` 判斷欄位是否存在，確保 idempotent（每次開啟可安全重跑）。
  Future<void> _ensureDealerSelfNetColumn() async {
    final columns = await customSelect(
      "PRAGMA table_info('daily_institutional')",
    ).get();
    final hasColumn = columns.any(
      (row) => row.read<String>('name') == 'dealer_self_net',
    );
    if (hasColumn) return;

    await customStatement(
      'ALTER TABLE daily_institutional ADD COLUMN dealer_self_net REAL',
    );
    AppLogger.info(
      'AppDatabase',
      '既有 DB 補上 daily_institutional.dealer_self_net 欄（保留既有資料）',
    );
  }

  /// Pre-launch idempotent schema 套用：在「不」bump schema fingerprint（不 wipe
  /// 既有 watchlist / 行情資料）的前提下，為既有 DB 補上 watchlist 自訂分組功能。
  ///
  /// 沿用 [_ensureDealerSelfNetColumn] 的先例（零資料損失、可安全重跑），分兩步：
  ///
  /// 1. **建新表 `watchlist_groups`**：直接用 Drift 自己的 [Migrator.createTable]，
  ///    讓 DDL 與 generated schema 完全一致（避免手寫 CREATE TABLE 造成欄位/型別
  ///    漂移）。Drift 的 `createTable` 內部用 `CREATE TABLE IF NOT EXISTS`，
  ///    既有 DB 已建過便 no-op、全新安裝由 `createAll` 先建好這裡也是 no-op。
  ///
  /// 2. **為 `watchlist` 加 `group_id` 欄**：SQLite `ALTER TABLE ADD COLUMN`
  ///    不支援 `IF NOT EXISTS`，故先以 `PRAGMA table_info('watchlist')` 判斷
  ///    欄位是否存在，缺才補。既有自選股資料全部保留（新欄對既有列為 null =
  ///    未分組）。
  ///
  /// 必須在 `PRAGMA foreign_keys = ON` 之前執行：欄位帶 FK 參照 watchlist_groups，
  /// 在 FK 關閉狀態下做 DDL 較安全；且步驟 1 先於步驟 2，確保 FK 參照的 parent
  /// 表已存在。
  Future<void> _ensureWatchlistGroupsSchema() async {
    // 步驟 1：建分組表（Drift 內建 CREATE TABLE IF NOT EXISTS，idempotent）
    await createMigrator().createTable(watchlistGroups);

    // 步驟 2：為既有 watchlist 表補 group_id 欄（缺才加）
    final columns = await customSelect("PRAGMA table_info('watchlist')").get();
    final hasColumn = columns.any(
      (row) => row.read<String>('name') == 'group_id',
    );
    if (hasColumn) return;

    await customStatement(
      'ALTER TABLE watchlist ADD COLUMN group_id INTEGER '
      'REFERENCES watchlist_groups(id) ON DELETE SET NULL',
    );
    AppLogger.info(
      'AppDatabase',
      '既有 DB 補上 watchlist.group_id 欄與 watchlist_groups 表（保留既有自選股）',
    );
  }

  /// 檢查 schema fingerprint 是否與當前 code 一致，若不一致則 drop 全部 table 重建
  ///
  /// ## 設計動機
  ///
  /// Pre-launch 階段我們刻意把 [schemaVersion] 鎖在 1（避免每次改 schema 都
  /// 要維護 migration ladder）。但 Drift 的 `onUpgrade` 是 version-driven，
  /// version 沒變就不會觸發 migration。結果：developer 改了 table 定義、
  /// 跑了 `build_runner` 後，舊的 `.sqlite` 檔案仍保有舊 schema，app 啟動
  /// 時會炸 `no such column` 之類的錯誤。
  ///
  /// 此 method 在 `beforeOpen` 執行，透過一個不受 Drift 管理的 meta table
  /// 儲存當前 schema 的指紋字串。啟動時比對，不一致就把**非使用者輸入**的
  /// Drift 表 drop 後呼叫 `Migrator.createAll` 重建。Drift `createTable`
  /// 本身用 `CREATE TABLE IF NOT EXISTS`，所以 whitelist 內已存在的表會
  /// 直接 skip、保留資料。
  ///
  /// ## 何時 bump fingerprint
  ///
  /// **任何 schema 改動都要 bump `_schemaFingerprint` 的字串值**：
  /// - 新增 / 刪除 / 重命名 column
  /// - 改 primary key / unique key / index
  /// - 新增 / 刪除 table
  ///
  /// 字串值是不透明的，只要跟前一個版本不同就會觸發 reset。建議用
  /// `<stage>-<feature>-<date>` 格式，方便看 git blame 追歷史。
  ///
  /// ## 使用者輸入表 whitelist（不會被 wipe）
  ///
  /// [_userInputTableNames] 內列出的表在 reset 時被跳過，避免使用者**手動
  /// 輸入**的資料（自選股、價格警示、自訂篩選、portfolio、自訂事件、app 偏好）
  /// 被洗掉。這是 M1 修正範圍。
  ///
  /// ## ⚠️ Whitelist 的已知限制
  ///
  /// Whitelist 內的表若**schema 改動**（加欄位、改 PK），此機制不會自動
  /// migrate — `CREATE TABLE IF NOT EXISTS` 看到既存表就放著不動，新 column
  /// 不會出現、舊 column 也不會被刪。
  ///
  /// 解法：若要動 whitelist 表的 schema，必須**同時加一段 ALTER TABLE 路徑**
  /// 處理現有 DB；或臨時把該表從 whitelist 拿掉接受該次 wipe。長期該換
  /// Drift `schemaVersion` + `onUpgrade` migration ladder 治本。
  ///
  /// ## 不在 whitelist 的表為何安全
  ///
  /// 其餘表都是 derived data（每日 syncer 重抓即可）。`update_run` 也不
  /// 進 whitelist — wipe 後首次啟動會被當成「沒跑過」觸發一次全量同步，
  /// 沒資料損失。
  ///
  /// ## 正式上線後的遷移路徑
  ///
  /// 上線之後此機制**仍建議移除**，改回 Drift 標準的 `schemaVersion` 遞增 +
  /// `onUpgrade` migration。此 whitelist fix 只是**避免 pre-launch 期間自
  /// 己 dogfooding 時被洗掉資料**的權宜之計。
  static const Set<String> _userInputTableNames = {
    'portfolio_position',
    'portfolio_transaction',
    'watchlist',
    'watchlist_groups',
    'price_alert',
    'screening_strategy_table',
    'stock_event',
    'app_settings',
  };

  Future<void> _ensureSchemaFingerprint() async {
    // 建立 meta table（不屬於 Drift schema，不會被 allTables 列出來）
    await customStatement('''
      CREATE TABLE IF NOT EXISTS _drift_schema_fingerprint (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        value TEXT NOT NULL
      )
    ''');

    final result = await customSelect(
      'SELECT value FROM _drift_schema_fingerprint WHERE id = 1',
    ).get();
    final stored = result.isEmpty ? null : result.first.read<String>('value');

    if (stored == _schemaFingerprint) {
      return; // fingerprint 一致，跳過
    }

    if (stored != null) {
      // 偵測到 schema drift — drop 所有非 whitelist 的 Drift managed table
      // 後重建。foreign_keys pragma 仍為 OFF（Drift 預設），可以安全 DROP。
      final preserved = <String>[];
      final dropped = <String>[];
      AppLogger.warning(
        'AppDatabase',
        'Schema fingerprint mismatch — resetting tables '
            '(stored=$stored, expected=$_schemaFingerprint)',
      );
      for (final table in allTables.toList().reversed) {
        final name = table.actualTableName;
        if (_userInputTableNames.contains(name)) {
          preserved.add(name);
          continue;
        }
        await customStatement('DROP TABLE IF EXISTS "$name"');
        dropped.add(name);
      }
      // createAll 用 CREATE TABLE IF NOT EXISTS（drift 2.x 內建），保留的
      // user input 表既存資料不會被動到。
      await Migrator(this).createAll();
      AppLogger.info(
        'AppDatabase',
        'Schema reset complete — dropped=${dropped.length} '
            '(${dropped.join(",")}), preserved=${preserved.length} '
            '(${preserved.join(",")})',
      );
    } else {
      // 第一次建立 DB — onCreate 已經跑過 createAll，這邊只需記錄 fingerprint
      AppLogger.info(
        'AppDatabase',
        'Initial schema fingerprint: $_schemaFingerprint',
      );
    }

    await customStatement(
      'INSERT OR REPLACE INTO _drift_schema_fingerprint (id, value) VALUES (1, ?)',
      [_schemaFingerprint],
    );
  }
}

/// Schema fingerprint for pre-launch drift auto-reset
///
/// **Bump this string whenever any Drift table definition changes**. See
/// [AppDatabase._ensureSchemaFingerprint] for the full rationale and the
/// post-launch migration path.
///
/// Format: `<stage>-<feature>-<YYYY-MM-DD>`. Any string change triggers a
/// reset — the value itself is opaque.
const String _schemaFingerprint = 'stage5b-dual-horizon-2026-04-11';

// 原 `QueryExecutor _openConnection()` 已搬到 `app_database_flutter.dart`
// 並改為 public `openDriftFlutterConnection()`，避免 `drift_flutter` import
// 把 `dart:ui` 拉進整個 type graph，讓 `tool/` 的純 Dart CLI 可以跑。
