import 'package:drift/drift.dart';

import 'package:afterclose/data/database/tables/stock_master.dart';

/// 每日 OHLCV 價格資料 Table
@DataClassName('DailyPriceEntry')
@TableIndex(name: 'idx_daily_price_symbol', columns: {#symbol})
@TableIndex(name: 'idx_daily_price_date', columns: {#date})
@TableIndex(name: 'idx_daily_price_symbol_date', columns: {#symbol, #date})
class DailyPrice extends Table {
  /// 股票代碼
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// 交易日期（以 UTC 儲存）
  DateTimeColumn get date => dateTime()();

  /// 開盤價
  RealColumn get open => real().nullable()();

  /// 最高價
  RealColumn get high => real().nullable()();

  /// 最低價
  RealColumn get low => real().nullable()();

  /// 收盤價
  RealColumn get close => real().nullable()();

  /// 成交量（張）
  RealColumn get volume => real().nullable()();

  @override
  Set<Column> get primaryKey => {symbol, date};
}
