import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/date_context.dart';
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

part 'app_database.g.dart';
part 'dao/analysis_dao.dart';
part 'dao/day_trading_dao.dart';
part 'dao/dividend_dao.dart';
part 'dao/event_dao.dart';
part 'dao/financial_data_dao.dart';
part 'dao/holding_distribution_dao.dart';
part 'dao/insider_holding_dao.dart';
part 'dao/institutional_dao.dart';
part 'dao/margin_trading_dao.dart';
part 'dao/market_index_dao.dart';
part 'dao/market_overview_dao.dart';
part 'dao/news_dao.dart';
part 'dao/portfolio_dao.dart';
part 'dao/price_dao.dart';
part 'dao/revenue_dao.dart';
part 'dao/shareholding_dao.dart';
part 'dao/stock_dao.dart';
part 'dao/trading_warning_dao.dart';
part 'dao/user_dao.dart';
part 'dao/valuation_dao.dart';

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
    UserNote,
    StrategyCard,
    UpdateRun,
    AppSettings,
    PriceAlert,
    // 用戶行為追蹤（Sprint 11 - 個人化推薦）
    UserInteraction,
    UserPreference,
    // 擴充市場資料（Phase 1）
    Shareholding,
    DayTrading,
    FinancialData,
    AdjustedPrice,
    WeeklyPrice,
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
class AppDatabase extends _$AppDatabase
    with
        _StockDaoMixin,
        _PriceDaoMixin,
        _AnalysisDaoMixin,
        _InstitutionalDaoMixin,
        _UserDaoMixin,
        _PortfolioDaoMixin,
        _EventDaoMixin,
        _MarketIndexDaoMixin,
        _NewsDaoMixin,
        _ShareholdingDaoMixin,
        _DayTradingDaoMixin,
        _MarginTradingDaoMixin,
        _FinancialDataDaoMixin,
        _RevenueDaoMixin,
        _ValuationDaoMixin,
        _DividendDaoMixin,
        _HoldingDistributionDaoMixin,
        _TradingWarningDaoMixin,
        _InsiderHoldingDaoMixin,
        _MarketOverviewDaoMixin {
  AppDatabase() : super(_openConnection());

  /// 測試用 - 建立記憶體內 Database
  AppDatabase.forTesting() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 12;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // 確保 FK 約束在 migration 時生效
      await customStatement('PRAGMA foreign_keys = ON');

      // v1 -> v2: 新增 news_item.content 欄位
      if (from < 2) {
        await customStatement('ALTER TABLE news_item ADD COLUMN content TEXT');
      }

      // v2 -> v3: 新增 Killer Features 表格（注意/處置股、董監持股）
      if (from < 3) {
        // 建立 trading_warning 表
        await customStatement('''
          CREATE TABLE IF NOT EXISTS trading_warning (
            symbol TEXT NOT NULL REFERENCES stock_master(symbol) ON DELETE CASCADE,
            date INTEGER NOT NULL,
            warning_type TEXT NOT NULL,
            reason_code TEXT,
            reason_description TEXT,
            disposal_measures TEXT,
            disposal_start_date INTEGER,
            disposal_end_date INTEGER,
            is_active INTEGER NOT NULL DEFAULT 1,
            PRIMARY KEY (symbol, date, warning_type)
          )
        ''');
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_trading_warning_symbol ON trading_warning(symbol)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_trading_warning_date ON trading_warning(date)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_trading_warning_type ON trading_warning(warning_type)',
        );

        // 建立 insider_holding 表
        await customStatement('''
          CREATE TABLE IF NOT EXISTS insider_holding (
            symbol TEXT NOT NULL REFERENCES stock_master(symbol) ON DELETE CASCADE,
            date INTEGER NOT NULL,
            director_shares REAL,
            supervisor_shares REAL,
            manager_shares REAL,
            insider_ratio REAL,
            pledge_ratio REAL,
            shares_change REAL,
            shares_issued REAL,
            PRIMARY KEY (symbol, date)
          )
        ''');
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_insider_holding_symbol ON insider_holding(symbol)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_insider_holding_date ON insider_holding(date)',
        );
      }

      // v3 -> v4: 新增股利歷史表
      if (from < 4) {
        await customStatement('''
          CREATE TABLE IF NOT EXISTS dividend_history (
            symbol TEXT NOT NULL REFERENCES stock_master(symbol) ON DELETE CASCADE,
            year INTEGER NOT NULL,
            cash_dividend REAL NOT NULL DEFAULT 0,
            stock_dividend REAL NOT NULL DEFAULT 0,
            ex_dividend_date TEXT,
            ex_rights_date TEXT,
            PRIMARY KEY (symbol, year)
          )
        ''');
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_dividend_history_symbol ON dividend_history(symbol)',
        );
        // year index 不需要：PK (symbol, year) 已提供最佳查詢路徑
      }

      // v4 -> v5: 新增自訂選股策略表
      if (from < 5) {
        await customStatement('''
          CREATE TABLE IF NOT EXISTS screening_strategy_table (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            conditions_json TEXT NOT NULL,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
            updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
          )
        ''');
      }

      // v5 -> v6: 新增投資組合表 + 事件行事曆表
      if (from < 6) {
        // portfolio_position
        await customStatement('''
          CREATE TABLE IF NOT EXISTS portfolio_position (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            symbol TEXT NOT NULL REFERENCES stock_master(symbol) ON DELETE CASCADE,
            quantity REAL NOT NULL DEFAULT 0,
            avg_cost REAL NOT NULL DEFAULT 0,
            realized_pnl REAL NOT NULL DEFAULT 0,
            total_dividend_received REAL NOT NULL DEFAULT 0,
            note TEXT,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
            updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
          )
        ''');
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_portfolio_position_symbol ON portfolio_position(symbol)',
        );

        // portfolio_transaction
        await customStatement('''
          CREATE TABLE IF NOT EXISTS portfolio_transaction (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            symbol TEXT NOT NULL REFERENCES stock_master(symbol) ON DELETE CASCADE,
            tx_type TEXT NOT NULL,
            date INTEGER NOT NULL,
            quantity REAL NOT NULL,
            price REAL NOT NULL,
            fee REAL NOT NULL DEFAULT 0,
            tax REAL NOT NULL DEFAULT 0,
            note TEXT,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
          )
        ''');
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_portfolio_tx_symbol ON portfolio_transaction(symbol)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_portfolio_tx_date ON portfolio_transaction(date)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_portfolio_tx_symbol_date ON portfolio_transaction(symbol, date)',
        );

        // stock_event
        await customStatement('''
          CREATE TABLE IF NOT EXISTS stock_event (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            symbol TEXT,
            event_type TEXT NOT NULL,
            event_date INTEGER NOT NULL,
            title TEXT NOT NULL,
            description TEXT,
            is_auto_generated INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
          )
        ''');
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_stock_event_date ON stock_event(event_date)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_stock_event_symbol ON stock_event(symbol)',
        );
      }

      // v6 -> v7: 新增大盤指數歷史表（v8 修正欄位型別）
      if (from < 7) {
        await customStatement('''
          CREATE TABLE IF NOT EXISTS market_index (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            name TEXT NOT NULL,
            close REAL NOT NULL,
            change REAL NOT NULL,
            change_percent REAL NOT NULL,
            created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
            UNIQUE (date, name)
          )
        ''');
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_market_index_date ON market_index(date)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_market_index_name ON market_index(name)',
        );
      }

      // v7 -> v8: 修正 market_index 欄位型別（INTEGER→TEXT 以配合 storeDateTimeAsText）
      if (from >= 7 && from < 8) {
        await customStatement('DROP TABLE IF EXISTS market_index');
        await customStatement('''
          CREATE TABLE market_index (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            name TEXT NOT NULL,
            close REAL NOT NULL,
            change REAL NOT NULL,
            change_percent REAL NOT NULL,
            created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
            UNIQUE (date, name)
          )
        ''');
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_market_index_date ON market_index(date)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_market_index_name ON market_index(name)',
        );
      }

      // v8 -> v9: 新增 daily_price.price_change 欄位（漲跌價差）
      if (from < 9) {
        await customStatement(
          'ALTER TABLE daily_price ADD COLUMN price_change REAL',
        );
      }

      // v9 -> v10: 新增複合索引加速 WHERE symbol=? AND date=? 查詢
      if (from < 10) {
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_trading_warning_symbol_date ON trading_warning(symbol, date)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_insider_holding_symbol_date ON insider_holding(symbol, date)',
        );
      }

      // v10 -> v11: 新增規則準確度表（Sprint 10）+ 用戶行為追蹤表（Sprint 11）
      if (from < 11) {
        // Sprint 10: 建立 rule_accuracy 表
        // 注意：updated_at 使用 TEXT 格式 (ISO8601) 以匹配 Drift 的 dateTime() 預設行為
        await customStatement('''
          CREATE TABLE IF NOT EXISTS rule_accuracy (
            rule_id TEXT NOT NULL,
            period TEXT NOT NULL,
            trigger_count INTEGER NOT NULL DEFAULT 0,
            success_count INTEGER NOT NULL DEFAULT 0,
            avg_return REAL NOT NULL DEFAULT 0,
            updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
            PRIMARY KEY (rule_id, period)
          )
        ''');
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_rule_accuracy_rule ON rule_accuracy(rule_id)',
        );

        // Sprint 10: 建立 recommendation_validation 表
        await customStatement('''
          CREATE TABLE IF NOT EXISTS recommendation_validation (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            recommendation_date INTEGER NOT NULL,
            symbol TEXT NOT NULL,
            primary_rule_id TEXT NOT NULL,
            entry_price REAL NOT NULL,
            exit_price REAL,
            return_rate REAL,
            is_success INTEGER,
            validation_date INTEGER,
            holding_days INTEGER NOT NULL DEFAULT 5
          )
        ''');
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_rec_validation_date ON recommendation_validation(recommendation_date)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_rec_validation_symbol ON recommendation_validation(symbol)',
        );

        // Sprint 11: 建立 user_interaction 表
        // 注意：timestamp 使用 TEXT 格式 (ISO8601) 以匹配 Drift 的 dateTime() 預設行為
        await customStatement('''
          CREATE TABLE IF NOT EXISTS user_interaction (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            interaction_type TEXT NOT NULL,
            symbol TEXT NOT NULL,
            timestamp TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
            duration_seconds INTEGER,
            source_page TEXT
          )
        ''');
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_user_interaction_symbol ON user_interaction(symbol)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_user_interaction_type ON user_interaction(interaction_type)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_user_interaction_time ON user_interaction(timestamp)',
        );

        // Sprint 11: 建立 user_preference 表
        // 注意：updated_at 使用 TEXT 格式 (ISO8601) 以匹配 Drift 的 dateTime() 預設行為
        await customStatement('''
          CREATE TABLE IF NOT EXISTS user_preference (
            preference_type TEXT NOT NULL,
            preference_value TEXT NOT NULL,
            weight REAL NOT NULL DEFAULT 0,
            updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
            PRIMARY KEY (preference_type, preference_value)
          )
        ''');
      }

      // v12: recommendation_validation 加 unique constraint 防止重複驗證
      if (from < 12) {
        await customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_rec_validation_unique '
          'ON recommendation_validation(recommendation_date, symbol, holding_days)',
        );
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'afterclose.db'));
    return NativeDatabase.createInBackground(file);
  });
}
