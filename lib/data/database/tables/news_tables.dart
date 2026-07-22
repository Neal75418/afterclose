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

  /// 新聞內文摘要（從 RSS description 抓取，可能為空）
  TextColumn get content => text().nullable()();

  /// 新聞連結
  TextColumn get url => text()();

  /// 分類：目前一律 'OTHER'（RSS 來源未實作分類器）
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

/// 每日提及數快照（新聞熱度發現層）
///
/// 唯一消費者是**未來回測**（顯示層即時計算、不讀此表）。
/// 新聞 30 天清理後提及數不可回補，故此表：
/// 1. 必須列入 app_database 的 `_userInputTableNames`（fingerprint reset 不得 wipe）
/// 2. 帶 dictionaryVersion 供回測取同版本區段（字典演化防假爆量）
@DataClassName('NewsMentionDailyEntry')
@TableIndex(name: 'idx_news_mention_daily_date', columns: {#date})
class NewsMentionDaily extends Table {
  /// 本地日曆日（新聞 publishedAt 的 local 日）
  DateTimeColumn get date => dateTime()();

  /// 'stock' 或 'theme'
  TextColumn get kind => text()();

  /// symbol（kind=stock）或題材名（kind=theme）
  TextColumn get itemKey => text()();

  /// 該日提及篇數
  IntColumn get mentionCount => integer()();

  /// 寫入當下的 NewsHeatParams.dictionaryVersion
  IntColumn get dictionaryVersion => integer()();

  @override
  Set<Column> get primaryKey => {date, kind, itemKey};
}
