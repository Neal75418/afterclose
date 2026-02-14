import 'package:drift/drift.dart';

import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/rss_parser.dart';
import 'package:afterclose/domain/repositories/news_repository.dart';

/// 新聞資料 Repository
class NewsRepository implements INewsRepository {
  NewsRepository({
    required AppDatabase database,
    required RssParser rssParser,
    AppClock clock = const SystemClock(),
  }) : _db = database,
       _rssParser = rssParser,
       _clock = clock;

  final AppDatabase _db;
  final RssParser _rssParser;
  final AppClock _clock;

  /// 從所有 RSS feeds 同步新聞
  ///
  /// 回傳 [NewsSyncResult]，包含新增筆數和錯誤資訊
  @override
  Future<NewsSyncResult> syncNews({List<RssFeedSource>? sources}) async {
    final feedSources = sources ?? RssFeedSource.defaultSources;
    final parseResult = await _rssParser.parseAllFeeds(feedSources);

    if (parseResult.items.isEmpty) {
      return NewsSyncResult(itemsAdded: 0, errors: parseResult.errors);
    }

    final newsItems = parseResult.items;

    // 預先載入所有上市股票以提升查詢效率
    final activeStocks = await _db.getAllActiveStocks();
    final stockSymbols = activeStocks.map((s) => s.symbol).toSet();

    // 準備資料
    final newsCompanions = <NewsItemCompanion>[];
    final mappingCompanions = <NewsStockMapCompanion>[];

    for (final item in newsItems) {
      newsCompanions.add(
        NewsItemCompanion.insert(
          id: item.id,
          source: item.source,
          title: item.title,
          content: Value(item.content),
          url: item.url,
          category: item.category,
          publishedAt: item.publishedAt,
        ),
      );

      // 從標題擷取並建立股票關聯
      final stockCodes = item.extractStockCodes();
      for (final code in stockCodes) {
        if (stockSymbols.contains(code)) {
          mappingCompanions.add(
            NewsStockMapCompanion.insert(newsId: item.id, symbol: code),
          );
        }
      }
    }

    // 在單一 Transaction 中批次寫入
    await _db.transaction(() async {
      // 批次寫入新聞
      await _db.batch((b) {
        for (final companion in newsCompanions) {
          b.insert(_db.newsItem, companion, mode: InsertMode.insertOrIgnore);
        }
      });

      // 批次寫入股票關聯
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

  /// 取得最近新聞（Database 層級過濾）
  ///
  /// [days] - 回溯天數（預設 3 天）
  /// [limit] - 回傳上限（預設無限制）
  /// [offset] - 略過筆數（分頁用，預設 0）
  @override
  Future<List<NewsItemEntry>> getRecentNews({
    int days = 3,
    int? limit,
    int offset = 0,
  }) async {
    final cutoff = _clock.now().subtract(Duration(days: days));
    final query = _db.select(_db.newsItem)
      ..where((n) => n.publishedAt.isBiggerOrEqualValue(cutoff))
      ..orderBy([(n) => OrderingTerm.desc(n.publishedAt)]);

    // 套用分頁
    if (limit != null) {
      query.limit(limit, offset: offset);
    }

    return query.get();
  }

  /// 取得特定股票的新聞（Database 層級過濾）
  ///
  /// [symbol] - 股票代碼
  /// [days] - 回溯天數（預設 3 天）
  /// [limit] - 回傳上限（預設無限制）
  /// [offset] - 略過筆數（分頁用，預設 0）
  @override
  Future<List<NewsItemEntry>> getNewsForStock(
    String symbol, {
    int days = 3,
    int? limit,
    int offset = 0,
  }) async {
    final cutoff = _clock.now().subtract(Duration(days: days));

    // 取得該股票關聯的新聞 ID
    final mappings = await (_db.select(
      _db.newsStockMap,
    )..where((m) => m.symbol.equals(symbol))).get();

    if (mappings.isEmpty) return [];

    final newsIds = mappings.map((m) => m.newsId).toList();

    // 以 Database 層級過濾日期
    final query = _db.select(_db.newsItem)
      ..where((n) => n.id.isIn(newsIds))
      ..where((n) => n.publishedAt.isBiggerOrEqualValue(cutoff))
      ..orderBy([(n) => OrderingTerm.desc(n.publishedAt)]);

    // 套用分頁
    if (limit != null) {
      query.limit(limit, offset: offset);
    }

    return query.get();
  }

  /// 批次取得多檔股票的新聞（避免 N+1 問題）
  ///
  /// 回傳 Map：symbol -> 新聞清單
  @override
  Future<Map<String, List<NewsItemEntry>>> getNewsForStocksBatch(
    List<String> symbols, {
    int days = 3,
  }) async {
    if (symbols.isEmpty) return {};

    final cutoff = _clock.now().subtract(Duration(days: days));

    // 一次查詢所有關聯
    final mappings = await (_db.select(
      _db.newsStockMap,
    )..where((m) => m.symbol.isIn(symbols))).get();

    if (mappings.isEmpty) return {};

    // 取得所有不重複的新聞 ID
    final newsIds = mappings.map((m) => m.newsId).toSet().toList();

    // 一次查詢所有新聞並套用日期過濾
    final newsItems =
        await (_db.select(_db.newsItem)
              ..where((n) => n.id.isIn(newsIds))
              ..where((n) => n.publishedAt.isBiggerOrEqualValue(cutoff))
              ..orderBy([(n) => OrderingTerm.desc(n.publishedAt)]))
            .get();

    // 建立快速查詢 Map
    final newsMap = {for (final item in newsItems) item.id: item};

    // 依股票分組
    final result = <String, List<NewsItemEntry>>{};
    for (final mapping in mappings) {
      final newsItem = newsMap[mapping.newsId];
      if (newsItem != null) {
        result.putIfAbsent(mapping.symbol, () => []).add(newsItem);
      }
    }

    return result;
  }

  /// 檢查股票是否有近期新聞
  @override
  Future<bool> hasRecentNews(String symbol, {int days = 2}) async {
    final news = await getNewsForStock(symbol, days: days);
    return news.isNotEmpty;
  }

  /// 依 ID 取得新聞
  @override
  Future<NewsItemEntry?> getNewsById(String id) async {
    return (_db.select(
      _db.newsItem,
    )..where((n) => n.id.equals(id))).getSingleOrNull();
  }

  /// 清理舊新聞（超過 N 天）
  ///
  /// 使用 Cascade Delete 自動刪除關聯資料
  @override
  Future<int> cleanupOldNews({int olderThanDays = 30}) async {
    final cutoff = _clock.now().subtract(Duration(days: olderThanDays));

    // 刪除舊新聞，Cascade Delete 會處理關聯
    return (_db.delete(
      _db.newsItem,
    )..where((n) => n.publishedAt.isSmallerThanValue(cutoff))).go();
  }
}
