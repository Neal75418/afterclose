import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/repositories/news_repository.dart';
import 'package:afterclose/domain/repositories/news_repository.dart'
    show NewsSyncResult;
import 'package:afterclose/presentation/providers/providers.dart';
import 'package:afterclose/presentation/providers/news_provider.dart';

// ==========================================
// Mocks
// ==========================================

class MockAppDatabase extends Mock implements AppDatabase {}

class MockNewsRepository extends Mock implements NewsRepository {}

// ==========================================
// Test Helpers
// ==========================================

NewsItemEntry createNewsEntry({
  required String id,
  required String title,
  String source = 'MoneyDJ',
  DateTime? publishedAt,
}) {
  return NewsItemEntry(
    id: id,
    title: title,
    source: source,
    url: 'https://example.com/$id',
    category: 'OTHER',
    publishedAt: publishedAt ?? DateTime(2026, 2, 13),
    fetchedAt: DateTime(2026, 2, 13),
  );
}

// ==========================================
// Tests
// ==========================================

void main() {
  late MockAppDatabase mockDb;
  late MockNewsRepository mockNewsRepo;
  late ProviderContainer container;

  setUp(() {
    mockDb = MockAppDatabase();
    mockNewsRepo = MockNewsRepository();

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(mockDb),
        newsRepositoryProvider.overrideWithValue(mockNewsRepo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  // ==========================================
  // NewsSource
  // ==========================================

  group('NewsSource', () {
    test('all matches every source', () {
      expect(NewsSource.all.matches('MoneyDJ'), isTrue);
      expect(NewsSource.all.matches('Yahoo財經'), isTrue);
      expect(NewsSource.all.matches('anything'), isTrue);
    });

    test('moneyDJ matches only MoneyDJ', () {
      expect(NewsSource.moneyDJ.matches('MoneyDJ'), isTrue);
      expect(NewsSource.moneyDJ.matches('Yahoo財經'), isFalse);
    });

    test('yahoo matches only Yahoo財經', () {
      expect(NewsSource.yahoo.matches('Yahoo財經'), isTrue);
      expect(NewsSource.yahoo.matches('MoneyDJ'), isFalse);
    });

    test('cnyes matches only 鉅亨網', () {
      expect(NewsSource.cnyes.matches('鉅亨網'), isTrue);
      expect(NewsSource.cnyes.matches('MoneyDJ'), isFalse);
    });

    test('cna matches only 中央社', () {
      expect(NewsSource.cna.matches('中央社'), isTrue);
      expect(NewsSource.cna.matches('MoneyDJ'), isFalse);
    });

    test('udn matches only 經濟日報', () {
      expect(NewsSource.udn.matches('經濟日報'), isTrue);
      expect(NewsSource.udn.matches('中央社'), isFalse);
    });

    test('ltn matches only 自由財經', () {
      expect(NewsSource.ltn.matches('自由財經'), isTrue);
      expect(NewsSource.ltn.matches('經濟日報'), isFalse);
    });
  });

  // ==========================================
  // NewsState
  // ==========================================

  group('NewsState', () {
    test('has correct default values', () {
      final state = NewsState();

      expect(state.allNews, isEmpty);
      expect(state.newsStockMap, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.selectedSource, NewsSource.all);
    });

    test('filteredNews returns all when source is all', () {
      final news = [
        createNewsEntry(id: '1', title: 'A', source: 'MoneyDJ'),
        createNewsEntry(id: '2', title: 'B', source: 'Yahoo財經'),
      ];
      final state = NewsState(allNews: news);

      expect(state.filteredNews, hasLength(2));
    });

    test('filteredNews filters by selected source', () {
      final news = [
        createNewsEntry(id: '1', title: 'A', source: 'MoneyDJ'),
        createNewsEntry(id: '2', title: 'B', source: 'Yahoo財經'),
        createNewsEntry(id: '3', title: 'C', source: 'MoneyDJ'),
      ];
      final state = NewsState(
        allNews: news,
        selectedSource: NewsSource.moneyDJ,
      );

      expect(state.filteredNews, hasLength(2));
      expect(state.filteredNews.every((n) => n.source == 'MoneyDJ'), isTrue);
    });

    test('sourceCounts counts per source', () {
      final news = [
        createNewsEntry(id: '1', title: 'A', source: 'MoneyDJ'),
        createNewsEntry(id: '2', title: 'B', source: 'Yahoo財經'),
        createNewsEntry(id: '3', title: 'C', source: 'MoneyDJ'),
      ];
      final state = NewsState(allNews: news);

      expect(state.sourceCounts[NewsSource.all], 3);
      expect(state.sourceCounts[NewsSource.moneyDJ], 2);
      expect(state.sourceCounts[NewsSource.yahoo], 1);
      expect(state.sourceCounts[NewsSource.cnyes], 0);
      expect(state.sourceCounts[NewsSource.cna], 0);
    });

    test('copyWith preserves unset values', () {
      final state = NewsState(isLoading: true);
      final copied = state.copyWith();
      expect(copied.isLoading, isTrue);
    });

    test('copyWith with sentinel handles error correctly', () {
      final state = NewsState(error: 'old error');

      final preserved = state.copyWith();
      expect(preserved.error, 'old error');

      final cleared = state.copyWith(error: null);
      expect(cleared.error, isNull);
    });
  });

  // ==========================================
  // NewsNotifier
  // ==========================================

  group('NewsNotifier', () {
    test('initial state is empty', () {
      final state = container.read(newsProvider);
      expect(state.allNews, isEmpty);
      expect(state.isLoading, isFalse);
    });

    test('loadData sets news from repository', () async {
      final news = [
        createNewsEntry(id: '1', title: '新聞一'),
        createNewsEntry(id: '2', title: '新聞二'),
      ];
      when(
        () => mockNewsRepo.getRecentNews(days: any(named: 'days')),
      ).thenAnswer((_) async => news);
      when(
        () => mockDb.getNewsStockMappingsBatch(any()),
      ).thenAnswer((_) async => {});

      final notifier = container.read(newsProvider.notifier);
      await notifier.loadData();

      final state = container.read(newsProvider);
      expect(state.allNews, hasLength(2));
      expect(state.isLoading, isFalse);
    });

    test('loadData sets empty when no news', () async {
      when(
        () => mockNewsRepo.getRecentNews(days: any(named: 'days')),
      ).thenAnswer((_) async => []);

      final notifier = container.read(newsProvider.notifier);
      await notifier.loadData();

      final state = container.read(newsProvider);
      expect(state.allNews, isEmpty);
      expect(state.isLoading, isFalse);
    });

    test('loadData handles error gracefully', () async {
      when(
        () => mockNewsRepo.getRecentNews(days: any(named: 'days')),
      ).thenThrow(Exception('Network error'));

      final notifier = container.read(newsProvider.notifier);
      await notifier.loadData();

      final state = container.read(newsProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNotNull);
    });

    test('setSourceFilter changes selected source', () {
      final notifier = container.read(newsProvider.notifier);
      notifier.setSourceFilter(NewsSource.yahoo);

      final state = container.read(newsProvider);
      expect(state.selectedSource, NewsSource.yahoo);
    });

    test('refresh syncs RSS before reloading local data', () async {
      final callOrder = <String>[];
      when(() => mockNewsRepo.syncNews()).thenAnswer((_) async {
        callOrder.add('sync');
        return const NewsSyncResult(itemsAdded: 3, errors: []);
      });
      when(
        () => mockNewsRepo.getRecentNews(days: any(named: 'days')),
      ).thenAnswer((_) async {
        callOrder.add('load');
        return [createNewsEntry(id: '1', title: '新聞一')];
      });
      when(
        () => mockDb.getNewsStockMappingsBatch(any()),
      ).thenAnswer((_) async => {});

      final notifier = container.read(newsProvider.notifier);
      await notifier.refresh();

      expect(callOrder, equals(['sync', 'load']));
      final state = container.read(newsProvider);
      expect(state.allNews, hasLength(1));
      expect(state.error, isNull);
    });

    test('refresh still loads local data when RSS sync throws', () async {
      when(() => mockNewsRepo.syncNews()).thenThrow(Exception('offline'));
      when(
        () => mockNewsRepo.getRecentNews(days: any(named: 'days')),
      ).thenAnswer((_) async => [createNewsEntry(id: '1', title: '新聞一')]);
      when(
        () => mockDb.getNewsStockMappingsBatch(any()),
      ).thenAnswer((_) async => {});

      final notifier = container.read(newsProvider.notifier);
      await notifier.refresh();

      final state = container.read(newsProvider);
      expect(state.allNews, hasLength(1));
      expect(state.error, isNull);
      expect(state.isLoading, isFalse);
    });

    test('refresh ignores re-entrant calls while in flight', () async {
      var syncCalls = 0;
      when(() => mockNewsRepo.syncNews()).thenAnswer((_) async {
        syncCalls++;
        await Future<void>.delayed(Duration.zero);
        return const NewsSyncResult(itemsAdded: 0, errors: []);
      });
      when(
        () => mockNewsRepo.getRecentNews(days: any(named: 'days')),
      ).thenAnswer((_) async => []);

      final notifier = container.read(newsProvider.notifier);
      await Future.wait([notifier.refresh(), notifier.refresh()]);

      expect(syncCalls, 1);
    });

    test(
      'refresh resets in-flight flag so sequential calls sync again',
      () async {
        var syncCalls = 0;
        when(() => mockNewsRepo.syncNews()).thenAnswer((_) async {
          syncCalls++;
          return const NewsSyncResult(itemsAdded: 0, errors: []);
        });
        when(
          () => mockNewsRepo.getRecentNews(days: any(named: 'days')),
        ).thenAnswer((_) async => []);

        final notifier = container.read(newsProvider.notifier);
        await notifier.refresh();
        await notifier.refresh();

        expect(syncCalls, 2);
      },
    );
  });
}
