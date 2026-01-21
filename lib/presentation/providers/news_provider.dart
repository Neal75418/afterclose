import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/rss_parser.dart';
import 'package:afterclose/presentation/providers/providers.dart';

// ==================================================
// News Screen State
// ==================================================

/// Available news sources for filtering
enum NewsSource {
  all('全部'),
  moneyDJ('MoneyDJ'),
  yahoo('Yahoo財經'),
  cnyes('鉅亨網'),
  cna('中央社');

  const NewsSource(this.label);
  final String label;

  /// Match source name from RSS feed
  bool matches(String sourceName) {
    return switch (this) {
      NewsSource.all => true,
      NewsSource.moneyDJ => sourceName == 'MoneyDJ',
      NewsSource.yahoo => sourceName == 'Yahoo財經',
      NewsSource.cnyes => sourceName == '鉅亨網',
      NewsSource.cna => sourceName == '中央社',
    };
  }
}

/// State for news screen
class NewsState {
  const NewsState({
    this.allNews = const [],
    this.newsStockMap = const {},
    this.isLoading = false,
    this.error,
    this.selectedSource = NewsSource.all,
  });

  final List<NewsItemEntry> allNews;
  final Map<String, List<String>> newsStockMap;
  final bool isLoading;
  final String? error;
  final NewsSource selectedSource;

  /// Filtered news based on selected source
  List<NewsItemEntry> get filteredNews {
    if (selectedSource == NewsSource.all) return allNews;
    return allNews.where((n) => selectedSource.matches(n.source)).toList();
  }

  /// Get available sources with counts
  Map<NewsSource, int> get sourceCounts {
    final counts = <NewsSource, int>{};
    counts[NewsSource.all] = allNews.length;

    for (final source in NewsSource.values) {
      if (source == NewsSource.all) continue;
      counts[source] = allNews.where((n) => source.matches(n.source)).length;
    }

    return counts;
  }

  NewsState copyWith({
    List<NewsItemEntry>? allNews,
    Map<String, List<String>>? newsStockMap,
    bool? isLoading,
    String? error,
    NewsSource? selectedSource,
  }) {
    return NewsState(
      allNews: allNews ?? this.allNews,
      newsStockMap: newsStockMap ?? this.newsStockMap,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedSource: selectedSource ?? this.selectedSource,
    );
  }
}

// ==================================================
// News Notifier
// ==================================================

class NewsNotifier extends StateNotifier<NewsState> {
  NewsNotifier(this._ref) : super(const NewsState());

  final Ref _ref;

  /// Load news data
  Future<void> loadData({int days = 7}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final newsRepo = _ref.read(newsRepositoryProvider);
      final db = _ref.read(databaseProvider);

      // Get recent news
      final news = await newsRepo.getRecentNews(days: days);

      if (news.isEmpty) {
        state = state.copyWith(allNews: [], newsStockMap: {}, isLoading: false);
        return;
      }

      // Collect all news IDs for batch query
      final newsIds = news.map((n) => n.id).toList();

      // Batch load all news-stock mappings in single query
      final newsStockMap = await db.getNewsStockMappingsBatch(newsIds);

      state = state.copyWith(
        allNews: news,
        newsStockMap: newsStockMap,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  /// Set the selected source filter
  void setSourceFilter(NewsSource source) {
    state = state.copyWith(selectedSource: source);
  }
}

// ==================================================
// Provider
// ==================================================

final newsProvider = StateNotifierProvider<NewsNotifier, NewsState>((ref) {
  return NewsNotifier(ref);
});

/// Provider for available RSS sources (for display purposes)
final newsSourcesProvider = Provider<List<String>>((ref) {
  return RssFeedSource.defaultSources.map((s) => s.name).toList();
});
