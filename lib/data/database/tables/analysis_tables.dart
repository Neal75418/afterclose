import 'package:drift/drift.dart';

import 'package:afterclose/data/database/tables/stock_master.dart';

/// Daily analysis result (immutable per day)
@DataClassName('DailyAnalysisEntry')
@TableIndex(name: 'idx_daily_analysis_date', columns: {#date})
@TableIndex(name: 'idx_daily_analysis_score', columns: {#score})
class DailyAnalysis extends Table {
  /// Stock symbol
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// Analysis date
  DateTimeColumn get date => dateTime()();

  /// Trend state: UP, DOWN, RANGE
  TextColumn get trendState => text()();

  /// Reversal state: NONE, W2S, S2W
  TextColumn get reversalState => text().withDefault(const Constant('NONE'))();

  /// Support price level
  RealColumn get supportLevel => real().nullable()();

  /// Resistance price level
  RealColumn get resistanceLevel => real().nullable()();

  /// Total score from all triggered rules
  RealColumn get score => real().withDefault(const Constant(0))();

  /// When this analysis was computed
  DateTimeColumn get computedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {symbol, date};
}

/// Triggered reasons for a stock on a given day
@DataClassName('DailyReasonEntry')
@TableIndex(name: 'idx_daily_reason_symbol_date', columns: {#symbol, #date})
class DailyReason extends Table {
  /// Stock symbol (foreign key to StockMaster)
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// Analysis date
  DateTimeColumn get date => dateTime()();

  /// Reason rank (1 = primary, 2 = secondary)
  IntColumn get rank => integer()();

  /// Reason type code
  TextColumn get reasonType => text()();

  /// Evidence data as JSON
  TextColumn get evidenceJson => text()();

  /// Score for this specific rule
  RealColumn get ruleScore => real().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {symbol, date, rank};
}

/// Daily top N recommendations
@DataClassName('DailyRecommendationEntry')
@TableIndex(name: 'idx_daily_recommendation_date', columns: {#date})
@TableIndex(name: 'idx_daily_recommendation_symbol', columns: {#symbol})
class DailyRecommendation extends Table {
  /// Recommendation date
  DateTimeColumn get date => dateTime()();

  /// Rank position (1-10)
  IntColumn get rank => integer()();

  /// Stock symbol
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  /// Total score
  RealColumn get score => real()();

  @override
  Set<Column> get primaryKey => {date, rank};

  @override
  List<Set<Column>> get uniqueKeys => [
    {date, symbol},
  ];
}
