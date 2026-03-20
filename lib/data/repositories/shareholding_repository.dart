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

  // ==================================================
  // 外資持股
  // ==================================================

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
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync shareholding for $symbol', e);
    }
  }

  // ==================================================
  // 股權分散表
  // ==================================================

  /// 批次取得多檔股票的最新持股資料
  @override
  Future<Map<String, ShareholdingEntry>> getLatestShareholdingsBatch(
    List<String> symbols,
  ) {
    return _db.getLatestShareholdingsBatch(symbols);
  }

  /// 取得最新股權分散表
  @override
  Future<List<HoldingDistributionEntry>> getLatestHoldingDistribution(
    String symbol,
  ) {
    return _db.getLatestHoldingDistribution(symbol);
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

  // ==================================================
  // 私有輔助方法
  // ==================================================

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
