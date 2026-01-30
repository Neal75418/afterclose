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

/// 股利歷史 Table
///
/// 儲存歷年現金股利、股票股利、除權息日期
@DataClassName('DividendHistoryEntry')
@TableIndex(name: 'idx_dividend_history_symbol', columns: {#symbol})
class DividendHistory extends Table {
  /// 股票代碼
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// 股利所屬年度
  IntColumn get year => integer()();

  /// 現金股利（元）
  RealColumn get cashDividend => real().withDefault(const Constant(0))();

  /// 股票股利（元）
  RealColumn get stockDividend => real().withDefault(const Constant(0))();

  /// 除息日（格式: yyyy-MM-dd）
  TextColumn get exDividendDate => text().nullable()();

  /// 除權日（格式: yyyy-MM-dd）
  TextColumn get exRightsDate => text().nullable()();

  @override
  Set<Column> get primaryKey => {symbol, year};
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

/// 注意股票/處置股票 Table
///
/// 用於風險控管：
/// - 注意股票 (ATTENTION): 交易量異常、價格異常波動
/// - 處置股票 (DISPOSAL): 嚴重異常，交易受限制
@DataClassName('TradingWarningEntry')
@TableIndex(name: 'idx_trading_warning_symbol', columns: {#symbol})
@TableIndex(name: 'idx_trading_warning_date', columns: {#date})
@TableIndex(name: 'idx_trading_warning_type', columns: {#warningType})
class TradingWarning extends Table {
  /// 股票代碼
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// 公告日期
  DateTimeColumn get date => dateTime()();

  /// 警示類型：ATTENTION（注意）| DISPOSAL（處置）
  TextColumn get warningType => text()();

  /// 列入原因代碼
  TextColumn get reasonCode => text().nullable()();

  /// 原因說明
  TextColumn get reasonDescription => text().nullable()();

  /// 處置措施（僅處置股）
  TextColumn get disposalMeasures => text().nullable()();

  /// 處置起始日
  DateTimeColumn get disposalStartDate => dateTime().nullable()();

  /// 處置結束日
  DateTimeColumn get disposalEndDate => dateTime().nullable()();

  /// 是否目前生效
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {symbol, date, warningType};
}

/// 董監事持股餘額 Table
///
/// 用於內部人持股變化追蹤：
/// - 連續減持為強賣訊號
/// - 大量增持為買進訊號
/// - 高質押率為風險警示
@DataClassName('InsiderHoldingEntry')
@TableIndex(name: 'idx_insider_holding_symbol', columns: {#symbol})
@TableIndex(name: 'idx_insider_holding_date', columns: {#date})
class InsiderHolding extends Table {
  /// 股票代碼
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// 報告日期（月報）
  DateTimeColumn get date => dateTime()();

  /// 董事持股總數（股）
  RealColumn get directorShares => real().nullable()();

  /// 監察人持股總數（股）
  RealColumn get supervisorShares => real().nullable()();

  /// 經理人持股總數（股）
  RealColumn get managerShares => real().nullable()();

  /// 董監持股比例（%）
  RealColumn get insiderRatio => real().nullable()();

  /// 質押比例（%）
  RealColumn get pledgeRatio => real().nullable()();

  /// 持股變動（股）- 與前期比較
  RealColumn get sharesChange => real().nullable()();

  /// 已發行股數
  RealColumn get sharesIssued => real().nullable()();

  @override
  Set<Column> get primaryKey => {symbol, date};
}
