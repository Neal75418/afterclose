part of 'package:afterclose/data/database/app_database.dart';

/// Shareholding (外資持股) operations.
mixin _ShareholdingDaoMixin on _$AppDatabase {
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

    final results = await customSelect('''
    SELECT s.*
    FROM shareholding s
    INNER JOIN (
      SELECT symbol, MAX(date) as max_date
      FROM shareholding
      WHERE symbol IN (${symbols.map((_) => '?').join(', ')})
      GROUP BY symbol
    ) latest ON s.symbol = latest.symbol AND s.date = latest.max_date
    ''', variables: symbols.map((s) => Variable.withString(s)).toList()).get();

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
}
