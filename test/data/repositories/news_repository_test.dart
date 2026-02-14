import 'package:afterclose/data/database/app_database.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:afterclose/data/remote/rss_parser.dart';
import 'package:afterclose/data/repositories/news_repository.dart';
import 'package:afterclose/domain/repositories/news_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/portfolio_data_builders.dart';

class MockAppDatabase extends Mock implements AppDatabase {
  @override
  Future<T> transaction<T>(Future<T> Function() action, {bool? requireNew}) {
    return action();
  }

  @override
  Future<void> batch(Function(Batch) callback) async {
    // No-op: skip actual batch operations in tests
  }
}

class MockRssParser extends Mock implements RssParser {}

void main() {
  late MockAppDatabase mockDb;
  late MockRssParser mockRssParser;
  late NewsRepository repo;

  setUp(() {
    mockDb = MockAppDatabase();
    mockRssParser = MockRssParser();
    repo = NewsRepository(database: mockDb, rssParser: mockRssParser);
  });

  // ==========================================
  // syncNews
  // ==========================================
  group('syncNews', () {
    test('returns 0 items when parse result is empty', () async {
      when(
        () => mockRssParser.parseAllFeeds(any()),
      ).thenAnswer((_) async => const RssParseResult(items: [], errors: []));

      final result = await repo.syncNews();

      expect(result.itemsAdded, equals(0));
      expect(result.hasErrors, isFalse);
    });

    test('returns errors from parse result', () async {
      when(() => mockRssParser.parseAllFeeds(any())).thenAnswer(
        (_) async => RssParseResult(
          items: [],
          errors: [
            RssFeedError(
              sourceName: 'TestFeed',
              url: 'https://example.com/rss',
              error: 'Connection timeout',
              timestamp: DateTime(2025, 1, 15),
            ),
          ],
        ),
      );

      final result = await repo.syncNews();

      expect(result.itemsAdded, equals(0));
      expect(result.hasErrors, isTrue);
      expect(result.errors.length, equals(1));
    });

    test('inserts news and stock mappings via batch', () async {
      when(() => mockRssParser.parseAllFeeds(any())).thenAnswer(
        (_) async => RssParseResult(
          items: [
            RssNewsItem(
              id: 'news-1',
              source: 'TestFeed',
              title: '台積電 2330 營收創新高',
              url: 'https://example.com/1',
              publishedAt: DateTime(2025, 1, 15),
              category: 'STOCK',
            ),
          ],
          errors: [],
        ),
      );
      when(() => mockDb.getAllActiveStocks()).thenAnswer(
        (_) async => [createTestStockMaster(symbol: '2330', name: '台積電')],
      );
      final result = await repo.syncNews();

      expect(result.itemsAdded, equals(1));
      expect(result.isFullySuccessful, isTrue);
    });

    test('filters stock codes not in active stocks', () async {
      when(() => mockRssParser.parseAllFeeds(any())).thenAnswer(
        (_) async => RssParseResult(
          items: [
            RssNewsItem(
              id: 'news-1',
              source: 'TestFeed',
              title: '9999 不存在的股票',
              url: 'https://example.com/1',
              publishedAt: DateTime(2025, 1, 15),
              category: 'STOCK',
            ),
          ],
          errors: [],
        ),
      );
      when(
        () => mockDb.getAllActiveStocks(),
      ).thenAnswer((_) async => <StockMasterEntry>[]);

      final result = await repo.syncNews();

      // News item added, but stock mapping should not be created for 9999
      expect(result.itemsAdded, equals(1));
    });
  });

  // ==========================================
  // NewsSyncResult
  // ==========================================
  group('NewsSyncResult', () {
    test('hasErrors returns true when errors present', () {
      final result = NewsSyncResult(
        itemsAdded: 5,
        errors: [
          RssFeedError(
            sourceName: 'Feed',
            url: 'https://example.com',
            error: 'Timeout',
            timestamp: DateTime(2025, 1, 15),
          ),
        ],
      );

      expect(result.hasErrors, isTrue);
      expect(result.isFullySuccessful, isFalse);
    });

    test('isFullySuccessful returns true when no errors', () {
      const result = NewsSyncResult(itemsAdded: 10, errors: []);

      expect(result.hasErrors, isFalse);
      expect(result.isFullySuccessful, isTrue);
    });
  });

  // ==========================================
  // RssNewsItem.extractStockCodes
  // ==========================================
  group('RssNewsItem.extractStockCodes', () {
    test('extracts 4-digit stock codes from title', () {
      final item = RssNewsItem(
        id: '1',
        source: 'Test',
        title: '台積電 2330 營收創新高，聯電 2303 跟進',
        url: 'https://example.com',
        publishedAt: DateTime(2025, 1, 15),
        category: 'STOCK',
      );

      expect(item.extractStockCodes(), equals(['2330', '2303']));
    });

    test('returns empty for no stock codes', () {
      final item = RssNewsItem(
        id: '1',
        source: 'Test',
        title: '台股大盤走勢分析',
        url: 'https://example.com',
        publishedAt: DateTime(2025, 1, 15),
        category: 'MARKET',
      );

      expect(item.extractStockCodes(), isEmpty);
    });
  });
}
