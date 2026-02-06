import 'package:drift/drift.dart';

import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';

/// 持股相關 Repository
///
/// 處理：外資持股、股權分散表
class ShareholdingRepository {
  ShareholdingRepository({
    required AppDatabase database,
    required FinMindClient finMindClient,
  }) : _db = database,
       _client = finMindClient;

  final AppDatabase _db;
  final FinMindClient _client;

  // ============================================
  // 外資持股
  // ============================================

  /// 取得外資持股歷史資料
  Future<List<ShareholdingEntry>> getShareholdingHistory(
    String symbol, {
    int days = 60,
  }) async {
    final startDate = DateTime.now().subtract(Duration(days: days + 30));
    return _db.getShareholdingHistory(symbol, startDate: startDate);
  }

  /// 取得股票最新外資持股資料
  Future<ShareholdingEntry?> getLatestShareholding(String symbol) {
    return _db.getLatestShareholding(symbol);
  }

  /// 從 FinMind 同步外資持股資料
  ///
  /// 包含新鮮度檢查以避免不必要的 API 呼叫。
  /// 若 [endDate]（或今日）的資料已存在則跳過。
  Future<int> syncShareholding(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      // 新鮮度檢查：若已有目標日期資料則跳過
      final targetDate = endDate ?? DateTime.now();
      final latest = await getLatestShareholding(symbol);
      if (latest != null && _isSameDay(latest.date, targetDate)) {
        return 0;
      }

      final data = await _client.getShareholding(
        stockId: symbol,
        startDate: DateContext.formatYmd(startDate),
        endDate: endDate != null ? DateContext.formatYmd(endDate) : null,
      );

      final entries = data.map((item) {
        return ShareholdingCompanion.insert(
          symbol: item.stockId,
          date: DateTime.parse(item.date),
          foreignRemainingShares: Value(item.foreignInvestmentRemainingShares),
          foreignSharesRatio: Value(item.foreignInvestmentSharesRatio),
          foreignUpperLimitRatio: Value(item.foreignInvestmentUpperLimitRatio),
          sharesIssued: Value(item.numberOfSharesIssued),
        );
      }).toList();

      await _db.insertShareholdingData(entries);
      return entries.length;
    } on RateLimitException {
      AppLogger.warning('ShareholdingRepo', '$symbol: 外資持股同步觸發 API 速率限制');
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync shareholding for $symbol', e);
    }
  }

  /// 檢查外資持股比例是否增加中
  Future<bool> isForeignShareholdingIncreasing(
    String symbol, {
    int days = 5,
  }) async {
    final history = await getShareholdingHistory(symbol, days: days + 10);
    if (history.length < days) return false;

    final recent = history.reversed.take(days).toList();
    if (recent.length < 2) return false;

    final first = recent.last.foreignSharesRatio ?? 0;
    final last = recent.first.foreignSharesRatio ?? 0;

    return last > first;
  }

  // ============================================
  // 股權分散表
  // ============================================

  /// 取得最新股權分散表
  Future<List<HoldingDistributionEntry>> getLatestHoldingDistribution(
    String symbol,
  ) {
    return _db.getLatestHoldingDistribution(symbol);
  }

  /// 同步股權分散表資料
  ///
  /// 包含新鮮度檢查以避免不必要的 API 呼叫。
  /// 股權分散表每週公布，若已有本週資料則跳過。
  ///
  /// 註：此 API 需要 FinMind 付費訂閱。
  Future<int> syncHoldingDistribution(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      // 新鮮度檢查：若已有本週資料則跳過
      final latestDate = await _db.getLatestHoldingDistributionDate(symbol);
      if (latestDate != null && _isSameWeek(latestDate, DateTime.now())) {
        return 0;
      }

      final data = await _client.getHoldingSharesPer(
        stockId: symbol,
        startDate: DateContext.formatYmd(startDate),
        endDate: endDate != null ? DateContext.formatYmd(endDate) : null,
      );

      final entries = data.map((item) {
        return HoldingDistributionCompanion.insert(
          symbol: item.stockId,
          date: DateTime.parse(item.date),
          level: item.holdingSharesLevel,
          shareholders: Value(item.people),
          percent: Value(item.percent),
          shares: Value(item.unit),
        );
      }).toList();

      await _db.insertHoldingDistribution(entries);
      return entries.length;
    } on RateLimitException {
      AppLogger.warning('ShareholdingRepo', '$symbol: 股權分散表同步觸發 API 速率限制');
      rethrow;
    } catch (e) {
      throw DatabaseException(
        'Failed to sync holding distribution for $symbol',
        e,
      );
    }
  }

  /// 計算籌碼集中度（大戶持股比例）
  ///
  /// 回傳持股超過 [threshold] 張的股東持股百分比
  Future<double?> getConcentrationRatio(
    String symbol, {
    int thresholdLevel = 400, // 400張 = 40萬股
  }) async {
    final distribution = await getLatestHoldingDistribution(symbol);
    if (distribution.isEmpty) return null;

    double largeHolderPercent = 0;

    for (final entry in distribution) {
      // 解析級距以取得最小持股數
      // 級距如 "400-600"、"600-800"、"800-1000"、"1000以上"
      final level = entry.level;
      final minShares = _parseMinSharesFromLevel(level);

      if (minShares >= thresholdLevel) {
        largeHolderPercent += entry.percent ?? 0;
      }
    }

    return largeHolderPercent;
  }

  // ============================================
  // Private helpers
  // ============================================

  /// 檢查兩個日期是否為同一天（忽略時間）
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 檢查兩個日期是否在同一週（週一至週日）
  bool _isSameWeek(DateTime a, DateTime b) {
    // 正規化至該週開始（週一）
    final aWeekStart = a.subtract(Duration(days: a.weekday - 1));
    final bWeekStart = b.subtract(Duration(days: b.weekday - 1));
    return _isSameDay(aWeekStart, bWeekStart);
  }

  /// 從級距字串解析最小持股數
  int _parseMinSharesFromLevel(String level) {
    // 處理 "1000以上" 或 "over 1000"
    if (level.contains('以上') || level.toLowerCase().contains('over')) {
      final numStr = level.replaceAll(RegExp(r'[^\d]'), '');
      return int.tryParse(numStr) ?? 0;
    }

    // 處理 "400-600" 格式
    final parts = level.split('-');
    if (parts.isNotEmpty) {
      final numStr = parts[0].replaceAll(RegExp(r'[^\d]'), '');
      return int.tryParse(numStr) ?? 0;
    }

    return 0;
  }
}
