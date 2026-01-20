import 'package:drift/drift.dart';

/// Stock master table - 股票主檔
@DataClassName('StockMasterEntry')
class StockMaster extends Table {
  /// Stock symbol (e.g., "2330")
  TextColumn get symbol => text()();

  /// Stock name (e.g., "台積電")
  TextColumn get name => text()();

  /// Market: "TWSE" | "TPEx"
  TextColumn get market => text()();

  /// Industry category (nullable)
  TextColumn get industry => text().nullable()();

  /// Whether the stock is actively traded
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// Last update timestamp
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {symbol};
}
