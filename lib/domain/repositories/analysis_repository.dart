import 'package:afterclose/core/constants/calibrated_scores/horizon.dart';
import 'package:afterclose/data/database/app_database.dart';

/// 分析結果與推薦的資料儲存庫介面
///
/// 支援測試時的 Mock 及不同實作（如本機資料庫、遠端 API、記憶體快取）
abstract class IAnalysisRepository {
  // ==================================================
  // 每日分析
  // ==================================================

  /// 取得特定股票在指定日期的分析結果
  Future<DailyAnalysisEntry?> getAnalysis(String symbol, DateTime date);

  /// 儲存分析結果
  ///
  /// Stage 5b dual-horizon: [scoreShort] 與 [scoreLong] 取代舊的單一 `score`。
  /// Commit 2 時 scoring pipeline 仍為單分數，caller 暫時對兩個參數傳
  /// 相同值；Commit 3 的 pipeline 改動會真正產生不同值。
  Future<void> saveAnalysis({
    required String symbol,
    required DateTime date,
    required String trendState,
    required String reversalState,
    double? supportLevel,
    double? resistanceLevel,
    required double scoreShort,
    required double scoreLong,
  });

  // ==================================================
  // 每日原因
  // ==================================================

  /// 取得特定股票在指定日期的推薦原因
  Future<List<DailyReasonEntry>> getReasons(String symbol, DateTime date);

  /// 儲存股票的推薦原因（原子性取代現有原因）
  Future<void> saveReasons(
    String symbol,
    DateTime date,
    List<ReasonData> reasons,
  );

  // ==================================================
  // 每日推薦
  // ==================================================

  /// 取得今日推薦清單
  Future<List<DailyRecommendationEntry>> getTodayRecommendations();

  /// 取得指定日期的推薦清單
  Future<List<DailyRecommendationEntry>> getRecommendations(DateTime date);

  /// 儲存每日推薦（原子性取代現有推薦）
  ///
  /// Stage 5b dual-horizon: [horizon] 必填，只取代該 horizon 的推薦列，
  /// 另一個 horizon 的列不受影響。每日最多 2 * [RuleParams.dailyTopN] 列
  /// （短線 + 長線各一份 Top 20）。
  Future<void> saveRecommendations(
    DateTime date,
    List<RecommendationData> recommendations, {
    required Horizon horizon,
  });

  // ==================================================
  // 冷卻期檢查
  // ==================================================

  /// 檢查股票是否近期已被推薦（單一查詢）
  Future<bool> wasRecentlyRecommended(String symbol, {int days});

  /// 取得近期已被推薦的所有股票代碼（用於批次冷卻期檢查）
  Future<Set<String>> getRecentlyRecommendedSymbols({int days});

  // ==================================================
  // 智慧日期回退
  // ==================================================

  /// 尋找最近有分析資料的日期和結果
  ///
  /// 依序嘗試今天、昨天、前天，若 3 天都無資料則回退至前一交易日。
  /// 所有日期已正規化，安全用於資料庫查詢。
  Future<({DateTime targetDate, List<DailyAnalysisEntry> analyses})>
  findLatestAnalyses();

  /// 尋找最近有分析資料的日期
  ///
  /// 若完全無資料則回傳 null。
  Future<DateTime?> findLatestAnalysisDate();

  // ==================================================
  // 資料清理
  // ==================================================

  /// 清除指定日期的所有原因記錄
  ///
  /// 在每日評分前呼叫，確保不會有舊的原因記錄殘留。
  /// 這解決了當股票不再觸發任何規則時，舊原因仍保留在資料庫的問題。
  Future<int> clearReasonsForDate(DateTime date);

  /// 清除指定日期的所有分析記錄
  ///
  /// 在每日評分前呼叫，確保不會有舊的分析記錄殘留。
  Future<int> clearAnalysisForDate(DateTime date);

  // ==================================================
  // UI 用組合查詢
  // ==================================================

  /// 取得推薦及股票詳細資訊（已優化為批次查詢）
  Future<List<RecommendationWithStock>> getRecommendationsWithDetails(
    DateTime date,
  );

  // ==================================================
  // 交易控制
  // ==================================================

  /// 在單一資料庫 transaction 內執行回呼
  Future<T> runInTransaction<T>(Future<T> Function() action);
}

/// 儲存推薦原因的資料類別
///
/// Stage 5b dual-horizon: [scoreShort] 與 [scoreLong] 分別代表此規則在
/// 短線 / 長線 horizon 下的 calibrated / fallback 分數。scoring pipeline
/// 在 isolate 內對每一條 reason 都會查兩個 horizon 的分數後一併放進此 DTO。
class ReasonData {
  const ReasonData({
    required this.type,
    required this.evidenceJson,
    required this.scoreShort,
    required this.scoreLong,
  });

  final String type;
  final String evidenceJson;
  final int scoreShort;
  final int scoreLong;
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
