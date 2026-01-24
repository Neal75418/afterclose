import 'package:afterclose/data/database/app_database.dart';

/// 分析結果與推薦的資料儲存庫介面
///
/// 支援測試時的 Mock 及不同實作（如本機資料庫、遠端 API、記憶體快取）
abstract class IAnalysisRepository {
  // ==========================================
  // 每日分析
  // ==========================================

  /// 取得特定股票在指定日期的分析結果
  Future<DailyAnalysisEntry?> getAnalysis(String symbol, DateTime date);

  /// 取得指定日期的所有分析結果
  Future<List<DailyAnalysisEntry>> getAnalysesForDate(DateTime date);

  /// 儲存分析結果
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
  // 每日原因
  // ==========================================

  /// 取得特定股票在指定日期的推薦原因
  Future<List<DailyReasonEntry>> getReasons(String symbol, DateTime date);

  /// 儲存股票的推薦原因（原子性取代現有原因）
  Future<void> saveReasons(
    String symbol,
    DateTime date,
    List<ReasonData> reasons,
  );

  // ==========================================
  // 每日推薦
  // ==========================================

  /// 取得今日推薦清單
  Future<List<DailyRecommendationEntry>> getTodayRecommendations();

  /// 取得指定日期的推薦清單
  Future<List<DailyRecommendationEntry>> getRecommendations(DateTime date);

  /// 儲存每日推薦（原子性取代現有推薦）
  Future<void> saveRecommendations(
    DateTime date,
    List<RecommendationData> recommendations,
  );

  /// 檢查指定日期是否已有推薦
  Future<bool> hasRecommendations(DateTime date);

  // ==========================================
  // 冷卻期檢查
  // ==========================================

  /// 檢查股票是否近期已被推薦（單一查詢）
  Future<bool> wasRecentlyRecommended(String symbol, {int days});

  /// 取得近期已被推薦的所有股票代碼（用於批次冷卻期檢查）
  Future<Set<String>> getRecentlyRecommendedSymbols({int days});

  // ==========================================
  // UI 用組合查詢
  // ==========================================

  /// 取得推薦及股票詳細資訊（已優化為批次查詢）
  Future<List<RecommendationWithStock>> getRecommendationsWithDetails(
    DateTime date,
  );
}

/// 儲存推薦原因的資料類別
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

/// 儲存推薦的資料類別
class RecommendationData {
  const RecommendationData({required this.symbol, required this.score});

  final String symbol;
  final double score;
}

/// UI 顯示用的組合資料
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
