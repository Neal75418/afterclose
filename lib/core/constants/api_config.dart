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

  /// 重試延遲（毫秒）
  static const int retryDelayMs = 1000;

  // ==================================================
  // 資料處理設定
  // ==================================================

  /// 民國年轉換偏移量（民國元年 = 西元 1912 年，偏移量 = 1911）
  static const int rocYearOffset = 1911;

  /// 預設歷史回溯天數
  static const int defaultHistoryLookbackDays = 5;

  /// 分析結束日期偏移天數
  static const int analysisEndDateOffsetDays = 1;

  /// 新聞歷史回溯天數
  static const int newsHistoryLookbackDays = 1;

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

  /// 更新操作超時（分鐘）
  static const int updateTimeoutMin = 60;
}

/// 快取設定常數
abstract final class CacheConfig {
  /// 預設 LRU 快取最大容量
  static const int defaultMaxSize = 100;

  /// 批次查詢快取最大容量
  static const int batchQueryMaxSize = 50;

  /// 批次查詢快取 TTL（秒）
  static const int batchQueryTtlSec = 30;
}
