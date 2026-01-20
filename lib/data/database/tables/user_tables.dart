import 'package:drift/drift.dart';

import 'package:afterclose/data/database/tables/stock_master.dart';

/// User watchlist
@DataClassName('WatchlistEntry')
class Watchlist extends Table {
  /// Stock symbol
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// When added to watchlist
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {symbol};
}

/// User notes for stocks
@DataClassName('UserNoteEntry')
class UserNote extends Table {
  /// Auto-increment ID
  IntColumn get id => integer().autoIncrement()();

  /// Stock symbol
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// Optional date context for this note
  DateTimeColumn get date => dateTime().nullable()();

  /// Note content
  TextColumn get content => text()();

  /// Created timestamp
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Last updated timestamp
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Strategy cards for trading plans
@DataClassName('StrategyCardEntry')
class StrategyCard extends Table {
  /// Auto-increment ID
  IntColumn get id => integer().autoIncrement()();

  /// Stock symbol
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// Target date for this strategy
  DateTimeColumn get forDate => dateTime().nullable()();

  /// If condition A
  TextColumn get ifA => text().nullable()();

  /// Then action A
  TextColumn get thenA => text().nullable()();

  /// If condition B
  TextColumn get ifB => text().nullable()();

  /// Then action B
  TextColumn get thenB => text().nullable()();

  /// Else plan
  TextColumn get elsePlan => text().nullable()();

  /// Created timestamp
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Last updated timestamp
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Update run history
@DataClassName('UpdateRunEntry')
class UpdateRun extends Table {
  /// Auto-increment ID
  IntColumn get id => integer().autoIncrement()();

  /// Target date for this update
  DateTimeColumn get runDate => dateTime()();

  /// When the update started
  DateTimeColumn get startedAt => dateTime().withDefault(currentDateAndTime)();

  /// When the update finished (nullable if still running)
  DateTimeColumn get finishedAt => dateTime().nullable()();

  /// Status: SUCCESS, FAILED, PARTIAL
  TextColumn get status => text()();

  /// Optional message (error details, etc.)
  TextColumn get message => text().nullable()();
}

/// App settings (key-value store)
@DataClassName('AppSettingEntry')
class AppSettings extends Table {
  /// Setting key
  TextColumn get key => text()();

  /// Setting value
  TextColumn get value => text()();

  /// Last updated timestamp
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}

/// Price alerts for stocks
/// Alert types: ABOVE (price goes above), BELOW (price goes below), CHANGE_PCT (daily % change)
@DataClassName('PriceAlertEntry')
class PriceAlert extends Table {
  /// Auto-increment ID
  IntColumn get id => integer().autoIncrement()();

  /// Stock symbol
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// Alert type: ABOVE, BELOW, CHANGE_PCT
  TextColumn get alertType => text()();

  /// Target price (for ABOVE/BELOW) or percent (for CHANGE_PCT)
  RealColumn get targetValue => real()();

  /// Is this alert currently active
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// When the alert was triggered (null if not yet triggered)
  DateTimeColumn get triggeredAt => dateTime().nullable()();

  /// Note or description for this alert
  TextColumn get note => text().nullable()();

  /// Created timestamp
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
