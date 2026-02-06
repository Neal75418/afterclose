part of 'package:afterclose/data/database/app_database.dart';

/// Daily price, adjusted price, and weekly price operations.
mixin _PriceDaoMixin on _$AppDatabase {
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
    // 多取一些以處理同一天不同時區格式的重複資料（通常每日 1-2 筆重複，保守取 3 倍）
    final allRecent =
        await (select(dailyPrice)
              ..where((t) => t.symbol.equals(symbol))
              ..orderBy([(t) => OrderingTerm.desc(t.date)])
              ..limit(count * 3))
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
        priceChange: row.readNullable<double>('price_change'),
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
}
