import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

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
        MarketOverviewDaoMixin {
  AppDatabase() : super(_openConnection());

  /// 測試用 - 建立記憶體內 Database
  AppDatabase.forTesting() : super(NativeDatabase.memory());

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
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'afterclose');
}
