import 'package:drift/drift.dart';

import 'package:afterclose/data/database/tables/stock_master.dart';

/// 使用者自訂分組 Table（資料夾模式：一檔股票只歸屬一個分組）
///
/// 與內建的 `none/status/trend` 自動分組正交：此表是使用者手動建立、可命名的
/// 分組。[Watchlist.groupId] 以 FK 指回此表，刪除分組時成員的 groupId 會被
/// `KeyAction.setNull` 清空（成員回到「未分組」、不會連帶刪除股票）。
@DataClassName('WatchlistGroupEntry')
class WatchlistGroups extends Table {
  /// 自動遞增 ID
  IntColumn get id => integer().autoIncrement()();

  /// 分組名稱（使用者自訂）
  TextColumn get name => text().withLength(min: 1, max: 50)();

  /// 排序順序（數字越小越前面，預設 0）
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// 建立時間
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// 使用者自選股清單 Table
@DataClassName('WatchlistEntry')
class Watchlist extends Table {
  /// 股票代碼
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// 加入自選股的時間
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// 所屬自訂分組 ID（null 代表未分組）
  ///
  /// 刪除分組時 `KeyAction.setNull` 會把成員的 groupId 清空，不刪股票。
  IntColumn get groupId => integer().nullable().references(
    WatchlistGroups,
    #id,
    onDelete: KeyAction.setNull,
  )();

  @override
  Set<Column> get primaryKey => {symbol};
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
