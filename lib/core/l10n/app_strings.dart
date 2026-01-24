/// 應用程式字串常數集中管理
///
/// 此類別為所有 UI 字串的單一來源，
/// 便於維護並未來轉換為完整的國際化。
///
/// 使用範例：
/// ```dart
/// Text(S.appName)
/// Text(S.priceUp(2.5))
/// ```
class S {
  S._();

  // ==================================================
  // 應用程式通用
  // ==================================================
  static const String appName = 'AfterClose';
  static const String loading = '載入中...';
  static const String retry = '重試';
  static const String cancel = '取消';
  static const String confirm = '確認';
  static const String save = '儲存';
  static const String delete = '刪除';
  static const String edit = '編輯';
  static const String add = '新增';
  static const String close = '關閉';
  static const String done = '完成';
  static const String search = '搜尋';
  static const String refresh = '重新整理';
  static const String settings = '設定';

  // ==================================================
  // 導航
  // ==================================================
  static const String navToday = '今日';
  static const String navScan = '掃描';
  static const String navWatchlist = '自選';
  static const String navNews = '新聞';

  // ==================================================
  // 今日頁面
  // ==================================================
  static const String todayTop10 = '今日推薦 Top 10';
  static const String todayWatchlistStatus = '自選狀態';
  static const String todayUpdateData = '更新資料';
  static const String todayStartingUpdate = '開始更新...';
  static const String todayPriceAlert = '價格提醒';
  static String todayLastUpdate(String time) => '最後更新: $time';
  static String todayUpdateFailed(String error) => '更新失敗: $error';

  // ==================================================
  // 新聞頁面
  // ==================================================
  static const String newsTitle = '市場新聞';
  static const String newsToday = '今天';
  static const String newsYesterday = '昨天';
  static const String newsEarlier = '更早';
  static const String newsRelatedStocks = '相關股票';
  static const String newsOpenInBrowser = '開啟原文';
  static String newsMinutesAgo(int minutes) => '$minutes 分鐘前';
  static String newsHoursAgo(int hours) => '$hours 小時前';
  static String newsDaysAgo(int days) => '$days 天前';

  // ==================================================
  // 掃描頁面
  // ==================================================
  static const String scanTitle = '市場掃描';
  static const String scanFilterAll = '全部';
  static const String scanFilterReversalW2S = '弱轉強';
  static const String scanFilterReversalS2W = '強轉弱';
  static const String scanFilterBreakout = '突破';
  static const String scanFilterBreakdown = '跌破';
  static const String scanFilterVolumeSpike = '放量';
  static const String scanSortScoreDesc = '分數高→低';
  static const String scanSortScoreAsc = '分數低→高';
  static const String scanSortPriceChangeDesc = '漲幅高→低';
  static const String scanSortPriceChangeAsc = '漲幅低→高';

  // ==================================================
  // 自選股頁面
  // ==================================================
  static const String watchlistTitle = '自選股票';
  static const String watchlistAdd = '新增股票';
  static const String watchlistAddDialog = '新增自選';
  static const String watchlistSymbolLabel = '股票代號';
  static const String watchlistSymbolHint = '例如: 2330';
  static String watchlistRemoved(String symbol) => '已從自選移除 $symbol';
  static String watchlistAdded(String symbol) => '已加入 $symbol';
  static String watchlistAddedToWatchlist(String symbol) => '已加入自選 $symbol';
  static const String watchlistAddFailed = '加入自選失敗';
  static String watchlistNotFound(String symbol) => '找不到股票 $symbol';
  static const String watchlistUndo = '復原';

  // ==================================================
  // 股票詳情
  // ==================================================
  static const String stockDetailTitle = '股票詳情';
  static const String stockAddToWatchlist = '加入自選';
  static const String stockRemoveFromWatchlist = '從自選移除';
  static const String stockViewDetails = '查看詳情';
  static const String stockPreview = '股票預覽';

  // ==================================================
  // 評分
  // ==================================================
  static const String scoreLabel = '推薦評分';
  static const String scoreLevelStrong = '強烈推薦';
  static const String scoreLevelWatch = '值得關注';
  static const String scoreLevelNormal = '一般';
  static const String scoreLevelWait = '觀望';

  static String getScoreLevel(double score) {
    if (score >= 80) return scoreLevelStrong;
    if (score >= 60) return scoreLevelWatch;
    if (score >= 40) return scoreLevelNormal;
    return scoreLevelWait;
  }

  // ==================================================
  // 趨勢
  // ==================================================
  static const String trendUp = '上升趨勢';
  static const String trendDown = '下降趨勢';
  static const String trendSideways = '盤整';

  static String getTrendLabel(String? trendState) {
    return switch (trendState) {
      'UP' => trendUp,
      'DOWN' => trendDown,
      _ => trendSideways,
    };
  }

  // ==================================================
  // 價格
  // ==================================================
  static const String priceLabel = '價格';
  static const String priceUp = '上漲';
  static const String priceDown = '下跌';
  static const String priceNeutral = '持平';

  static String priceChangeLabel(double? change) {
    if (change == null || change == 0) return priceNeutral;
    return change > 0 ? priceUp : priceDown;
  }

  static String priceValue(double price) => '${price.toStringAsFixed(2)} 元';
  static String priceChangePercent(double change) {
    final sign = change >= 0 ? '+' : '';
    return '$sign${change.toStringAsFixed(2)}%';
  }

  // ==================================================
  // 推薦理由（訊號類型）
  // ==================================================
  static const String reasonReversalW2S = '弱轉強';
  static const String reasonReversalS2W = '強轉弱';
  static const String reasonBreakout = '技術突破';
  static const String reasonBreakdown = '技術跌破';
  static const String reasonVolumeSpike = '放量';
  static const String reasonPriceSpike = '價格異動';
  static const String reasonInstitutional = '法人動向';
  static const String reasonNews = '新聞相關';
  static const String reasonsLabel = '推薦理由';

  // ==================================================
  // 空狀態
  // ==================================================
  static const String emptyNoRecommendations = '尚無今日推薦';
  static const String emptyNoRecommendationsHint = '目前沒有符合條件的股票\n請稍後再試或手動更新';
  static const String emptyNoFilterResults = '無符合條件的股票';
  static const String emptyNoFilterResultsHint = '試著調整篩選條件';
  static const String emptyClearFilter = '清除篩選';
  static const String emptyNoWatchlist = '尚無自選股票';
  static const String emptyNoWatchlistHint = '在市場掃描頁面\n點擊星號加入自選';
  static const String emptyGoToScan = '前往掃描';
  static const String emptyNoNews = '暫無新聞';
  static const String emptyNoNewsHint = '目前沒有相關新聞';
  static const String emptyError = '發生錯誤';
  static const String emptyNetworkError = '網路連線失敗';
  static const String emptyNetworkErrorHint = '請檢查網路連線後再試';

  // ==================================================
  // 無障礙
  // ==================================================
  static String accessibilityStock(String symbol) => '股票 $symbol';
  static String accessibilityPrice(double price) =>
      '價格 ${price.toStringAsFixed(2)} 元';
  static String accessibilityPriceChange(double change) {
    final direction = change >= 0 ? '上漲' : '下跌';
    return '$direction ${change.abs().toStringAsFixed(2)} 百分比';
  }

  static String accessibilityScore(int score) => '評分 $score 分';
  static String accessibilitySignals(String signals) => '訊號: $signals';
  static const String accessibilityAddToWatchlist = '加入自選';
  static const String accessibilityRemoveFromWatchlist = '從自選移除';
  static String accessibilityButtonPress(String label) => '按鈕: $label';

  // 走勢圖無障礙標籤
  static const String sparklineDefault = '近期價格走勢圖';
  static String sparklineFlat(int days) => '近 $days 日價格持平走勢圖';
  static String sparklineTrend(int days, double change) {
    final direction = change >= 0 ? '上漲' : '下跌';
    return '近 $days 日價格 $direction ${change.abs().toStringAsFixed(1)} 百分比走勢圖';
  }

  // Shimmer 載入無障礙標籤
  static const String shimmerLoadingStockList = '股票列表載入中';
  static const String shimmerLoadingStockDetail = '股票詳情載入中';
  static const String shimmerLoadingNewsList = '新聞列表載入中';

  // ==================================================
  // 自選股狀態圖示
  // ==================================================
  static const String statusHasSignal = '有訊號';
  static const String statusVolatile = '波動中';
  static const String statusQuiet = '平靜';
  static String signalType(String? type) => '有訊號: ${type ?? "異常"}';

  // ==================================================
  // 時間與日期
  // ==================================================
  static String dateFormat(DateTime dt) {
    final local = dt.toLocal();
    return '${local.month}/${local.day} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
