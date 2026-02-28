import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/domain/services/technical_indicator_service.dart';
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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from == 1) {
        // Drop personalization tables (removed as dead code)
        await m.deleteTable('user_interaction');
        await m.deleteTable('user_preference');
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
