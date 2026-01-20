import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/providers/providers.dart';

// ==================================================
// News Screen State
// ==================================================

/// State for news screen
class NewsState {
  const NewsState({
    this.news = const [],
    this.newsStockMap = const {},
    this.isLoading = false,
    this.error,
  });

  final List<NewsItemEntry> news;
  final Map<String, List<String>> newsStockMap;
  final bool isLoading;
  final String? error;

  NewsState copyWith({
    List<NewsItemEntry>? news,
    Map<String, List<String>>? newsStockMap,
    bool? isLoading,
    String? error,
  }) {
    return NewsState(
      news: news ?? this.news,
      newsStockMap: newsStockMap ?? this.newsStockMap,
      isLoading: isLoading ?? this.isLoading,
      error: error,
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
        state = state.copyWith(
          news: [],
          newsStockMap: {},
          isLoading: false,
        );
        return;
      }

      // Collect all news IDs for batch query
      final newsIds = news.map((n) => n.id).toList();

      // Batch load all news-stock mappings in single query
      final newsStockMap = await db.getNewsStockMappingsBatch(newsIds);

      state = state.copyWith(
        news: news,
        newsStockMap: newsStockMap,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }
}

// ==================================================
// Provider
// ==================================================

final newsProvider = StateNotifierProvider<NewsNotifier, NewsState>((ref) {
  return NewsNotifier(ref);
});
