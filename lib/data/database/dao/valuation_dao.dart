part of 'package:afterclose/data/database/app_database.dart';

/// Stock valuation (估值) operations.
mixin _ValuationDaoMixin on _$AppDatabase {
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

  /// 取得指定日期的估值資料筆數
  Future<int> getValuationCountForDate(DateTime date) async {
    final countExpr = stockValuation.symbol.count();
    final query = selectOnly(stockValuation)
      ..addColumns([countExpr])
      ..where(stockValuation.date.equals(date));
    final result = await query.getSingle();
    return result.read(countExpr) ?? 0;
  }
}
