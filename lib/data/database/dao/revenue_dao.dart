import 'package:drift/drift.dart';
import 'package:afterclose/data/database/app_database.dart';

/// Monthly revenue (月營收) operations.
extension RevenueDao on AppDatabase {
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
}
