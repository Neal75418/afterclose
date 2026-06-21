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

  /// 冷啟動自動更新門檻：距上次成功 update_run 超過此時間（小時）才會在
  /// `TodayNotifier.loadData()` 觸發背景 `runUpdate`
  ///
  /// **設計動機（2026-06-18 B-lite）**：macOS 沒有 workmanager 背景任務，
  /// CLI 走 launchd 又卡 Flutter binding（dart:ui 缺）。妥協做法：使用者
  /// 開 app 時自動跑 update。`6` 小時對齊「**一個交易日只跑 1 次就夠**」：
  /// - 同日多次開 app 不重複跑（symbol-level freshness check 也會擋）
  /// - 隔天首次開 app（≥12h）一定觸發
  /// - 出國 / 長假後回來，app 一開馬上有最新資料
  ///
  /// 非交易日（週末 / 國定假日）即使 stale 也不觸發 — 由 caller 額外用
  /// `TaiwanCalendar.isTradingDay()` 過濾。
  static const int coldStartAutoUpdateGateHours = 6;

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

  // `historicalPartialSyncMonths`（早期固定 4）已於 2026-06 移除：partial 場景
  // 的 API 呼叫數實際取決於 cached 資料的月份分佈，由 estimator 動態計算，
  // 而非靠單一常數估算。詳見 `HistoricalPriceSyncer._estimateAvgMonthsNeeded`。

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

  // ==================================================
  // 籌碼資料載入回溯天數
  // ==================================================

  /// 籌碼 API 查詢回溯天數（融資融券、法人）
  static const int chipDataLookbackDays = 20;

  /// 籌碼短期資料回溯天數（當沖、融資融券 DB 查詢）
  static const int chipTradingLookbackDays = 15;

  /// 籌碼持股比例回溯天數（外資持股 DB 查詢）
  static const int chipShareholdingLookbackDays = 90;

  // ==================================================
  // 估值資料查詢回溯天數（詳細頁面）
  // ==================================================

  /// 個股詳細頁估值 DB 查詢回溯天數
  static const int valuationDbLookbackDays = 30;

  /// 個股詳細頁估值 API fallback 查詢回溯天數
  static const int valuationApiLookbackDays = 5;

  // ==================================================
  // 新聞資料保留天數
  // ==================================================

  /// 舊新聞清理保留天數
  static const int newsRetentionDays = 30;

  // ==================================================
  // 當沖資料查詢回溯天數
  // ==================================================

  /// 當沖資料回溯查詢天數（無目標日期資料時的 fallback 窗口）
  static const int dayTradingFallbackDays = 5;

  // ==================================================
  // 月營收顯示月數
  // ==================================================

  /// 比較頁面與批次載入的月營收顯示月數
  static const int revenueDisplayMonths = 6;

  // ==================================================
  // 總報酬指數查詢回溯天數
  // ==================================================

  /// FinMind 總報酬指數預設查詢回溯天數
  static const int totalReturnIndexLookbackDays = 60;

  // ==================================================
  // 大盤位階歷史查詢回溯天數
  // ==================================================

  /// 大盤位階（均線乖離）歷史查詢回溯天數（日曆天）
  ///
  /// MA60 至少需 60 個交易日；台股交易日約佔日曆天 71%，120 日曆天約
  /// 涵蓋 85 個交易日，足以計算 MA60 並留有緩衝。與走勢圖的 30 點窗口
  /// 分離載入，避免拉長 sparkline。
  static const int marketStageHistoryLookbackDays = 120;

  // ==================================================
  // 當沖資料刪除視窗（UTC 偏移補償）
  // ==================================================

  /// 當沖資料刪除視窗前緣（小時）— 涵蓋 UTC 偏移
  static const int dayTradingDeleteWindowBeforeHours = 12;

  /// 當沖資料刪除視窗後緣（小時）— 涵蓋 UTC 偏移 + 1 日
  static const int dayTradingDeleteWindowAfterHours = 36;

  // ==================================================
  // 日曆事件預覽
  // ==================================================

  /// 日曆頁面「近期事件」預覽天數
  static const int upcomingEventsDays = 14;

  // ==================================================
  // 警示資料新鮮度
  // ==================================================

  /// 警示資料同步新鮮度門檻（小時）
  ///
  /// 最近一次同步距今不超過此時間，則跳過重新同步。
  static const int warningSyncFreshnessHours = 6;

  // ==================================================
  // 警示價格歷史
  // ==================================================

  /// 價格警示觸發判定的歷史價格回溯天數
  static const int alertPriceHistoryDays = 2;
}
