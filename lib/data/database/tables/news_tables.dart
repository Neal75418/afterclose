import 'package:drift/drift.dart';

import 'package:afterclose/data/database/tables/stock_master.dart';

/// News item from RSS feeds
@DataClassName('NewsItemEntry')
class NewsItem extends Table {
  /// Unique news ID (hash of url or RSS guid)
  TextColumn get id => text()();

  /// News source (e.g., "MoneyDJ", "Yahoo")
  TextColumn get source => text()();

  /// News title
  TextColumn get title => text()();

  /// News URL
  TextColumn get url => text()();

  /// Category: EARNINGS, POLICY, INDUSTRY, COMPANY_EVENT, OTHER
  TextColumn get category => text()();

  /// Published timestamp
  DateTimeColumn get publishedAt => dateTime()();

  /// When we fetched this news
  DateTimeColumn get fetchedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Mapping between news and related stocks
@DataClassName('NewsStockMapEntry')
class NewsStockMap extends Table {
  /// News ID
  TextColumn get newsId => text().references(NewsItem, #id)();

  /// Related stock symbol
  TextColumn get symbol => text().references(StockMaster, #symbol)();

  @override
  Set<Column> get primaryKey => {newsId, symbol};
}
