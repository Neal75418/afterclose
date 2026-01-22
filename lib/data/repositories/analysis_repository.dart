import 'package:drift/drift.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/repositories/analysis_repository.dart';

/// Repository implementation for analysis results and recommendations
class AnalysisRepository implements IAnalysisRepository {
  AnalysisRepository({required AppDatabase database}) : _db = database;

  final AppDatabase _db;

  // ==========================================
  // Daily Analysis
  // ==========================================

  /// Get analysis for a specific stock and date
  @override
  Future<DailyAnalysisEntry?> getAnalysis(String symbol, DateTime date) {
    return _db.getAnalysis(symbol, _normalizeDate(date));
  }

  /// Get all analyses for a date
  @override
  Future<List<DailyAnalysisEntry>> getAnalysesForDate(DateTime date) {
    return _db.getAnalysisForDate(_normalizeDate(date));
  }

  /// Save analysis result
  @override
  Future<void> saveAnalysis({
    required String symbol,
    required DateTime date,
    required String trendState,
    required String reversalState,
    double? supportLevel,
    double? resistanceLevel,
    required double score,
  }) {
    return _db.insertAnalysis(
      DailyAnalysisCompanion.insert(
        symbol: symbol,
        date: _normalizeDate(date),
        trendState: trendState,
        reversalState: Value(reversalState),
        supportLevel: Value(supportLevel),
        resistanceLevel: Value(resistanceLevel),
        score: Value(score),
      ),
    );
  }

  // ==========================================
  // Daily Reasons
  // ==========================================

  /// Get reasons for a stock on a date
  @override
  Future<List<DailyReasonEntry>> getReasons(String symbol, DateTime date) {
    return _db.getReasons(symbol, _normalizeDate(date));
  }

  /// Save reasons for a stock (replaces existing reasons atomically)
  @override
  Future<void> saveReasons(
    String symbol,
    DateTime date,
    List<ReasonData> reasons,
  ) async {
    // Limit to max reasons
    final limitedReasons = reasons.take(RuleParams.maxReasonsPerStock).toList();
    final normalizedDate = _normalizeDate(date);

    final entries = <DailyReasonCompanion>[];
    for (var i = 0; i < limitedReasons.length; i++) {
      final reason = limitedReasons[i];
      entries.add(
        DailyReasonCompanion.insert(
          symbol: symbol,
          date: normalizedDate,
          rank: i + 1,
          reasonType: reason.type,
          evidenceJson: reason.evidenceJson,
          ruleScore: Value(reason.score.toDouble()),
        ),
      );
    }

    // Use atomic replace to ensure consistency
    await _db.replaceReasons(symbol, normalizedDate, entries);
  }

  // ==========================================
  // Daily Recommendations
  // ==========================================

  /// Get today's recommendations
  @override
  Future<List<DailyRecommendationEntry>> getTodayRecommendations() {
    return getRecommendations(DateTime.now());
  }

  /// Get recommendations for a date
  @override
  Future<List<DailyRecommendationEntry>> getRecommendations(DateTime date) {
    return _db.getRecommendations(_normalizeDate(date));
  }

  /// Save daily recommendations (replaces existing recommendations atomically)
  @override
  Future<void> saveRecommendations(
    DateTime date,
    List<RecommendationData> recommendations,
  ) async {
    // Limit to top N
    final limited = recommendations.take(RuleParams.dailyTopN).toList();
    final normalizedDate = _normalizeDate(date);

    final entries = <DailyRecommendationCompanion>[];
    for (var i = 0; i < limited.length; i++) {
      final rec = limited[i];
      entries.add(
        DailyRecommendationCompanion.insert(
          date: normalizedDate,
          rank: i + 1,
          symbol: rec.symbol,
          score: rec.score,
        ),
      );
    }

    // Use atomic replace to ensure consistency
    await _db.replaceRecommendations(normalizedDate, entries);
  }

  /// Check if recommendations exist for date
  @override
  Future<bool> hasRecommendations(DateTime date) async {
    final recs = await getRecommendations(date);
    return recs.isNotEmpty;
  }

  // ==========================================
  // Cooldown Check
  // ==========================================

  /// Check if a stock was recently recommended (single query)
  @override
  Future<bool> wasRecentlyRecommended(
    String symbol, {
    int days = RuleParams.cooldownDays,
  }) {
    final now = DateTime.now();
    final endDate = _normalizeDate(now.subtract(const Duration(days: 1)));
    final startDate = _normalizeDate(now.subtract(Duration(days: days)));

    return _db.wasSymbolRecommendedInRange(
      symbol,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Get all symbols that were recently recommended (for batch cooldown check)
  @override
  Future<Set<String>> getRecentlyRecommendedSymbols({
    int days = RuleParams.cooldownDays,
  }) {
    final now = DateTime.now();
    final endDate = _normalizeDate(now.subtract(const Duration(days: 1)));
    final startDate = _normalizeDate(now.subtract(Duration(days: days)));

    return _db.getRecommendedSymbolsInRange(
      startDate: startDate,
      endDate: endDate,
    );
  }

  // ==========================================
  // Combined Queries for UI
  // ==========================================

  /// Get recommendation with stock details (optimized with batch queries)
  ///
  /// Uses batch queries to avoid N+1 problem:
  /// - 1 query for recommendations
  /// - 1 query for all stocks (batch)
  /// - 1 query for all reasons (batch)
  /// Total: 3 queries instead of 1 + N*2
  @override
  Future<List<RecommendationWithStock>> getRecommendationsWithDetails(
    DateTime date,
  ) async {
    final recs = await getRecommendations(date);
    if (recs.isEmpty) return [];

    // Collect all symbols for batch queries
    final symbols = recs.map((r) => r.symbol).toList();
    final normalizedDate = _normalizeDate(date);

    // Execute batch queries in parallel
    final results = await Future.wait([
      _db.getStocksBatch(symbols),
      _db.getReasonsBatch(symbols, normalizedDate),
    ]);

    final stocksMap = results[0] as Map<String, StockMasterEntry>;
    final reasonsMap = results[1] as Map<String, List<DailyReasonEntry>>;

    // Build results from batch data
    final output = <RecommendationWithStock>[];
    for (final rec in recs) {
      final stock = stocksMap[rec.symbol];
      if (stock != null) {
        output.add(
          RecommendationWithStock(
            recommendation: rec,
            stock: stock,
            reasons: reasonsMap[rec.symbol] ?? [],
          ),
        );
      }
    }

    return output;
  }

  /// Normalize date to start of day in UTC (remove time component)
  ///
  /// Using UTC ensures consistent behavior across timezones
  DateTime _normalizeDate(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }
}
