import 'package:drift/drift.dart';
import 'package:afterclose/data/database/app_database.dart';

/// Financial data (財務報表) operations.
extension FinancialDataDao on AppDatabase {
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
}
