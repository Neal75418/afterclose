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
  /// Returns a [NewsSyncResult] containing count of items added and any errors
  Future<NewsSyncResult> syncNews({List<RssFeedSource>? sources}) async {
    final feedSources = sources ?? RssFeedSource.defaultSources;
    final parseResult = await _rssParser.parseAllFeeds(feedSources);

    if (parseResult.items.isEmpty) {
      return NewsSyncResult(itemsAdded: 0, errors: parseResult.errors);
    }

    final newsItems = parseResult.items;

    // Pre-fetch all active stocks for efficient lookup
    final activeStocks = await _db.getAllActiveStocks();
    final stockSymbols = activeStocks.map((s) => s.symbol).toSet();

    // Prepare all entries
    final newsCompanions = <NewsItemCompanion>[];
    final mappingCompanions = <NewsStockMapCompanion>[];

    for (final item in newsItems) {
      newsCompanions.add(
        NewsItemCompanion.insert(
          id: item.id,
          source: item.source,
          title: item.title,
          url: item.url,
          category: item.category,
          publishedAt: item.publishedAt,
        ),
      );

      // Extract and map stock codes from title
      final stockCodes = item.extractStockCodes();
      for (final code in stockCodes) {
        if (stockSymbols.contains(code)) {
          mappingCompanions.add(
            NewsStockMapCompanion.insert(newsId: item.id, symbol: code),
          );
        }
      }
    }

    // Insert all in a single transaction with batch operations
    await _db.transaction(() async {
      // Batch insert news items
      await _db.batch((b) {
        for (final companion in newsCompanions) {
          b.insert(_db.newsItem, companion, mode: InsertMode.insertOrIgnore);
        }
      });

      // Batch insert stock mappings
      if (mappingCompanions.isNotEmpty) {
        await _db.batch((b) {
          for (final companion in mappingCompanions) {
            b.insert(
              _db.newsStockMap,
              companion,
              mode: InsertMode.insertOrIgnore,
            );
          }
        });
      }
    });

    return NewsSyncResult(
      itemsAdded: newsCompanions.length,
      errors: parseResult.errors,
    );
  }

  /// Get recent news (last N days) - uses DB-level filtering
  Future<List<NewsItemEntry>> getRecentNews({int days = 3}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return (_db.select(_db.newsItem)
          ..where((n) => n.publishedAt.isBiggerOrEqualValue(cutoff))
          ..orderBy([(n) => OrderingTerm.desc(n.publishedAt)]))
        .get();
  }

  /// Get news for a specific stock - uses DB-level filtering
  Future<List<NewsItemEntry>> getNewsForStock(
    String symbol, {
    int days = 3,
  }) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));

    // Get news IDs mapped to this stock
    final mappings = await (_db.select(_db.newsStockMap)
          ..where((m) => m.symbol.equals(symbol)))
        .get();

    if (mappings.isEmpty) return [];

    final newsIds = mappings.map((m) => m.newsId).toList();

    // Get news items with DB-level date filtering
    return (_db.select(_db.newsItem)
          ..where((n) => n.id.isIn(newsIds))
          ..where((n) => n.publishedAt.isBiggerOrEqualValue(cutoff))
          ..orderBy([(n) => OrderingTerm.desc(n.publishedAt)]))
        .get();
  }

  /// Get news for multiple stocks (batch query to avoid N+1)
  ///
  /// Returns a map of symbol -> news list
  Future<Map<String, List<NewsItemEntry>>> getNewsForStocksBatch(
    List<String> symbols, {
    int days = 3,
  }) async {
    if (symbols.isEmpty) return {};

    final cutoff = DateTime.now().subtract(Duration(days: days));

    // Get all mappings for the given symbols
    final mappings = await (_db.select(_db.newsStockMap)
          ..where((m) => m.symbol.isIn(symbols)))
        .get();

    if (mappings.isEmpty) return {};

    // Get all unique news IDs
    final newsIds = mappings.map((m) => m.newsId).toSet().toList();

    // Get all news items in one query with date filter
    final newsItems = await (_db.select(_db.newsItem)
          ..where((n) => n.id.isIn(newsIds))
          ..where((n) => n.publishedAt.isBiggerOrEqualValue(cutoff))
          ..orderBy([(n) => OrderingTerm.desc(n.publishedAt)]))
        .get();

    // Create a map for quick lookup
    final newsMap = {for (final item in newsItems) item.id: item};

    // Group by symbol
    final result = <String, List<NewsItemEntry>>{};
    for (final mapping in mappings) {
      final newsItem = newsMap[mapping.newsId];
      if (newsItem != null) {
        result.putIfAbsent(mapping.symbol, () => []).add(newsItem);
      }
    }

    return result;
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
  ///
  /// Uses cascade delete - removing news items automatically removes mappings
  Future<int> cleanupOldNews({int olderThanDays = 30}) async {
    final cutoff = DateTime.now().subtract(Duration(days: olderThanDays));

    // Delete old news items - cascade delete will handle mappings
    return (_db.delete(
      _db.newsItem,
    )..where((n) => n.publishedAt.isSmallerThanValue(cutoff))).go();
  }
}

/// Result of news sync operation
class NewsSyncResult {
  const NewsSyncResult({required this.itemsAdded, required this.errors});

  final int itemsAdded;
  final List<RssFeedError> errors;

  /// Whether any feeds failed to parse
  bool get hasErrors => errors.isNotEmpty;

  /// Whether sync was completely successful (no errors)
  bool get isFullySuccessful => errors.isEmpty;
}
