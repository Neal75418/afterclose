import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

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
    Watchlist,
    UpdateRun,
    AppSettings,
    PriceAlert,
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
  AppDatabase() : super(_openConnection());

  /// 測試用 - 建立記憶體內 Database
  AppDatabase.forTesting() : super(NativeDatabase.memory());

  /// Tool/calibration 用 — 開啟指定路徑的 SQLite 檔案作為獨立 DB
  ///
  /// Stage 3+4 backfill + calibration 專用（`tool/backfill.dart`、
  /// `tool/replay_calibrator.dart`、`tool/recalibrate.dart`）。**不用於
  /// runtime app** — 開發者手動指定如 `tool/calibration.db` 的路徑以
  /// 避免污染正式 dev DB，並讓 calibration 產物可以獨立 .gitignore。
  ///
  /// 若 [path] 不存在會自動建立，schema 透過既有的 `onCreate` +
  /// fingerprint 機制建好。
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
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

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
  /// 儲存當前 schema 的指紋字串。啟動時比對，不一致就把所有 Drift 管理的
  /// table drop 後呼叫 `Migrator.createAll` 重建。Pre-launch 所有資料都是
  /// derived data，清掉後由 syncer 重新下載即可。
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
  /// ## 正式上線後的遷移路徑
  ///
  /// 上線之後此機制**必須移除**，改回 Drift 標準的 `schemaVersion` 遞增 +
  /// `onUpgrade` migration。正式 user 不能接受「升級 app 資料全清空」的
  /// 體驗。屆時 `_schemaFingerprint` 跟 `_ensureSchemaFingerprint` 都要刪除。
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
      // 偵測到 schema drift — drop 所有 Drift managed table 後重建
      // 此時 foreign_keys pragma 仍為 OFF（Drift 預設），可以安全 DROP
      AppLogger.warning(
        'AppDatabase',
        'Schema fingerprint mismatch — resetting all tables '
            '(stored=$stored, expected=$_schemaFingerprint)',
      );
      for (final table in allTables.toList().reversed) {
        await customStatement(
          'DROP TABLE IF EXISTS "${table.actualTableName}"',
        );
      }
      await Migrator(this).createAll();
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

QueryExecutor _openConnection() {
  return driftDatabase(name: 'afterclose');
}
