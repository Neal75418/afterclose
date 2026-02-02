part of 'package:afterclose/data/database/app_database.dart';

/// Market overview aggregate query (大盤總覽彙總查詢) operations.
mixin _MarketOverviewDaoMixin on _$AppDatabase {
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
