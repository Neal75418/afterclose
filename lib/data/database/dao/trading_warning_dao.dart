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

  /// 讓不在最新名單中的注意股（ATTENTION）失效
  ///
  /// **為何 [updateExpiredWarnings] 涵蓋不到注意股**：它唯一的失效條件是
  /// `disposal_end_date < now`，而 ATTENTION 的該欄恆為 NULL——SQL 三值邏輯下
  /// `NULL < ?` 求值為 NULL 而非 true，該 UPDATE 對注意股**永遠匹配不到任何列**。
  /// 加上表 PK 為 {symbol, date, warningType}、每日同步寫新列且無 retention，
  /// 注意股一旦上榜就永久 `is_active = 1`。2026-07-25 實測：437 筆 / 140 檔
  /// active，但當日真實名單僅 19 檔（121 檔為幽靈），而
  /// `RuleScores.tradingWarningAttention = -15` 會把股票直接壓出推薦榜。
  ///
  /// **語意差異**：DISPOSAL 是期間制（有 disposalEndDate 可判斷），ATTENTION 是
  /// 主管機關**逐日公告的名單**——今日名單以外的即為已下架，故採 full-refresh。
  ///
  /// ⚠️ [syncedMarkets] 必須只包含**本輪實際同步成功**的市場。表上沒有 market
  /// 欄，市場歸屬由 stock_master 推導；若不限定市場，在「非交易日只同步上櫃」
  /// 這類情境會把未同步市場的注意股全部誤殺。
  ///
  /// [currentSymbols] 本輪取得的注意股名單（空集合＝該市場今日無注意股，
  /// 其舊列應全數失效）；[syncDate] 本輪同步日。回傳實際失效的列數。
  ///
  /// 失效條件為「不在今日名單」**或**「日期早於本輪」——後者確保同一檔連續
  /// 多日上榜時只留今日那列 active。否則同 symbol 會有多筆 active，而讀取端
  /// [getActiveWarningsMapBatch] 的 orderBy 只有 `desc(warningType)`、同鍵是
  /// tie，SQLite 不保證取到最新列，可能顯示過期的 reasonDescription。
  Future<int> deactivateStaleAttentionWarnings({
    required Set<String> currentSymbols,
    required Set<String> syncedMarkets,
    required DateTime syncDate,
  }) async {
    if (syncedMarkets.isEmpty) return 0;

    final vars = <Variable<Object>>[];
    final marketPlaceholders = syncedMarkets
        .map((m) {
          vars.add(Variable<String>(m));
          return '?';
        })
        .join(', ');

    // currentSymbols 為空時省略 NOT IN 子句——`NOT IN ()` 在 SQLite 是語法錯誤，
    // 且語意上「今日名單為空」本就等於「該市場所有舊列都該失效」。
    var staleClause = 'date < ?';
    if (currentSymbols.isNotEmpty) {
      final symbolPlaceholders = currentSymbols
          .map((s) {
            vars.add(Variable<String>(s));
            return '?';
          })
          .join(', ');
      staleClause = 'symbol NOT IN ($symbolPlaceholders) OR date < ?';
    }
    vars.add(Variable<DateTime>(syncDate));

    return customUpdate(
      '''
      UPDATE trading_warning
         SET is_active = 0
       WHERE warning_type = 'ATTENTION'
         AND is_active = 1
         AND symbol IN (
           SELECT symbol FROM stock_master WHERE market IN ($marketPlaceholders)
         )
         AND ($staleClause)
      ''',
      variables: vars,
      updates: {tradingWarning},
    );
  }

  /// 更新過期的警示狀態
  ///
  /// 將處置結束日已過的警示標記為非生效。
  /// **僅涵蓋 DISPOSAL**（依賴 disposalEndDate）；注意股的失效走
  /// [deactivateStaleAttentionWarnings]。
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
