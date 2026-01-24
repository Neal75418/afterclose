import 'package:drift/drift.dart';

import 'package:afterclose/data/database/tables/stock_master.dart';

/// 三大法人每日買賣超 Table
@DataClassName('DailyInstitutionalEntry')
@TableIndex(name: 'idx_daily_institutional_symbol', columns: {#symbol})
@TableIndex(name: 'idx_daily_institutional_date', columns: {#date})
class DailyInstitutional extends Table {
  /// 股票代碼
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// 交易日期
  DateTimeColumn get date => dateTime()();

  /// 外資買賣超（張）
  RealColumn get foreignNet => real().nullable()();

  /// 投信買賣超（張）
  RealColumn get investmentTrustNet => real().nullable()();

  /// 自營商買賣超（張）
  RealColumn get dealerNet => real().nullable()();

  @override
  Set<Column> get primaryKey => {symbol, date};
}
