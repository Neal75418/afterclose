import 'package:easy_localization/easy_localization.dart';

/// 應用程式字串集中管理（基於 easy_localization）
///
/// 此類別為所有 UI 字串的單一來源，
/// 內部委託 `.tr()` 讀取 JSON 翻譯檔。
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
  static String get appName => 'app.name'.tr();
  static String get loading => 'common.loading'.tr();
  static String get retry => 'common.retry'.tr();
  static String get cancel => 'common.cancel'.tr();
  static String get confirm => 'common.confirm'.tr();
  static String get save => 'common.save'.tr();
  static String get delete => 'common.delete'.tr();
  static String get edit => 'common.edit'.tr();
  static String get add => 'common.add'.tr();
  static String get close => 'common.close'.tr();
  static String get done => 'common.done'.tr();
  static String get search => 'common.search'.tr();
  static String get refresh => 'common.refresh'.tr();
  static String get settings => 'common.settings'.tr();

  // ==================================================
  // 導航
  // ==================================================
  static String get navToday => 'nav.today'.tr();
  static String get navScan => 'nav.scan'.tr();
  static String get navWatchlist => 'nav.watchlist'.tr();
  static String get navNews => 'nav.news'.tr();

  // ==================================================
  // 今日頁面
  // ==================================================
  static String get todayTop10 => 'today.top10'.tr();
  static String get todayWatchlistStatus => 'today.watchlistStatus'.tr();
  static String get todayUpdateData => 'today.updateData'.tr();
  static String get todayStartingUpdate => 'today.startingUpdate'.tr();
  static String get todayPriceAlert => 'today.priceAlert'.tr();
  static String todayLastUpdate(String time) =>
      'today.lastUpdate'.tr(namedArgs: {'time': time});
  static String todayDataDate(String date) =>
      'today.dataDate'.tr(namedArgs: {'date': date});
  static String get todayDataToday => 'today.dataToday'.tr();
  static String get todayDataYesterday => 'today.dataYesterday'.tr();
  static String todayUpdateFailed(String error) =>
      'today.updateFailed'.tr(namedArgs: {'error': error});

  // ==================================================
  // 新聞頁面
  // ==================================================
  static String get newsTitle => 'news.title'.tr();
  static String get newsToday => 'news.today'.tr();
  static String get newsYesterday => 'news.yesterday'.tr();
  static String get newsEarlier => 'news.earlier'.tr();
  static String get newsRelatedStocks => 'news.relatedStocks'.tr();
  static String get newsOpenInBrowser => 'news.openInBrowser'.tr();
  static String get newsCannotOpenLink => 'news.cannotOpenLink'.tr();
  static String newsMinutesAgo(int minutes) =>
      'news.minutesAgo'.tr(namedArgs: {'minutes': minutes.toString()});
  static String newsHoursAgo(int hours) =>
      'news.hoursAgo'.tr(namedArgs: {'hours': hours.toString()});
  static String newsDaysAgo(int days) =>
      'news.daysAgo'.tr(namedArgs: {'days': days.toString()});

  // ==================================================
  // 掃描頁面
  // ==================================================
  static String get scanTitle => 'scan.title'.tr();
  static String get scanFilterAll => 'scan.filterAll'.tr();
  static String get scanFilterReversalW2S => 'scan.filterReversalW2S'.tr();
  static String get scanFilterReversalS2W => 'scan.filterReversalS2W'.tr();
  static String get scanFilterBreakout => 'scan.filterBreakout'.tr();
  static String get scanFilterBreakdown => 'scan.filterBreakdown'.tr();
  static String get scanFilterVolumeSpike => 'scan.filterVolumeSpike'.tr();
  static String get scanSortScoreDesc => 'scan.sortScoreDesc'.tr();
  static String get scanSortScoreAsc => 'scan.sortScoreAsc'.tr();
  static String get scanSortPriceChangeDesc => 'scan.sortPriceChangeDesc'.tr();
  static String get scanSortPriceChangeAsc => 'scan.sortPriceChangeAsc'.tr();

  // ==================================================
  // 自選股頁面
  // ==================================================
  static String get watchlistTitle => 'watchlist.title'.tr();
  static String get watchlistAdd => 'watchlist.add'.tr();
  static String get watchlistAddDialog => 'watchlist.addDialog'.tr();
  static String get watchlistSymbolLabel => 'watchlist.symbolLabel'.tr();
  static String get watchlistSymbolHint => 'watchlist.symbolHint'.tr();
  static String watchlistRemoved(String symbol) =>
      'watchlist.removed'.tr(namedArgs: {'symbol': symbol});
  static String watchlistAdded(String symbol) =>
      'watchlist.added'.tr(namedArgs: {'symbol': symbol});
  static String watchlistAddedToWatchlist(String symbol) =>
      'watchlist.addedToWatchlist'.tr(namedArgs: {'symbol': symbol});
  static String get watchlistAddFailed => 'watchlist.addFailed'.tr();
  static String watchlistNotFound(String symbol) =>
      'watchlist.notFound'.tr(namedArgs: {'symbol': symbol});
  static String get watchlistUndo => 'watchlist.undo'.tr();
  static String get watchlistRemoveTooltip => 'watchlist.removeTooltip'.tr();
  static String get watchlistAddTooltip => 'watchlist.addTooltip'.tr();

  // ==================================================
  // 股票詳情
  // ==================================================
  static String get stockDetailTitle => 'stock.detailTitle'.tr();
  static String get stockAddToWatchlist => 'stock.addToWatchlist'.tr();
  static String get stockRemoveFromWatchlist =>
      'stock.removeFromWatchlist'.tr();
  static String get stockViewDetails => 'stock.viewDetails'.tr();
  static String get stockPreview => 'stock.preview'.tr();

  // ==================================================
  // 評分
  // ==================================================
  static String get scoreLabel => 'score.label'.tr();
  static String get scoreLevelStrong => 'score.strong'.tr();
  static String get scoreLevelWatch => 'score.watch'.tr();
  static String get scoreLevelNormal => 'score.normal'.tr();
  static String get scoreLevelWait => 'score.wait'.tr();

  static String getScoreLevel(double score) {
    if (score >= 80) return scoreLevelStrong;
    if (score >= 60) return scoreLevelWatch;
    if (score >= 40) return scoreLevelNormal;
    return scoreLevelWait;
  }

  // ==================================================
  // 趨勢
  // ==================================================
  static String get trendUp => 'trend.up'.tr();
  static String get trendDown => 'trend.down'.tr();
  static String get trendSideways => 'trend.sideways'.tr();

  static String getTrendLabel(String? trendState) {
    return switch (trendState) {
      'UP' => trendUp,
      'DOWN' => trendDown,
      _ => trendSideways,
    };
  }

  static String? getReversalLabel(String? reversalState) {
    return switch (reversalState) {
      'W2S' => reasonReversalW2S,
      'S2W' => reasonReversalS2W,
      _ => null,
    };
  }

  // ==================================================
  // 價格
  // ==================================================
  static String get priceLabel => 'price.label'.tr();
  static String get priceUp => 'price.up'.tr();
  static String get priceDown => 'price.down'.tr();
  static String get priceNeutral => 'price.neutral'.tr();
  static String get priceLimitUp => 'price.limitUp'.tr();
  static String get priceLimitDown => 'price.limitDown'.tr();

  static String priceChangeLabel(double? change) {
    if (change == null || change == 0) return priceNeutral;
    return change > 0 ? priceUp : priceDown;
  }

  static String priceValue(double price) =>
      'price.value'.tr(namedArgs: {'price': price.toStringAsFixed(2)});
  static String priceChangePercent(double change) {
    final sign = change >= 0 ? '+' : '';
    return 'price.changePercent'.tr(
      namedArgs: {'sign': sign, 'change': change.toStringAsFixed(2)},
    );
  }

  // ==================================================
  // 推薦理由（訊號類型）
  // ==================================================
  static String get reasonReversalW2S => 'reasons.reversalW2S'.tr();
  static String get reasonReversalS2W => 'reasons.reversalS2W'.tr();
  static String get reasonBreakout => 'reasons.breakout'.tr();
  static String get reasonBreakdown => 'reasons.breakdown'.tr();
  static String get reasonVolumeSpike => 'reasons.volumeSpike'.tr();
  static String get reasonPriceSpike => 'reasons.priceSpike'.tr();
  static String get reasonInstitutional => 'reasons.institutional'.tr();
  static String get reasonNews => 'reasons.newsRelated'.tr();
  static String get reasonsLabel => 'reasons.label'.tr();

  // ==================================================
  // 空狀態
  // ==================================================
  static String get emptyNoRecommendations => 'empty.noRecommendations'.tr();
  static String get emptyNoRecommendationsHint =>
      'empty.noRecommendationsHint'.tr();
  static String get emptyNoFilterResults => 'empty.noFilterResults'.tr();
  static String get emptyNoFilterResultsHint =>
      'empty.noFilterResultsHint'.tr();
  static String get emptyClearFilter => 'empty.clearFilter'.tr();
  static String get emptyNoWatchlist => 'empty.noWatchlist'.tr();
  static String get emptyNoWatchlistHint => 'empty.noWatchlistHint'.tr();
  static String get emptyGoToScan => 'empty.goToScan'.tr();
  static String get emptyNoNews => 'empty.noNews'.tr();
  static String get emptyNoNewsHint => 'empty.noNewsHint'.tr();
  static String get emptyError => 'empty.error'.tr();
  static String get emptyNetworkError => 'empty.networkError'.tr();
  static String get emptyNetworkErrorHint => 'empty.networkErrorHint'.tr();

  // ==================================================
  // 無障礙
  // ==================================================
  static String accessibilityStock(String symbol) =>
      'accessibility.stock'.tr(namedArgs: {'symbol': symbol});
  static String accessibilityPrice(double price) =>
      'accessibility.price'.tr(namedArgs: {'price': price.toStringAsFixed(2)});
  static String accessibilityPriceChange(double change) {
    final key = change >= 0
        ? 'accessibility.priceChangeUp'
        : 'accessibility.priceChangeDown';
    return key.tr(namedArgs: {'change': change.abs().toStringAsFixed(2)});
  }

  static String accessibilityScore(int score) =>
      'accessibility.score'.tr(namedArgs: {'score': score.toString()});
  static String accessibilitySignals(String signals) =>
      'accessibility.signals'.tr(namedArgs: {'signals': signals});
  static String get accessibilityAddToWatchlist =>
      'accessibility.addToWatchlist'.tr();
  static String get accessibilityRemoveFromWatchlist =>
      'accessibility.removeFromWatchlist'.tr();
  static String accessibilityButtonPress(String label) =>
      'accessibility.buttonPress'.tr(namedArgs: {'label': label});

  // 股票詳情頁無障礙標籤
  static String accessibilityClosePrice(String price) =>
      'accessibility.closePrice'.tr(namedArgs: {'price': price});
  static String accessibilityAbsoluteChange(String change) =>
      'accessibility.absoluteChange'.tr(namedArgs: {'change': change});
  static String accessibilityPriceChangeDetail(
    String absText,
    String pctText,
  ) => 'accessibility.priceChangeDetail'.tr(
    namedArgs: {'absText': absText, 'pctText': pctText},
  );
  static String accessibilityTrend(String trend) =>
      'accessibility.trend'.tr(namedArgs: {'trend': trend});

  // 比較頁面無障礙標籤
  static String accessibilityPriceComparisonChart(String symbols) =>
      'accessibility.priceComparisonChart'.tr(namedArgs: {'symbols': symbols});
  static String accessibilityRadarChart(String symbols) =>
      'accessibility.radarChart'.tr(namedArgs: {'symbols': symbols});
  static String accessibilityComparisonTable(String symbols) =>
      'accessibility.comparisonTable'.tr(namedArgs: {'symbols': symbols});

  // 投資組合無障礙標籤
  static String accessibilityAllocationPieChart(int count) =>
      'accessibility.allocationPieChart'.tr(
        namedArgs: {'count': count.toString()},
      );

  // 走勢圖無障礙標籤
  static String get sparklineDefault => 'accessibility.sparklineDefault'.tr();
  static String sparklineFlat(int days) =>
      'accessibility.sparklineFlat'.tr(namedArgs: {'days': days.toString()});
  static String sparklineTrend(int days, double change) {
    final key = change >= 0
        ? 'accessibility.sparklineTrendUp'
        : 'accessibility.sparklineTrendDown';
    return key.tr(
      namedArgs: {
        'days': days.toString(),
        'change': change.abs().toStringAsFixed(1),
      },
    );
  }

  // Shimmer 載入無障礙標籤
  static String get shimmerLoadingStockList =>
      'accessibility.shimmerStockList'.tr();
  static String get shimmerLoadingStockDetail =>
      'accessibility.shimmerStockDetail'.tr();
  static String get shimmerLoadingNewsList =>
      'accessibility.shimmerNewsList'.tr();
  static String get shimmerLoadingGenericList =>
      'accessibility.shimmerGenericList'.tr();

  // ==================================================
  // 自選股狀態圖示
  // ==================================================
  static String get statusHasSignal => 'status.hasSignal'.tr();
  static String get statusVolatile => 'status.volatile'.tr();
  static String get statusQuiet => 'status.quiet'.tr();
  static String signalType(String? type) =>
      'status.signalType'.tr(namedArgs: {'type': type ?? '異常'});

  // ==================================================
  // 市場類型
  // ==================================================
  static String get marketTWSE => 'market.twse'.tr();
  static String get marketTPEx => 'market.tpex'.tr();

  // ==================================================
  // 基本面
  // ==================================================
  static String dividendYearAverage(int years) =>
      'fundamental.dividendYearAverage'.tr(
        namedArgs: {'years': years.toString()},
      );

  // ==================================================
  // 時間與日期
  // ==================================================
  static String dateFormat(DateTime dt) {
    final local = dt.toLocal();
    return '${local.month}/${local.day} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
