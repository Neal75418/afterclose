import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:afterclose/core/constants/scoring_mode.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/repositories/news_repository.dart';
import 'package:afterclose/presentation/providers/mode_recommendation_provider.dart';
import 'package:afterclose/presentation/providers/news_heat_provider.dart';
import 'package:afterclose/presentation/providers/providers.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

class MockNewsRepository extends Mock implements NewsRepository {}

NewsItemEntry news(String id, String title, DateTime publishedAt) =>
    NewsItemEntry(
      id: id,
      source: '鉅亨網',
      title: title,
      url: 'https://example.com/$id',
      category: 'OTHER',
      publishedAt: publishedAt,
      fetchedAt: publishedAt,
    );

StockMasterEntry stock(String symbol, String name) => StockMasterEntry(
  symbol: symbol,
  name: name,
  market: 'TWSE',
  industry: '電子工業',
  isActive: true,
  updatedAt: DateTime(2026, 7, 15),
);

ModeRecommendation rec(String symbol) => ModeRecommendation(
  symbol: symbol,
  rank: 1,
  modeScoreShort: 20,
  modeScoreLong: 20,
  reasons: const [],
);

void main() {
  late MockAppDatabase mockDb;
  late MockNewsRepository mockNewsRepo;
  late ProviderContainer container;

  setUp(() {
    mockDb = MockAppDatabase();
    mockNewsRepo = MockNewsRepository();
    when(
      () => mockDb.getAllActiveStocks(),
    ).thenAnswer((_) async => [stock('2330', '台積電'), stock('2408', '南亞科')]);
    when(() => mockNewsRepo.getRecentNews(days: any(named: 'days'))).thenAnswer(
      (_) async => [
        news('a', '台積電法說會', DateTime.now()),
        news('b', '記憶體漲價 南亞科受惠', DateTime.now()),
        news('c', '南亞科獲利創高', DateTime.now()),
      ],
    );
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(mockDb),
        newsRepositoryProvider.overrideWithValue(mockNewsRepo),
        // 三模式：南亞科在回檔（weaknessObserve）
        for (final m in ScoringMode.userFacingModes)
          modeRecommendationsProvider(m).overrideWith(
            (ref) async =>
                m == ScoringMode.weaknessObserve ? [rec('2408')] : [],
          ),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('焦點股按提及數排序並帶名稱', () async {
    final r = await container.read(newsHeatProvider.future);
    expect(r.stocks.first.symbol, '2408'); // 2 篇 > 台積電 1 篇
    expect(r.stockNames['2408'], '南亞科');
  });

  test('題材熱度與成分股', () async {
    final r = await container.read(newsHeatProvider.future);
    final memory = r.themes.firstWhere((t) => t.theme == '記憶體');
    expect(memory.articles7d, 1);
    expect(memory.topStocks, contains('2408'));
  });

  test('三模式交叉：回檔股標注 weaknessObserve', () async {
    final r = await container.read(newsHeatProvider.future);
    expect(r.modeBySymbol['2408'], ScoringMode.weaknessObserve);
    expect(r.modeBySymbol.containsKey('2330'), isFalse);
  });
}
