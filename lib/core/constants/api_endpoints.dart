/// API 端點常數
///
/// 集中管理所有外部 API URL，便於維護與修改。
abstract final class ApiEndpoints {
  // ==================================================
  // TWSE (台灣證券交易所)
  // ==================================================

  /// TWSE 官方網站基礎 URL
  static const String twseBaseUrl = 'https://www.twse.com.tw';

  /// TWSE Open Data API 基礎 URL
  static const String twseOpenDataBaseUrl = 'https://openapi.twse.com.tw';

  /// 每日全市場股價
  static const String twseDailyPricesAll = '/rwd/zh/afterTrading/STOCK_DAY_ALL';

  /// 個股歷史價格
  static const String twseStockDay = '/exchangeReport/STOCK_DAY';

  /// 三大法人買賣超（個股）
  static const String twseInstitutional = '/rwd/zh/fund/T86';

  /// 三大法人買賣金額統計表（市場總計，單位：元）
  static const String twseInstitutionalAmounts = '/rwd/zh/fund/BFI82U';

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

  /// 大盤各類指數（每日收盤後更新）
  static const String twseMarketIndex = '/rwd/zh/afterTrading/MI_INDEX';

  /// 上市注意股票
  /// 回傳交易量異常、價格異常波動的股票清單
  /// 2025 年後端點變更：TWTAVU → notice
  static const String twseTradingWarning = '/rwd/zh/announcement/notice';

  /// 上市處置股票
  /// 回傳交易受限制的股票清單
  /// 2025 年後端點變更：TWTAUU → punish
  static const String twseDisposal = '/rwd/zh/announcement/punish';

  /// 上市董監持股 - Open Data（免費、無限制）
  /// 回傳董監事持股餘額資料，格式與 TPEX 相同（個別董監記錄）
  static const String twseInsiderHolding =
      '$twseOpenDataBaseUrl/v1/opendata/t187ap11_L';

  /// 上市股票基本資料 - Open Data（免費、無限制）
  /// 回傳上市公司基本資料，包含已發行股數
  static const String twseStockInfo =
      '$twseOpenDataBaseUrl/v1/opendata/t187ap03_L';

  // ==================================================
  // TPEX (台灣櫃檯買賣中心)
  // ==================================================

  /// TPEX 官方網站基礎 URL
  static const String tpexBaseUrl = 'https://www.tpex.org.tw';

  /// 每日全市場上櫃股價（回傳 tables[0].data）
  static const String tpexDailyPricesAll =
      '/web/stock/aftertrading/daily_close_quotes/stk_quote_result.php';

  /// 三大法人上櫃買賣超（回傳 tables[0].data）
  static const String tpexInstitutional =
      '/web/stock/3insti/daily_trade/3itrade_hedge_result.php';

  /// 三大法人買賣金額彙總表（市場總計，單位：元）
  static const String tpexInstitutionalAmounts =
      '/web/stock/3insti/3insti_summary/3itrdsum_result.php';

  /// 上櫃融資融券餘額（回傳 tables[0].data）
  static const String tpexMarginTrading =
      '/web/stock/margin_trading/margin_sbl/margin_sbl_result.php';

  /// 上櫃當沖交易統計（回傳 tables[0].data）
  /// 類似 TWSE 的 TWTB4U，提供全市場上櫃股票當沖資料
  static const String tpexDayTrading =
      '/web/stock/aftertrading/daily_trading_info/st43_result.php';

  /// TPEX OpenAPI 基礎 URL（免費、無限制）
  static const String tpexOpenApiBaseUrl = 'https://www.tpex.org.tw/openapi';

  /// 上櫃估值資料（本益比、股價淨值比、殖利率）- OpenAPI
  /// 回傳 JSON 陣列，每筆含 SecuritiesCompanyCode, PriceEarningRatio, PriceBookRatio, YieldRatio
  static const String tpexValuation =
      '$tpexOpenApiBaseUrl/v1/tpex_mainboard_peratio_analysis';

  /// 上櫃注意股票 - OpenAPI（免費、無限制）
  /// 回傳交易量異常、價格異常波動的股票清單
  static const String tpexTradingWarning =
      '$tpexOpenApiBaseUrl/v1/tpex_trading_warning_information';

  /// 上櫃處置股票 - OpenAPI（免費、無限制）
  /// 回傳交易受限制的股票清單
  static const String tpexDisposal =
      '$tpexOpenApiBaseUrl/v1/tpex_disposal_information';

  /// 上櫃董監持股 - OpenAPI（免費、無限制）
  /// 回傳董監事持股餘額資料
  static const String tpexInsiderHolding =
      '$tpexOpenApiBaseUrl/v1/mopsfin_t187ap11_O';

  /// 上櫃公司每月營業收入彙總表 - OpenAPI（免費、無限制）
  /// 回傳所有上櫃公司的月營收資料，包含月增率和年增率
  static const String tpexMonthlyRevenue =
      '$tpexOpenApiBaseUrl/v1/mopsfin_t187ap05_O';

  /// 上櫃股票基本資料 - OpenAPI（免費、無限制）
  /// 回傳上櫃公司基本資料，包含已發行股數 (IssueShares)
  static const String tpexStockInfo =
      '$tpexOpenApiBaseUrl/v1/mopsfin_t187ap03_O';

  // ==================================================
  // TDCC (台灣集中保管結算所)
  // ==================================================

  /// TDCC 股權分散表 - Open Data（免費、無需認證、每週更新）
  /// 一次回傳全市場所有股票的持股級距分布
  static const String tdccHoldingDistribution =
      'https://openapi.tdcc.com.tw/v1/opendata/1-5';

  // ==================================================
  // FinMind
  // ==================================================

  /// FinMind API 基礎 URL
  static const String finmindBaseUrl =
      'https://api.finmindtrade.com/api/v4/data';

  /// FinMind 網站（供使用者註冊 Token）
  static const String finmindWebsite = 'https://finmindtrade.com/';

  // ==================================================
  // RSS 新聞來源
  // ==================================================

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
