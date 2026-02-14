import 'package:drift/drift.dart';

import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/domain/repositories/shareholding_repository.dart';

/// 持股相關 Repository
///
/// 處理：外資持股、股權分散表
class ShareholdingRepository implements IShareholdingRepository {
  ShareholdingRepository({
    required AppDatabase database,
    required FinMindClient finMindClient,
    AppClock clock = const SystemClock(),
  }) : _db = database,
       _client = finMindClient,
       _clock = clock;

  final AppDatabase _db;
  final FinMindClient _client;
  final AppClock _clock;

  // ============================================
  // 外資持股
  // ============================================

  /// 取得外資持股歷史資料
  @override
  Future<List<ShareholdingEntry>> getShareholdingHistory(
    String symbol, {
    int days = 60,
  }) async {
    final startDate = _clock.now().subtract(Duration(days: days + 30));
    return _db.getShareholdingHistory(symbol, startDate: startDate);
  }

  /// 取得股票最新外資持股資料
  @override
  Future<ShareholdingEntry?> getLatestShareholding(String symbol) {
    return _db.getLatestShareholding(symbol);
  }

  /// 從 FinMind 同步外資持股資料
  ///
  /// 包含新鮮度檢查以避免不必要的 API 呼叫。
  /// 若 [endDate]（或今日）的資料已存在則跳過。
  @override
  Future<int> syncShareholding(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      // 新鮮度檢查：若已有目標日期資料則跳過
      final targetDate = endDate ?? _clock.now();
      final latest = await getLatestShareholding(symbol);
      if (latest != null && DateContext.isSameDay(latest.date, targetDate)) {
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
  @override
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
  @override
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
  @override
  Future<int> syncHoldingDistribution(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      // 新鮮度檢查：若已有本週資料則跳過
      final latestDate = await _db.getLatestHoldingDistributionDate(symbol);
      if (latestDate != null &&
          DateContext.isSameWeek(latestDate, _clock.now())) {
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
  @override
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

  /// 批次計算多檔股票的籌碼集中度
  ///
  /// 回傳 symbol -> 大戶持股比例(%) 的 Map。
  /// 無資料的股票不會出現在結果中。
  @override
  Future<Map<String, double>> getConcentrationRatioBatch(
    List<String> symbols, {
    int thresholdLevel = 400,
  }) async {
    final batchData = await _db.getLatestHoldingDistributionBatch(symbols);
    final result = <String, double>{};

    for (final entry in batchData.entries) {
      double largeHolderPercent = 0;
      for (final dist in entry.value) {
        final minShares = _parseMinSharesFromLevel(dist.level);
        if (minShares >= thresholdLevel) {
          largeHolderPercent += dist.percent ?? 0;
        }
      }
      result[entry.key] = largeHolderPercent;
    }

    return result;
  }

  // ============================================
  // Private helpers
  // ============================================

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
