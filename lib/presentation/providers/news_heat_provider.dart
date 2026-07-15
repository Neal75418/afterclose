// lib/presentation/providers/news_heat_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/constants/news_heat_params.dart';
import 'package:afterclose/core/constants/scoring_mode.dart';
import 'package:afterclose/domain/services/news/heat_calculator.dart';
import 'package:afterclose/domain/services/news/stock_name_matcher.dart';
import 'package:afterclose/domain/services/news/theme_matcher.dart';
import 'package:afterclose/presentation/providers/data_update_epoch_provider.dart';
import 'package:afterclose/presentation/providers/mode_recommendation_provider.dart';
import 'package:afterclose/presentation/providers/providers.dart';

/// 熱度分析結果（新聞頁「熱度分析」Tab 的完整狀態）
class NewsHeatAnalysis {
  const NewsHeatAnalysis({
    required this.themes,
    required this.stocks,
    required this.stockNames,
    required this.modeBySymbol,
  });

  /// 主流族群 Top N（articles7d 降冪）
  final List<ThemeHeat> themes;

  /// 焦點股 Top N（mentions7d 降冪）
  final List<StockHeat> stocks;

  /// symbol → 公司名（顯示用）
  final Map<String, String> stockNames;

  /// 三模式交叉：symbol → 當前指派 mode（未入選任何 mode 則缺 key）
  final Map<String, ScoringMode> modeBySymbol;
}

/// 即時計算近 28 天新聞的熱度分析。
///
/// 資料源與新聞頁共用（重新整理抓完 RSS 後 invalidate 本 provider 即同步）。
/// 匹配結果只存在記憶體，不寫 news_stock_map（不進評分）。
final newsHeatProvider = FutureProvider<NewsHeatAnalysis>((ref) async {
  ref.watch(dataUpdateEpochProvider);

  final newsRepo = ref.read(newsRepositoryProvider);
  final db = ref.read(databaseProvider);

  const windowDays =
      NewsHeatParams.recentWindowDays + NewsHeatParams.baselineWindowDays;
  final news = await newsRepo.getRecentNews(days: windowDays);
  final stocks = await db.getAllActiveStocks();

  final nameMatcher = StockNameMatcher.fromStocks(stocks);
  final themeMatcher = ThemeMatcher();
  final articles = [
    for (final n in news)
      ArticleTags(
        newsId: n.id,
        publishedAt: n.publishedAt,
        symbols: nameMatcher.match(n.title),
        themes: themeMatcher.match(n.title),
      ),
  ];
  final heat = HeatCalculator().compute(articles, now: DateTime.now());

  // 三模式交叉（與今日頁同源）
  final modeBySymbol = <String, ScoringMode>{};
  for (final mode in ScoringMode.userFacingModes) {
    final recs = await ref.watch(modeRecommendationsProvider(mode).future);
    for (final r in recs) {
      modeBySymbol[r.symbol] = mode;
    }
  }

  return NewsHeatAnalysis(
    themes: heat.themes.take(NewsHeatParams.topThemesCount).toList(),
    stocks: heat.stocks.take(NewsHeatParams.topStocksCount).toList(),
    stockNames: {for (final s in stocks) s.symbol: s.name},
    modeBySymbol: modeBySymbol,
  );
});
