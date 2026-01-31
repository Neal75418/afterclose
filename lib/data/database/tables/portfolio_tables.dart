import 'package:drift/drift.dart';

import 'package:afterclose/data/database/tables/stock_master.dart';

/// 投資組合持倉 Table
///
/// 每支股票一筆記錄，記錄聚合後的持倉資訊。
/// 由 PortfolioTransaction 記錄計算而來（avgCost, quantity）。
@DataClassName('PortfolioPositionEntry')
@TableIndex(name: 'idx_portfolio_position_symbol', columns: {#symbol})
class PortfolioPosition extends Table {
  /// 自動遞增 ID
  IntColumn get id => integer().autoIncrement()();

  /// 股票代碼
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// 持有股數（可為 0，代表已清倉但保留記錄）
  RealColumn get quantity => real().withDefault(const Constant(0))();

  /// 平均成本（元/股）
  RealColumn get avgCost => real().withDefault(const Constant(0))();

  /// 已實現損益（元）
  RealColumn get realizedPnl => real().withDefault(const Constant(0))();

  /// 累計收到的現金股利（元）
  RealColumn get totalDividendReceived =>
      real().withDefault(const Constant(0))();

  /// 備註
  TextColumn get note => text().nullable()();

  /// 建立時間
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  /// 最後更新時間
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// 交易紀錄 Table
///
/// 記錄每筆買賣與配息。
/// 類型：BUY, SELL, DIVIDEND_CASH, DIVIDEND_STOCK
@DataClassName('PortfolioTransactionEntry')
@TableIndex(name: 'idx_portfolio_tx_symbol', columns: {#symbol})
@TableIndex(name: 'idx_portfolio_tx_date', columns: {#date})
class PortfolioTransaction extends Table {
  /// 自動遞增 ID
  IntColumn get id => integer().autoIncrement()();

  /// 股票代碼
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// 交易類型：BUY, SELL, DIVIDEND_CASH, DIVIDEND_STOCK
  TextColumn get txType => text()();

  /// 交易日期
  DateTimeColumn get date => dateTime()();

  /// 數量（股）
  RealColumn get quantity => real()();

  /// 單價（元/股）
  RealColumn get price => real()();

  /// 手續費（元）
  RealColumn get fee => real().withDefault(const Constant(0))();

  /// 交易稅（元）
  RealColumn get tax => real().withDefault(const Constant(0))();

  /// 備註
  TextColumn get note => text().nullable()();

  /// 建立時間
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}
