import 'package:drift/drift.dart';

import 'package:afterclose/core/constants/market_codes.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/data/database/app_database.drift.dart';

/// 大盤總覽彙總查詢操作
mixin MarketOverviewDaoMixin on $AppDatabase {
  /// 取得指定日期的上漲/下跌/平盤家數（依市場分組）
  ///
  /// 從 DailyPrice 統計當日漲跌家數，依 market 欄位分組。
  Future<Map<String, ({int advance, int decline, int unchanged})>>
  getAdvanceDeclineCountsByMarket(DateTime date) async {
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

    final byMarket = <String, ({int advance, int decline, int unchanged})>{};
    for (final row in results) {
      final market = row.readNullable<String>('market');
      if (market == null) continue;

      byMarket[market] = (
        advance: row.readNullable<int>('advance') ?? 0,
        decline: row.readNullable<int>('decline') ?? 0,
        unchanged: row.readNullable<int>('unchanged') ?? 0,
      );
    }

    return byMarket;
  }

  /// 取得指定日期的上漲/下跌/平盤家數（全市場合併）
  ///
  /// 內部呼叫 [getAdvanceDeclineCountsByMarket] 並合併結果。
  Future<({int advance, int decline, int unchanged})> getAdvanceDeclineCounts(
    DateTime date,
  ) async {
    final byMarket = await getAdvanceDeclineCountsByMarket(date);

    final twse = byMarket[MarketCode.twse];
    final tpex = byMarket[MarketCode.tpex];
    return (
      advance: (twse?.advance ?? 0) + (tpex?.advance ?? 0),
      decline: (twse?.decline ?? 0) + (tpex?.decline ?? 0),
      unchanged: (twse?.unchanged ?? 0) + (tpex?.unchanged ?? 0),
    );
  }

  /// 取得各市場最新融資融券餘額彙總（自動偵測各市場最新日期）
  ///
  /// 單一查詢：用 subquery 找出各市場最新日期後直接聚合。
  /// 解決 TWSE/TPEx 融資融券資料日期不同步的問題（TPEx 有 T+1 延遲）。
  Future<
    Map<
      String,
      ({
        double marginBalance,
        double marginChange,
        double shortBalance,
        double shortChange,
        DateTime? dataDate,
      })
    >
  >
  getLatestMarginTradingTotalsByMarket() async {
    const query = '''
    SELECT
      sm.market,
      latest.max_date as data_date,
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

    final byMarket =
        <
          String,
          ({
            double marginBalance,
            double marginChange,
            double shortBalance,
            double shortChange,
            DateTime? dataDate,
          })
        >{};
    for (final row in results) {
      final market = row.readNullable<String>('market');
      if (market == null) continue;

      // max_date 存為 ISO-8601 字串（Drift store_date_time_values_as_text）
      final dateStr = row.readNullable<String>('data_date');
      final dataDate = dateStr != null ? DateTime.tryParse(dateStr) : null;

      byMarket[market] = (
        marginBalance: row.readNullable<double>('margin_balance') ?? 0,
        marginChange: row.readNullable<double>('margin_change') ?? 0,
        shortBalance: row.readNullable<double>('short_balance') ?? 0,
        shortChange: row.readNullable<double>('short_change') ?? 0,
        dataDate: dataDate,
      );
    }

    return byMarket;
  }

  /// 取得指定日期的成交額統計（依市場分組）
  ///
  /// 從 DailyPrice 彙總當日成交額（元），依 market 分組。
  /// 計算方式：SUM(close × volume)
  Future<Map<String, ({double totalTurnover})>> getTurnoverSummaryByMarket(
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

    final byMarket = <String, ({double totalTurnover})>{};
    for (final row in results) {
      final market = row.readNullable<String>('market');
      if (market == null) continue;

      byMarket[market] = (
        totalTurnover: row.readNullable<double>('total_turnover') ?? 0.0,
      );
    }

    return byMarket;
  }

  /// 取得指定日期的漲停/跌停家數（依市場分組）
  ///
  /// 計算方式：`priceChange / (close - priceChange) * 100`
  /// >= 9.5% 為漲停，<= -9.5% 為跌停（台股漲跌停幅度 10%，用 9.5% 以涵蓋四捨五入）
  ///
  /// 注意：槓桿型/反向型 ETF 漲跌幅限制不同（如 2x 為 20%），此處統一用
  /// 9.5% 門檻，可能將這類 ETF 的正常波動誤判為漲停/跌停。數量極少不影響趨勢。
  Future<Map<String, ({int limitUp, int limitDown})>>
  getLimitUpDownCountsByMarket(DateTime date) async {
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

    final byMarket = <String, ({int limitUp, int limitDown})>{};
    for (final row in results) {
      final market = row.readNullable<String>('market');
      if (market == null) continue;

      byMarket[market] = (
        limitUp: row.readNullable<int>('limit_up') ?? 0,
        limitDown: row.readNullable<int>('limit_down') ?? 0,
      );
    }

    return byMarket;
  }

  /// 取得近 N+1 個「完整覆蓋」交易日各市場成交額（供計算今日 vs 均量比較）
  ///
  /// 本地 DB 部分日子僅同步候選子集（約半市場），混入後會使均量嚴重失真
  /// （曾出現假性「5日均 +278%」），故以 [minCoverage]（預設
  /// [kMinSymbolsForCompleteTradingDay]）濾除半套日，只保留個股報價數達
  /// 門檻的完整日。完整日約佔交易日 4-5 成，故回看窗口放寬至 days*5，確保
  /// 能取到 N+1 個完整日。
  ///
  /// 回傳 `Map<String, List<({DateTime date, double turnover})>>`
  /// 日期降序排列（最新在前），第一筆為當日，後續為前 N 個完整日
  Future<Map<String, List<({DateTime date, double turnover})>>>
  getRecentTurnoverByMarket(
    DateTime date, {
    int days = 5,
    int? minCoverage,
  }) async {
    final coverage = minCoverage ?? kMinSymbolsForCompleteTradingDay;
    final endOfDay = DateContext.normalize(date).add(const Duration(days: 1));
    // 完整日約佔交易日 4-5 成，放寬回看窗口以確保能取到 N+1 個完整日
    final startDate = DateContext.normalize(
      date,
    ).subtract(Duration(days: days * 5 + 7));

    const query = '''
    SELECT sm.market, dp.date, COALESCE(SUM(dp.close * dp.volume), 0) as day_turnover
    FROM daily_price dp
    INNER JOIN stock_master sm ON dp.symbol = sm.symbol
    WHERE dp.date > ? AND dp.date < ?
      AND dp.volume IS NOT NULL AND dp.close IS NOT NULL
    GROUP BY sm.market, dp.date
    HAVING COUNT(DISTINCT dp.symbol) >= ?
    ORDER BY dp.date DESC
  ''';

    final results = await customSelect(
      query,
      variables: [
        Variable.withDateTime(startDate),
        Variable.withDateTime(endOfDay),
        Variable.withInt(coverage),
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

  /// 取得近 N 個交易日各市場融資融券餘額歷史（供趨勢圖使用）
  ///
  /// 回傳 `Map<String, List<({DateTime date, double marginBalance, double shortBalance})>>`
  /// 日期降序排列（最新在前）
  Future<
    Map<
      String,
      List<({DateTime date, double marginBalance, double shortBalance})>
    >
  >
  getRecentMarginTradingByMarket(DateTime date, {int days = 30}) async {
    final endOfDay = DateContext.normalize(date).add(const Duration(days: 1));
    final startDate = DateContext.normalize(
      date,
    ).subtract(Duration(days: days * 2 + 5));

    const query = '''
    SELECT sm.market, mt.date,
      COALESCE(SUM(mt.margin_balance), 0) as margin_balance,
      COALESCE(SUM(mt.short_balance), 0) as short_balance
    FROM margin_trading mt
    INNER JOIN stock_master sm ON mt.symbol = sm.symbol
    WHERE mt.date > ? AND mt.date < ?
    GROUP BY sm.market, mt.date
    ORDER BY mt.date DESC
  ''';

    final results = await customSelect(
      query,
      variables: [
        Variable.withDateTime(startDate),
        Variable.withDateTime(endOfDay),
      ],
      readsFrom: {marginTrading, stockMaster},
    ).get();

    final byMarket =
        <
          String,
          List<({DateTime date, double marginBalance, double shortBalance})>
        >{};
    for (final row in results) {
      final market = row.readNullable<String>('market');
      final rowDate = row.readNullable<DateTime>('date');
      if (market == null || rowDate == null) continue;

      byMarket.putIfAbsent(market, () => []).add((
        date: rowDate,
        marginBalance: row.readNullable<double>('margin_balance') ?? 0,
        shortBalance: row.readNullable<double>('short_balance') ?? 0,
      ));
    }

    for (final key in byMarket.keys) {
      final list = byMarket[key]!;
      if (list.length > days) {
        byMarket[key] = list.sublist(0, days);
      }
    }

    return byMarket;
  }

  /// 取得近 N 個「完整覆蓋」交易日各市場漲跌家數歷史（供趨勢圖使用）
  ///
  /// 本地 DB 部分日子僅同步候選子集（約半市場 ~545 檔），與完整日（~1200 檔）
  /// 等權重混入 sparkline 會使漲跌比逐日跳動失真（曾出現完整日 0.557 ↔
  /// 半套日 0.279/0.677），且污染情緒歷史（advanceRatio 佔 25% 權重）。
  /// 故以 [minCoverage]（預設 [kMinSymbolsForCompleteTradingDay]）濾除半套
  /// 日，只保留個股報價數達門檻的完整日。完整日約佔交易日 4-5 成，故回看窗口
  /// 放寬至 days*5 以確保能取到足夠完整日。
  ///
  /// 回傳 `Map<String, List<({DateTime date, int advance, int decline, int unchanged})>>`
  /// 日期降序排列（最新在前）
  Future<
    Map<
      String,
      List<({DateTime date, int advance, int decline, int unchanged})>
    >
  >
  getRecentAdvanceDeclineByMarket(
    DateTime date, {
    int days = 30,
    int? minCoverage,
  }) async {
    final coverage = minCoverage ?? kMinSymbolsForCompleteTradingDay;
    final endOfDay = DateContext.normalize(date).add(const Duration(days: 1));
    // 完整日約佔交易日 4-5 成，放寬回看窗口以確保能取到足夠完整日
    final startDate = DateContext.normalize(
      date,
    ).subtract(Duration(days: days * 5 + 7));

    const query = '''
    SELECT sm.market, dp.date,
      SUM(CASE WHEN dp.price_change > 0 THEN 1 ELSE 0 END) as advance,
      SUM(CASE WHEN dp.price_change < 0 THEN 1 ELSE 0 END) as decline,
      SUM(CASE WHEN dp.price_change = 0 THEN 1 ELSE 0 END) as unchanged
    FROM daily_price dp
    INNER JOIN stock_master sm ON dp.symbol = sm.symbol
    WHERE dp.date > ? AND dp.date < ?
      AND dp.close IS NOT NULL
      AND dp.price_change IS NOT NULL
    GROUP BY sm.market, dp.date
    HAVING COUNT(DISTINCT dp.symbol) >= ?
    ORDER BY dp.date DESC
  ''';

    final results = await customSelect(
      query,
      variables: [
        Variable.withDateTime(startDate),
        Variable.withDateTime(endOfDay),
        Variable.withInt(coverage),
      ],
      readsFrom: {dailyPrice, stockMaster},
    ).get();

    final byMarket =
        <
          String,
          List<({DateTime date, int advance, int decline, int unchanged})>
        >{};
    for (final row in results) {
      final market = row.readNullable<String>('market');
      final rowDate = row.readNullable<DateTime>('date');
      if (market == null || rowDate == null) continue;

      byMarket.putIfAbsent(market, () => []).add((
        date: rowDate,
        advance: row.readNullable<int>('advance') ?? 0,
        decline: row.readNullable<int>('decline') ?? 0,
        unchanged: row.readNullable<int>('unchanged') ?? 0,
      ));
    }

    for (final key in byMarket.keys) {
      final list = byMarket[key]!;
      if (list.length > days) {
        byMarket[key] = list.sublist(0, days);
      }
    }

    return byMarket;
  }

  /// 取得各市場 52 週新高/新低家數（依市場分組）
  ///
  /// 對每檔個股，比較今日收盤與 trailing-[lookbackDays] 日（含今日）的最高/
  /// 最低收盤：close ≥ 區間最高 ⇒ 創 52 週新高、close ≤ 區間最低 ⇒ 創 52 週
  /// 新低，依 market 分組計數。為廣度趨勢（market breadth trend）指標。
  ///
  /// 採用 window function：以每檔個股的日期降序開窗，frame 取「當列起往後
  /// [lookbackDays] 列」涵蓋 trailing window，`rn = 1` 即今日該列。
  /// 日期範圍 start = date − lookbackDays×2 日（寬鬆，確保涵蓋 252 個交易
  /// 日）、end = date+1 日。
  ///
  /// 注意：WINDOW frame 的 `lookbackDays - 1`（FOLLOWING 列數）為 SQLite
  /// 字面量、不可綁定參數，故以信任的 int 常數插值進查詢字串（非使用者輸入）。
  ///
  /// 回傳 `Map<String, ({int newHighs, int newLows})>`
  Future<Map<String, ({int newHighs, int newLows})>>
  getNewHighLowCountsByMarket(
    DateTime date, {
    int lookbackDays = kNewHighLowLookbackDays,
  }) async {
    final endOfDay = DateContext.normalize(date).add(const Duration(days: 1));
    // 寬鬆回看：以日曆日 lookbackDays×2 涵蓋約 lookbackDays 個交易日
    final startDate = DateContext.normalize(
      date,
    ).subtract(Duration(days: lookbackDays * 2));

    // frame 的 FOLLOWING 列數須為字面量（SQLite 不允許綁定），插值信任常數
    final query =
        '''
    WITH win AS (
      SELECT dp.symbol, sm.market, dp.close,
        MAX(dp.close) OVER w AS hi, MIN(dp.close) OVER w AS lo,
        ROW_NUMBER() OVER (PARTITION BY dp.symbol ORDER BY dp.date DESC) rn
      FROM daily_price dp INNER JOIN stock_master sm ON sm.symbol = dp.symbol
      WHERE dp.close IS NOT NULL AND dp.date > ? AND dp.date < ?
      WINDOW w AS (PARTITION BY dp.symbol ORDER BY dp.date DESC
        ROWS BETWEEN CURRENT ROW AND ${lookbackDays - 1} FOLLOWING))
    SELECT market,
      SUM(CASE WHEN close >= hi THEN 1 ELSE 0 END) AS new_highs,
      SUM(CASE WHEN close <= lo THEN 1 ELSE 0 END) AS new_lows
    FROM win WHERE rn = 1 GROUP BY market
  ''';

    final results = await customSelect(
      query,
      variables: [
        Variable.withDateTime(startDate),
        Variable.withDateTime(endOfDay),
      ],
      readsFrom: {dailyPrice, stockMaster},
    ).get();

    final byMarket = <String, ({int newHighs, int newLows})>{};
    for (final row in results) {
      final market = row.readNullable<String>('market');
      if (market == null) continue;

      byMarket[market] = (
        newHighs: row.readNullable<int>('new_highs') ?? 0,
        newLows: row.readNullable<int>('new_lows') ?? 0,
      );
    }

    return byMarket;
  }

  /// 取得指定日期的產業表現統計（指定市場）
  ///
  /// 依平均漲跌幅降序排列。
  Future<
    List<
      ({
        String industry,
        int stockCount,
        double avgChangePct,
        int advance,
        int decline,
      })
    >
  >
  getIndustrySummaryByMarket(DateTime date, String market) async {
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
      return (
        industry: row.readNullable<String>('industry') ?? '',
        stockCount: row.readNullable<int>('stock_count') ?? 0,
        avgChangePct: row.readNullable<double>('avg_change_pct') ?? 0.0,
        advance: row.readNullable<int>('advance') ?? 0,
        decline: row.readNullable<int>('decline') ?? 0,
      );
    }).toList();
  }
}
