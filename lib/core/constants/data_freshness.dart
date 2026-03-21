/// 資料新鮮度判斷參數
///
/// 集中管理 Repository 層使用的批次資料快取門檻、
/// 時效性判斷天數和回溯緩衝天數。
abstract final class DataFreshness {
  // ==================================================
  // 批次資料快取門檻
  // ==================================================

  /// 上市（TWSE）批次資料新鮮度門檻
  ///
  /// 若該日期已有超過此數量的資料，則跳過 API 呼叫。
  static const int twseBatchThreshold = 100;

  /// 上櫃（TPEX）批次資料新鮮度門檻
  ///
  /// 上櫃股票數量較少，使用較低閾值。
  static const int tpexBatchThreshold = 50;

  /// 全市場批次資料新鮮度門檻
  ///
  /// 上市 + 上櫃約 1800+ 家，用 1500 作為快取判斷門檻。
  static const int fullMarketThreshold = 1500;

  /// 營收資料快取門檻
  ///
  /// 全市場通常有 ~1800+ 檔股票，超過此數量視為該月已有資料。
  static const int revenueRecordThreshold = 1000;

  // ==================================================
  // 時效性判斷
  // ==================================================

  /// 財報資料過期天數
  ///
  /// 季報每 ~90 天發布，60 天確保不會錯過最新一季。
  static const int financialStatementStaleDays = 60;

  /// 上櫃估值資料新鮮天數
  ///
  /// 3 天內視為新鮮，不需重複同步。
  static const int otcValuationFreshDays = 3;

  /// 每月最少交易日數
  ///
  /// 少於此數量表示該月資料不完整，需要重新同步。
  static const int minTradingDaysPerMonth = 10;

  // ==================================================
  // 回溯緩衝天數
  // ==================================================

  /// 當沖資料回溯緩衝天數
  static const int dayTradingBufferDays = 10;

  /// 融資融券資料回溯緩衝天數
  static const int marginTradingBufferDays = 10;

  /// 董監持股預設回溯月數
  static const int insiderDefaultMonths = 12;

  /// 董監持股近期查詢月數
  static const int insiderRecentMonths = 6;

  // ==================================================
  // 當沖比例顯示門檻
  // ==================================================

  /// 高當沖股判定門檻（%）
  static const double dayTradingHighRatio = 30.0;

  /// 高當沖比例顯示門檻（%）— 用於日誌統計
  static const double dayTradingHighDisplayRatio = 60.0;

  /// 極高當沖比例顯示門檻（%）— 用於日誌統計
  static const double dayTradingExtremeDisplayRatio = 70.0;

  /// 當沖比例驗證上限（%）
  static const double dayTradingMaxValidRatio = 100.0;

  // ==================================================
  // App Lifecycle
  // ==================================================

  /// App 回到前景後，超過此時間（分鐘）視為資料過期，自動重新載入
  static const int appStaleThresholdMinutes = 30;

  /// 股票清單初始化最低股票數
  ///
  /// 低於此數量表示股票清單尚未完整初始化，需要從 TWSE/TPEx 同步。
  static const int minInitialStockCount = 500;

  // ==================================================
  // 歷史價格資料估算
  // ==================================================

  /// 交易日佔日曆天的比例（台股約 71%）
  ///
  /// 用於由上市天數估算預期應有的交易日筆數。
  static const double tradingDayRatio = 0.71;

  /// 歷史資料可接受比例
  ///
  /// 實際資料達預期交易日的 50% 即視為足夠，不需重複同步。
  static const double minAcceptableDataRatio = 0.5;

  /// 無歷史資料股票所需完整同步月數
  ///
  /// DB 全新時每檔股票平均需要抓取約 14 個月的歷史。
  static const int historicalFullSyncMonths = 14;

  /// 有部分歷史資料股票平均所需同步月數
  static const int historicalPartialSyncMonths = 4;

  // ==================================================
  // 法人資料估算
  // ==================================================

  /// 每個交易日的法人資料估計筆數（上市 + 上櫃約 1000 檔）
  ///
  /// 用於由同步天數估算已處理的資料量。
  static const int estimatedDailyInstitutionalRecords = 1000;

  // ==================================================
  // 財務資料查詢緩衝
  // ==================================================

  /// 每季約含的日曆天數（用於由季數推算查詢起始日期）
  static const int daysPerQuarter = 90;

  /// 財務指標查詢額外緩衝天數（確保跨季邊界不遺漏資料）
  static const int quarterBufferDays = 30;

  // ==================================================
  // 篩選器查詢回溯天數
  // ==================================================

  /// 篩選器前日收盤價查詢回溯天數
  ///
  /// 確保能找到目標日期前的最近一個交易日收盤價。
  static const int prevPriceLookbackDays = 10;

  /// 篩選器估值資料查詢回溯天數
  ///
  /// 估值資料更新頻率較低，以 7 天確保能取到最新資料。
  static const int valuationLookbackDays = 7;
}
