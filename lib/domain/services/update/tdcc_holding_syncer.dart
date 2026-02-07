import 'package:drift/drift.dart';

import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/tdcc_client.dart';

/// TDCC 股權分散表同步器
///
/// 從 TDCC 集保中心 Open Data 取得全市場股權分散表，
/// 篩選候選股票後寫入 HoldingDistribution 表。
///
/// - 資料每週更新（週五收盤後公布）
/// - 一次 API 呼叫取得全市場資料，無需逐檔查詢
/// - 內建新鮮度檢查，同一週不重複同步
class TdccHoldingSyncer {
  TdccHoldingSyncer({
    required AppDatabase database,
    required TdccClient tdccClient,
  }) : _db = database,
       _tdcc = tdccClient;

  final AppDatabase _db;
  final TdccClient _tdcc;

  /// 同步股權分散表資料
  ///
  /// [candidateSymbols] 若提供，則只寫入這些股票的資料（節省 DB 空間）。
  /// 若為 null 則寫入全市場。
  ///
  /// 回傳寫入的股票數。
  Future<int> sync({Set<String>? candidateSymbols}) async {
    // 新鮮度檢查：使用任一常見股票代碼檢查是否已有本週資料
    if (await _hasCurrentWeekData()) {
      AppLogger.debug('TdccHoldingSyncer', '已有本週資料，跳過同步');
      return 0;
    }

    try {
      final allData = await _tdcc.getAllHoldingDistribution();
      if (allData.isEmpty) {
        AppLogger.warning('TdccHoldingSyncer', 'TDCC API 回傳空資料');
        return 0;
      }

      // 取得 DB 中所有已知股票（FK constraint 要求 symbol 必須存在於 StockMaster）
      final knownStocks = await _db.getAllActiveStocks();
      final knownSymbols = knownStocks.map((s) => s.symbol).toSet();

      // 篩選：必須存在於 StockMaster + 可選候選過濾
      final symbolsToSync = allData.keys.where(
        (s) =>
            knownSymbols.contains(s) &&
            (candidateSymbols == null || candidateSymbols.contains(s)),
      );

      final companions = <HoldingDistributionCompanion>[];

      for (final symbol in symbolsToSync) {
        final levels = allData[symbol]!;
        for (final level in levels) {
          companions.add(
            HoldingDistributionCompanion(
              symbol: Value(symbol),
              date: Value(level.date),
              level: Value(TdccClient.levelCodeToRangeString(level.level)),
              shareholders: Value(level.shareholders),
              percent: Value(level.percent),
              shares: Value(level.shares),
            ),
          );
        }
      }

      if (companions.isEmpty) {
        AppLogger.debug('TdccHoldingSyncer', '無需寫入的資料');
        return 0;
      }

      await _db.insertHoldingDistribution(companions);

      final syncedCount = symbolsToSync.length;
      AppLogger.info(
        'TdccHoldingSyncer',
        '同步完成: $syncedCount 檔股票 (${companions.length} 筆級距)',
      );
      return syncedCount;
    } catch (e) {
      AppLogger.warning('TdccHoldingSyncer', '同步失敗: $e');
      rethrow;
    }
  }

  /// 檢查是否已有本週的股權分散表資料
  ///
  /// 檢查 DB 中任一股票的最新資料日期是否在本週內。
  Future<bool> _hasCurrentWeekData() async {
    // 用台積電 (2330) 作為哨兵檢查
    final latestDate = await _db.getLatestHoldingDistributionDate('2330');
    if (latestDate == null) return false;
    return _isSameWeek(latestDate, DateTime.now());
  }

  /// 檢查兩個日期是否在同一週（週一至週日）
  bool _isSameWeek(DateTime a, DateTime b) {
    final aWeekStart = a.subtract(Duration(days: a.weekday - 1));
    final bWeekStart = b.subtract(Duration(days: b.weekday - 1));
    return aWeekStart.year == bWeekStart.year &&
        aWeekStart.month == bWeekStart.month &&
        aWeekStart.day == bWeekStart.day;
  }
}
