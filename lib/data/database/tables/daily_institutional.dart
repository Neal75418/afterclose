import 'package:drift/drift.dart';

import 'package:afterclose/data/database/tables/stock_master.dart';

/// Daily institutional trading data (optional)
@DataClassName('DailyInstitutionalEntry')
class DailyInstitutional extends Table {
  /// Stock symbol
  TextColumn get symbol => text().references(StockMaster, #symbol)();

  /// Trading date
  DateTimeColumn get date => dateTime()();

  /// Foreign institutional net buy/sell
  RealColumn get foreignNet => real().nullable()();

  /// Investment trust net buy/sell
  RealColumn get investmentTrustNet => real().nullable()();

  /// Dealer net buy/sell
  RealColumn get dealerNet => real().nullable()();

  @override
  Set<Column> get primaryKey => {symbol, date};
}
