import 'package:drift/drift.dart';

import 'package:afterclose/core/constants/rule_params_indicator.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/data/database/app_database.drift.dart';
import 'package:afterclose/data/database/tables/daily_price.drift.dart';

/// 日價格、還原價格、週價格操作
mixin PriceDaoMixin on $AppDatabase {
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

  /// 取得指定 symbol 在指定日期的價格（事件詳情用）
  Future<DailyPriceEntry?> getPriceOnDate(String symbol, DateTime date) {
    final normalized = DateContext.normalize(date);
    return (select(dailyPrice)
          ..where((t) => t.symbol.equals(symbol) & t.date.equals(normalized)))
        .getSingleOrNull();
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
  Future<Map<String, int>> cleanupInvalidStockCodes() {
    // 包裝在 transaction 確保 6 個跨表刪除的原子性；
    // 中斷時不會留下部分清理的不一致狀態
    return transaction(() async {
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
    });
  }

  /// 計算某交易日、某市場（TWSE / TPEx）已寫入的價格筆數
  ///
  /// backfill per-day batch 的 resume 判斷用：該日該市場筆數達目標數量
  /// 門檻即視為已完成、跳過 API 呼叫。以 stock_master.market 區分市場，
  /// 避免 TWSE 已回補的日子讓 TPEx phase 誤判為完成（或反之）。
  Future<int> countPricesByDateAndMarket(DateTime date, String market) async {
    final result = await customSelect(
      '''
    SELECT COUNT(*) as cnt
    FROM daily_price dp
    INNER JOIN stock_master sm ON dp.symbol = sm.symbol
    WHERE dp.date = ? AND sm.market = ?
    ''',
      variables: [Variable.withDateTime(date), Variable.withString(market)],
    ).getSingle();
    return result.read<int>('cnt');
  }

  /// 批次計算每檔股票「近 [windowDays] 個交易日」的中位成交值（volume × close）。
  ///
  /// 候選層流動性下限用（`RuleParams.liquidityMinMedianTurnoverNtd`）。
  /// 交易日窗以**全市場第 [windowDays] 新的日期**為界（個股停牌日自然缺席）。
  /// 有效資料（volume 與 close 皆非 null）天數 < [minDataDays] 的股票不出現
  /// 在結果中 —— caller 應視為「無法判定」而 permissive 放行。
  Future<Map<String, double>> getMedianTurnoverBatch({
    required DateTime endDate,
    required int windowDays,
    required int minDataDays,
  }) async {
    // 全市場第 windowDays 新的交易日（含 endDate 以前）
    final cutoffRow = await customSelect(
      '''
      SELECT DISTINCT date FROM daily_price
      WHERE date <= ? ORDER BY date DESC LIMIT 1 OFFSET ?
      ''',
      variables: [
        Variable.withDateTime(endDate),
        Variable.withInt(windowDays - 1),
      ],
    ).getSingleOrNull();
    if (cutoffRow == null) return const {};
    final cutoff = cutoffRow.read<DateTime>('date');

    final rows = await customSelect(
      '''
      SELECT symbol, volume * close AS turnover FROM daily_price
      WHERE date >= ? AND date <= ?
        AND volume IS NOT NULL AND close IS NOT NULL
      ''',
      variables: [
        Variable.withDateTime(cutoff),
        Variable.withDateTime(endDate),
      ],
    ).get();

    final bySymbol = <String, List<double>>{};
    for (final row in rows) {
      bySymbol
          .putIfAbsent(row.read<String>('symbol'), () => [])
          .add(row.read<double>('turnover'));
    }

    final result = <String, double>{};
    for (final entry in bySymbol.entries) {
      final values = entry.value;
      if (values.length < minDataDays) continue;
      values.sort();
      final mid = values.length ~/ 2;
      result[entry.key] = values.length.isOdd
          ? values[mid]
          : (values[mid - 1] + values[mid]) / 2;
    }
    return result;
  }

  /// 取得候選股票歷史資料完成度
  ///
  /// 回傳 (已完成檔數, 總檔數)
  /// - total: 有價格資料的股票數量（實際會被分析的候選股票）
  /// - completed: 有 >= [IndicatorParams.historicalDataMinDays] 天價格資料的股票數量
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
      variables: [Variable.withInt(IndicatorParams.historicalDataMinDays)],
    ).getSingle();
    final completed = completedResult.read<int>('cnt');

    return (completed: completed, total: total);
  }

  /// 批次取得多檔股票的價格歷史（批次查詢避免 N+1 問題）
  ///
  /// 回傳 symbol -> 價格列表 的 Map，依日期升冪排序
  /// 批次取得多檔股票的價格覆蓋摘要（歷史資料需求掃描用）
  ///
  /// 一次 GROUP BY (symbol, 年月) 取代 [getPriceHistoryBatch] 的整包載入
  /// ——需求掃描只用每檔的筆數/首末日/每月分佈，卻曾把 ~59 萬列完整
  /// 價格物件化跨 isolate（2026-07-15 in-app 實測 3.0 秒；aggregate
  /// 同資料量 ~0.7 秒）。邊界語意與 [getPriceHistoryBatch] 相同
  /// （>= startDate、<= endDate）。無資料的 symbol 不在回傳 Map。
  Future<Map<String, PriceCoverage>> getPriceCoverageBatch(
    List<String> symbols, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (symbols.isEmpty) return {};

    final rows = await customSelect(
      '''
      SELECT symbol,
             CAST(substr(date, 1, 4) AS INTEGER) AS y,
             CAST(substr(date, 6, 2) AS INTEGER) AS m,
             COUNT(*) AS n,
             MIN(date) AS first_date,
             MAX(date) AS last_date
      FROM daily_price
      WHERE date >= ? AND date <= ?
      GROUP BY symbol, y, m
      ''',
      variables: [
        Variable.withDateTime(startDate),
        Variable.withDateTime(endDate),
      ],
      readsFrom: {dailyPrice},
    ).get();

    final wanted = symbols.toSet();
    final counts = <String, int>{};
    final firsts = <String, DateTime>{};
    final lasts = <String, DateTime>{};
    final months = <String, Map<(int, int), int>>{};

    for (final row in rows) {
      final symbol = row.read<String>('symbol');
      if (!wanted.contains(symbol)) continue;

      final n = row.read<int>('n');
      // aggregate read() 回 UTC 表示，與 table 映射（local）是同一時刻的
      // 不同表示；統一轉 local 保持與 entry 版本完全等價（含 == 語意）
      final first = row.read<DateTime>('first_date').toLocal();
      final last = row.read<DateTime>('last_date').toLocal();

      counts[symbol] = (counts[symbol] ?? 0) + n;
      final prevFirst = firsts[symbol];
      if (prevFirst == null || first.isBefore(prevFirst)) {
        firsts[symbol] = first;
      }
      final prevLast = lasts[symbol];
      if (prevLast == null || last.isAfter(prevLast)) {
        lasts[symbol] = last;
      }
      months.putIfAbsent(
        symbol,
        () => {},
      )[(row.read<int>('y'), row.read<int>('m'))] = n;
    }

    return {
      for (final symbol in counts.keys)
        symbol: PriceCoverage(
          count: counts[symbol]!,
          firstDate: firsts[symbol]!,
          lastDate: lasts[symbol]!,
          daysByMonth: months[symbol]!,
        ),
    };
  }

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
    SELECT dp.symbol, COUNT(*) as cnt
    FROM daily_price dp
    INNER JOIN stock_master sm ON dp.symbol = sm.symbol AND sm.is_active = 1
    WHERE dp.date >= ? AND dp.date <= ?
    GROUP BY dp.symbol
    HAVING cnt >= ?
    ORDER BY cnt DESC, dp.symbol ASC
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
}

/// 單檔股票在指定窗內的價格覆蓋摘要（[PriceDaoMixin.getPriceCoverageBatch]）
///
/// 歷史資料需求掃描的讀取模型：只帶掃描所需的聚合值，
/// 不物件化完整價格列。
class PriceCoverage {
  const PriceCoverage({
    required this.count,
    required this.firstDate,
    required this.lastDate,
    required this.daysByMonth,
  });

  /// 窗內價格筆數
  final int count;

  /// 窗內首筆價格日
  final DateTime firstDate;

  /// 窗內末筆價格日
  final DateTime lastDate;

  /// (年, 月) → 該月已有的價格天數（月度缺口估算用）
  ///
  /// ⚠️ 與 [firstDate]/[lastDate] 走不同推導路徑：本欄位鍵值取自儲存文字
  /// 的 substr 前綴，首末日則經 drift 解析 + toLocal()。兩者一致性依賴
  /// 「寫入與讀取在同一裝置時區」——本 app 為 local-first 單機（GUI 與
  /// launchd CLI 同機同時區）故恆成立；若日後跨時區讀取 DB 檔，兩路徑
  /// 對月界列可能分歧。消費者一律唯讀，請勿變異此 Map（跨消費者共享
  /// 同一參考）。
  final Map<(int, int), int> daysByMonth;
}
