import 'package:drift/drift.dart';

import 'package:afterclose/data/database/app_database.drift.dart';
import 'package:afterclose/data/database/tables/market_data_tables.drift.dart';

/// 股票估值（PER / PBR / 殖利率）資料操作
mixin ValuationDaoMixin on $AppDatabase {
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

  /// 批次取得多檔股票的最新估值（批次查詢）
  /// [asOf] 給定時只取該日（含）以前的資料
  ///
  /// 無上界的全域 `MAX(date)` 在對歷史日重跑時會把**未來**的基本面寫進當日
  /// 訊號（`daily_reason` → `rule_accuracy` 的輸入）。`tool/replay_calibrator`
  /// 早已做 point-in-time 過濾，此處補上同一口徑，讓 runtime 與 calibrator
  /// 結構上一致，也讓「把歷史重放進 daily_reason」成為安全的操作。
  ///
  /// 省略時維持原本的全域最新語意（正式路徑的評分日恆為今日，實測四張
  /// 基本面表無任何超前列，故行為不變）。
  Future<Map<String, StockValuationEntry>> getLatestValuationsBatch(
    List<String> symbols, {
    DateTime? asOf,
  }) async {
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
      ${asOf == null ? '' : 'AND date <= ?'}
      GROUP BY symbol
    ) latest ON sv.symbol = latest.symbol AND sv.date = latest.max_date
  ''';

    final results = await customSelect(
      query,
      variables: [
        ...symbols.map((s) => Variable.withString(s)),
        if (asOf != null) Variable.withDateTime(asOf),
      ],
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
