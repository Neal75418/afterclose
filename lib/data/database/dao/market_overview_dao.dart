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
    final startOfDay = DateContext.normalize(date);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // 直接使用 daily_price.price_change 欄位（API 同步時已填入）
    // 避免 INNER JOIN 前一交易日，確保只有 1 天資料的股票也能統計
    const query = '''
    SELECT
      sm.market,
      SUM(CASE WHEN dp.price_change > 0 THEN 1 ELSE 0 END) as advance,
      SUM(CASE WHEN dp.price_change < 0 THEN 1 ELSE 0 END) as decline,
      SUM(CASE WHEN dp.price_change = 0 THEN 1 ELSE 0 END) as unchanged
    FROM daily_price dp
    INNER JOIN stock_master sm ON dp.symbol = sm.symbol
    WHERE dp.date >= ? AND dp.date < ?
      AND dp.close IS NOT NULL
      AND dp.price_change IS NOT NULL
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
    final startOfDay = DateContext.normalize(date);
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
    final startOfDay = DateContext.normalize(date);
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

  /// 取得各市場最新融資融券餘額彙總（自動偵測各市場最新日期）
  ///
  /// 單一查詢：用 subquery 找出各市場最新日期後直接聚合。
  /// 解決 TWSE/TPEx 融資融券資料日期不同步的問題（TPEx 有 T+1 延遲）。
  /// 回傳格式同 [getMarginTradingTotalsByMarket]。
  Future<Map<String, Map<String, double>>>
  getLatestMarginTradingTotalsByMarket() async {
    const query = '''
    SELECT
      sm.market,
      COALESCE(SUM(mt.margin_balance), 0) as margin_balance,
      COALESCE(SUM(mt.margin_buy - mt.margin_sell), 0) as margin_change,
      COALESCE(SUM(mt.short_balance), 0) as short_balance,
      COALESCE(SUM(mt.short_sell - mt.short_buy), 0) as short_change
    FROM margin_trading mt
    INNER JOIN stock_master sm ON mt.symbol = sm.symbol
    INNER JOIN (
      SELECT sm2.market, MAX(mt2.date) as max_date
      FROM margin_trading mt2
      INNER JOIN stock_master sm2 ON mt2.symbol = sm2.symbol
      GROUP BY sm2.market
    ) latest ON sm.market = latest.market AND mt.date = latest.max_date
    GROUP BY sm.market
  ''';

    final results = await customSelect(
      query,
      readsFrom: {marginTrading, stockMaster},
    ).get();

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
    final startOfDay = DateContext.normalize(date);
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

  /// 取得指定日期的漲停/跌停家數（依市場分組）
  ///
  /// 計算方式：`priceChange / (close - priceChange) * 100`
  /// >= 9.5% 為漲停，<= -9.5% 為跌停（台股漲跌停幅度 10%，用 9.5% 以涵蓋四捨五入）
  ///
  /// 注意：槓桿型/反向型 ETF 漲跌幅限制不同（如 2x 為 20%），此處統一用
  /// 9.5% 門檻，可能將這類 ETF 的正常波動誤判為漲停/跌停。數量極少不影響趨勢。
  /// 回傳 `Map<String, Map<String, int>>`
  /// 範例: `{'TWSE': {'limitUp': 5, 'limitDown': 3}, 'TPEx': {...}}`
  Future<Map<String, Map<String, int>>> getLimitUpDownCountsByMarket(
    DateTime date,
  ) async {
    final startOfDay = DateContext.normalize(date);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    const query = '''
    SELECT sm.market,
      SUM(CASE WHEN (dp.price_change / (dp.close - dp.price_change) * 100) >= 9.5 THEN 1 ELSE 0 END) as limit_up,
      SUM(CASE WHEN (dp.price_change / (dp.close - dp.price_change) * 100) <= -9.5 THEN 1 ELSE 0 END) as limit_down
    FROM daily_price dp
    INNER JOIN stock_master sm ON dp.symbol = sm.symbol
    WHERE dp.date >= ? AND dp.date < ?
      AND dp.close IS NOT NULL AND dp.price_change IS NOT NULL
      AND (dp.close - dp.price_change) != 0
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

    final byMarket = <String, Map<String, int>>{};
    for (final row in results) {
      final market = row.readNullable<String>('market');
      if (market == null) continue;

      byMarket[market] = {
        'limitUp': row.readNullable<int>('limit_up') ?? 0,
        'limitDown': row.readNullable<int>('limit_down') ?? 0,
      };
    }

    return byMarket;
  }

  /// 取得近 N+1 個交易日各市場成交額（供計算今日 vs 均量比較）
  ///
  /// 回傳 `Map<String, List<({DateTime date, double turnover})>>`
  /// 日期降序排列（最新在前），第一筆為當日，後續為前 N 日
  Future<Map<String, List<({DateTime date, double turnover})>>>
  getRecentTurnoverByMarket(DateTime date, {int days = 5}) async {
    final endOfDay = DateContext.normalize(date).add(const Duration(days: 1));
    // 多取幾天以排除非交易日
    final startDate = DateContext.normalize(
      date,
    ).subtract(Duration(days: days * 2 + 5));

    const query = '''
    SELECT sm.market, dp.date, COALESCE(SUM(dp.close * dp.volume), 0) as day_turnover
    FROM daily_price dp
    INNER JOIN stock_master sm ON dp.symbol = sm.symbol
    WHERE dp.date > ? AND dp.date < ?
      AND dp.volume IS NOT NULL AND dp.close IS NOT NULL
    GROUP BY sm.market, dp.date
    ORDER BY dp.date DESC
  ''';

    final results = await customSelect(
      query,
      variables: [
        Variable.withDateTime(startDate),
        Variable.withDateTime(endOfDay),
      ],
      readsFrom: {dailyPrice, stockMaster},
    ).get();

    final byMarket = <String, List<({DateTime date, double turnover})>>{};
    for (final row in results) {
      final market = row.readNullable<String>('market');
      final rowDate = row.readNullable<DateTime>('date');
      final turnover = row.readNullable<double>('day_turnover');
      if (market == null || rowDate == null) continue;

      byMarket.putIfAbsent(market, () => []).add((
        date: rowDate,
        turnover: turnover ?? 0,
      ));
    }

    // 只保留前 days+1 筆（當日 + N 個歷史交易日）
    for (final key in byMarket.keys) {
      final list = byMarket[key]!;
      if (list.length > days + 1) {
        byMarket[key] = list.sublist(0, days + 1);
      }
    }

    return byMarket;
  }

  /// 取得目前生效的注意/處置股家數（依市場分組）
  ///
  /// 回傳 `Map<String, Map<String, int>>`
  /// 範例: `{'TWSE': {'ATTENTION': 15, 'DISPOSAL': 3}, 'TPEx': {...}}`
  Future<Map<String, Map<String, int>>> getActiveWarningCountsByMarket() async {
    const query = '''
    SELECT sm.market, tw.warning_type, COUNT(DISTINCT tw.symbol) as cnt
    FROM trading_warning tw
    INNER JOIN stock_master sm ON tw.symbol = sm.symbol
    WHERE tw.is_active = 1
    GROUP BY sm.market, tw.warning_type
  ''';

    final results = await customSelect(
      query,
      readsFrom: {tradingWarning, stockMaster},
    ).get();

    final byMarket = <String, Map<String, int>>{};
    for (final row in results) {
      final market = row.readNullable<String>('market');
      final type = row.readNullable<String>('warning_type');
      final cnt = row.readNullable<int>('cnt') ?? 0;
      if (market == null || type == null) continue;

      byMarket.putIfAbsent(market, () => {})[type] = cnt;
    }

    return byMarket;
  }

  /// 取得近 N 日各市場法人每日淨額聚合（供連續買賣超天數計算）
  ///
  /// 回傳 `Map<String, List<({DateTime date, double foreignNet, double trustNet, double dealerNet})>>`
  /// 日期降序排列（最新在前）
  Future<
    Map<
      String,
      List<
        ({DateTime date, double foreignNet, double trustNet, double dealerNet})
      >
    >
  >
  getRecentInstitutionalDailyByMarket(DateTime date, {int days = 30}) async {
    final endOfDay = DateContext.normalize(date).add(const Duration(days: 1));
    final startDate = DateContext.normalize(
      date,
    ).subtract(Duration(days: days * 2));

    const query = '''
    SELECT sm.market, di.date,
      COALESCE(SUM(di.foreign_net), 0) as foreign_net,
      COALESCE(SUM(di.investment_trust_net), 0) as trust_net,
      COALESCE(SUM(di.dealer_net), 0) as dealer_net
    FROM daily_institutional di
    INNER JOIN stock_master sm ON di.symbol = sm.symbol
    WHERE di.date > ? AND di.date < ?
    GROUP BY sm.market, di.date
    ORDER BY di.date DESC
  ''';

    final results = await customSelect(
      query,
      variables: [
        Variable.withDateTime(startDate),
        Variable.withDateTime(endOfDay),
      ],
      readsFrom: {dailyInstitutional, stockMaster},
    ).get();

    final byMarket =
        <
          String,
          List<
            ({
              DateTime date,
              double foreignNet,
              double trustNet,
              double dealerNet,
            })
          >
        >{};
    for (final row in results) {
      final market = row.readNullable<String>('market');
      final rowDate = row.readNullable<DateTime>('date');
      if (market == null || rowDate == null) continue;

      byMarket.putIfAbsent(market, () => []).add((
        date: rowDate,
        foreignNet: row.readNullable<double>('foreign_net') ?? 0,
        trustNet: row.readNullable<double>('trust_net') ?? 0,
        dealerNet: row.readNullable<double>('dealer_net') ?? 0,
      ));
    }

    // 只保留最多 days 筆
    for (final key in byMarket.keys) {
      final list = byMarket[key]!;
      if (list.length > days) {
        byMarket[key] = list.sublist(0, days);
      }
    }

    return byMarket;
  }

  /// 取得指定日期的產業表現統計（指定市場）
  ///
  /// 回傳 `List<Map<String, dynamic>>` 依平均漲跌幅降序
  /// 每筆包含：industry, stockCount, avgChangePct, advance, decline
  Future<List<Map<String, dynamic>>> getIndustrySummaryByMarket(
    DateTime date,
    String market,
  ) async {
    final startOfDay = DateContext.normalize(date);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    const query = '''
    SELECT sm.industry, COUNT(*) as stock_count,
      AVG(dp.price_change / (dp.close - dp.price_change) * 100) as avg_change_pct,
      SUM(CASE WHEN dp.price_change > 0 THEN 1 ELSE 0 END) as advance,
      SUM(CASE WHEN dp.price_change < 0 THEN 1 ELSE 0 END) as decline
    FROM daily_price dp
    INNER JOIN stock_master sm ON dp.symbol = sm.symbol
    WHERE dp.date >= ? AND dp.date < ? AND sm.market = ?
      AND dp.close IS NOT NULL AND dp.price_change IS NOT NULL
      AND (dp.close - dp.price_change) != 0
      AND sm.industry IS NOT NULL
    GROUP BY sm.industry
    ORDER BY avg_change_pct DESC
  ''';

    final results = await customSelect(
      query,
      variables: [
        Variable.withDateTime(startOfDay),
        Variable.withDateTime(endOfDay),
        Variable.withString(market),
      ],
      readsFrom: {dailyPrice, stockMaster},
    ).get();

    return results.map((row) {
      return {
        'industry': row.readNullable<String>('industry') ?? '',
        'stockCount': row.readNullable<int>('stock_count') ?? 0,
        'avgChangePct': row.readNullable<double>('avg_change_pct') ?? 0.0,
        'advance': row.readNullable<int>('advance') ?? 0,
        'decline': row.readNullable<int>('decline') ?? 0,
      };
    }).toList();
  }
}
