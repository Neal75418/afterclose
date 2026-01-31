import 'package:drift/drift.dart';

import 'package:afterclose/data/database/tables/stock_master.dart';

/// 使用者自選股清單 Table
@DataClassName('WatchlistEntry')
class Watchlist extends Table {
  /// 股票代碼
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// 加入自選股的時間
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {symbol};
}

/// 使用者股票筆記 Table
@DataClassName('UserNoteEntry')
class UserNote extends Table {
  /// 自動遞增 ID
  IntColumn get id => integer().autoIncrement()();

  /// 股票代碼
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// 筆記對應的日期（可為空）
  DateTimeColumn get date => dateTime().nullable()();

  /// 筆記內容
  TextColumn get content => text()();

  /// 建立時間
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// 最後更新時間
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// 交易策略卡 Table
@DataClassName('StrategyCardEntry')
class StrategyCard extends Table {
  /// 自動遞增 ID
  IntColumn get id => integer().autoIncrement()();

  /// 股票代碼
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// 策略目標日期
  DateTimeColumn get forDate => dateTime().nullable()();

  /// 條件 A
  TextColumn get ifA => text().nullable()();

  /// 條件 A 成立時的操作
  TextColumn get thenA => text().nullable()();

  /// 條件 B
  TextColumn get ifB => text().nullable()();

  /// 條件 B 成立時的操作
  TextColumn get thenB => text().nullable()();

  /// 其他情況的操作
  TextColumn get elsePlan => text().nullable()();

  /// 建立時間
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// 最後更新時間
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// 資料更新執行紀錄 Table
@DataClassName('UpdateRunEntry')
class UpdateRun extends Table {
  /// 自動遞增 ID
  IntColumn get id => integer().autoIncrement()();

  /// 更新的目標日期
  DateTimeColumn get runDate => dateTime()();

  /// 開始執行時間
  DateTimeColumn get startedAt => dateTime().withDefault(currentDateAndTime)();

  /// 完成時間（執行中則為空）
  DateTimeColumn get finishedAt => dateTime().nullable()();

  /// 狀態：SUCCESS、FAILED、PARTIAL
  TextColumn get status => text()();

  /// 訊息（錯誤詳情等）
  TextColumn get message => text().nullable()();
}

/// 應用程式設定 Table（Key-Value 儲存）
@DataClassName('AppSettingEntry')
class AppSettings extends Table {
  /// 設定鍵
  TextColumn get key => text()();

  /// 設定值
  TextColumn get value => text()();

  /// 最後更新時間
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}

/// 股價提醒 Table
///
/// 提醒類型：
/// - ABOVE：價格高於目標價
/// - BELOW：價格低於目標價
/// - CHANGE_PCT：當日漲跌幅超過百分比
@DataClassName('PriceAlertEntry')
class PriceAlert extends Table {
  /// 自動遞增 ID
  IntColumn get id => integer().autoIncrement()();

  /// 股票代碼
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// 提醒類型：ABOVE、BELOW、CHANGE_PCT
  TextColumn get alertType => text()();

  /// 目標值（價格或百分比）
  RealColumn get targetValue => real()();

  /// 是否啟用
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// 觸發時間（尚未觸發則為空）
  DateTimeColumn get triggeredAt => dateTime().nullable()();

  /// 備註說明
  TextColumn get note => text().nullable()();

  /// 建立時間
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// 自訂選股策略 Table
@DataClassName('ScreeningStrategyEntry')
class ScreeningStrategyTable extends Table {
  /// 自動遞增 ID
  IntColumn get id => integer().autoIncrement()();

  /// 策略名稱
  TextColumn get name => text().withLength(min: 1, max: 100)();

  /// 篩選條件（JSON array）
  TextColumn get conditionsJson => text()();

  /// 建立時間
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// 最後更新時間
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
