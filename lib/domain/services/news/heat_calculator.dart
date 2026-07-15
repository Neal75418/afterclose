import 'package:afterclose/core/constants/news_heat_params.dart';

/// 一篇新聞的標籤（matcher 輸出的彙整）
class ArticleTags {
  const ArticleTags({
    required this.newsId,
    required this.publishedAt,
    required this.symbols,
    required this.themes,
  });

  final String newsId;
  final DateTime publishedAt;
  final Set<String> symbols;
  final Set<String> themes;
}

/// 焦點股熱度
class StockHeat {
  const StockHeat({
    required this.symbol,
    required this.mentions7d,
    required this.mentionsPrev21d,
    required this.isSurging,
  });

  final String symbol;
  final int mentions7d;
  final int mentionsPrev21d;
  final bool isSurging;
}

/// 題材熱度
class ThemeHeat {
  const ThemeHeat({
    required this.theme,
    required this.articles7d,
    required this.articlesPrev21d,
    required this.isSurging,
    required this.topStocks,
  });

  final String theme;
  final int articles7d;
  final int articlesPrev21d;
  final bool isSurging;

  /// 近 7 天與該題材共現次數最高的個股（Top [NewsHeatParams.themeTopStocksCount]）
  final List<String> topStocks;
}

class HeatResult {
  const HeatResult({required this.stocks, required this.themes});

  /// mentions7d 降冪
  final List<StockHeat> stocks;

  /// articles7d 降冪
  final List<ThemeHeat> themes;
}

/// 熱度計算（純函數）：窗口切分與爆量判定
///
/// 窗口以 **local 日曆日差**切分：0–6 天＝近窗、7–27 天＝基準窗、其餘忽略。
/// 爆量＝近 7 天篇數達前 21 天週均 3 倍（等價 `mentions7d >= mentionsPrev21d`）
/// 且 `mentions7d >= surgeMinMentions`。
///
/// 時區假設：`now` 與 `publishedAt` 皆以 `.toLocal()` 正規化到**執行裝置**
/// 的時區再取日曆日——假設寫入與讀取在同一裝置（同 PriceCoverage 的
/// 已文件化假設）。單機 App 成立；若未來跨時區同步需改以固定時區錨定。
class HeatCalculator {
  HeatResult compute(List<ArticleTags> articles, {required DateTime now}) {
    final localNow = now.toLocal();
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    final stockRecent = <String, int>{};
    final stockBaseline = <String, int>{};
    final themeRecent = <String, int>{};
    final themeBaseline = <String, int>{};
    // (theme, symbol) 近窗共現次數
    final coOccurrence = <String, Map<String, int>>{};

    for (final a in articles) {
      final local = a.publishedAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      final diff = today.difference(day).inDays;
      final isRecent = diff >= 0 && diff < NewsHeatParams.recentWindowDays;
      final isBaseline =
          diff >= NewsHeatParams.recentWindowDays &&
          diff <
              NewsHeatParams.recentWindowDays +
                  NewsHeatParams.baselineWindowDays;
      if (!isRecent && !isBaseline) continue;

      final stockBucket = isRecent ? stockRecent : stockBaseline;
      for (final s in a.symbols) {
        stockBucket[s] = (stockBucket[s] ?? 0) + 1;
      }
      final themeBucket = isRecent ? themeRecent : themeBaseline;
      for (final t in a.themes) {
        themeBucket[t] = (themeBucket[t] ?? 0) + 1;
        if (isRecent) {
          final co = coOccurrence.putIfAbsent(t, () => {});
          for (final s in a.symbols) {
            co[s] = (co[s] ?? 0) + 1;
          }
        }
      }
    }

    bool surging(int recent, int baseline) =>
        recent >= NewsHeatParams.surgeMinMentions && recent >= baseline;

    final stocks =
        {...stockRecent.keys, ...stockBaseline.keys}.map((s) {
          final r = stockRecent[s] ?? 0;
          final b = stockBaseline[s] ?? 0;
          return StockHeat(
            symbol: s,
            mentions7d: r,
            mentionsPrev21d: b,
            isSurging: surging(r, b),
          );
        }).toList()..sort((a, b) {
          final byRecent = b.mentions7d.compareTo(a.mentions7d);
          if (byRecent != 0) return byRecent;
          return a.symbol.compareTo(b.symbol);
        });

    final themes =
        {...themeRecent.keys, ...themeBaseline.keys}.map((t) {
          final r = themeRecent[t] ?? 0;
          final b = themeBaseline[t] ?? 0;
          final co = coOccurrence[t] ?? const <String, int>{};
          final top = co.entries.toList()
            ..sort((x, y) {
              final byCount = y.value.compareTo(x.value);
              if (byCount != 0) return byCount;
              return x.key.compareTo(y.key);
            });
          return ThemeHeat(
            theme: t,
            articles7d: r,
            articlesPrev21d: b,
            isSurging: surging(r, b),
            topStocks: top
                .take(NewsHeatParams.themeTopStocksCount)
                .map((e) => e.key)
                .toList(),
          );
        }).toList()..sort((a, b) {
          final byRecent = b.articles7d.compareTo(a.articles7d);
          if (byRecent != 0) return byRecent;
          return a.theme.compareTo(b.theme);
        });

    return HeatResult(stocks: stocks, themes: themes);
  }
}
