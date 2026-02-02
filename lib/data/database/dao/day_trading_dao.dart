import 'package:drift/drift.dart';
import 'package:afterclose/data/database/app_database.dart';

/// Day trading (當沖) operations.
extension DayTradingDao on AppDatabase {
  /// 取得股票的當沖歷史
  Future<List<DayTradingEntry>> getDayTradingHistory(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) {
    final query = select(dayTrading)
      ..where((t) => t.symbol.equals(symbol))
      ..where((t) => t.date.isBiggerOrEqualValue(startDate));

    if (endDate != null) {
      query.where((t) => t.date.isSmallerOrEqualValue(endDate));
    }

    query.orderBy([(t) => OrderingTerm.asc(t.date)]);
    return query.get();
  }

  /// 取得股票的最新當沖資料
  Future<DayTradingEntry?> getLatestDayTrading(String symbol) {
    return (select(dayTrading)
          ..where((t) => t.symbol.equals(symbol))
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// 取得指定日期的當沖資料筆數（新鮮度檢查用）
  Future<int> getDayTradingCountForDate(DateTime date) async {
    // 使用本地時間午夜以匹配資料庫儲存格式
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final countExpr = dayTrading.symbol.count();
    final query = selectOnly(dayTrading)
      ..addColumns([countExpr])
      ..where(dayTrading.date.isBiggerOrEqualValue(startOfDay))
      ..where(dayTrading.date.isSmallerThanValue(endOfDay));
    final result = await query.getSingle();
    return result.read(countExpr) ?? 0;
  }

  /// 取得指定日期和市場的當沖資料筆數（新鮮度檢查用）
  ///
  /// [market] - 市場類型：'TWSE' 或 'TPEx'
  Future<int> getDayTradingCountForDateAndMarket(
    DateTime date,
    String market,
  ) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // 使用 JOIN 查詢統計特定市場的當沖資料筆數
    final countExpr = dayTrading.symbol.count();
    final query =
        selectOnly(dayTrading).join([
            innerJoin(
              stockMaster,
              stockMaster.symbol.equalsExp(dayTrading.symbol),
            ),
          ])
          ..addColumns([countExpr])
          ..where(dayTrading.date.isBiggerOrEqualValue(startOfDay))
          ..where(dayTrading.date.isSmallerThanValue(endOfDay))
          ..where(stockMaster.market.equals(market));

    final result = await query.getSingle();
    return result.read(countExpr) ?? 0;
  }

  /// 批次新增當沖資料
  Future<void> insertDayTradingData(List<DayTradingCompanion> entries) async {
    await batch((b) {
      for (final entry in entries) {
        b.insert(dayTrading, entry, mode: InsertMode.insertOrReplace);
      }
    });
  }

  /// 刪除指定日期範圍內的當沖資料
  ///
  /// 用於清理可能存在的重複記錄（由於 UTC/本地時間不一致）
  Future<int> deleteDayTradingForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return (delete(dayTrading)..where(
          (t) =>
              t.date.isBiggerOrEqualValue(startDate) &
              t.date.isSmallerOrEqualValue(endDate),
        ))
        .go();
  }

  /// 取得資料庫中最新的當沖資料日期
  ///
  /// 用於上櫃股票的新鮮度檢查基準。
  /// 回傳 TWSE 批次同步後的實際資料日期。
  Future<DateTime?> getLatestDayTradingDate() async {
    final result =
        await (select(dayTrading)
              ..orderBy([(t) => OrderingTerm.desc(t.date)])
              ..limit(1))
            .getSingleOrNull();
    return result?.date;
  }

  /// 批次取得最新當沖資料 Map
  ///
  /// 用於 Isolate 評分時傳遞當沖資料。
  /// 優先取得指定日期的資料，若無則取得最近 5 天內的最新資料。
  /// 回傳 symbol -> dayTradingRatio 的對應表。
  Future<Map<String, double>> getDayTradingMapForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // 先嘗試取得指定日期的資料
    var results =
        await (select(dayTrading)
              ..where((t) => t.date.isBiggerOrEqualValue(startOfDay))
              ..where((t) => t.date.isSmallerThanValue(endOfDay)))
            .get();

    // 若指定日期沒有資料，取得最近 5 天內最新一天的資料
    if (results.isEmpty) {
      final lookbackStart = startOfDay.subtract(const Duration(days: 5));
      final latestDateResult = await customSelect(
        '''
        SELECT MAX(date) as latest_date
        FROM day_trading
        WHERE date >= ? AND date < ?
        ''',
        variables: [
          Variable.withDateTime(lookbackStart),
          Variable.withDateTime(endOfDay),
        ],
      ).getSingleOrNull();

      final latestDateStr = latestDateResult?.read<String?>('latest_date');
      if (latestDateStr != null) {
        final latestDate = DateTime.parse(latestDateStr);
        final latestStartOfDay = DateTime(
          latestDate.year,
          latestDate.month,
          latestDate.day,
        );
        final latestEndOfDay = latestStartOfDay.add(const Duration(days: 1));

        results =
            await (select(dayTrading)
                  ..where((t) => t.date.isBiggerOrEqualValue(latestStartOfDay))
                  ..where((t) => t.date.isSmallerThanValue(latestEndOfDay)))
                .get();
      }
    }

    final map = <String, double>{};
    for (final entry in results) {
      if (entry.dayTradingRatio != null) {
        map[entry.symbol] = entry.dayTradingRatio!;
      }
    }
    return map;
  }
}
