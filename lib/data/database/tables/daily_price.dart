import 'package:drift/drift.dart';

import 'package:afterclose/data/database/tables/stock_master.dart';

/// Daily OHLCV price data
@DataClassName('DailyPriceEntry')
class DailyPrice extends Table {
  /// Stock symbol
  TextColumn get symbol => text().references(StockMaster, #symbol)();

  /// Trading date (YYYY-MM-DD)
  DateTimeColumn get date => dateTime()();

  /// Opening price
  RealColumn get open => real().nullable()();

  /// Highest price
  RealColumn get high => real().nullable()();

  /// Lowest price
  RealColumn get low => real().nullable()();

  /// Closing price
  RealColumn get close => real().nullable()();

  /// Trading volume
  RealColumn get volume => real().nullable()();

  @override
  Set<Column> get primaryKey => {symbol, date};
}
