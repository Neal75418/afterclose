import 'package:drift/drift.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';

/// Repository for analysis results and recommendations
class AnalysisRepository {
  AnalysisRepository({required AppDatabase database}) : _db = database;

  final AppDatabase _db;

  // ==========================================
  // Daily Analysis
  // ==========================================

  /// Get analysis for a specific stock and date
  Future<DailyAnalysisEntry?> getAnalysis(String symbol, DateTime date) {
    return _db.getAnalysis(symbol, _normalizeDate(date));
  }

  /// Get all analyses for a date
  Future<List<DailyAnalysisEntry>> getAnalysesForDate(DateTime date) {
    return _db.getAnalysisForDate(_normalizeDate(date));
  }

  /// Save analysis result
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
  Future<List<DailyReasonEntry>> getReasons(String symbol, DateTime date) {
    return _db.getReasons(symbol, _normalizeDate(date));
  }

  /// Save reasons for a stock
  Future<void> saveReasons(
    String symbol,
    DateTime date,
    List<ReasonData> reasons,
  ) async {
    // Limit to max reasons
    final limitedReasons = reasons.take(RuleParams.maxReasonsPerStock).toList();

    final entries = <DailyReasonCompanion>[];
    for (var i = 0; i < limitedReasons.length; i++) {
      final reason = limitedReasons[i];
      entries.add(
        DailyReasonCompanion.insert(
          symbol: symbol,
          date: _normalizeDate(date),
          rank: i + 1,
          reasonType: reason.type,
          evidenceJson: reason.evidenceJson,
          ruleScore: Value(reason.score.toDouble()),
        ),
      );
    }

    await _db.insertReasons(entries);
  }

  // ==========================================
  // Daily Recommendations
  // ==========================================

  /// Get today's recommendations
  Future<List<DailyRecommendationEntry>> getTodayRecommendations() {
    return getRecommendations(DateTime.now());
  }

  /// Get recommendations for a date
  Future<List<DailyRecommendationEntry>> getRecommendations(DateTime date) {
    return _db.getRecommendations(_normalizeDate(date));
  }

  /// Save daily recommendations
  Future<void> saveRecommendations(
    DateTime date,
    List<RecommendationData> recommendations,
  ) async {
    // Limit to top N
    final limited = recommendations.take(RuleParams.dailyTopN).toList();

    final entries = <DailyRecommendationCompanion>[];
    for (var i = 0; i < limited.length; i++) {
      final rec = limited[i];
      entries.add(
        DailyRecommendationCompanion.insert(
          date: _normalizeDate(date),
          rank: i + 1,
          symbol: rec.symbol,
          score: rec.score,
        ),
      );
    }

    await _db.insertRecommendations(entries);
  }

  /// Check if recommendations exist for date
  Future<bool> hasRecommendations(DateTime date) async {
    final recs = await getRecommendations(date);
    return recs.isNotEmpty;
  }

  // ==========================================
  // Cooldown Check
  // ==========================================

  /// Check if a stock was recently recommended
  Future<bool> wasRecentlyRecommended(
    String symbol, {
    int days = RuleParams.cooldownDays,
  }) async {
    // Check recommendations for past N days
    for (var i = 0; i < days; i++) {
      final checkDate = DateTime.now().subtract(Duration(days: i + 1));
      final recs = await getRecommendations(checkDate);
      if (recs.any((r) => r.symbol == symbol)) {
        return true;
      }
    }

    return false;
  }

  // ==========================================
  // Combined Queries for UI
  // ==========================================

  /// Get recommendation with stock details
  Future<List<RecommendationWithStock>> getRecommendationsWithDetails(
    DateTime date,
  ) async {
    final recs = await getRecommendations(date);
    final results = <RecommendationWithStock>[];

    for (final rec in recs) {
      final stock = await _db.getStock(rec.symbol);
      final reasons = await getReasons(rec.symbol, date);

      if (stock != null) {
        results.add(
          RecommendationWithStock(
            recommendation: rec,
            stock: stock,
            reasons: reasons,
          ),
        );
      }
    }

    return results;
  }

  /// Normalize date to start of day (remove time component)
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}

/// Data class for saving reasons
class ReasonData {
  const ReasonData({
    required this.type,
    required this.evidenceJson,
    required this.score,
  });

  final String type;
  final String evidenceJson;
  final int score;
}

/// Data class for saving recommendations
class RecommendationData {
  const RecommendationData({required this.symbol, required this.score});

  final String symbol;
  final double score;
}

/// Combined data for UI display
class RecommendationWithStock {
  const RecommendationWithStock({
    required this.recommendation,
    required this.stock,
    required this.reasons,
  });

  final DailyRecommendationEntry recommendation;
  final StockMasterEntry stock;
  final List<DailyReasonEntry> reasons;
}
