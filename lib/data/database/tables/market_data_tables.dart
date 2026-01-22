import 'package:drift/drift.dart';

import 'package:afterclose/data/database/tables/stock_master.dart';

/// Foreign investor shareholding data (外資持股比例)
@DataClassName('ShareholdingEntry')
@TableIndex(name: 'idx_shareholding_symbol', columns: {#symbol})
@TableIndex(name: 'idx_shareholding_date', columns: {#date})
class Shareholding extends Table {
  /// Stock symbol
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// Trading date
  DateTimeColumn get date => dateTime()();

  /// Foreign investment remaining shares (外資持股餘額)
  RealColumn get foreignRemainingShares => real().nullable()();

  /// Foreign investment shares ratio (外資持股比例%)
  RealColumn get foreignSharesRatio => real().nullable()();

  /// Foreign investment upper limit ratio (外資持股上限比例%)
  RealColumn get foreignUpperLimitRatio => real().nullable()();

  /// Number of shares issued (已發行股數)
  RealColumn get sharesIssued => real().nullable()();

  @override
  Set<Column> get primaryKey => {symbol, date};
}

/// Day trading data (當沖資料)
@DataClassName('DayTradingEntry')
@TableIndex(name: 'idx_day_trading_symbol', columns: {#symbol})
@TableIndex(name: 'idx_day_trading_date', columns: {#date})
class DayTrading extends Table {
  /// Stock symbol
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// Trading date
  DateTimeColumn get date => dateTime()();

  /// Day trading buy volume (當沖買進量)
  RealColumn get buyVolume => real().nullable()();

  /// Day trading sell volume (當沖賣出量)
  RealColumn get sellVolume => real().nullable()();

  /// Day trading ratio percentage (當沖比例%)
  RealColumn get dayTradingRatio => real().nullable()();

  /// Total trade volume (總成交量)
  RealColumn get tradeVolume => real().nullable()();

  @override
  Set<Column> get primaryKey => {symbol, date};
}

/// Financial statement data (財務報表資料)
/// Note: Stores key-value pairs from income statement, balance sheet, cash flow
@DataClassName('FinancialDataEntry')
@TableIndex(name: 'idx_financial_data_symbol', columns: {#symbol})
@TableIndex(name: 'idx_financial_data_date', columns: {#date})
@TableIndex(name: 'idx_financial_data_type', columns: {#dataType})
class FinancialData extends Table {
  /// Stock symbol
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// Report date (YYYY-QQ format stored as date)
  DateTimeColumn get date => dateTime()();

  /// Statement type: INCOME, BALANCE, CASHFLOW
  TextColumn get statementType => text()();

  /// Data type (e.g., Revenue, NetIncome, TotalAssets)
  TextColumn get dataType => text()();

  /// Value in thousands (千元)
  RealColumn get value => real().nullable()();

  /// Original Chinese name
  TextColumn get originName => text().nullable()();

  @override
  Set<Column> get primaryKey => {symbol, date, statementType, dataType};
}

/// Adjusted stock price data (還原股價)
@DataClassName('AdjustedPriceEntry')
@TableIndex(name: 'idx_adjusted_price_symbol', columns: {#symbol})
@TableIndex(name: 'idx_adjusted_price_date', columns: {#date})
class AdjustedPrice extends Table {
  /// Stock symbol
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// Trading date
  DateTimeColumn get date => dateTime()();

  /// Adjusted opening price
  RealColumn get open => real().nullable()();

  /// Adjusted highest price
  RealColumn get high => real().nullable()();

  /// Adjusted lowest price
  RealColumn get low => real().nullable()();

  /// Adjusted closing price
  RealColumn get close => real().nullable()();

  /// Trading volume
  RealColumn get volume => real().nullable()();

  @override
  Set<Column> get primaryKey => {symbol, date};
}

/// Weekly stock price data (週K線)
@DataClassName('WeeklyPriceEntry')
@TableIndex(name: 'idx_weekly_price_symbol', columns: {#symbol})
@TableIndex(name: 'idx_weekly_price_date', columns: {#date})
class WeeklyPrice extends Table {
  /// Stock symbol
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// Week ending date
  DateTimeColumn get date => dateTime()();

  /// Weekly opening price
  RealColumn get open => real().nullable()();

  /// Weekly highest price
  RealColumn get high => real().nullable()();

  /// Weekly lowest price
  RealColumn get low => real().nullable()();

  /// Weekly closing price
  RealColumn get close => real().nullable()();

  /// Weekly trading volume
  RealColumn get volume => real().nullable()();

  @override
  Set<Column> get primaryKey => {symbol, date};
}

/// Shareholding distribution data (股權分散表)
/// Note: This is denormalized - one row per level per date
@DataClassName('HoldingDistributionEntry')
@TableIndex(name: 'idx_holding_dist_symbol', columns: {#symbol})
@TableIndex(name: 'idx_holding_dist_date', columns: {#date})
class HoldingDistribution extends Table {
  /// Stock symbol
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// Report date
  DateTimeColumn get date => dateTime()();

  /// Holding level (e.g., "1-999", "1000-5000")
  TextColumn get level => text()();

  /// Number of shareholders at this level
  IntColumn get shareholders => integer().nullable()();

  /// Percentage of total shares (%)
  RealColumn get percent => real().nullable()();

  /// Number of shares (unit: 股)
  RealColumn get shares => real().nullable()();

  @override
  Set<Column> get primaryKey => {symbol, date, level};
}

/// Monthly revenue data (月營收)
/// For fundamental analysis signals
@DataClassName('MonthlyRevenueEntry')
@TableIndex(name: 'idx_monthly_revenue_symbol', columns: {#symbol})
@TableIndex(name: 'idx_monthly_revenue_date', columns: {#date})
class MonthlyRevenue extends Table {
  /// Stock symbol
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// Report date (use first day of the month for consistency)
  DateTimeColumn get date => dateTime()();

  /// Revenue year
  IntColumn get revenueYear => integer()();

  /// Revenue month
  IntColumn get revenueMonth => integer()();

  /// Monthly revenue (千元)
  RealColumn get revenue => real()();

  /// Month-over-month growth rate (%)
  RealColumn get momGrowth => real().nullable()();

  /// Year-over-year growth rate (%)
  RealColumn get yoyGrowth => real().nullable()();

  @override
  Set<Column> get primaryKey => {symbol, date};
}

/// Stock valuation data (估值資料: PE, PBR, 殖利率)
/// For fundamental analysis signals
@DataClassName('StockValuationEntry')
@TableIndex(name: 'idx_stock_valuation_symbol', columns: {#symbol})
@TableIndex(name: 'idx_stock_valuation_date', columns: {#date})
class StockValuation extends Table {
  /// Stock symbol
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// Trading date
  DateTimeColumn get date => dateTime()();

  /// Price-to-Earnings ratio (本益比)
  RealColumn get per => real().nullable()();

  /// Price-to-Book ratio (股價淨值比)
  RealColumn get pbr => real().nullable()();

  /// Dividend yield (殖利率 %)
  RealColumn get dividendYield => real().nullable()();

  @override
  Set<Column> get primaryKey => {symbol, date};
}
