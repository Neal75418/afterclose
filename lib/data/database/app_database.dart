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
    // 股利歷史
    DividendHistory,
    // 融資融券資料（Phase 4）
    MarginTrading,
    // 風險控管資料（Killer Features）
    TradingWarning,
    InsiderHolding,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// 測試用 - 建立記憶體內 Database
  AppDatabase.forTesting() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // 確保 FK 約束在 migration 時生效
      await customStatement('PRAGMA foreign_keys = ON');

      // v1 -> v2: 新增 news_item.content 欄位
      if (from < 2) {
        await customStatement('ALTER TABLE news_item ADD COLUMN content TEXT');
      }

      // v2 -> v3: 新增 Killer Features 表格（注意/處置股、董監持股）
      if (from < 3) {
        // 建立 trading_warning 表
        await customStatement('''
          CREATE TABLE IF NOT EXISTS trading_warning (
            symbol TEXT NOT NULL REFERENCES stock_master(symbol) ON DELETE CASCADE,
            date INTEGER NOT NULL,
            warning_type TEXT NOT NULL,
            reason_code TEXT,
            reason_description TEXT,
            disposal_measures TEXT,
            disposal_start_date INTEGER,
            disposal_end_date INTEGER,
            is_active INTEGER NOT NULL DEFAULT 1,
            PRIMARY KEY (symbol, date, warning_type)
          )
        ''');
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_trading_warning_symbol ON trading_warning(symbol)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_trading_warning_date ON trading_warning(date)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_trading_warning_type ON trading_warning(warning_type)',
        );

        // 建立 insider_holding 表
        await customStatement('''
          CREATE TABLE IF NOT EXISTS insider_holding (
            symbol TEXT NOT NULL REFERENCES stock_master(symbol) ON DELETE CASCADE,
            date INTEGER NOT NULL,
            director_shares REAL,
            supervisor_shares REAL,
            manager_shares REAL,
            insider_ratio REAL,
            pledge_ratio REAL,
            shares_change REAL,
            shares_issued REAL,
            PRIMARY KEY (symbol, date)
          )
        ''');
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_insider_holding_symbol ON insider_holding(symbol)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_insider_holding_date ON insider_holding(date)',
        );
      }

      // v3 -> v4: 新增股利歷史表
      if (from < 4) {
        await customStatement('''
          CREATE TABLE IF NOT EXISTS dividend_history (
            symbol TEXT NOT NULL REFERENCES stock_master(symbol) ON DELETE CASCADE,
            year INTEGER NOT NULL,
            cash_dividend REAL NOT NULL DEFAULT 0,
            stock_dividend REAL NOT NULL DEFAULT 0,
            ex_dividend_date TEXT,
            ex_rights_date TEXT,
            PRIMARY KEY (symbol, year)
          )
        ''');
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_dividend_history_symbol ON dividend_history(symbol)',
        );
        // year index 不需要：PK (symbol, year) 已提供最佳查詢路徑
      }
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

  /// 取得所有不重複的產業類別（已排序）
  Future<List<String>> getDistinctIndustries() async {
    final query = selectOnly(stockMaster, distinct: true)
      ..addColumns([stockMaster.industry])
      ..where(stockMaster.isActive.equals(true))
      ..where(stockMaster.industry.isNotNull());
    final rows = await query.get();
    return rows
        .map((row) => row.read(stockMaster.industry))
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toList()
      ..sort();
  }

  /// 取得指定產業的所有股票代碼
  Future<Set<String>> getSymbolsByIndustry(String industry) async {
    if (industry.isEmpty) return {};
    final results =
        await (select(stockMaster)
              ..where((t) => t.isActive.equals(true))
              ..where((t) => t.industry.equals(industry)))
            .get();
    return results.map((s) => s.symbol).toSet();
  }

  /// 取得各產業的股票數量
  Future<Map<String, int>> getIndustryStockCounts() async {
    final query = selectOnly(stockMaster)
      ..addColumns([stockMaster.industry, stockMaster.symbol.count()])
      ..where(stockMaster.isActive.equals(true))
      ..where(stockMaster.industry.isNotNull())
      ..groupBy([stockMaster.industry]);
    final rows = await query.get();
    final result = <String, int>{};
    for (final row in rows) {
      final industry = row.read(stockMaster.industry);
      final count = row.read(stockMaster.symbol.count());
      if (industry != null && industry.isNotEmpty && count != null) {
        result[industry] = count;
      }
    }
    return result;
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

  /// 取得候選股票歷史資料完成度
  ///
  /// 回傳 (已完成檔數, 總檔數)
  /// - total: 有價格資料的股票數量（實際會被分析的候選股票）
  /// - completed: 有 >= [RuleParams.historicalDataMinDays] 天價格資料的股票數量
  Future<({int completed, int total})> getHistoricalDataProgress() async {
    // 計算有價格資料的股票數量（實際會被分析的候選股票）
    final totalResult = await customSelect('''
      SELECT COUNT(DISTINCT dp.symbol) as cnt
      FROM daily_price dp
      INNER JOIN stock_master sm ON dp.symbol = sm.symbol AND sm.is_active = 1
      ''').getSingle();
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

  /// 取得單一自選股條目（含 createdAt 時間戳）
  Future<WatchlistEntry?> getWatchlistEntry(String symbol) {
    return (select(
      watchlist,
    )..where((t) => t.symbol.equals(symbol))).getSingleOrNull();
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

  /// 更新執行記錄的資料日期
  ///
  /// 用於日期校正後更新 runDate，確保記錄的是實際資料日期
  Future<void> updateRunDate(int id, DateTime runDate) {
    return (update(updateRun)..where((t) => t.id.equals(id))).write(
      UpdateRunCompanion(runDate: Value(runDate)),
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

  /// 批次取得多檔股票的最新持股資料
  ///
  /// 用於 Isolate 評分時傳遞外資持股資料。
  /// 回傳 symbol -> ShareholdingEntry 的對應表。
  Future<Map<String, ShareholdingEntry>> getLatestShareholdingsBatch(
    List<String> symbols,
  ) async {
    if (symbols.isEmpty) return {};

    final results = await customSelect(
      '''
      SELECT s.*
      FROM shareholding s
      INNER JOIN (
        SELECT symbol, MAX(date) as max_date
        FROM shareholding
        WHERE symbol IN (${symbols.map((_) => '?').join(', ')})
        GROUP BY symbol
      ) latest ON s.symbol = latest.symbol AND s.date = latest.max_date
      ''',
      variables: symbols.map((s) => Variable.withString(s)).toList(),
    ).get();

    final map = <String, ShareholdingEntry>{};
    for (final row in results) {
      final symbol = row.read<String>('symbol');
      map[symbol] = ShareholdingEntry(
        symbol: symbol,
        date: DateTime.parse(row.read<String>('date')),
        foreignRemainingShares: row.read<double?>('foreign_remaining_shares'),
        foreignSharesRatio: row.read<double?>('foreign_shares_ratio'),
        foreignUpperLimitRatio: row.read<double?>('foreign_upper_limit_ratio'),
        sharesIssued: row.read<double?>('shares_issued'),
      );
    }
    return map;
  }

  /// 批次取得 N 天前的外資持股資料
  ///
  /// 用於計算外資持股變化量（foreignSharesRatioChange）。
  /// 取得每檔股票在指定日期之前最接近的持股資料。
  Future<Map<String, ShareholdingEntry>> getShareholdingsBeforeDateBatch(
    List<String> symbols, {
    required DateTime beforeDate,
  }) async {
    if (symbols.isEmpty) return {};

    final results = await customSelect(
      '''
      SELECT s.*
      FROM shareholding s
      INNER JOIN (
        SELECT symbol, MAX(date) as max_date
        FROM shareholding
        WHERE symbol IN (${symbols.map((_) => '?').join(', ')})
          AND date < ?
        GROUP BY symbol
      ) prev ON s.symbol = prev.symbol AND s.date = prev.max_date
      ''',
      variables: [
        ...symbols.map((s) => Variable.withString(s)),
        Variable.withDateTime(beforeDate),
      ],
    ).get();

    final map = <String, ShareholdingEntry>{};
    for (final row in results) {
      final symbol = row.read<String>('symbol');
      map[symbol] = ShareholdingEntry(
        symbol: symbol,
        date: DateTime.parse(row.read<String>('date')),
        foreignRemainingShares: row.read<double?>('foreign_remaining_shares'),
        foreignSharesRatio: row.read<double?>('foreign_shares_ratio'),
        foreignUpperLimitRatio: row.read<double?>('foreign_upper_limit_ratio'),
        sharesIssued: row.read<double?>('shares_issued'),
      );
    }
    return map;
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

  /// 取得單檔股票的 EPS 歷史（最近 8 季，降序）
  Future<List<FinancialDataEntry>> getEPSHistory(String symbol) {
    return (select(financialData)
          ..where((t) => t.symbol.equals(symbol))
          ..where((t) => t.statementType.equals('INCOME'))
          ..where((t) => t.dataType.equals('EPS'))
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(8))
        .get();
  }

  /// 批次取得多檔股票的 EPS 歷史（評分管線用）
  Future<Map<String, List<FinancialDataEntry>>> getEPSHistoryBatch(
    List<String> symbols,
  ) async {
    if (symbols.isEmpty) return {};

    final entries =
        await (select(financialData)
              ..where((t) => t.symbol.isIn(symbols))
              ..where((t) => t.statementType.equals('INCOME'))
              ..where((t) => t.dataType.equals('EPS'))
              ..orderBy([(t) => OrderingTerm.desc(t.date)]))
            .get();

    final result = <String, List<FinancialDataEntry>>{};
    for (final e in entries) {
      result.putIfAbsent(e.symbol, () => []).add(e);
    }
    // 每檔只保留最近 8 季
    for (final key in result.keys) {
      if (result[key]!.length > 8) {
        result[key] = result[key]!.sublist(0, 8);
      }
    }
    return result;
  }

  /// 取得最新一季的完整財務指標（UI 用）
  Future<Map<String, double>> getLatestQuarterMetrics(String symbol) async {
    final latest =
        await (select(financialData)
              ..where((t) => t.symbol.equals(symbol))
              ..where((t) => t.statementType.equals('INCOME'))
              ..orderBy([(t) => OrderingTerm.desc(t.date)])
              ..limit(1))
            .getSingleOrNull();

    if (latest == null) return {};

    final entries =
        await (select(financialData)
              ..where((t) => t.symbol.equals(symbol))
              ..where((t) => t.date.equals(latest.date)))
            .get();

    return {
      for (final e in entries)
        if (e.value != null) e.dataType: e.value!,
    };
  }

  /// 取得單檔股票的 Equity 歷史（最近 8 季，降序）
  Future<List<FinancialDataEntry>> getEquityHistory(String symbol) {
    return (select(financialData)
          ..where((t) => t.symbol.equals(symbol))
          ..where((t) => t.statementType.equals('BALANCE'))
          ..where((t) => t.dataType.equals('Equity'))
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(8))
        .get();
  }

  /// 批次計算 ROE 歷史（評分管線用）
  ///
  /// 從 INCOME.NetIncome + BALANCE.Equity 按 symbol+date join 計算
  /// ROE = NetIncome / Equity × 100
  /// 回傳虛擬 FinancialDataEntry (dataType='ROE')
  Future<Map<String, List<FinancialDataEntry>>> getROEHistoryBatch(
    List<String> symbols,
  ) async {
    if (symbols.isEmpty) return {};

    // 1. 批次查 NetIncome
    final netIncomeEntries =
        await (select(financialData)
              ..where((t) => t.symbol.isIn(symbols))
              ..where((t) => t.statementType.equals('INCOME'))
              ..where((t) => t.dataType.equals('NetIncome'))
              ..orderBy([(t) => OrderingTerm.desc(t.date)]))
            .get();

    // 2. 批次查 Equity
    final equityEntries =
        await (select(financialData)
              ..where((t) => t.symbol.isIn(symbols))
              ..where((t) => t.statementType.equals('BALANCE'))
              ..where((t) => t.dataType.equals('Equity'))
              ..orderBy([(t) => OrderingTerm.desc(t.date)]))
            .get();

    // 3. 建立 Equity 快速查詢 map: (symbol, date) -> value
    final equityMap = <(String, DateTime), double>{};
    for (final e in equityEntries) {
      if (e.value != null && e.value! > 0) {
        equityMap[(e.symbol, e.date)] = e.value!;
      }
    }

    // 4. Join 計算年化 ROE（季度 NetIncome × 4 / Equity × 100）
    final result = <String, List<FinancialDataEntry>>{};
    for (final ni in netIncomeEntries) {
      if (ni.value == null) continue;
      final equity = equityMap[(ni.symbol, ni.date)];
      if (equity == null || equity == 0) continue;

      final roe = ni.value! * 4 / equity * 100;
      final roeEntry = FinancialDataEntry(
        symbol: ni.symbol,
        date: ni.date,
        statementType: 'ROE',
        dataType: 'ROE',
        value: roe,
        originName: null,
      );
      result.putIfAbsent(ni.symbol, () => []).add(roeEntry);
    }

    // 5. 每檔只保留最近 8 季
    for (final key in result.keys) {
      if (result[key]!.length > 8) {
        result[key] = result[key]!.sublist(0, 8);
      }
    }
    return result;
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

  // ==========================================
  // 股利歷史操作
  // ==========================================

  /// 取得股票的股利歷史（依年度降冪排序）
  Future<List<DividendHistoryEntry>> getDividendHistory(String symbol) {
    return (select(dividendHistory)
          ..where((t) => t.symbol.equals(symbol))
          ..orderBy([(t) => OrderingTerm.desc(t.year)]))
        .get();
  }

  /// 批次新增股利資料
  Future<void> insertDividendData(
    List<DividendHistoryCompanion> entries,
  ) async {
    await batch((b) {
      for (final entry in entries) {
        b.insert(dividendHistory, entry, mode: InsertMode.insertOrReplace);
      }
    });
  }

  /// 取得股票最新的股利年度（新鮮度檢查用）
  Future<int?> getLatestDividendYear(String symbol) async {
    final result =
        await (select(dividendHistory)
              ..where((t) => t.symbol.equals(symbol))
              ..orderBy([(t) => OrderingTerm.desc(t.year)])
              ..limit(1))
            .getSingleOrNull();
    return result?.year;
  }

  // ==========================================
  // 注意股票/處置股票操作
  // ==========================================

  /// 取得股票的警示歷史
  Future<List<TradingWarningEntry>> getWarningHistory(
    String symbol, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final query = select(tradingWarning)..where((t) => t.symbol.equals(symbol));

    if (startDate != null) {
      query.where((t) => t.date.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where((t) => t.date.isSmallerOrEqualValue(endDate));
    }

    query.orderBy([(t) => OrderingTerm.desc(t.date)]);
    return query.get();
  }

  /// 取得股票目前生效的警示
  Future<List<TradingWarningEntry>> getActiveWarnings(String symbol) {
    return (select(tradingWarning)
          ..where((t) => t.symbol.equals(symbol))
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

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

  /// 檢查股票是否有目前生效的警示
  Future<bool> hasActiveWarning(String symbol) async {
    final result =
        await (select(tradingWarning)
              ..where((t) => t.symbol.equals(symbol))
              ..where((t) => t.isActive.equals(true))
              ..limit(1))
            .getSingleOrNull();
    return result != null;
  }

  /// 檢查股票是否為處置股
  Future<bool> isDisposalStock(String symbol) async {
    final result =
        await (select(tradingWarning)
              ..where((t) => t.symbol.equals(symbol))
              ..where((t) => t.isActive.equals(true))
              ..where((t) => t.warningType.equals('DISPOSAL'))
              ..limit(1))
            .getSingleOrNull();
    return result != null;
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
  Future<int> updateExpiredWarnings() async {
    final now = DateTime.now();
    return (update(tradingWarning)
          ..where((t) => t.isActive.equals(true))
          ..where((t) => t.disposalEndDate.isSmallerThanValue(now)))
        .write(const TradingWarningCompanion(isActive: Value(false)));
  }

  /// 取得指定日期的警示資料筆數（新鮮度檢查用）
  Future<int> getWarningCountForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
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

  // ==========================================
  // 董監事持股操作
  // ==========================================

  /// 取得股票的董監持股歷史
  Future<List<InsiderHoldingEntry>> getInsiderHoldingHistory(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) {
    final query = select(insiderHolding)
      ..where((t) => t.symbol.equals(symbol))
      ..where((t) => t.date.isBiggerOrEqualValue(startDate));

    if (endDate != null) {
      query.where((t) => t.date.isSmallerOrEqualValue(endDate));
    }

    query.orderBy([(t) => OrderingTerm.asc(t.date)]);
    return query.get();
  }

  /// 取得股票的最新董監持股資料
  Future<InsiderHoldingEntry?> getLatestInsiderHolding(String symbol) {
    return (select(insiderHolding)
          ..where((t) => t.symbol.equals(symbol))
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// 取得股票近 N 個月的董監持股資料
  Future<List<InsiderHoldingEntry>> getRecentInsiderHoldings(
    String symbol, {
    int months = 6,
  }) {
    return (select(insiderHolding)
          ..where((t) => t.symbol.equals(symbol))
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(months))
        .get();
  }

  /// 批次取得多檔股票的最新董監持股（批次查詢）
  Future<Map<String, InsiderHoldingEntry>> getLatestInsiderHoldingsBatch(
    List<String> symbols,
  ) async {
    if (symbols.isEmpty) return {};

    final placeholders = List.filled(symbols.length, '?').join(', ');

    final query =
        '''
      SELECT ih.*
      FROM insider_holding ih
      INNER JOIN (
        SELECT symbol, MAX(date) as max_date
        FROM insider_holding
        WHERE symbol IN ($placeholders)
        GROUP BY symbol
      ) latest ON ih.symbol = latest.symbol AND ih.date = latest.max_date
    ''';

    final results = await customSelect(
      query,
      variables: symbols.map((s) => Variable.withString(s)).toList(),
      readsFrom: {insiderHolding},
    ).get();

    final result = <String, InsiderHoldingEntry>{};
    for (final row in results) {
      final entry = InsiderHoldingEntry(
        symbol: row.read<String>('symbol'),
        date: row.read<DateTime>('date'),
        directorShares: row.readNullable<double>('director_shares'),
        supervisorShares: row.readNullable<double>('supervisor_shares'),
        managerShares: row.readNullable<double>('manager_shares'),
        insiderRatio: row.readNullable<double>('insider_ratio'),
        pledgeRatio: row.readNullable<double>('pledge_ratio'),
        sharesChange: row.readNullable<double>('shares_change'),
        sharesIssued: row.readNullable<double>('shares_issued'),
      );
      result[entry.symbol] = entry;
    }

    return result;
  }

  /// 批次取得多檔股票近 N 月的董監持股歷史（批次查詢）
  ///
  /// 用於計算連續減持/增持狀態
  Future<Map<String, List<InsiderHoldingEntry>>> getRecentInsiderHoldingsBatch(
    List<String> symbols, {
    int months = 4,
  }) async {
    if (symbols.isEmpty) return {};

    final placeholders = List.filled(symbols.length, '?').join(', ');

    // 計算起始日期（Dart 側計算，避免 SQL 字串插值）
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month - months, now.day);
    final startDateStr =
        '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';

    // 取得每個 symbol 最近 N 筆資料（按日期降序）
    final query =
        '''
      SELECT ih.*
      FROM insider_holding ih
      WHERE ih.symbol IN ($placeholders)
        AND ih.date >= ?
      ORDER BY ih.symbol, ih.date DESC
    ''';

    final results = await customSelect(
      query,
      variables: [
        ...symbols.map((s) => Variable.withString(s)),
        Variable.withString(startDateStr),
      ],
      readsFrom: {insiderHolding},
    ).get();

    final result = <String, List<InsiderHoldingEntry>>{};
    for (final row in results) {
      final entry = InsiderHoldingEntry(
        symbol: row.read<String>('symbol'),
        date: row.read<DateTime>('date'),
        directorShares: row.readNullable<double>('director_shares'),
        supervisorShares: row.readNullable<double>('supervisor_shares'),
        managerShares: row.readNullable<double>('manager_shares'),
        insiderRatio: row.readNullable<double>('insider_ratio'),
        pledgeRatio: row.readNullable<double>('pledge_ratio'),
        sharesChange: row.readNullable<double>('shares_change'),
        sharesIssued: row.readNullable<double>('shares_issued'),
      );
      result.putIfAbsent(entry.symbol, () => []).add(entry);
    }

    return result;
  }

  /// 取得高質押比例的股票（風險警示）
  Future<List<InsiderHoldingEntry>> getHighPledgeRatioStocks({
    required double threshold,
  }) async {
    // 先取得每檔股票的最新資料，再過濾高質押
    const query = '''
      SELECT ih.*
      FROM insider_holding ih
      INNER JOIN (
        SELECT symbol, MAX(date) as max_date
        FROM insider_holding
        GROUP BY symbol
      ) latest ON ih.symbol = latest.symbol AND ih.date = latest.max_date
      WHERE ih.pledge_ratio >= ?
      ORDER BY ih.pledge_ratio DESC
    ''';

    final results = await customSelect(
      query,
      variables: [Variable.withReal(threshold)],
      readsFrom: {insiderHolding},
    ).get();

    return results.map((row) {
      return InsiderHoldingEntry(
        symbol: row.read<String>('symbol'),
        date: row.read<DateTime>('date'),
        directorShares: row.readNullable<double>('director_shares'),
        supervisorShares: row.readNullable<double>('supervisor_shares'),
        managerShares: row.readNullable<double>('manager_shares'),
        insiderRatio: row.readNullable<double>('insider_ratio'),
        pledgeRatio: row.readNullable<double>('pledge_ratio'),
        sharesChange: row.readNullable<double>('shares_change'),
        sharesIssued: row.readNullable<double>('shares_issued'),
      );
    }).toList();
  }

  /// 批次新增董監持股資料
  Future<void> insertInsiderHoldingData(
    List<InsiderHoldingCompanion> entries,
  ) async {
    await batch((b) {
      for (final entry in entries) {
        b.insert(insiderHolding, entry, mode: InsertMode.insertOrReplace);
      }
    });
  }

  /// 取得指定年月的董監持股資料筆數（新鮮度檢查用）
  Future<int> getInsiderHoldingCountForYearMonth(int year, int month) async {
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 1);
    final countExpr = insiderHolding.symbol.count();
    final query = selectOnly(insiderHolding)
      ..addColumns([countExpr])
      ..where(insiderHolding.date.isBiggerOrEqualValue(startOfMonth))
      ..where(insiderHolding.date.isSmallerThanValue(endOfMonth));
    final result = await query.getSingle();
    return result.read(countExpr) ?? 0;
  }

  // ==========================================
  // 大盤總覽彙總查詢
  // ==========================================

  /// 取得指定日期的上漲/下跌/平盤家數
  ///
  /// 從 DailyPrice 統計當日漲跌家數。
  /// 回傳 `{advance: int, decline: int, unchanged: int}`
  Future<Map<String, int>> getAdvanceDeclineCounts(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // 用子查詢計算每檔漲跌：當日收盤 vs 前一交易日收盤
    const query = '''
      WITH today AS (
        SELECT symbol, close
        FROM daily_price
        WHERE date >= ? AND date < ?
          AND close IS NOT NULL
      ),
      prev AS (
        SELECT dp.symbol, dp.close
        FROM daily_price dp
        INNER JOIN (
          SELECT symbol, MAX(date) as prev_date
          FROM daily_price
          WHERE date < ? AND close IS NOT NULL
          GROUP BY symbol
        ) latest ON dp.symbol = latest.symbol AND dp.date = latest.prev_date
      )
      SELECT
        SUM(CASE WHEN t.close > p.close THEN 1 ELSE 0 END) as advance,
        SUM(CASE WHEN t.close < p.close THEN 1 ELSE 0 END) as decline,
        SUM(CASE WHEN t.close = p.close THEN 1 ELSE 0 END) as unchanged
      FROM today t
      INNER JOIN prev p ON t.symbol = p.symbol
    ''';

    final results = await customSelect(
      query,
      variables: [
        Variable.withDateTime(startOfDay),
        Variable.withDateTime(endOfDay),
        Variable.withDateTime(startOfDay),
      ],
      readsFrom: {dailyPrice},
    ).getSingle();

    return {
      'advance': results.readNullable<int>('advance') ?? 0,
      'decline': results.readNullable<int>('decline') ?? 0,
      'unchanged': results.readNullable<int>('unchanged') ?? 0,
    };
  }

  /// 取得指定日期的三大法人買賣超總額
  ///
  /// 從 DailyInstitutional 彙總外資、投信、自營買賣超（元）。
  /// 回傳 `{foreignNet, trustNet, dealerNet, totalNet}`
  Future<Map<String, double>> getInstitutionalTotals(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    const query = '''
      SELECT
        COALESCE(SUM(foreign_net), 0) as foreign_net,
        COALESCE(SUM(investment_trust_net), 0) as trust_net,
        COALESCE(SUM(dealer_net), 0) as dealer_net,
        COALESCE(SUM(foreign_net), 0) + COALESCE(SUM(investment_trust_net), 0) + COALESCE(SUM(dealer_net), 0) as total_net
      FROM daily_institutional
      WHERE date >= ? AND date < ?
    ''';

    final results = await customSelect(
      query,
      variables: [
        Variable.withDateTime(startOfDay),
        Variable.withDateTime(endOfDay),
      ],
      readsFrom: {dailyInstitutional},
    ).getSingle();

    return {
      'foreignNet': results.readNullable<double>('foreign_net') ?? 0,
      'trustNet': results.readNullable<double>('trust_net') ?? 0,
      'dealerNet': results.readNullable<double>('dealer_net') ?? 0,
      'totalNet': results.readNullable<double>('total_net') ?? 0,
    };
  }

  /// 取得指定日期的融資融券餘額彙總
  ///
  /// 從 MarginTrading 彙總融資/融券餘額及變化（張）。
  /// 回傳 `{marginBalance, marginChange, shortBalance, shortChange}`
  Future<Map<String, double>> getMarginTradingTotals(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    const query = '''
      SELECT
        COALESCE(SUM(margin_balance), 0) as margin_balance,
        COALESCE(SUM(margin_buy - margin_sell), 0) as margin_change,
        COALESCE(SUM(short_balance), 0) as short_balance,
        COALESCE(SUM(short_sell - short_buy), 0) as short_change
      FROM margin_trading
      WHERE date >= ? AND date < ?
    ''';

    final results = await customSelect(
      query,
      variables: [
        Variable.withDateTime(startOfDay),
        Variable.withDateTime(endOfDay),
      ],
      readsFrom: {marginTrading},
    ).getSingle();

    return {
      'marginBalance': results.readNullable<double>('margin_balance') ?? 0,
      'marginChange': results.readNullable<double>('margin_change') ?? 0,
      'shortBalance': results.readNullable<double>('short_balance') ?? 0,
      'shortChange': results.readNullable<double>('short_change') ?? 0,
    };
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'afterclose.db'));
    return NativeDatabase.createInBackground(file);
  });
}
