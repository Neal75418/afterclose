import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/tables/stock_master.dart';
import 'package:afterclose/data/database/tables/daily_price.dart';
import 'package:afterclose/data/database/tables/daily_institutional.dart';
import 'package:afterclose/data/database/tables/news_tables.dart';
import 'package:afterclose/data/database/tables/analysis_tables.dart';
import 'package:afterclose/data/database/tables/user_tables.dart';
import 'package:afterclose/data/database/tables/market_data_tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    // 主檔資料
    StockMaster,
    // 每日市場資料
    DailyPrice,
    DailyInstitutional,
    // 新聞
    NewsItem,
    NewsStockMap,
    // 分析結果
    DailyAnalysis,
    DailyReason,
    DailyRecommendation,
    // 使用者資料
    Watchlist,
    UserNote,
    StrategyCard,
    UpdateRun,
    AppSettings,
    PriceAlert,
    // 擴充市場資料（Phase 1）
    Shareholding,
    DayTrading,
    FinancialData,
    AdjustedPrice,
    WeeklyPrice,
    HoldingDistribution,
    // 基本面資料（Phase 3）
    MonthlyRevenue,
    StockValuation,
    // 融資融券資料（Phase 4）
    MarginTrading,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// 測試用 - 建立記憶體內 Database
  AppDatabase.forTesting() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  // ==========================================
  // 股票主檔操作
  // ==========================================

  /// 取得所有上市中的股票
  Future<List<StockMasterEntry>> getAllActiveStocks() {
    return (select(stockMaster)..where((t) => t.isActive.equals(true))).get();
  }

  /// 依股票代碼取得股票
  Future<StockMasterEntry?> getStock(String symbol) {
    return (select(
      stockMaster,
    )..where((t) => t.symbol.equals(symbol))).getSingleOrNull();
  }

  /// 新增或更新股票主檔
  Future<void> upsertStock(StockMasterCompanion entry) {
    return into(stockMaster).insertOnConflictUpdate(entry);
  }

  /// 批次新增或更新股票
  Future<void> upsertStocks(List<StockMasterCompanion> entries) async {
    await batch((b) {
      for (final entry in entries) {
        b.insert(stockMaster, entry, onConflict: DoUpdate((_) => entry));
      }
    });
  }

  /// 依代碼或名稱搜尋股票（Database 層級過濾）
  Future<List<StockMasterEntry>> searchStocks(String query) {
    final lowerQuery = '%${query.toLowerCase()}%';
    return (select(stockMaster)
          ..where((t) => t.isActive.equals(true))
          ..where(
            (t) =>
                t.symbol.lower().like(lowerQuery) |
                t.name.lower().like(lowerQuery),
          ))
        .get();
  }

  /// 依市場取得股票（Database 層級過濾）
  Future<List<StockMasterEntry>> getStocksByMarket(String market) {
    return (select(stockMaster)
          ..where((t) => t.isActive.equals(true))
          ..where((t) => t.market.equals(market)))
        .get();
  }

  /// 批次取得多檔股票（批次查詢）
  ///
  /// 回傳 symbol -> 股票資料 的 Map
  Future<Map<String, StockMasterEntry>> getStocksBatch(
    List<String> symbols,
  ) async {
    if (symbols.isEmpty) return {};

    final results = await (select(
      stockMaster,
    )..where((t) => t.symbol.isIn(symbols))).get();

    return {for (final stock in results) stock.symbol: stock};
  }

  // ==========================================
  // 每日價格操作
  // ==========================================

  /// 取得股票的價格歷史
  Future<List<DailyPriceEntry>> getPriceHistory(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) {
    final query = select(dailyPrice)
      ..where((t) => t.symbol.equals(symbol))
      ..where((t) => t.date.isBiggerOrEqualValue(startDate));

    if (endDate != null) {
      query.where((t) => t.date.isSmallerOrEqualValue(endDate));
    }

    query.orderBy([(t) => OrderingTerm.asc(t.date)]);

    return query.get();
  }

  /// 取得股票的最新價格
  Future<DailyPriceEntry?> getLatestPrice(String symbol) {
    return (select(dailyPrice)
          ..where((t) => t.symbol.equals(symbol))
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// 取得股票最近 N 個不同日期的價格（用於計算漲跌幅）
  ///
  /// 依日期降序排列，第一筆為最新價格。
  /// 會過濾掉同一天但不同時區格式的重複資料。
  Future<List<DailyPriceEntry>> getRecentPrices(
    String symbol, {
    int count = 2,
  }) async {
    // 多取一些資料以處理可能的重複日期
    final allRecent =
        await (select(dailyPrice)
              ..where((t) => t.symbol.equals(symbol))
              ..orderBy([(t) => OrderingTerm.desc(t.date)])
              ..limit(count * 5))
            .get();

    // 過濾出不同日期的價格（以年月日判斷）
    final seenDates = <String>{};
    final distinctPrices = <DailyPriceEntry>[];

    for (final price in allRecent) {
      final dateKey =
          '${price.date.year}-${price.date.month}-${price.date.day}';
      if (!seenDates.contains(dateKey)) {
        seenDates.add(dateKey);
        distinctPrices.add(price);
        if (distinctPrices.length >= count) break;
      }
    }

    return distinctPrices;
  }

  /// 取得指定日期的價格筆數
  Future<int> getPriceCountForDate(DateTime date) async {
    final countExpr = dailyPrice.symbol.count();
    final query = selectOnly(dailyPrice)
      ..addColumns([countExpr])
      ..where(dailyPrice.date.equals(date));
    final result = await query.getSingle();
    return result.read(countExpr) ?? 0;
  }

  /// 取得指定日期的所有價格資料
  ///
  /// 用於跳過 API 呼叫時的快篩候選股。
  Future<List<DailyPriceEntry>> getPricesForDate(DateTime date) {
    return (select(dailyPrice)..where((t) => t.date.equals(date))).get();
  }

  /// 取得 Database 中最新的資料日期
  ///
  /// 回傳 daily_price 表中的最大日期，代表最近一個有資料的交易日。
  Future<DateTime?> getLatestDataDate() async {
    const query = '''
      SELECT MAX(date) as max_date FROM daily_price
    ''';

    final result = await customSelect(
      query,
      readsFrom: {dailyPrice},
    ).getSingleOrNull();

    if (result == null) return null;
    return result.read<DateTime?>('max_date');
  }

  /// 取得 Database 中最新的法人資料日期
  Future<DateTime?> getLatestInstitutionalDate() async {
    const query = '''
      SELECT MAX(date) as max_date FROM daily_institutional
    ''';

    final result = await customSelect(
      query,
      readsFrom: {dailyInstitutional},
    ).getSingleOrNull();

    if (result == null) return null;
    return result.read<DateTime?>('max_date');
  }

  /// 批次取得多檔股票的最新價格（批次查詢）
  ///
  /// 回傳 symbol -> 最新價格 的 Map
  ///
  /// 使用最佳化 SQL 搭配 GROUP BY + MAX(date) 子查詢，
  /// 避免將所有歷史價格載入記憶體。
  Future<Map<String, DailyPriceEntry>> getLatestPricesBatch(
    List<String> symbols,
  ) async {
    if (symbols.isEmpty) return {};

    // 建立 SQL IN 子句的佔位符
    final placeholders = List.filled(symbols.length, '?').join(', ');

    // 使用帶有子查詢的最佳化查詢，只取得每檔股票的最新價格
    // 避免擷取所有歷史價格（可能有數百萬筆）
    final query =
        '''
      SELECT dp.*
      FROM daily_price dp
      INNER JOIN (
        SELECT symbol, MAX(date) as max_date
        FROM daily_price
        WHERE symbol IN ($placeholders)
        GROUP BY symbol
      ) latest ON dp.symbol = latest.symbol AND dp.date = latest.max_date
    ''';

    final results = await customSelect(
      query,
      variables: symbols.map((s) => Variable.withString(s)).toList(),
      readsFrom: {dailyPrice},
    ).get();

    // 將查詢列轉換為 DailyPriceEntry 物件
    final result = <String, DailyPriceEntry>{};
    for (final row in results) {
      final entry = DailyPriceEntry(
        symbol: row.read<String>('symbol'),
        date: row.read<DateTime>('date'),
        open: row.readNullable<double>('open'),
        high: row.readNullable<double>('high'),
        low: row.readNullable<double>('low'),
        close: row.readNullable<double>('close'),
        volume: row.readNullable<double>('volume'),
      );
      result[entry.symbol] = entry;
    }

    return result;
  }

  /// 批次新增價格
  Future<void> insertPrices(List<DailyPriceCompanion> entries) async {
    await batch((b) {
      for (final entry in entries) {
        b.insert(dailyPrice, entry, mode: InsertMode.insertOrReplace);
      }
    });
  }

  /// 清理無效股票代碼的資料
  ///
  /// 刪除所有不符合有效股票代碼格式的記錄（如權證、ETF 特殊代碼）
  /// 有效格式：4 位數字（一般股票）或 5-6 位數字開頭為 00（ETF）
  ///
  /// 回傳各表刪除的記錄數
  Future<Map<String, int>> cleanupInvalidStockCodes() async {
    final results = <String, int>{};

    // 有效股票代碼：
    // - 4 位數字（一般股票）
    // - 00 開頭的 ETF (00xxx, 006xxx)
    // 無效代碼：6 位數字（權證）、含英文字母的特殊代碼等
    //
    // 使用 SQLite GLOB 語法：
    // - [0-9] 匹配單個數字
    // - * 匹配任意字符
    //
    // 策略：刪除長度為 6 且不是 00 開頭的（權證）

    // 清理 daily_price - 刪除 6 位數字權證
    results['daily_price'] = await customUpdate(
      'DELETE FROM daily_price WHERE LENGTH(symbol) = 6 AND symbol NOT LIKE ?',
      variables: [Variable.withString('00%')],
      updates: {dailyPrice},
    );

    // 清理 daily_institutional
    results['daily_institutional'] = await customUpdate(
      'DELETE FROM daily_institutional WHERE LENGTH(symbol) = 6 AND symbol NOT LIKE ?',
      variables: [Variable.withString('00%')],
      updates: {dailyInstitutional},
    );

    // 清理 day_trading
    results['day_trading'] = await customUpdate(
      'DELETE FROM day_trading WHERE LENGTH(symbol) = 6 AND symbol NOT LIKE ?',
      variables: [Variable.withString('00%')],
      updates: {dayTrading},
    );

    // 清理 margin_trading
    results['margin_trading'] = await customUpdate(
      'DELETE FROM margin_trading WHERE LENGTH(symbol) = 6 AND symbol NOT LIKE ?',
      variables: [Variable.withString('00%')],
      updates: {marginTrading},
    );

    // 清理 shareholding
    results['shareholding'] = await customUpdate(
      'DELETE FROM shareholding WHERE LENGTH(symbol) = 6 AND symbol NOT LIKE ?',
      variables: [Variable.withString('00%')],
      updates: {shareholding},
    );

    // 清理 stock_master (主檔)
    results['stock_master'] = await customUpdate(
      'DELETE FROM stock_master WHERE LENGTH(symbol) = 6 AND symbol NOT LIKE ?',
      variables: [Variable.withString('00%')],
      updates: {stockMaster},
    );

    return results;
  }

  /// 取得歷史資料完成度
  ///
  /// 回傳 (已完成檔數, 總檔數)
  /// 完成定義：該股票有 >= [RuleParams.historicalDataMinDays] 天的價格資料
  Future<({int completed, int total})> getHistoricalDataProgress() async {
    // 取得所有有效股票數量
    final totalResult = await customSelect(
      'SELECT COUNT(*) as cnt FROM stock_master WHERE is_active = 1',
    ).getSingle();
    final total = totalResult.read<int>('cnt');

    if (total == 0) return (completed: 0, total: 0);

    // 計算有足夠歷史資料的股票數量
    final completedResult = await customSelect(
      '''
      SELECT COUNT(*) as cnt FROM (
        SELECT dp.symbol
        FROM daily_price dp
        INNER JOIN stock_master sm ON dp.symbol = sm.symbol AND sm.is_active = 1
        GROUP BY dp.symbol
        HAVING COUNT(*) >= ?
      )
      ''',
      variables: [Variable.withInt(RuleParams.historicalDataMinDays)],
    ).getSingle();
    final completed = completedResult.read<int>('cnt');

    return (completed: completed, total: total);
  }

  /// 批次取得多檔股票的價格歷史（批次查詢避免 N+1 問題）
  ///
  /// 回傳 symbol -> 價格列表 的 Map，依日期升冪排序
  Future<Map<String, List<DailyPriceEntry>>> getPriceHistoryBatch(
    List<String> symbols, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    if (symbols.isEmpty) return {};

    final query = select(dailyPrice)
      ..where((t) => t.symbol.isIn(symbols))
      ..where((t) => t.date.isBiggerOrEqualValue(startDate));

    if (endDate != null) {
      query.where((t) => t.date.isSmallerOrEqualValue(endDate));
    }

    query.orderBy([
      (t) => OrderingTerm.asc(t.symbol),
      (t) => OrderingTerm.asc(t.date),
    ]);

    final results = await query.get();

    // 依 symbol 分組
    final grouped = <String, List<DailyPriceEntry>>{};
    for (final entry in results) {
      grouped.putIfAbsent(entry.symbol, () => []).add(entry);
    }

    return grouped;
  }

  /// 取得日期範圍內的所有價格（全市場分析用）
  ///
  /// 回傳依 symbol 分組的價格
  Future<Map<String, List<DailyPriceEntry>>> getAllPricesInRange({
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    final query = select(dailyPrice)
      ..where((t) => t.date.isBiggerOrEqualValue(startDate));

    if (endDate != null) {
      query.where((t) => t.date.isSmallerOrEqualValue(endDate));
    }

    query.orderBy([
      (t) => OrderingTerm.asc(t.symbol),
      (t) => OrderingTerm.asc(t.date),
    ]);

    final results = await query.get();

    // 依 symbol 分組
    final grouped = <String, List<DailyPriceEntry>>{};
    for (final entry in results) {
      grouped.putIfAbsent(entry.symbol, () => []).add(entry);
    }

    return grouped;
  }

  /// 取得至少有 [minDays] 天價格資料的所有股票代碼
  ///
  /// 用於全市場分析，找出可直接分析而無需額外擷取歷史資料的股票。
  ///
  /// 回傳依資料筆數排序的股票代碼列表（資料最多者優先）
  Future<List<String>> getSymbolsWithSufficientData({
    required int minDays,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    // 使用原生 SQL 以達成高效的 GROUP BY 搭配 HAVING 子句
    final effectiveEndDate = endDate ?? DateTime.now();

    const query = '''
      SELECT symbol, COUNT(*) as cnt
      FROM daily_price
      WHERE date >= ? AND date <= ?
      GROUP BY symbol
      HAVING cnt >= ?
      ORDER BY cnt DESC, symbol ASC
    ''';

    final results = await customSelect(
      query,
      variables: [
        Variable.withDateTime(startDate),
        Variable.withDateTime(effectiveEndDate),
        Variable.withInt(minDays),
      ],
    ).get();

    return results.map((row) => row.read<String>('symbol')).toList();
  }

  // ==========================================
  // 三大法人資料操作
  // ==========================================

  /// 取得股票的法人資料歷史
  Future<List<DailyInstitutionalEntry>> getInstitutionalHistory(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) {
    final query = select(dailyInstitutional)
      ..where((t) => t.symbol.equals(symbol))
      ..where((t) => t.date.isBiggerOrEqualValue(startDate));

    if (endDate != null) {
      query.where((t) => t.date.isSmallerOrEqualValue(endDate));
    }

    query.orderBy([(t) => OrderingTerm.asc(t.date)]);

    return query.get();
  }

  /// 取得股票的最新法人資料
  Future<DailyInstitutionalEntry?> getLatestInstitutional(String symbol) {
    return (select(dailyInstitutional)
          ..where((t) => t.symbol.equals(symbol))
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// 批次新增法人資料
  Future<void> insertInstitutionalData(
    List<DailyInstitutionalCompanion> entries,
  ) async {
    await batch((b) {
      for (final entry in entries) {
        b.insert(dailyInstitutional, entry, mode: InsertMode.insertOrReplace);
      }
    });
  }

  /// 批次取得多檔股票的法人資料（批次查詢）
  ///
  /// 回傳 symbol -> 法人資料列表 的 Map，依日期升冪排序
  Future<Map<String, List<DailyInstitutionalEntry>>>
  getInstitutionalHistoryBatch(
    List<String> symbols, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    if (symbols.isEmpty) return {};

    final query = select(dailyInstitutional)
      ..where((t) => t.symbol.isIn(symbols))
      ..where((t) => t.date.isBiggerOrEqualValue(startDate));

    if (endDate != null) {
      query.where((t) => t.date.isSmallerOrEqualValue(endDate));
    }

    query.orderBy([
      (t) => OrderingTerm.asc(t.symbol),
      (t) => OrderingTerm.asc(t.date),
    ]);

    final results = await query.get();

    // 依 symbol 分組
    final grouped = <String, List<DailyInstitutionalEntry>>{};
    for (final entry in results) {
      grouped.putIfAbsent(entry.symbol, () => []).add(entry);
    }

    return grouped;
  }

  // ==========================================
  // 每日分析操作
  // ==========================================

  /// 取得指定日期的分析結果
  Future<List<DailyAnalysisEntry>> getAnalysisForDate(DateTime date) {
    return (select(dailyAnalysis)
          ..where((t) => t.date.equals(date))
          ..orderBy([(t) => OrderingTerm.desc(t.score)]))
        .get();
  }

  /// 取得指定日期分數 > 0 的分頁分析結果
  ///
  /// 回傳從 [offset] 開始的 [limit] 筆資料，依分數降冪排序。
  /// 僅回傳正分數的項目（適用於掃描功能）。
  Future<List<DailyAnalysisEntry>> getAnalysisForDatePaginated(
    DateTime date, {
    required int limit,
    required int offset,
  }) {
    return (select(dailyAnalysis)
          ..where((t) => t.date.equals(date))
          ..where((t) => t.score.isBiggerThanValue(0))
          ..orderBy([(t) => OrderingTerm.desc(t.score)])
          ..limit(limit, offset: offset))
        .get();
  }

  /// 取得指定日期分數 > 0 的分析總筆數
  Future<int> getAnalysisCountForDate(DateTime date) async {
    final countExpr = dailyAnalysis.symbol.count();
    final query = selectOnly(dailyAnalysis)
      ..addColumns([countExpr])
      ..where(dailyAnalysis.date.equals(date))
      ..where(dailyAnalysis.score.isBiggerThanValue(0));
    final result = await query.getSingle();
    return result.read(countExpr) ?? 0;
  }

  /// 取得指定日期的法人資料筆數
  Future<int> getInstitutionalCountForDate(DateTime date) async {
    final countExpr = dailyInstitutional.symbol.count();
    final query = selectOnly(dailyInstitutional)
      ..addColumns([countExpr])
      ..where(dailyInstitutional.date.equals(date));
    final result = await query.getSingle();
    return result.read(countExpr) ?? 0;
  }

  /// 取得指定日期的估值資料筆數
  Future<int> getValuationCountForDate(DateTime date) async {
    final countExpr = stockValuation.symbol.count();
    final query = selectOnly(stockValuation)
      ..addColumns([countExpr])
      ..where(stockValuation.date.equals(date));
    final result = await query.getSingle();
    return result.read(countExpr) ?? 0;
  }

  /// 取得股票的分析結果
  Future<DailyAnalysisEntry?> getAnalysis(String symbol, DateTime date) {
    return (select(dailyAnalysis)
          ..where((t) => t.symbol.equals(symbol))
          ..where((t) => t.date.equals(date)))
        .getSingleOrNull();
  }

  /// 新增分析結果
  Future<void> insertAnalysis(DailyAnalysisCompanion entry) {
    return into(dailyAnalysis).insertOnConflictUpdate(entry);
  }

  /// 批次取得多檔股票在指定日期的分析結果（批次查詢）
  ///
  /// 回傳 symbol -> 分析結果 的 Map
  Future<Map<String, DailyAnalysisEntry>> getAnalysesBatch(
    List<String> symbols,
    DateTime date,
  ) async {
    if (symbols.isEmpty) return {};

    final results =
        await (select(dailyAnalysis)
              ..where((t) => t.symbol.isIn(symbols))
              ..where((t) => t.date.equals(date)))
            .get();

    return {for (final analysis in results) analysis.symbol: analysis};
  }

  // ==========================================
  // 每日原因操作
  // ==========================================

  /// 取得股票在指定日期的觸發原因
  Future<List<DailyReasonEntry>> getReasons(String symbol, DateTime date) {
    return (select(dailyReason)
          ..where((t) => t.symbol.equals(symbol))
          ..where((t) => t.date.equals(date))
          ..orderBy([(t) => OrderingTerm.asc(t.rank)]))
        .get();
  }

  /// 批次取得多檔股票在指定日期的觸發原因（批次查詢）
  ///
  /// 回傳 symbol -> 原因列表 的 Map，依 rank 排序
  Future<Map<String, List<DailyReasonEntry>>> getReasonsBatch(
    List<String> symbols,
    DateTime date,
  ) async {
    if (symbols.isEmpty) return {};

    final results =
        await (select(dailyReason)
              ..where((t) => t.symbol.isIn(symbols))
              ..where((t) => t.date.equals(date))
              ..orderBy([
                (t) => OrderingTerm.asc(t.symbol),
                (t) => OrderingTerm.asc(t.rank),
              ]))
            .get();

    // 依 symbol 分組
    final grouped = <String, List<DailyReasonEntry>>{};
    for (final entry in results) {
      grouped.putIfAbsent(entry.symbol, () => []).add(entry);
    }

    return grouped;
  }

  /// 新增原因
  Future<void> insertReasons(List<DailyReasonCompanion> entries) async {
    await batch((b) {
      for (final entry in entries) {
        b.insert(dailyReason, entry, mode: InsertMode.insertOrReplace);
      }
    });
  }

  /// 取代股票在指定日期的原因（原子性操作）
  Future<void> replaceReasons(
    String symbol,
    DateTime date,
    List<DailyReasonCompanion> entries,
  ) {
    return transaction(() async {
      // 刪除此 symbol/date 的既有原因
      await (delete(dailyReason)
            ..where((t) => t.symbol.equals(symbol))
            ..where((t) => t.date.equals(date)))
          .go();

      // 新增新的原因
      if (entries.isNotEmpty) {
        await batch((b) {
          for (final entry in entries) {
            b.insert(dailyReason, entry);
          }
        });
      }
    });
  }

  /// 清除指定日期的所有原因記錄
  ///
  /// 在每日更新前呼叫，確保不會有舊的原因記錄殘留
  Future<int> clearReasonsForDate(DateTime date) {
    return (delete(dailyReason)..where((t) => t.date.equals(date))).go();
  }

  /// 清除指定日期的所有分析記錄
  ///
  /// 在每日更新前呼叫，確保不會有舊的分析記錄殘留
  Future<int> clearAnalysisForDate(DateTime date) {
    return (delete(dailyAnalysis)..where((t) => t.date.equals(date))).go();
  }

  // ==========================================
  // 推薦股操作
  // ==========================================

  /// 取得指定日期的推薦股
  Future<List<DailyRecommendationEntry>> getRecommendations(DateTime date) {
    return (select(dailyRecommendation)
          ..where((t) => t.date.equals(date))
          ..orderBy([(t) => OrderingTerm.asc(t.rank)]))
        .get();
  }

  /// 新增推薦股
  Future<void> insertRecommendations(
    List<DailyRecommendationCompanion> entries,
  ) async {
    await batch((b) {
      for (final entry in entries) {
        b.insert(dailyRecommendation, entry, mode: InsertMode.insertOrReplace);
      }
    });
  }

  /// 取代指定日期的推薦股（原子性操作）
  Future<void> replaceRecommendations(
    DateTime date,
    List<DailyRecommendationCompanion> entries,
  ) {
    return transaction(() async {
      // 刪除此日期的既有推薦股
      await (delete(
        dailyRecommendation,
      )..where((t) => t.date.equals(date))).go();

      // 新增新的推薦股
      if (entries.isNotEmpty) {
        await batch((b) {
          for (final entry in entries) {
            b.insert(dailyRecommendation, entry);
          }
        });
      }
    });
  }

  /// 檢查股票是否在日期範圍內曾被推薦（單次查詢）
  Future<bool> wasSymbolRecommendedInRange(
    String symbol, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final result =
        await (select(dailyRecommendation)
              ..where((t) => t.symbol.equals(symbol))
              ..where((t) => t.date.isBiggerOrEqualValue(startDate))
              ..where((t) => t.date.isSmallerOrEqualValue(endDate))
              ..limit(1))
            .getSingleOrNull();
    return result != null;
  }

  /// 取得日期範圍內所有曾被推薦的股票代碼（批次檢查）
  Future<Set<String>> getRecommendedSymbolsInRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final results =
        await (select(dailyRecommendation)
              ..where((t) => t.date.isBiggerOrEqualValue(startDate))
              ..where((t) => t.date.isSmallerOrEqualValue(endDate)))
            .get();
    return results.map((r) => r.symbol).toSet();
  }

  // ==========================================
  // 新聞操作
  // ==========================================

  /// 批次取得多則新聞的股票關聯（批次查詢）
  ///
  /// 回傳 newsId -> 股票代碼列表 的 Map
  Future<Map<String, List<String>>> getNewsStockMappingsBatch(
    List<String> newsIds,
  ) async {
    if (newsIds.isEmpty) return {};

    final results = await (select(
      newsStockMap,
    )..where((t) => t.newsId.isIn(newsIds))).get();

    // 依 newsId 分組
    final grouped = <String, List<String>>{};
    for (final entry in results) {
      grouped.putIfAbsent(entry.newsId, () => []).add(entry.symbol);
    }

    return grouped;
  }

  // ==========================================
  // 自選股操作
  // ==========================================

  /// 取得所有自選股
  Future<List<WatchlistEntry>> getWatchlist() {
    return (select(
      watchlist,
    )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();
  }

  /// 加入自選股
  Future<void> addToWatchlist(String symbol) {
    return into(watchlist).insert(
      WatchlistCompanion.insert(symbol: symbol),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// 從自選股移除
  Future<void> removeFromWatchlist(String symbol) {
    return (delete(watchlist)..where((t) => t.symbol.equals(symbol))).go();
  }

  /// 檢查股票是否在自選股中
  Future<bool> isInWatchlist(String symbol) async {
    final result = await (select(
      watchlist,
    )..where((t) => t.symbol.equals(symbol))).getSingleOrNull();
    return result != null;
  }

  // ==========================================
  // 應用程式設定操作（Token 儲存用）
  // ==========================================

  /// 取得設定值
  Future<String?> getSetting(String key) async {
    final result = await (select(
      appSettings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return result?.value;
  }

  /// 設定設定值
  Future<void> setSetting(String key, String value) {
    return into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(key: key, value: value),
    );
  }

  /// 刪除設定
  Future<void> deleteSetting(String key) {
    return (delete(appSettings)..where((t) => t.key.equals(key))).go();
  }

  // ==========================================
  // 更新執行記錄操作
  // ==========================================

  /// 建立新的更新執行記錄
  Future<int> createUpdateRun(DateTime runDate, String status) {
    return into(
      updateRun,
    ).insert(UpdateRunCompanion.insert(runDate: runDate, status: status));
  }

  /// 更新執行狀態
  Future<void> finishUpdateRun(int id, String status, {String? message}) {
    return (update(updateRun)..where((t) => t.id.equals(id))).write(
      UpdateRunCompanion(
        finishedAt: Value(DateTime.now()),
        status: Value(status),
        message: Value(message),
      ),
    );
  }

  /// 取得最新的更新執行記錄
  Future<UpdateRunEntry?> getLatestUpdateRun() {
    return (select(updateRun)
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(1))
        .getSingleOrNull();
  }

  // ==========================================
  // 股價提醒操作
  // ==========================================

  /// 取得所有啟用中的股價提醒
  Future<List<PriceAlertEntry>> getActiveAlerts() {
    return (select(priceAlert)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// 取得所有股價提醒（包含啟用與停用）
  Future<List<PriceAlertEntry>> getAllAlerts() {
    return (select(
      priceAlert,
    )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();
  }

  /// 取得股票的所有提醒
  Future<List<PriceAlertEntry>> getAlertsForSymbol(String symbol) {
    return (select(priceAlert)
          ..where((t) => t.symbol.equals(symbol))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// 取得股票的啟用中提醒
  Future<List<PriceAlertEntry>> getActiveAlertsForSymbol(String symbol) {
    return (select(priceAlert)
          ..where((t) => t.symbol.equals(symbol))
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// 依 ID 取得單一提醒
  Future<PriceAlertEntry?> getAlertById(int id) {
    return (select(
      priceAlert,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// 建立新的股價提醒
  Future<int> createPriceAlert({
    required String symbol,
    required String alertType,
    required double targetValue,
    String? note,
  }) {
    return into(priceAlert).insert(
      PriceAlertCompanion.insert(
        symbol: symbol,
        alertType: alertType,
        targetValue: targetValue,
        note: Value(note),
      ),
    );
  }

  /// 更新股價提醒
  Future<void> updatePriceAlert(int id, PriceAlertCompanion entry) {
    return (update(priceAlert)..where((t) => t.id.equals(id))).write(entry);
  }

  /// 停用股價提醒（標記為已觸發）
  Future<void> triggerAlert(int id) {
    return (update(priceAlert)..where((t) => t.id.equals(id))).write(
      PriceAlertCompanion(
        isActive: const Value(false),
        triggeredAt: Value(DateTime.now()),
      ),
    );
  }

  /// 刪除股價提醒
  Future<void> deletePriceAlert(int id) {
    return (delete(priceAlert)..where((t) => t.id.equals(id))).go();
  }

  /// 刪除股票的所有提醒
  Future<void> deleteAlertsForSymbol(String symbol) {
    return (delete(priceAlert)..where((t) => t.symbol.equals(symbol))).go();
  }

  /// 比對提醒與當前價格，回傳已觸發的提醒
  Future<List<PriceAlertEntry>> checkAlerts(
    Map<String, double> currentPrices,
    Map<String, double> priceChanges,
  ) async {
    final activeAlerts = await getActiveAlerts();
    final triggered = <PriceAlertEntry>[];

    for (final alert in activeAlerts) {
      final currentPrice = currentPrices[alert.symbol];
      final priceChange = priceChanges[alert.symbol];

      if (currentPrice == null) continue;

      bool shouldTrigger = false;

      switch (alert.alertType) {
        case 'ABOVE':
          shouldTrigger = currentPrice >= alert.targetValue;
          break;
        case 'BELOW':
          shouldTrigger = currentPrice <= alert.targetValue;
          break;
        case 'CHANGE_PCT':
          if (priceChange != null) {
            shouldTrigger = priceChange.abs() >= alert.targetValue;
          }
          break;
      }

      if (shouldTrigger) {
        triggered.add(alert);
      }
    }

    return triggered;
  }

  // ==========================================
  // 外資持股操作
  // ==========================================

  /// 取得股票的持股歷史
  Future<List<ShareholdingEntry>> getShareholdingHistory(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) {
    final query = select(shareholding)
      ..where((t) => t.symbol.equals(symbol))
      ..where((t) => t.date.isBiggerOrEqualValue(startDate));

    if (endDate != null) {
      query.where((t) => t.date.isSmallerOrEqualValue(endDate));
    }

    query.orderBy([(t) => OrderingTerm.asc(t.date)]);
    return query.get();
  }

  /// 取得股票的最新持股資料
  Future<ShareholdingEntry?> getLatestShareholding(String symbol) {
    return (select(shareholding)
          ..where((t) => t.symbol.equals(symbol))
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// 批次新增持股資料
  Future<void> insertShareholdingData(
    List<ShareholdingCompanion> entries,
  ) async {
    await batch((b) {
      for (final entry in entries) {
        b.insert(shareholding, entry, mode: InsertMode.insertOrReplace);
      }
    });
  }

  // ==========================================
  // 當沖操作
  // ==========================================

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

  // ==========================================
  // 融資融券操作
  // ==========================================

  /// 取得股票的融資融券歷史
  Future<List<MarginTradingEntry>> getMarginTradingHistory(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) {
    final query = select(marginTrading)
      ..where((t) => t.symbol.equals(symbol))
      ..where((t) => t.date.isBiggerOrEqualValue(startDate));

    if (endDate != null) {
      query.where((t) => t.date.isSmallerOrEqualValue(endDate));
    }

    query.orderBy([(t) => OrderingTerm.asc(t.date)]);
    return query.get();
  }

  /// 取得股票的最新融資融券資料
  Future<MarginTradingEntry?> getLatestMarginTrading(String symbol) {
    return (select(marginTrading)
          ..where((t) => t.symbol.equals(symbol))
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// 取得指定日期的所有融資融券資料
  Future<List<MarginTradingEntry>> getMarginTradingForDate(DateTime date) {
    // 使用本地時間午夜以匹配資料庫儲存格式
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return (select(marginTrading)
          ..where((t) => t.date.isBiggerOrEqualValue(startOfDay))
          ..where((t) => t.date.isSmallerThanValue(endOfDay)))
        .get();
  }

  /// 取得指定日期的融資融券資料筆數（新鮮度檢查用）
  Future<int> getMarginTradingCountForDate(DateTime date) async {
    // 使用本地時間午夜以匹配資料庫儲存格式
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final countExpr = marginTrading.symbol.count();
    final query = selectOnly(marginTrading)
      ..addColumns([countExpr])
      ..where(marginTrading.date.isBiggerOrEqualValue(startOfDay))
      ..where(marginTrading.date.isSmallerThanValue(endOfDay));
    final result = await query.getSingle();
    return result.read(countExpr) ?? 0;
  }

  /// 批次新增融資融券資料
  Future<void> insertMarginTradingData(
    List<MarginTradingCompanion> entries,
  ) async {
    await batch((b) {
      for (final entry in entries) {
        b.insert(marginTrading, entry, mode: InsertMode.insertOrReplace);
      }
    });
  }

  // ==========================================
  // 財務報表操作
  // ==========================================

  /// 取得股票的財務資料
  Future<List<FinancialDataEntry>> getFinancialData(
    String symbol, {
    required String statementType,
    required DateTime startDate,
    DateTime? endDate,
  }) {
    final query = select(financialData)
      ..where((t) => t.symbol.equals(symbol))
      ..where((t) => t.statementType.equals(statementType))
      ..where((t) => t.date.isBiggerOrEqualValue(startDate));

    if (endDate != null) {
      query.where((t) => t.date.isSmallerOrEqualValue(endDate));
    }

    query.orderBy([(t) => OrderingTerm.asc(t.date)]);
    return query.get();
  }

  /// 取得股票的特定財務指標
  Future<List<FinancialDataEntry>> getFinancialMetrics(
    String symbol, {
    required List<String> dataTypes,
    required DateTime startDate,
  }) {
    return (select(financialData)
          ..where((t) => t.symbol.equals(symbol))
          ..where((t) => t.dataType.isIn(dataTypes))
          ..where((t) => t.date.isBiggerOrEqualValue(startDate))
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();
  }

  /// 批次新增財務資料
  Future<void> insertFinancialData(List<FinancialDataCompanion> entries) async {
    await batch((b) {
      for (final entry in entries) {
        b.insert(financialData, entry, mode: InsertMode.insertOrReplace);
      }
    });
  }

  /// 取得股票與報表類型的最新財務資料日期（新鮮度檢查用）
  Future<DateTime?> getLatestFinancialDataDate(
    String symbol,
    String statementType,
  ) async {
    final result =
        await (select(financialData)
              ..where((t) => t.symbol.equals(symbol))
              ..where((t) => t.statementType.equals(statementType))
              ..orderBy([(t) => OrderingTerm.desc(t.date)])
              ..limit(1))
            .getSingleOrNull();
    return result?.date;
  }

  // ==========================================
  // 還原股價操作
  // ==========================================

  /// 取得股票的還原股價歷史
  Future<List<AdjustedPriceEntry>> getAdjustedPriceHistory(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) {
    final query = select(adjustedPrice)
      ..where((t) => t.symbol.equals(symbol))
      ..where((t) => t.date.isBiggerOrEqualValue(startDate));

    if (endDate != null) {
      query.where((t) => t.date.isSmallerOrEqualValue(endDate));
    }

    query.orderBy([(t) => OrderingTerm.asc(t.date)]);
    return query.get();
  }

  /// 批次新增還原股價資料
  Future<void> insertAdjustedPrices(
    List<AdjustedPriceCompanion> entries,
  ) async {
    await batch((b) {
      for (final entry in entries) {
        b.insert(adjustedPrice, entry, mode: InsertMode.insertOrReplace);
      }
    });
  }

  /// 取得股票的最新還原股價日期（新鮮度檢查用）
  Future<DateTime?> getLatestAdjustedPriceDate(String symbol) async {
    final result =
        await (select(adjustedPrice)
              ..where((t) => t.symbol.equals(symbol))
              ..orderBy([(t) => OrderingTerm.desc(t.date)])
              ..limit(1))
            .getSingleOrNull();
    return result?.date;
  }

  // ==========================================
  // 週K線操作
  // ==========================================

  /// 取得股票的週K線歷史
  Future<List<WeeklyPriceEntry>> getWeeklyPriceHistory(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) {
    final query = select(weeklyPrice)
      ..where((t) => t.symbol.equals(symbol))
      ..where((t) => t.date.isBiggerOrEqualValue(startDate));

    if (endDate != null) {
      query.where((t) => t.date.isSmallerOrEqualValue(endDate));
    }

    query.orderBy([(t) => OrderingTerm.asc(t.date)]);
    return query.get();
  }

  /// 批次新增週K線資料
  Future<void> insertWeeklyPrices(List<WeeklyPriceCompanion> entries) async {
    await batch((b) {
      for (final entry in entries) {
        b.insert(weeklyPrice, entry, mode: InsertMode.insertOrReplace);
      }
    });
  }

  /// 取得股票的最新週K線日期（新鮮度檢查用）
  Future<DateTime?> getLatestWeeklyPriceDate(String symbol) async {
    final result =
        await (select(weeklyPrice)
              ..where((t) => t.symbol.equals(symbol))
              ..orderBy([(t) => OrderingTerm.desc(t.date)])
              ..limit(1))
            .getSingleOrNull();
    return result?.date;
  }

  // ==========================================
  // 股權分散操作
  // ==========================================

  /// 取得股票在指定日期的股權分散資料
  Future<List<HoldingDistributionEntry>> getHoldingDistribution(
    String symbol, {
    required DateTime date,
  }) {
    return (select(holdingDistribution)
          ..where((t) => t.symbol.equals(symbol))
          ..where((t) => t.date.equals(date)))
        .get();
  }

  /// 取得股票的最新股權分散資料
  Future<List<HoldingDistributionEntry>> getLatestHoldingDistribution(
    String symbol,
  ) async {
    // 先取得最新日期
    final latestDate = await customSelect(
      'SELECT MAX(date) as max_date FROM holding_distribution WHERE symbol = ?',
      variables: [Variable.withString(symbol)],
      readsFrom: {holdingDistribution},
    ).getSingleOrNull();

    if (latestDate == null) return [];
    final maxDate = latestDate.read<DateTime?>('max_date');
    if (maxDate == null) return [];

    return (select(holdingDistribution)
          ..where((t) => t.symbol.equals(symbol))
          ..where((t) => t.date.equals(maxDate)))
        .get();
  }

  /// 批次新增股權分散資料
  Future<void> insertHoldingDistribution(
    List<HoldingDistributionCompanion> entries,
  ) async {
    await batch((b) {
      for (final entry in entries) {
        b.insert(holdingDistribution, entry, mode: InsertMode.insertOrReplace);
      }
    });
  }

  /// 取得股票的最新股權分散日期（新鮮度檢查用）
  Future<DateTime?> getLatestHoldingDistributionDate(String symbol) async {
    final result = await customSelect(
      'SELECT MAX(date) as max_date FROM holding_distribution WHERE symbol = ?',
      variables: [Variable.withString(symbol)],
      readsFrom: {holdingDistribution},
    ).getSingleOrNull();
    return result?.read<DateTime?>('max_date');
  }

  // ==========================================
  // 月營收操作
  // ==========================================

  /// 取得股票的月營收歷史
  Future<List<MonthlyRevenueEntry>> getMonthlyRevenueHistory(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) {
    final query = select(monthlyRevenue)
      ..where((t) => t.symbol.equals(symbol))
      ..where((t) => t.date.isBiggerOrEqualValue(startDate));

    if (endDate != null) {
      query.where((t) => t.date.isSmallerOrEqualValue(endDate));
    }

    query.orderBy([(t) => OrderingTerm.asc(t.date)]);
    return query.get();
  }

  /// 取得股票的最新月營收
  Future<MonthlyRevenueEntry?> getLatestMonthlyRevenue(String symbol) {
    return (select(monthlyRevenue)
          ..where((t) => t.symbol.equals(symbol))
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// 批次取得多檔股票的最新月營收（批次查詢）
  Future<Map<String, MonthlyRevenueEntry>> getLatestMonthlyRevenuesBatch(
    List<String> symbols,
  ) async {
    if (symbols.isEmpty) return {};

    // 建立 SQL IN 子句的佔位符
    final placeholders = List.filled(symbols.length, '?').join(', ');

    final query =
        '''
      SELECT mr.*
      FROM monthly_revenue mr
      INNER JOIN (
        SELECT symbol, MAX(date) as max_date
        FROM monthly_revenue
        WHERE symbol IN ($placeholders)
        GROUP BY symbol
      ) latest ON mr.symbol = latest.symbol AND mr.date = latest.max_date
    ''';

    final results = await customSelect(
      query,
      variables: symbols.map((s) => Variable.withString(s)).toList(),
      readsFrom: {monthlyRevenue},
    ).get();

    final result = <String, MonthlyRevenueEntry>{};
    for (final row in results) {
      final entry = MonthlyRevenueEntry(
        symbol: row.read<String>('symbol'),
        date: row.read<DateTime>('date'),
        revenueYear: row.read<int>('revenue_year'),
        revenueMonth: row.read<int>('revenue_month'),
        revenue: row.read<double>('revenue'),
        momGrowth: row.readNullable<double>('mom_growth'),
        yoyGrowth: row.readNullable<double>('yoy_growth'),
      );
      result[entry.symbol] = entry;
    }

    return result;
  }

  /// 取得股票近 N 個月的營收資料
  Future<List<MonthlyRevenueEntry>> getRecentMonthlyRevenue(
    String symbol, {
    int months = 13, // 13 個月以計算 12 個月的年增率
  }) {
    return (select(monthlyRevenue)
          ..where((t) => t.symbol.equals(symbol))
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(months))
        .get();
  }

  /// 批次取得多檔股票近 N 個月的營收資料（批次查詢）
  ///
  /// 回傳 symbol -> 營收資料列表 的 Map（依日期降冪排序）
  Future<Map<String, List<MonthlyRevenueEntry>>> getRecentMonthlyRevenueBatch(
    List<String> symbols, {
    int months = 6, // 6 個月用於追蹤月增率
  }) async {
    if (symbols.isEmpty) return {};

    // 建立 SQL IN 子句的佔位符
    final placeholders = List.filled(symbols.length, '?').join(', ');

    // 使用 ROW_NUMBER 取得每檔股票的前 N 個月
    // 比執行 N 次個別查詢更有效率
    final query =
        '''
      SELECT * FROM (
        SELECT mr.*, 
               ROW_NUMBER() OVER (PARTITION BY symbol ORDER BY date DESC) as rn
        FROM monthly_revenue mr
        WHERE symbol IN ($placeholders)
      ) ranked
      WHERE rn <= ?
      ORDER BY symbol, date DESC
    ''';

    final results = await customSelect(
      query,
      variables: [
        ...symbols.map((s) => Variable.withString(s)),
        Variable.withInt(months),
      ],
      readsFrom: {monthlyRevenue},
    ).get();

    // 依 symbol 分組
    final result = <String, List<MonthlyRevenueEntry>>{};
    for (final row in results) {
      final symbol = row.read<String>('symbol');
      final entry = MonthlyRevenueEntry(
        symbol: symbol,
        date: row.read<DateTime>('date'),
        revenueYear: row.read<int>('revenue_year'),
        revenueMonth: row.read<int>('revenue_month'),
        revenue: row.read<double>('revenue'),
        momGrowth: row.readNullable<double>('mom_growth'),
        yoyGrowth: row.readNullable<double>('yoy_growth'),
      );
      result.putIfAbsent(symbol, () => []).add(entry);
    }

    return result;
  }

  /// 批次新增月營收資料
  Future<void> insertMonthlyRevenue(
    List<MonthlyRevenueCompanion> entries,
  ) async {
    await batch((b) {
      for (final entry in entries) {
        b.insert(monthlyRevenue, entry, mode: InsertMode.insertOrReplace);
      }
    });
  }

  /// 取得指定年/月的月營收資料筆數
  ///
  /// 用於檢查是否已有該月的全市場營收資料，以避免重複的 API 呼叫。
  Future<int> getRevenueCountForYearMonth(int year, int month) async {
    final countExpr = monthlyRevenue.symbol.count();
    final query = selectOnly(monthlyRevenue)
      ..addColumns([countExpr])
      ..where(monthlyRevenue.revenueYear.equals(year))
      ..where(monthlyRevenue.revenueMonth.equals(month));
    final result = await query.getSingle();
    return result.read(countExpr) ?? 0;
  }

  // ==========================================
  // 估值資料操作
  // ==========================================

  /// 取得股票的估值歷史
  Future<List<StockValuationEntry>> getValuationHistory(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) {
    final query = select(stockValuation)
      ..where((t) => t.symbol.equals(symbol))
      ..where((t) => t.date.isBiggerOrEqualValue(startDate));

    if (endDate != null) {
      query.where((t) => t.date.isSmallerOrEqualValue(endDate));
    }

    query.orderBy([(t) => OrderingTerm.asc(t.date)]);
    return query.get();
  }

  /// 取得股票的最新估值
  Future<StockValuationEntry?> getLatestValuation(String symbol) {
    return (select(stockValuation)
          ..where((t) => t.symbol.equals(symbol))
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// 批次取得多檔股票的最新估值（批次查詢）
  Future<Map<String, StockValuationEntry>> getLatestValuationsBatch(
    List<String> symbols,
  ) async {
    if (symbols.isEmpty) return {};

    // 建立 SQL IN 子句的佔位符
    final placeholders = List.filled(symbols.length, '?').join(', ');

    final query =
        '''
      SELECT sv.*
      FROM stock_valuation sv
      INNER JOIN (
        SELECT symbol, MAX(date) as max_date
        FROM stock_valuation
        WHERE symbol IN ($placeholders)
        GROUP BY symbol
      ) latest ON sv.symbol = latest.symbol AND sv.date = latest.max_date
    ''';

    final results = await customSelect(
      query,
      variables: symbols.map((s) => Variable.withString(s)).toList(),
      readsFrom: {stockValuation},
    ).get();

    final result = <String, StockValuationEntry>{};
    for (final row in results) {
      final entry = StockValuationEntry(
        symbol: row.read<String>('symbol'),
        date: row.read<DateTime>('date'),
        per: row.readNullable<double>('per'),
        pbr: row.readNullable<double>('pbr'),
        dividendYield: row.readNullable<double>('dividend_yield'),
      );
      result[entry.symbol] = entry;
    }

    return result;
  }

  /// 批次新增估值資料
  Future<void> insertValuationData(
    List<StockValuationCompanion> entries,
  ) async {
    await batch((b) {
      for (final entry in entries) {
        b.insert(stockValuation, entry, mode: InsertMode.insertOrReplace);
      }
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'afterclose.db'));
    return NativeDatabase.createInBackground(file);
  });
}
