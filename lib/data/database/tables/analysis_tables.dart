import 'package:drift/drift.dart';

import 'package:afterclose/data/database/tables/stock_master.dart';

/// 每日分析結果 Table（每日資料不可變）
@DataClassName('DailyAnalysisEntry')
@TableIndex(name: 'idx_daily_analysis_date', columns: {#date})
@TableIndex(name: 'idx_daily_analysis_score', columns: {#score})
@TableIndex(name: 'idx_daily_analysis_symbol_date', columns: {#symbol, #date})
class DailyAnalysis extends Table {
  /// 股票代碼
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// 分析日期
  DateTimeColumn get date => dateTime()();

  /// 趨勢狀態：UP（上漲）、DOWN（下跌）、RANGE（盤整）
  TextColumn get trendState => text()();

  /// 反轉狀態：NONE（無）、W2S（弱轉強）、S2W（強轉弱）
  TextColumn get reversalState => text().withDefault(const Constant('NONE'))();

  /// 支撐價位
  RealColumn get supportLevel => real().nullable()();

  /// 壓力價位
  RealColumn get resistanceLevel => real().nullable()();

  /// 所有觸發規則的總分數
  RealColumn get score => real().withDefault(const Constant(0))();

  /// 分析運算時間
  DateTimeColumn get computedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {symbol, date};
}

/// 每日分析觸發原因 Table
@DataClassName('DailyReasonEntry')
@TableIndex(name: 'idx_daily_reason_symbol_date', columns: {#symbol, #date})
class DailyReason extends Table {
  /// 股票代碼
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// 分析日期
  DateTimeColumn get date => dateTime()();

  /// 原因排序（1 = 主要、2 = 次要）
  IntColumn get rank => integer()();

  /// 原因類型代碼
  TextColumn get reasonType => text()();

  /// 證據資料（JSON 格式）
  TextColumn get evidenceJson => text()();

  /// 此規則的分數
  RealColumn get ruleScore => real().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {symbol, date, rank};
}

/// 每日推薦股票 Table（Top N）
@DataClassName('DailyRecommendationEntry')
@TableIndex(name: 'idx_daily_recommendation_date', columns: {#date})
@TableIndex(name: 'idx_daily_recommendation_symbol', columns: {#symbol})
@TableIndex(
  name: 'idx_daily_recommendation_date_symbol',
  columns: {#date, #symbol},
)
class DailyRecommendation extends Table {
  /// 推薦日期
  DateTimeColumn get date => dateTime()();

  /// 排名（1-10）
  IntColumn get rank => integer()();

  /// 股票代碼
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// 總分數
  RealColumn get score => real()();

  @override
  Set<Column> get primaryKey => {date, rank};

  @override
  List<Set<Column>> get uniqueKeys => [
    {date, symbol},
  ];
}
