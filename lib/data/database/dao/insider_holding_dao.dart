part of 'package:afterclose/data/database/app_database.dart';

/// Insider holding (董監事持股) operations.
mixin _InsiderHoldingDaoMixin on _$AppDatabase {
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
    DateTime? now,
  }) async {
    if (symbols.isEmpty) return {};

    final placeholders = List.filled(symbols.length, '?').join(', ');

    // 計算起始日期（Dart 側計算，避免 SQL 字串插值）
    final effectiveNow = now ?? DateTime.now();
    final startDate = DateTime(
      effectiveNow.year,
      effectiveNow.month - months,
      effectiveNow.day,
    );
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
}
