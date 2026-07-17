import 'package:drift/drift.dart';

import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/data/database/app_database.drift.dart';
import 'package:afterclose/data/database/tables/market_data_tables.drift.dart';

/// 注意股票 / 處置股票操作
mixin TradingWarningDaoMixin on $AppDatabase {
  /// 取得所有目前生效的警示（全市場）
  Future<List<TradingWarningEntry>> getAllActiveWarnings() {
    return (select(tradingWarning)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  /// 依類型取得所有目前生效的警示
  Future<List<TradingWarningEntry>> getActiveWarningsByType(String type) {
    return (select(tradingWarning)
          ..where((t) => t.isActive.equals(true))
          ..where((t) => t.warningType.equals(type))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  /// 批次檢查多檔股票是否為處置股（批次查詢）
  Future<Set<String>> getDisposalStocksBatch(List<String> symbols) async {
    if (symbols.isEmpty) return {};

    final results =
        await (select(tradingWarning)
              ..where((t) => t.symbol.isIn(symbols))
              ..where((t) => t.isActive.equals(true))
              ..where((t) => t.warningType.equals('DISPOSAL')))
            .get();

    return results.map((r) => r.symbol).toSet();
  }

  /// 批次取得多檔股票的警示資料 Map
  ///
  /// 用於 Isolate 評分時傳遞警示資料。
  /// 優先回傳 DISPOSAL（處置股），若無則回傳 ATTENTION（注意股）。
  Future<Map<String, TradingWarningEntry>> getActiveWarningsMapBatch(
    List<String> symbols,
  ) async {
    if (symbols.isEmpty) return {};

    final results =
        await (select(tradingWarning)
              ..where((t) => t.symbol.isIn(symbols))
              ..where((t) => t.isActive.equals(true))
              ..orderBy([
                // DISPOSAL 優先於 ATTENTION
                (t) => OrderingTerm.desc(t.warningType),
              ]))
            .get();

    final map = <String, TradingWarningEntry>{};
    for (final entry in results) {
      // 只保留第一筆（DISPOSAL 優先）
      if (!map.containsKey(entry.symbol)) {
        map[entry.symbol] = entry;
      }
    }
    return map;
  }

  /// 批次新增警示資料
  ///
  /// 使用 insertOrReplace（self-healing 寫入，與 margin_trading / daily_price 等
  /// 同型別表一致）：`date` 是「本輪同步日」而非不可變歷史鍵，且 App 同一天會
  /// 多次同步。若 TWSE/TPEX 於兩輪之間更正同日處置公告（延長 disposalEndDate、
  /// 修正 reasonDescription/disposalMeasures），insertOrIgnore 會永久保留第一筆、
  /// 靜默吞掉更正。改用 insertOrReplace 讓同鍵重新同步即更新該列。
  ///
  /// 「避免重新同步時誤將已過期警示重新激活」的顧慮由 [updateExpiredWarnings]
  /// 承接——它在每次 insertWarningData 後執行、以 disposalEndDate vs now 重新
  /// 推導 isActive，與插入模式無關，故 insertOrReplace 對該顧慮同樣安全。
  Future<void> insertWarningData(List<TradingWarningCompanion> entries) async {
    await batch((b) {
      for (final entry in entries) {
        b.insert(tradingWarning, entry, mode: InsertMode.insertOrReplace);
      }
    });
  }

  /// 更新過期的警示狀態
  ///
  /// 將處置結束日已過的警示標記為非生效
  Future<int> updateExpiredWarnings({DateTime? now}) async {
    final effectiveNow = now ?? DateTime.now();
    return (update(tradingWarning)
          ..where((t) => t.isActive.equals(true))
          ..where((t) => t.disposalEndDate.isSmallerThanValue(effectiveNow)))
        .write(const TradingWarningCompanion(isActive: Value(false)));
  }

  /// 取得指定日期的警示資料筆數（新鮮度檢查用）
  Future<int> getWarningCountForDate(DateTime date) async {
    final startOfDay = DateContext.normalize(date);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final countExpr = tradingWarning.symbol.count();
    final query = selectOnly(tradingWarning)
      ..addColumns([countExpr])
      ..where(tradingWarning.date.isBiggerOrEqualValue(startOfDay))
      ..where(tradingWarning.date.isSmallerThanValue(endOfDay));
    final result = await query.getSingle();
    return result.read(countExpr) ?? 0;
  }

  /// 取得最新警示資料的同步時間
  ///
  /// 用於新鮮度檢查，避免重複同步。
  Future<DateTime?> getLatestWarningSyncTime() async {
    final query = select(tradingWarning)
      ..orderBy([(t) => OrderingTerm.desc(t.date)])
      ..limit(1);
    final result = await query.getSingleOrNull();
    return result?.date;
  }
}
