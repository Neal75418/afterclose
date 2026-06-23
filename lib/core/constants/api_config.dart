/// API 設定常數
///
/// 集中管理所有 API 相關的超時、延遲、重試等參數。
abstract final class ApiConfig {
  // ==================================================
  // HTTP 超時設定
  // ==================================================

  /// RSS 解析器連線超時（秒）
  static const int rssConnectTimeoutSec = 15;

  /// RSS 解析器接收超時（秒）
  static const int rssReceiveTimeoutSec = 15;

  /// TWSE 連線超時（秒）
  static const int twseConnectTimeoutSec = 30;

  /// TWSE 接收超時（秒）
  static const int twseReceiveTimeoutSec = 60;

  /// FinMind 連線超時（秒）
  static const int finmindConnectTimeoutSec = 30;

  /// FinMind 接收超時（秒）
  static const int finmindReceiveTimeoutSec = 30;

  /// TDCC 快取 TTL（分鐘）— 週資料，60 分鐘已足夠
  static const int tdccCacheTtlMin = 60;

  // ==================================================
  // 請求延遲設定（避免過度請求）
  // ==================================================

  /// FinMind 批次請求基礎延遲（毫秒）
  static const int finmindBaseDelayMs = 500;

  /// 價格資料批次查詢延遲（毫秒）
  static const int priceBatchQueryDelayMs = 250;

  /// 價格資料請求間延遲（毫秒）
  static const int priceRequestDelayMs = 200;

  /// 更新服務批次延遲（毫秒）
  static const int updateBatchDelayMs = 200;

  /// Syncer 批次操作間延遲（毫秒），避免觸發 API rate limit
  static const int syncerBatchDelayMs = 500;

  /// TWSE 歷史資料逐月請求間延遲（毫秒）
  static const int twseHistoryRequestDelayMs = 300;

  /// TWSE/TPEX 市場 API 最大重試次數
  static const int marketClientMaxRetries = 2;

  /// 重試延遲（毫秒）
  static const int retryDelayMs = 1000;

  /// 財報同步最大市場候選數（避免 FinMind 免費額度耗盡）
  static const int financialSyncMaxCandidates = 150;

  /// 上櫃候選股基本面同步最大數量
  ///
  /// 上櫃候選清單通常較小，以 100 為上限避免 API 額度過度消耗。
  static const int otcFundamentalsSyncMaxCount = 100;

  /// Syncer 批次大小（每批並行處理的股票數）
  static const int syncerBatchSize = 10;

  /// 市場籌碼資料更新器批次大小（每批並行處理的股票數）
  static const int marketDataBatchSize = 5;

  /// 市場籌碼資料更新器最大總錯誤次數（斷路器閾值）
  static const int marketDataMaxTotalErrors = 5;

  /// 額度耗盡提前終止最低錯誤次數
  static const int marketDataQuotaExhaustMinErrors = 2;

  /// 外資持股查詢額外緩衝天數（確保不遺漏邊界資料）
  static const int foreignShareholdingBufferDays = 5;

  /// 歷史價格同步連續失敗批次上限（斷路器閾值）
  ///
  /// 連續失敗達此值時中止同步，避免在網路或 API 異常時持續耗費配額。
  static const int historicalPriceMaxConsecutiveFailedBatches = 2;

  /// 歷史價格同步月度 API 呼叫預算
  ///
  /// 用於動態計算單次同步最多可處理的股票數量。
  static const int historicalPriceMaxMonthlyApiCalls = 300;

  /// 歷史價格同步每批並行處理的股票數
  static const int historicalPriceBatchSize = 5;

  /// 歷史價格同步動態上限最大值
  ///
  /// 正常日（每檔平均 1 個月）約同步 200 檔。
  static const int historicalPriceMaxSyncCount = 200;

  /// 歷史價格同步動態上限最小值
  ///
  /// Fresh DB 場景（每檔平均 14 個月）仍至少同步 15 檔。
  static const int historicalPriceMinSyncCount = 15;

  /// 財報同步回溯天數（約 2 年）
  static const int financialSyncLookbackDays = 730;

  // ==================================================
  // 排程設定
  // ==================================================

  /// 台股收盤時間（時）
  static const int marketCloseHour = 15;

  /// 台股收盤時間（分）
  static const int marketCloseMinute = 0;

  /// 背景更新重試延遲（分鐘）
  static const int backoffDelayMinutes = 15;

  // ==================================================
  // 資料處理設定
  // ==================================================

  /// 民國年轉換偏移量（民國元年 = 西元 1912 年，偏移量 = 1911）
  static const int rocYearOffset = 1911;

  /// 合理西元年下限（日期解析防護）
  ///
  /// 台股集中市場 1962 年開業，2000 為保守下限。早於此年的日期視為解析錯誤
  /// （曾出現 `0000-12-18` 等髒資料），由 [TwParseUtils.parseAdDate] 與
  /// [MarketIndexSyncer] 的寫入防護拒絕。
  static const int minSaneAdYear = 2000;

  /// 寫入日期與請求日期容許的最大偏移天數（指數同步防護）
  ///
  /// TWSE API 偶爾回傳與請求日期無關的髒日期（例如固定 `12-18`）。同步當日
  /// 資料時，若解析出的日期與請求日期相差超過此天數即視為異常並跳過。
  static const int marketIndexDateDriftToleranceDays = 7;

  /// 法人資料「日常更新」的回補天數（涵蓋分析所需的 ~10 天回溯）
  static const int institutionalDailyBackfillDays = 15;

  /// 法人資料「強制同步」的回補天數（calendar，~62 個交易日）
  ///
  /// 強制同步會清空法人資料重抓，故一次補深一點以恢復下游信號所需的歷史深度：
  /// institutionalSurge baseline（60 日）、自營/外資 streak 深度、情緒法人
  /// Z-score 視窗（10 日）。以 1 秒/交易日節流，~62 個交易日約 2-3 分鐘。
  static const int institutionalForceBackfillDays = 90;

  /// 新聞內容最大長度（超過截斷以節省儲存空間）
  static const int newsContentMaxLength = 500;

  // ==================================================
  // UI 訊息顯示時間
  // ==================================================

  /// 長訊息顯示時間（秒）- 用於成功訊息
  static const int longMessageDurationSec = 3;

  /// 短訊息顯示時間（秒）- 用於狀態更新
  static const int shortMessageDurationSec = 2;

  /// 提醒對話框顯示時間（秒）
  static const int alertDialogDurationSec = 4;

  // ==================================================
  // 重新整理設定
  // ==================================================

  /// 下拉重新整理超時（秒）
  static const int refreshTimeoutSec = 30;

  /// 大盤總覽載入超時（秒）
  ///
  /// 超過此時間後先顯示 DB 快取資料，API 回應後再更新。
  static const int marketOverviewLoadTimeoutSec = 20;

  /// 分享匯出檔案保留時間（分鐘）
  static const int shareExportRetentionMinutes = 5;

  /// 更新操作超時（分鐘）
  static const int updateTimeoutMin = 60;

  /// Provider keepAlive 持續時間（分鐘）
  static const int keepAliveMin = 3;
}

/// 快取設定常數
abstract final class CacheConfig {
  /// 預設 LRU 快取最大容量
  static const int defaultMaxSize = 100;

  /// 批次查詢快取最大容量
  static const int batchQueryMaxSize = 50;

  /// 批次查詢快取 TTL（秒）
  static const int batchQueryTtlSec = 30;

  /// FinMind API response 快取最大容量
  static const int finmindResponseCacheMaxSize = 200;

  /// TWSE/TPEX market client response 快取最大容量
  static const int marketClientCacheMaxSize = 20;

  /// TWSE/TPEX market client 快取 TTL（分鐘）
  static const int marketClientCacheTtlMin = 30;
}
