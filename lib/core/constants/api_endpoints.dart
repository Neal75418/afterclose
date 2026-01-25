/// API 端點常數
///
/// 集中管理所有外部 API URL，便於維護與修改。
abstract final class ApiEndpoints {
  // ==========================================
  // TWSE (台灣證券交易所)
  // ==========================================

  /// TWSE 官方網站基礎 URL
  static const String twseBaseUrl = 'https://www.twse.com.tw';

  /// TWSE Open Data API 基礎 URL
  static const String twseOpenDataBaseUrl = 'https://openapi.twse.com.tw';

  /// 每日全市場股價
  static const String twseDailyPricesAll = '/rwd/zh/afterTrading/STOCK_DAY_ALL';

  /// 個股歷史價格
  static const String twseStockDay = '/exchangeReport/STOCK_DAY';

  /// 三大法人買賣超
  static const String twseInstitutional = '/rwd/zh/fund/T86';

  /// 融資融券餘額
  static const String twseMarginTrading = '/rwd/zh/marginTrading/MI_MARGN';

  /// 當沖交易標的
  static const String twseDayTrading = '/exchangeReport/TWTB4U';

  /// 估值資料（本益比、殖利率、股價淨值比）- Open Data
  static const String twseValuation =
      '$twseOpenDataBaseUrl/v1/exchangeReport/BWIBBU_ALL';

  /// 月營收資料 - Open Data
  static const String twseMonthlyRevenue =
      '$twseOpenDataBaseUrl/v1/opendata/t187ap05_L';

  // ==========================================
  // TPEX (台灣櫃檯買賣中心)
  // ==========================================

  /// TPEX 官方網站基礎 URL
  static const String tpexBaseUrl = 'https://www.tpex.org.tw';

  /// 每日全市場上櫃股價（回傳 tables[0].data）
  static const String tpexDailyPricesAll =
      '/web/stock/aftertrading/daily_close_quotes/stk_quote_result.php';

  /// 三大法人上櫃買賣超（回傳 tables[0].data）
  static const String tpexInstitutional =
      '/web/stock/3insti/daily_trade/3itrade_hedge_result.php';

  /// 上櫃融資融券餘額（回傳 tables[0].data）
  static const String tpexMarginTrading =
      '/web/stock/margin_trading/margin_sbl/margin_sbl_result.php';

  // ==========================================
  // FinMind
  // ==========================================

  /// FinMind API 基礎 URL
  static const String finmindBaseUrl =
      'https://api.finmindtrade.com/api/v4/data';

  /// FinMind 網站（供使用者註冊 Token）
  static const String finmindWebsite = 'https://finmindtrade.com/';

  // ==========================================
  // RSS 新聞來源
  // ==========================================

  /// MoneyDJ 理財網
  static const String rssMoneyDj =
      'https://www.moneydj.com/KMDJ/RssCenter.aspx?svc=NR&fno=1&arg=MB010000';

  /// Yahoo 財經
  static const String rssYahooFinance =
      'https://tw.stock.yahoo.com/rss?category=tw-market';

  /// 鉅亨網
  static const String rssCnyes =
      'https://news.cnyes.com/rss/v1/news/category/tw_stock';

  /// 中央社
  static const String rssCna = 'https://feeds.feedburner.com/rsscna/finance';
}
