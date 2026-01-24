import 'package:drift/drift.dart';

import 'package:afterclose/data/database/tables/stock_master.dart';

/// 新聞資料 Table（來自 RSS feeds）
@DataClassName('NewsItemEntry')
@TableIndex(name: 'idx_news_item_published_at', columns: {#publishedAt})
@TableIndex(name: 'idx_news_item_source', columns: {#source})
class NewsItem extends Table {
  /// 新聞唯一 ID（URL 或 RSS guid 的 hash）
  TextColumn get id => text()();

  /// 新聞來源（如 MoneyDJ、Yahoo）
  TextColumn get source => text()();

  /// 新聞標題
  TextColumn get title => text()();

  /// 新聞連結
  TextColumn get url => text()();

  /// 分類：EARNINGS、POLICY、INDUSTRY、COMPANY_EVENT、OTHER
  TextColumn get category => text()();

  /// 發布時間
  DateTimeColumn get publishedAt => dateTime()();

  /// 抓取時間
  DateTimeColumn get fetchedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// 新聞與股票關聯 Table
@DataClassName('NewsStockMapEntry')
@TableIndex(name: 'idx_news_stock_map_symbol', columns: {#symbol})
@TableIndex(name: 'idx_news_stock_map_news_id', columns: {#newsId})
class NewsStockMap extends Table {
  /// 新聞 ID
  TextColumn get newsId =>
      text().references(NewsItem, #id, onDelete: KeyAction.cascade)();

  /// 關聯股票代碼
  TextColumn get symbol =>
      text().references(StockMaster, #symbol, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {newsId, symbol};
}
