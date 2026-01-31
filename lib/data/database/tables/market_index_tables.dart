import 'package:drift/drift.dart';

/// 大盤指數歷史表
///
/// 儲存每日的市場指數收盤資料，供大盤總覽走勢圖使用。
/// 資料來源：TWSE MI_INDEX API (type=IND)
@DataClassName('MarketIndexEntry')
@TableIndex(name: 'idx_market_index_date', columns: {#date})
@TableIndex(name: 'idx_market_index_name', columns: {#name})
class MarketIndex extends Table {
  /// 自動遞增 ID
  IntColumn get id => integer().autoIncrement()();

  /// 交易日期
  DateTimeColumn get date => dateTime()();

  /// 指數名稱（原始全名，如「發行量加權股價指數」）
  TextColumn get name => text()();

  /// 收盤值
  RealColumn get close => real()();

  /// 漲跌點數
  RealColumn get change => real()();

  /// 漲跌幅 (%)
  RealColumn get changePercent => real()();

  /// 建立時間
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {date, name},
      ];
}
