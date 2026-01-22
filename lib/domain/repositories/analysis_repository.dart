import 'package:afterclose/data/database/app_database.dart';

/// Interface for analysis results and recommendations repository
///
/// Enables mocking in tests and allows for different implementations
/// (e.g., local database, remote API, in-memory cache).
abstract class IAnalysisRepository {
  // ==========================================
  // Daily Analysis
  // ==========================================

  /// Get analysis for a specific stock and date
  Future<DailyAnalysisEntry?> getAnalysis(String symbol, DateTime date);

  /// Get all analyses for a date
  Future<List<DailyAnalysisEntry>> getAnalysesForDate(DateTime date);

  /// Save analysis result
  Future<void> saveAnalysis({
    required String symbol,
    required DateTime date,
    required String trendState,
    required String reversalState,
    double? supportLevel,
    double? resistanceLevel,
    required double score,
  });

  // ==========================================
  // Daily Reasons
  // ==========================================

  /// Get reasons for a stock on a date
  Future<List<DailyReasonEntry>> getReasons(String symbol, DateTime date);

  /// Save reasons for a stock (replaces existing reasons atomically)
  Future<void> saveReasons(
    String symbol,
    DateTime date,
    List<ReasonData> reasons,
  );

  // ==========================================
  // Daily Recommendations
  // ==========================================

  /// Get today's recommendations
  Future<List<DailyRecommendationEntry>> getTodayRecommendations();

  /// Get recommendations for a date
  Future<List<DailyRecommendationEntry>> getRecommendations(DateTime date);

  /// Save daily recommendations (replaces existing recommendations atomically)
  Future<void> saveRecommendations(
    DateTime date,
    List<RecommendationData> recommendations,
  );

  /// Check if recommendations exist for date
  Future<bool> hasRecommendations(DateTime date);

  // ==========================================
  // Cooldown Check
  // ==========================================

  /// Check if a stock was recently recommended (single query)
  Future<bool> wasRecentlyRecommended(String symbol, {int days});

  /// Get all symbols that were recently recommended (for batch cooldown check)
  Future<Set<String>> getRecentlyRecommendedSymbols({int days});

  // ==========================================
  // Combined Queries for UI
  // ==========================================

  /// Get recommendation with stock details (optimized with batch queries)
  Future<List<RecommendationWithStock>> getRecommendationsWithDetails(
    DateTime date,
  );
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
