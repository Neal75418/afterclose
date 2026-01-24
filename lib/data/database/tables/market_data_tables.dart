import 'package:drift/drift.dart';

import 'package:afterclose/data/database/tables/stock_master.dart';

/// 外資持股資料 Table
@DataClassName('ShareholdingEntry')
@TableIndex(name: 'idx_shareholding_symbol', columns: {#symbol})
@TableIndex(name: 'idx_shareholding_date', columns: {#date})
class Shareholding extends Table {
  /// 股票代碼
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// 交易日期
  DateTimeColumn get date => dateTime()();

  /// 外資持股餘額（股）
  RealColumn get foreignRemainingShares => real().nullable()();

  /// 外資持股比例（%）
  RealColumn get foreignSharesRatio => real().nullable()();

  /// 外資持股上限比例（%）
  RealColumn get foreignUpperLimitRatio => real().nullable()();

  /// 已發行股數
  RealColumn get sharesIssued => real().nullable()();

  @override
  Set<Column> get primaryKey => {symbol, date};
}

/// 當沖資料 Table
///
/// **資料來源說明：**
/// - FinMind API：提供實際股數
/// - TWSE TWTB4U API：買賣欄位提供金額（元）
///
/// [dayTradingRatio] 為交易訊號使用的主要指標，
/// 由每日價量資料另行計算。
@DataClassName('DayTradingEntry')
@TableIndex(name: 'idx_day_trading_symbol', columns: {#symbol})
@TableIndex(name: 'idx_day_trading_date', columns: {#date})
class DayTrading extends Table {
  /// 股票代碼
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// 交易日期
  DateTimeColumn get date => dateTime()();

  /// 當沖買進量/金額
  ///
  /// 註：TWSE API 提供金額（元），FinMind 提供股數
  RealColumn get buyVolume => real().nullable()();

  /// 當沖賣出量/金額
  ///
  /// 註：TWSE API 提供金額（元），FinMind 提供股數
  RealColumn get sellVolume => real().nullable()();

  /// 當沖比例（%）
  ///
  /// 此為主要指標，由總成交量計算。
  RealColumn get dayTradingRatio => real().nullable()();

  /// 當沖成交股數
  RealColumn get tradeVolume => real().nullable()();

  @override
  Set<Column> get primaryKey => {symbol, date};
}

/// 財務報表資料 Table
///
/// 儲存損益表、資產負債表、現金流量表的 Key-Value 資料
@DataClassName('FinancialDataEntry')
@TableIndex(name: 'idx_financial_data_symbol', columns: {#symbol})
@TableIndex(name: 'idx_financial_data_date', columns: {#date})
@TableIndex(name: 'idx_financial_data_type', columns: {#dataType})
class FinancialData extends Table {
  /// 股票代碼
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// 報告日期（季度以日期格式儲存）
  DateTimeColumn get date => dateTime()();

  /// 報表類型：INCOME、BALANCE、CASHFLOW
  TextColumn get statementType => text()();

  /// 資料項目（如 Revenue、NetIncome、TotalAssets）
  TextColumn get dataType => text()();

  /// 數值（千元）
  RealColumn get value => real().nullable()();

  /// 原始中文名稱
  TextColumn get originName => text().nullable()();

  @override
  Set<Column> get primaryKey => {symbol, date, statementType, dataType};
}

/// 還原股價 Table
@DataClassName('AdjustedPriceEntry')
@TableIndex(name: 'idx_adjusted_price_symbol', columns: {#symbol})
@TableIndex(name: 'idx_adjusted_price_date', columns: {#date})
class AdjustedPrice extends Table {
  /// 股票代碼
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// 交易日期
  DateTimeColumn get date => dateTime()();

  /// 還原開盤價
  RealColumn get open => real().nullable()();

  /// 還原最高價
  RealColumn get high => real().nullable()();

  /// 還原最低價
  RealColumn get low => real().nullable()();

  /// 還原收盤價
  RealColumn get close => real().nullable()();

  /// 成交量
  RealColumn get volume => real().nullable()();

  @override
  Set<Column> get primaryKey => {symbol, date};
}

/// 週K線 Table
@DataClassName('WeeklyPriceEntry')
@TableIndex(name: 'idx_weekly_price_symbol', columns: {#symbol})
@TableIndex(name: 'idx_weekly_price_date', columns: {#date})
class WeeklyPrice extends Table {
  /// 股票代碼
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// 週結束日期
  DateTimeColumn get date => dateTime()();

  /// 週開盤價
  RealColumn get open => real().nullable()();

  /// 週最高價
  RealColumn get high => real().nullable()();

  /// 週最低價
  RealColumn get low => real().nullable()();

  /// 週收盤價
  RealColumn get close => real().nullable()();

  /// 週成交量
  RealColumn get volume => real().nullable()();

  @override
  Set<Column> get primaryKey => {symbol, date};
}

/// 股權分散表 Table
///
/// 每個持股級距一筆資料（非正規化設計）
@DataClassName('HoldingDistributionEntry')
@TableIndex(name: 'idx_holding_dist_symbol', columns: {#symbol})
@TableIndex(name: 'idx_holding_dist_date', columns: {#date})
class HoldingDistribution extends Table {
  /// 股票代碼
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// 報告日期
  DateTimeColumn get date => dateTime()();

  /// 持股級距（如 "1-999"、"1000-5000"）
  TextColumn get level => text()();

  /// 該級距股東人數
  IntColumn get shareholders => integer().nullable()();

  /// 佔總股數比例（%）
  RealColumn get percent => real().nullable()();

  /// 持股數（股）
  RealColumn get shares => real().nullable()();

  @override
  Set<Column> get primaryKey => {symbol, date, level};
}

/// 月營收 Table
///
/// 用於基本面分析訊號
@DataClassName('MonthlyRevenueEntry')
@TableIndex(name: 'idx_monthly_revenue_symbol', columns: {#symbol})
@TableIndex(name: 'idx_monthly_revenue_date', columns: {#date})
class MonthlyRevenue extends Table {
  /// 股票代碼
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// 報告日期（統一使用當月第一天）
  DateTimeColumn get date => dateTime()();

  /// 營收年度
  IntColumn get revenueYear => integer()();

  /// 營收月份
  IntColumn get revenueMonth => integer()();

  /// 月營收（千元）
  RealColumn get revenue => real()();

  /// 月增率（%）
  RealColumn get momGrowth => real().nullable()();

  /// 年增率（%）
  RealColumn get yoyGrowth => real().nullable()();

  @override
  Set<Column> get primaryKey => {symbol, date};
}

/// 股票估值資料 Table（本益比、股價淨值比、殖利率）
///
/// 用於基本面分析訊號
@DataClassName('StockValuationEntry')
@TableIndex(name: 'idx_stock_valuation_symbol', columns: {#symbol})
@TableIndex(name: 'idx_stock_valuation_date', columns: {#date})
class StockValuation extends Table {
  /// 股票代碼
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// 交易日期
  DateTimeColumn get date => dateTime()();

  /// 本益比（PE ratio）
  RealColumn get per => real().nullable()();

  /// 股價淨值比（PB ratio）
  RealColumn get pbr => real().nullable()();

  /// 殖利率（%）
  RealColumn get dividendYield => real().nullable()();

  @override
  Set<Column> get primaryKey => {symbol, date};
}

/// 融資融券 Table
///
/// 用於籌碼分析訊號
@DataClassName('MarginTradingEntry')
@TableIndex(name: 'idx_margin_trading_symbol', columns: {#symbol})
@TableIndex(name: 'idx_margin_trading_date', columns: {#date})
class MarginTrading extends Table {
  /// 股票代碼
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// 交易日期
  DateTimeColumn get date => dateTime()();

  /// 融資買進（張）
  RealColumn get marginBuy => real().nullable()();

  /// 融資賣出（張）
  RealColumn get marginSell => real().nullable()();

  /// 融資餘額（張）
  RealColumn get marginBalance => real().nullable()();

  /// 融券買進/回補（張）
  RealColumn get shortBuy => real().nullable()();

  /// 融券賣出（張）
  RealColumn get shortSell => real().nullable()();

  /// 融券餘額（張）
  RealColumn get shortBalance => real().nullable()();

  @override
  Set<Column> get primaryKey => {symbol, date};
}
