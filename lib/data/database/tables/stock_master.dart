import 'package:drift/drift.dart';

/// 股票主檔 Table
@DataClassName('StockMasterEntry')
@TableIndex(name: 'idx_stock_master_industry', columns: {#industry})
class StockMaster extends Table {
  /// 股票代碼（如 "2330"）
  TextColumn get symbol => text()();

  /// 股票名稱（如「台積電」）
  TextColumn get name => text()();

  /// 市場：TWSE（上市）或 TPEx（上櫃）
  TextColumn get market => text()();

  /// 產業類別（可為空）
  TextColumn get industry => text().nullable()();

  /// 是否仍在交易
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// 最後更新時間
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {symbol};
}
