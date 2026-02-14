import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart'
    show StateNotifier, StateNotifierProvider;

import 'package:afterclose/core/utils/sentinel.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/rss_parser.dart';
import 'package:afterclose/presentation/providers/providers.dart';

// ==================================================
// News Screen State
// ==================================================

/// 可用的新聞來源篩選選項
enum NewsSource {
  all,
  moneyDJ,
  yahoo,
  cnyes,
  cna;

  String get label =>
      'empty.source${name[0].toUpperCase()}${name.substring(1)}'.tr();

  /// 比對 RSS feed 中的來源名稱
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

/// 新聞頁面狀態
class NewsState {
  NewsState({
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

  /// 依選定來源過濾的新聞
  List<NewsItemEntry> get filteredNews {
    if (selectedSource == NewsSource.all) return allNews;
    return allNews.where((n) => selectedSource.matches(n.source)).toList();
  }

  /// 各來源的新聞數量（建構時計算一次，避免每次 watch 重新遍歷）
  late final Map<NewsSource, int> sourceCounts = _computeSourceCounts();

  Map<NewsSource, int> _computeSourceCounts() {
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
    Object? error = sentinel,
    NewsSource? selectedSource,
  }) {
    return NewsState(
      allNews: allNews ?? this.allNews,
      newsStockMap: newsStockMap ?? this.newsStockMap,
      isLoading: isLoading ?? this.isLoading,
      error: error == sentinel ? this.error : error as String?,
      selectedSource: selectedSource ?? this.selectedSource,
    );
  }
}

// ==================================================
// News Notifier
// ==================================================

class NewsNotifier extends StateNotifier<NewsState> {
  NewsNotifier(this._ref) : super(NewsState());

  final Ref _ref;

  /// 載入新聞資料
  Future<void> loadData({int days = 7}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final newsRepo = _ref.read(newsRepositoryProvider);
      final db = _ref.read(databaseProvider);

      // 取得近期新聞
      final news = await newsRepo.getRecentNews(days: days);

      if (news.isEmpty) {
        state = state.copyWith(allNews: [], newsStockMap: {}, isLoading: false);
        return;
      }

      // 收集所有新聞 ID 進行批次查詢
      final newsIds = news.map((n) => n.id).toList();

      // 單次查詢批量載入新聞-股票對應
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

  /// 設定來源篩選
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

/// RSS 來源清單 Provider（供顯示用）
final newsSourcesProvider = Provider<List<String>>((ref) {
  return RssFeedSource.defaultSources.map((s) => s.name).toList();
});
