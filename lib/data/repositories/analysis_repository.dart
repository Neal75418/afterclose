import 'package:drift/drift.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/repositories/analysis_repository.dart';

import 'package:afterclose/core/utils/taiwan_calendar.dart';

/// 分析結果與推薦股 Repository 實作
class AnalysisRepository implements IAnalysisRepository {
  AnalysisRepository({required AppDatabase database}) : _db = database;

  final AppDatabase _db;

  // ==========================================
  // 每日分析
  // ==========================================

  /// 取得特定股票和日期的分析結果
  @override
  Future<DailyAnalysisEntry?> getAnalysis(String symbol, DateTime date) {
    return _db.getAnalysis(symbol, _normalizeDate(date));
  }

  /// 取得某日期的所有分析結果
  @override
  Future<List<DailyAnalysisEntry>> getAnalysesForDate(DateTime date) {
    return _db.getAnalysisForDate(_normalizeDate(date));
  }

  /// 儲存分析結果
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
  // 每日原因
  // ==========================================

  /// 取得股票在某日期的觸發原因
  @override
  Future<List<DailyReasonEntry>> getReasons(String symbol, DateTime date) {
    return _db.getReasons(symbol, _normalizeDate(date));
  }

  /// 儲存股票的觸發原因（原子性取代既有原因）
  @override
  Future<void> saveReasons(
    String symbol,
    DateTime date,
    List<ReasonData> reasons,
  ) async {
    // 限制最大原因數
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

    // 使用原子性取代確保一致性
    await _db.replaceReasons(symbol, normalizedDate, entries);
  }

  // ==========================================
  // 每日推薦股
  // ==========================================

  /// 取得今日推薦股
  ///
  /// 智慧回退：若今日為假日/週末且無資料，
  /// 回傳最近一個交易日的推薦股。
  @override
  Future<List<DailyRecommendationEntry>> getTodayRecommendations() async {
    final now = DateTime.now();

    // 1. 先嘗試取得今日資料
    final todayRecs = await getRecommendations(now);
    if (todayRecs.isNotEmpty) {
      return todayRecs;
    }

    // 2. 若今日非交易日（週末/假日），嘗試取得前一交易日
    // 確保使用者能看到最新市場資料（如週六看到週五資料）
    if (!TaiwanCalendar.isTradingDay(now)) {
      final prevTradingDay = TaiwanCalendar.getPreviousTradingDay(now);
      return getRecommendations(prevTradingDay);
    }

    // 3. 交易日但尚無資料（更新前）-> 回傳空清單
    return [];
  }

  /// 取得某日期的推薦股
  @override
  Future<List<DailyRecommendationEntry>> getRecommendations(DateTime date) {
    return _db.getRecommendations(_normalizeDate(date));
  }

  /// 儲存每日推薦股（原子性取代既有推薦）
  @override
  Future<void> saveRecommendations(
    DateTime date,
    List<RecommendationData> recommendations,
  ) async {
    // 限制為 Top N
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

    // 使用原子性取代確保一致性
    await _db.replaceRecommendations(normalizedDate, entries);
  }

  /// 檢查某日期是否有推薦股
  @override
  Future<bool> hasRecommendations(DateTime date) async {
    final recs = await getRecommendations(date);
    return recs.isNotEmpty;
  }

  // ==========================================
  // 冷卻期檢查
  // ==========================================

  /// 檢查股票是否近期曾被推薦（單一查詢）
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

  /// 取得所有近期曾被推薦的股票（供批次冷卻期檢查）
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
  // 資料清理
  // ==========================================

  /// 清除指定日期的所有原因記錄
  @override
  Future<int> clearReasonsForDate(DateTime date) {
    return _db.clearReasonsForDate(_normalizeDate(date));
  }

  /// 清除指定日期的所有分析記錄
  @override
  Future<int> clearAnalysisForDate(DateTime date) {
    return _db.clearAnalysisForDate(_normalizeDate(date));
  }

  // ==========================================
  // UI 用組合查詢
  // ==========================================

  /// 取得推薦股及其詳細資訊（批次查詢最佳化）
  ///
  /// 使用批次查詢避免 N+1 問題：
  /// - 1 次查詢取得推薦股
  /// - 1 次查詢取得所有股票資訊（批次）
  /// - 1 次查詢取得所有原因（批次）
  /// 共 3 次查詢，而非 1 + N*2 次
  @override
  Future<List<RecommendationWithStock>> getRecommendationsWithDetails(
    DateTime date,
  ) async {
    final recs = await getRecommendations(date);
    if (recs.isEmpty) return [];

    // 收集所有股票代碼供批次查詢
    final symbols = recs.map((r) => r.symbol).toList();
    final normalizedDate = _normalizeDate(date);

    // 平行執行批次查詢
    final results = await Future.wait([
      _db.getStocksBatch(symbols),
      _db.getReasonsBatch(symbols, normalizedDate),
    ]);

    final stocksMap = results[0] as Map<String, StockMasterEntry>;
    final reasonsMap = results[1] as Map<String, List<DailyReasonEntry>>;

    // 從批次資料組合結果
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

  /// 正規化日期至本地時間當日開始（移除時間部分）
  ///
  /// 使用本地時間以匹配資料庫儲存格式
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
