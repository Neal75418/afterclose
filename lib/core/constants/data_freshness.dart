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

  /// 融資融券短期回溯天數（預設）
  static const int marginShortLookbackDays = 5;
}
