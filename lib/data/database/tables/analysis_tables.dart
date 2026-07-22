import 'package:drift/drift.dart';

import 'package:afterclose/data/database/tables/stock_master.dart';

/// 每日分析結果 Table（每日資料不可變）
///
/// Dual-horizon: `score` 欄位拆分為 `scoreShort` + `scoreLong`，
/// 技術分析欄位（trendState / reversalState / support / resistance）
/// 是 horizon-agnostic 仍維持單欄位。
@DataClassName('DailyAnalysisEntry')
@TableIndex(name: 'idx_daily_analysis_date', columns: {#date})
@TableIndex(name: 'idx_daily_analysis_score_short', columns: {#scoreShort})
@TableIndex(name: 'idx_daily_analysis_score_long', columns: {#scoreLong})
@TableIndex(name: 'idx_daily_analysis_symbol_date', columns: {#symbol, #date})
@TableIndex(
  name: 'idx_daily_analysis_date_score_short',
  columns: {#date, #scoreShort},
)
@TableIndex(
  name: 'idx_daily_analysis_date_score_long',
  columns: {#date, #scoreLong},
)
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

  /// 短線（5 日）所有觸發規則的總分數
  RealColumn get scoreShort => real().withDefault(const Constant(0))();

  /// 長線（60 日）所有觸發規則的總分數
  RealColumn get scoreLong => real().withDefault(const Constant(0))();

  /// 分析運算時間
  DateTimeColumn get computedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {symbol, date};
}

/// 每日分析觸發原因 Table
///
/// Dual-horizon: `ruleScore` 欄位拆分為 `ruleScoreShort` +
/// `ruleScoreLong`，同一條 rule 在兩個 horizon 下的分數貢獻可能不同
/// （calibrated JSON 為空時兩者相等，走 hardcoded fallback）。
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

  /// 此規則在短線 horizon 的分數貢獻
  RealColumn get ruleScoreShort => real().withDefault(const Constant(0))();

  /// 此規則在長線 horizon 的分數貢獻
  RealColumn get ruleScoreLong => real().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {symbol, date, rank};
}

/// 每日推薦股票 Table（Top N）
///
/// Dual-horizon: 加入 `horizon` pivot column，PK 改為
/// `(date, horizon, rank)`，每天最多 40 rows（20 短 + 20 長）。
/// 同一檔股票若在兩個 horizon 都上榜會有兩 rows，各自帶 per-horizon
/// 的 rank 與 score。
@DataClassName('DailyRecommendationEntry')
@TableIndex(
  name: 'idx_daily_recommendation_date_horizon',
  columns: {#date, #horizon},
)
@TableIndex(name: 'idx_daily_recommendation_symbol', columns: {#symbol})
@TableIndex(
  name: 'idx_daily_recommendation_date_horizon_symbol',
  columns: {#date, #horizon, #symbol},
)
class DailyRecommendation extends Table {
  /// 推薦日期
  DateTimeColumn get date => dateTime()();

  /// Horizon pivot：'short' 或 'long'（對應 `Horizon.name`）
  TextColumn get horizon => text()();

  /// 此 horizon 內的排名（1..dailyTopN）
  IntColumn get rank => integer()();

  /// 股票代碼
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// 此 horizon 的分數
  RealColumn get score => real()();

  @override
  Set<Column> get primaryKey => {date, horizon, rank};

  @override
  List<Set<Column>> get uniqueKeys => [
    {date, horizon, symbol},
  ];
}

/// 規則準確度追蹤表
///
/// 記錄每條規則的歷史表現，用於計算命中率和平均報酬率。
@DataClassName('RuleAccuracyEntry')
@TableIndex(name: 'idx_rule_accuracy_rule', columns: {#ruleId})
class RuleAccuracy extends Table {
  /// 規則 ID（如 reversal_w2s）
  TextColumn get ruleId => text()();

  /// 統計週期：「N 天 + D」持有天數字串（如 5D、20D、60D）
  TextColumn get period => text()();

  /// 觸發次數
  IntColumn get triggerCount => integer().withDefault(const Constant(0))();

  /// 成功次數（N 日後上漲）
  IntColumn get successCount => integer().withDefault(const Constant(0))();

  /// 平均報酬率（%）
  RealColumn get avgReturn => real().withDefault(const Constant(0))();

  /// 最後更新時間
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {ruleId, period};
}

/// 推薦驗證記錄表
///
/// 記錄每次推薦的後續表現，用於回溯驗證。
@DataClassName('RecommendationValidationEntry')
@TableIndex(name: 'idx_rec_validation_date', columns: {#recommendationDate})
@TableIndex(name: 'idx_rec_validation_symbol', columns: {#symbol})
class RecommendationValidation extends Table {
  /// 自增 ID
  IntColumn get id => integer().autoIncrement()();

  /// 推薦日期
  DateTimeColumn get recommendationDate => dateTime()();

  /// 股票代碼
  TextColumn get symbol => text()();

  /// 主要觸發規則
  TextColumn get primaryRuleId => text()();

  /// 推薦當日收盤價
  RealColumn get entryPrice => real()();

  /// N 日後收盤價
  RealColumn get exitPrice => real().nullable()();

  /// N 日後報酬率（%）
  RealColumn get returnRate => real().nullable()();

  /// 是否成功（報酬 > 0）
  BoolColumn get isSuccess => boolean().nullable()();

  /// 驗證日期（N 日後的日期）
  DateTimeColumn get validationDate => dateTime().nullable()();

  /// 驗證天數（預設 5 日）
  IntColumn get holdingDays => integer().withDefault(const Constant(5))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {recommendationDate, symbol, holdingDays},
  ];
}
