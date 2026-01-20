import 'package:drift/drift.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/rss_parser.dart';

/// Repository for news data
class NewsRepository {
  NewsRepository({required AppDatabase database, required RssParser rssParser})
    : _db = database,
      _rssParser = rssParser;

  final AppDatabase _db;
  final RssParser _rssParser;

  /// Sync news from all RSS feeds
  ///
  /// Returns the number of new items added
  Future<int> syncNews({List<RssFeedSource>? sources}) async {
    final feedSources = sources ?? RssFeedSource.defaultSources;
    final newsItems = await _rssParser.parseAllFeeds(feedSources);

    var addedCount = 0;

    for (final item in newsItems) {
      // Insert news item
      final companion = NewsItemCompanion.insert(
        id: item.id,
        source: item.source,
        title: item.title,
        url: item.url,
        category: item.category,
        publishedAt: item.publishedAt,
      );

      try {
        await _db
            .into(_db.newsItem)
            .insert(companion, mode: InsertMode.insertOrIgnore);
        addedCount++;

        // Extract and map stock codes from title
        final stockCodes = item.extractStockCodes();
        for (final code in stockCodes) {
          // Check if stock exists before mapping
          final stock = await _db.getStock(code);
          if (stock != null) {
            await _db
                .into(_db.newsStockMap)
                .insert(
                  NewsStockMapCompanion.insert(newsId: item.id, symbol: code),
                  mode: InsertMode.insertOrIgnore,
                );
          }
        }
      } catch (_) {
        // Ignore duplicate inserts
      }
    }

    return addedCount;
  }

  /// Get recent news (last N days)
  Future<List<NewsItemEntry>> getRecentNews({int days = 3}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return (await _db.select(_db.newsItem).get())
        .where((n) => n.publishedAt.isAfter(cutoff))
        .toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  }

  /// Get news for a specific stock
  Future<List<NewsItemEntry>> getNewsForStock(
    String symbol, {
    int days = 3,
  }) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));

    // Get news IDs mapped to this stock
    final mappings = await (_db.select(
      _db.newsStockMap,
    )..where((m) => m.symbol.equals(symbol))).get();

    if (mappings.isEmpty) return [];

    final newsIds = mappings.map((m) => m.newsId).toSet();

    // Get the actual news items
    final allNews = await _db.select(_db.newsItem).get();

    return allNews
        .where((n) => newsIds.contains(n.id) && n.publishedAt.isAfter(cutoff))
        .toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  }

  /// Check if stock has recent news
  Future<bool> hasRecentNews(String symbol, {int days = 2}) async {
    final news = await getNewsForStock(symbol, days: days);
    return news.isNotEmpty;
  }

  /// Get news item by ID
  Future<NewsItemEntry?> getNewsById(String id) async {
    return (_db.select(
      _db.newsItem,
    )..where((n) => n.id.equals(id))).getSingleOrNull();
  }

  /// Clean up old news (older than N days)
  Future<int> cleanupOldNews({int olderThanDays = 30}) async {
    final cutoff = DateTime.now().subtract(Duration(days: olderThanDays));

    // First delete mappings for old news
    final oldNews = (await _db.select(_db.newsItem).get())
        .where((n) => n.publishedAt.isBefore(cutoff))
        .map((n) => n.id)
        .toList();

    if (oldNews.isEmpty) return 0;

    // Delete mappings
    for (final newsId in oldNews) {
      await (_db.delete(
        _db.newsStockMap,
      )..where((m) => m.newsId.equals(newsId))).go();
    }

    // Delete news items
    return (_db.delete(
      _db.newsItem,
    )..where((n) => n.publishedAt.isSmallerThanValue(cutoff))).go();
  }
}
