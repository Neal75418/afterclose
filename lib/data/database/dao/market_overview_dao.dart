part of 'package:afterclose/data/database/app_database.dart';

/// Market overview aggregate query (大盤總覽彙總查詢) operations.
mixin _MarketOverviewDaoMixin on _$AppDatabase {
  /// 取得指定日期的上漲/下跌/平盤家數（依市場分組）
  ///
  /// 從 DailyPrice 統計當日漲跌家數，依 market 欄位分組。
  /// 回傳 `Map<String, Map<String, int>>`
  /// 範例: `{'TWSE': {'advance': 120, 'decline': 85, 'unchanged': 10}, 'TPEx': {...}}`
  Future<Map<String, Map<String, int>>> getAdvanceDeclineCountsByMarket(
    DateTime date,
  ) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // 用子查詢計算每檔漲跌：當日收盤 vs 前一交易日收盤，依市場分組
    const query = '''
    WITH today AS (
      SELECT dp.symbol, dp.close, sm.market
      FROM daily_price dp
      INNER JOIN stock_master sm ON dp.symbol = sm.symbol
      WHERE dp.date >= ? AND dp.date < ?
        AND dp.close IS NOT NULL
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
      t.market,
      SUM(CASE WHEN t.close > p.close THEN 1 ELSE 0 END) as advance,
      SUM(CASE WHEN t.close < p.close THEN 1 ELSE 0 END) as decline,
      SUM(CASE WHEN t.close = p.close THEN 1 ELSE 0 END) as unchanged
    FROM today t
    INNER JOIN prev p ON t.symbol = p.symbol
    GROUP BY t.market
  ''';

    final results = await customSelect(
      query,
      variables: [
        Variable.withDateTime(startOfDay),
        Variable.withDateTime(endOfDay),
        Variable.withDateTime(startOfDay),
      ],
      readsFrom: {dailyPrice, stockMaster},
    ).get();

    // 轉換為 Map<String, Map<String, int>>
    final byMarket = <String, Map<String, int>>{};
    for (final row in results) {
      final market = row.readNullable<String>('market');
      if (market == null) continue;

      byMarket[market] = {
        'advance': row.readNullable<int>('advance') ?? 0,
        'decline': row.readNullable<int>('decline') ?? 0,
        'unchanged': row.readNullable<int>('unchanged') ?? 0,
      };
    }

    return byMarket;
  }

  /// 取得指定日期的上漲/下跌/平盤家數（全市場合併）
  ///
  /// 向後相容方法，內部呼叫 [getAdvanceDeclineCountsByMarket] 並合併結果。
  /// 回傳 `{advance: int, decline: int, unchanged: int}`
  Future<Map<String, int>> getAdvanceDeclineCounts(DateTime date) async {
    final byMarket = await getAdvanceDeclineCountsByMarket(date);

    // 合併 TWSE + TPEx
    int sumKey(String key) =>
        (byMarket['TWSE']?[key] ?? 0) + (byMarket['TPEx']?[key] ?? 0);

    return {
      'advance': sumKey('advance'),
      'decline': sumKey('decline'),
      'unchanged': sumKey('unchanged'),
    };
  }

  /// 取得指定日期的三大法人買賣超總額（依市場分組）
  ///
  /// 從 DailyInstitutional 彙總外資、投信、自營買賣超（張），依 market 分組。
  /// 回傳 `Map<String, Map<String, double>>`
  /// 範例: `{'TWSE': {'foreignNet': 12345, ...}, 'TPEx': {...}}`
  Future<Map<String, Map<String, double>>> getInstitutionalTotalsByMarket(
    DateTime date,
  ) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    const query = '''
    SELECT
      sm.market,
      COALESCE(SUM(di.foreign_net), 0) as foreign_net,
      COALESCE(SUM(di.investment_trust_net), 0) as trust_net,
      COALESCE(SUM(di.dealer_net), 0) as dealer_net,
      COALESCE(SUM(di.foreign_net), 0) + COALESCE(SUM(di.investment_trust_net), 0) + COALESCE(SUM(di.dealer_net), 0) as total_net
    FROM daily_institutional di
    INNER JOIN stock_master sm ON di.symbol = sm.symbol
    WHERE di.date >= ? AND di.date < ?
    GROUP BY sm.market
  ''';

    final results = await customSelect(
      query,
      variables: [
        Variable.withDateTime(startOfDay),
        Variable.withDateTime(endOfDay),
      ],
      readsFrom: {dailyInstitutional, stockMaster},
    ).get();

    // 轉換為 Map<String, Map<String, double>>
    final byMarket = <String, Map<String, double>>{};
    for (final row in results) {
      final market = row.readNullable<String>('market');
      if (market == null) continue;

      byMarket[market] = {
        'foreignNet': row.readNullable<double>('foreign_net') ?? 0,
        'trustNet': row.readNullable<double>('trust_net') ?? 0,
        'dealerNet': row.readNullable<double>('dealer_net') ?? 0,
        'totalNet': row.readNullable<double>('total_net') ?? 0,
      };
    }

    return byMarket;
  }

  /// 取得指定日期的三大法人買賣超總額（全市場合併）
  ///
  /// 向後相容方法，內部呼叫 [getInstitutionalTotalsByMarket] 並合併結果。
  /// 回傳 `{foreignNet, trustNet, dealerNet, totalNet}`
  Future<Map<String, double>> getInstitutionalTotals(DateTime date) async {
    final byMarket = await getInstitutionalTotalsByMarket(date);

    // 合併 TWSE + TPEx
    double sumKey(String key) =>
        (byMarket['TWSE']?[key] ?? 0) + (byMarket['TPEx']?[key] ?? 0);

    return {
      'foreignNet': sumKey('foreignNet'),
      'trustNet': sumKey('trustNet'),
      'dealerNet': sumKey('dealerNet'),
      'totalNet': sumKey('totalNet'),
    };
  }

  /// 取得指定日期的融資融券餘額彙總（依市場分組）
  ///
  /// 從 MarginTrading 彙總融資/融券餘額及變化（張），依 market 分組。
  /// 回傳 `Map<String, Map<String, double>>`
  /// 範例: `{'TWSE': {'marginBalance': 123456, ...}, 'TPEx': {...}}`
  Future<Map<String, Map<String, double>>> getMarginTradingTotalsByMarket(
    DateTime date,
  ) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    const query = '''
    SELECT
      sm.market,
      COALESCE(SUM(mt.margin_balance), 0) as margin_balance,
      COALESCE(SUM(mt.margin_buy - mt.margin_sell), 0) as margin_change,
      COALESCE(SUM(mt.short_balance), 0) as short_balance,
      COALESCE(SUM(mt.short_sell - mt.short_buy), 0) as short_change
    FROM margin_trading mt
    INNER JOIN stock_master sm ON mt.symbol = sm.symbol
    WHERE mt.date >= ? AND mt.date < ?
    GROUP BY sm.market
  ''';

    final results = await customSelect(
      query,
      variables: [
        Variable.withDateTime(startOfDay),
        Variable.withDateTime(endOfDay),
      ],
      readsFrom: {marginTrading, stockMaster},
    ).get();

    // 轉換為 Map<String, Map<String, double>>
    final byMarket = <String, Map<String, double>>{};
    for (final row in results) {
      final market = row.readNullable<String>('market');
      if (market == null) continue;

      byMarket[market] = {
        'marginBalance': row.readNullable<double>('margin_balance') ?? 0,
        'marginChange': row.readNullable<double>('margin_change') ?? 0,
        'shortBalance': row.readNullable<double>('short_balance') ?? 0,
        'shortChange': row.readNullable<double>('short_change') ?? 0,
      };
    }

    return byMarket;
  }

  /// 取得指定日期的融資融券餘額彙總（全市場合併）
  ///
  /// 向後相容方法，內部呼叫 [getMarginTradingTotalsByMarket] 並合併結果。
  /// 回傳 `{marginBalance, marginChange, shortBalance, shortChange}`
  Future<Map<String, double>> getMarginTradingTotals(DateTime date) async {
    final byMarket = await getMarginTradingTotalsByMarket(date);

    // 合併 TWSE + TPEx
    double sumKey(String key) =>
        (byMarket['TWSE']?[key] ?? 0) + (byMarket['TPEx']?[key] ?? 0);

    return {
      'marginBalance': sumKey('marginBalance'),
      'marginChange': sumKey('marginChange'),
      'shortBalance': sumKey('shortBalance'),
      'shortChange': sumKey('shortChange'),
    };
  }

  /// 取得指定日期的成交額統計（依市場分組）
  ///
  /// 從 DailyPrice 彙總當日成交額（元），依 market 分組。
  /// 計算方式：SUM(close × volume)
  /// 回傳 `Map<String, Map<String, double>>`
  /// 範例: `{'TWSE': {'totalTurnover': 642195569620.0}, 'TPEx': {...}}`
  Future<Map<String, Map<String, double>>> getTurnoverSummaryByMarket(
    DateTime date,
  ) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    const query = '''
    SELECT
      sm.market,
      COALESCE(SUM(dp.close * dp.volume), 0) as total_turnover
    FROM daily_price dp
    INNER JOIN stock_master sm ON dp.symbol = sm.symbol
    WHERE dp.date >= ? AND dp.date < ?
      AND dp.volume IS NOT NULL
      AND dp.close IS NOT NULL
    GROUP BY sm.market
  ''';

    final results = await customSelect(
      query,
      variables: [
        Variable.withDateTime(startOfDay),
        Variable.withDateTime(endOfDay),
      ],
      readsFrom: {dailyPrice, stockMaster},
    ).get();

    // 轉換為 Map<String, Map<String, double>>
    final byMarket = <String, Map<String, double>>{};
    for (final row in results) {
      final market = row.readNullable<String>('market');
      if (market == null) continue;

      byMarket[market] = {
        'totalTurnover': row.readNullable<double>('total_turnover') ?? 0.0,
      };
    }

    return byMarket;
  }

  /// 取得指定日期的成交額統計（全市場合併）
  ///
  /// 向後相容方法，內部呼叫 [getTurnoverSummaryByMarket] 並合併結果。
  /// 回傳 `{totalTurnover: double}`（單位：元）
  Future<Map<String, double>> getTurnoverSummary(DateTime date) async {
    final byMarket = await getTurnoverSummaryByMarket(date);

    // 合併 TWSE + TPEx
    double sumKey(String key) =>
        (byMarket['TWSE']?[key] ?? 0) + (byMarket['TPEx']?[key] ?? 0);

    return {'totalTurnover': sumKey('totalTurnover')};
  }

  /// 取得指定日期的成交量統計（依市場分組）- 向後相容
  @Deprecated('Use getTurnoverSummaryByMarket instead')
  Future<Map<String, Map<String, double>>> getVolumeSummaryByMarket(
    DateTime date,
  ) => getTurnoverSummaryByMarket(date);
}
