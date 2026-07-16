// test/domain/services/news/heat_calculator_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/domain/services/news/heat_calculator.dart';

ArticleTags article(
  String id,
  DateTime publishedAt, {
  Set<String> symbols = const {},
  Set<String> themes = const {},
  String source = '鉅亨網',
  bool hasRiskKeyword = false,
}) => ArticleTags(
  newsId: id,
  publishedAt: publishedAt,
  symbols: symbols,
  themes: themes,
  source: source,
  hasRiskKeyword: hasRiskKeyword,
);

void main() {
  final now = DateTime(2026, 7, 15, 20, 0);
  final calc = HeatCalculator();

  test('近 7 天與前 21 天窗口切分（含當天）', () {
    final r = calc.compute([
      article('a', DateTime(2026, 7, 15, 9), symbols: {'2330'}), // day 0 → 近窗
      article('b', DateTime(2026, 7, 9, 9), symbols: {'2330'}), // day 6 → 近窗
      article('c', DateTime(2026, 7, 8, 9), symbols: {'2330'}), // day 7 → 基準窗
      article('d', DateTime(2026, 6, 18, 9), symbols: {'2330'}), // day 27 → 基準窗
      article('e', DateTime(2026, 6, 16, 9), symbols: {'2330'}), // day 29 → 忽略
    ], now: now);
    final heat = r.stocks.single;
    expect(heat.mentions7d, 2);
    expect(heat.mentionsPrev21d, 2);
  });

  test('爆量：近 7 天 >= 前 21 天總數且 >= 3 篇', () {
    List<ArticleTags> mentions(int recent, int baseline) => [
      for (var i = 0; i < recent; i++)
        article('r$i', DateTime(2026, 7, 14, 9), symbols: {'3231'}),
      for (var i = 0; i < baseline; i++)
        article('b$i', DateTime(2026, 7, 1, 9), symbols: {'3231'}),
    ];
    expect(
      calc.compute(mentions(3, 3), now: now).stocks.single.isSurging,
      isTrue,
    );
    expect(
      calc.compute(mentions(2, 0), now: now).stocks.single.isSurging,
      isFalse, // 低基數：未達 3 篇
    );
    expect(
      calc.compute(mentions(3, 4), now: now).stocks.single.isSurging,
      isFalse, // 3 < 4
    );
  });

  test('焦點股按 mentions7d 降冪排序', () {
    final r = calc.compute([
      article('a', DateTime(2026, 7, 14, 9), symbols: {'2330', '2317'}),
      article('b', DateTime(2026, 7, 14, 10), symbols: {'2330'}),
    ], now: now);
    expect(r.stocks.map((s) => s.symbol).toList(), ['2330', '2317']);
  });

  test('題材熱度與成分股（近 7 天共現次數 Top N）', () {
    final r = calc.compute([
      article(
        'a',
        DateTime(2026, 7, 14, 9),
        themes: {'記憶體'},
        symbols: {'2408'},
      ),
      article(
        'b',
        DateTime(2026, 7, 14, 10),
        themes: {'記憶體'},
        symbols: {'2408', '2344'},
      ),
      article('c', DateTime(2026, 7, 1, 9), themes: {'記憶體'}),
    ], now: now);
    final theme = r.themes.single;
    expect(theme.articles7d, 2);
    expect(theme.articlesPrev21d, 1);
    expect(theme.topStocks.first, '2408'); // 共現 2 次 > 2344 的 1 次
  });

  test('空輸入回空結果', () {
    final r = calc.compute([], now: now);
    expect(r.stocks, isEmpty);
    expect(r.themes, isEmpty);
  });

  test('distinctSources7d：近窗來源去重計數', () {
    final r = calc.compute([
      article('a', DateTime(2026, 7, 14, 9), symbols: {'2330'}, source: '鉅亨網'),
      article(
        'b',
        DateTime(2026, 7, 14, 10),
        symbols: {'2330'},
        source: '經濟日報',
      ),
      article(
        'c',
        DateTime(2026, 7, 13, 9),
        symbols: {'2330'},
        source: '鉅亨網',
      ), // 重複來源
      article(
        'd',
        DateTime(2026, 7, 1, 9),
        symbols: {'2330'},
        source: '工商時報',
      ), // 基準窗不計
    ], now: now);
    expect(r.stocks.single.distinctSources7d, 2);
  });

  test('風險旗標：命中風險關鍵字的文章使其提及個股掛旗；非風險文章不掛', () {
    final r = calc.compute([
      article(
        'a',
        DateTime(2026, 7, 14, 9),
        symbols: {'2330'},
        hasRiskKeyword: true,
      ),
      article('b', DateTime(2026, 7, 14, 10), symbols: {'2317'}),
    ], now: now);
    final tsmc = r.stocks.firstWhere((s) => s.symbol == '2330');
    final honhai = r.stocks.firstWhere((s) => s.symbol == '2317');
    expect(tsmc.hasRiskNews, isTrue);
    expect(honhai.hasRiskNews, isFalse);
  });

  test('isNewEntrant：3/0 為新進榜；3/1 與 2/0 皆非', () {
    List<ArticleTags> mentions(int recent, int baseline) => [
      for (var i = 0; i < recent; i++)
        article('r$i', DateTime(2026, 7, 14, 9), symbols: {'3231'}),
      for (var i = 0; i < baseline; i++)
        article('b$i', DateTime(2026, 7, 1, 9), symbols: {'3231'}),
    ];
    expect(
      calc.compute(mentions(3, 0), now: now).stocks.single.isNewEntrant,
      isTrue,
    );
    expect(
      calc.compute(mentions(3, 1), now: now).stocks.single.isNewEntrant,
      isFalse,
    );
    expect(
      calc.compute(mentions(2, 0), now: now).stocks.single.isNewEntrant,
      isFalse,
    );
  });

  test('surgeRatio：週均基期＋下限 1.0 damp 低基數', () {
    List<ArticleTags> mentions(int recent, int baseline) => [
      for (var i = 0; i < recent; i++)
        article('r$i', DateTime(2026, 7, 14, 9), symbols: {'3231'}),
      for (var i = 0; i < baseline; i++)
        article('b$i', DateTime(2026, 7, 1, 9), symbols: {'3231'}),
    ];
    // 6 近窗 / 3 基準窗 → 週均 1.0（下限生效）→ 6/1.0 = 6.0
    expect(
      calc.compute(mentions(6, 3), now: now).stocks.single.surgeRatio,
      6.0,
    );
    // 6 近窗 / 9 基準窗 → 週均 3.0 → 6/3.0 = 2.0
    expect(
      calc.compute(mentions(6, 9), now: now).stocks.single.surgeRatio,
      2.0,
    );
  });

  test('baselineCoverageDays：計基準窗內有新聞的相異日曆日（與匹配與否無關）', () {
    // 14 個相異日（diff 7..20，皆落在基準窗 7-27），每天 1 篇無標籤文章
    // （DateTime 建構子自動正規化跨月：7/8 往前推到 6/25）
    final articles = [
      for (var i = 7; i <= 20; i++)
        article('d$i', DateTime(2026, 7, 15 - i, 9)),
    ];
    final r = calc.compute(articles, now: now);
    expect(r.baselineCoverageDays, 14);
    expect(r.surgeReliable, isTrue); // 14 >= surgeBaselineMinCoverageDays(14)
  });

  test('baselineCoverageDays 同日多篇不重複計數；未達門檻 surgeReliable=false', () {
    final articles = [
      for (var i = 7; i <= 19; i++) // 13 個相異日
        article('d$i', DateTime(2026, 7, 15 - i, 9)),
      // 同一天（diff=7）再加一篇，不應讓覆蓋天數變成 14
      article('dup', DateTime(2026, 7, 8, 15)),
    ];
    final r = calc.compute(articles, now: now);
    expect(r.baselineCoverageDays, 13);
    expect(r.surgeReliable, isFalse); // 13 < surgeBaselineMinCoverageDays(14)
  });

  test('now 傳 UTC 與傳 local 結果一致（對稱正規化）', () {
    // 早上 7 點（UTC+8）→ UTC 是前一天 23:00，日曆日不同；
    // 7/9 的文章距 7/16 恰為 7 天（基準窗），若 today 誤用 UTC 日
    // （7/15）會變 6 天（近窗）——此組合能判別未修復的程式。
    // 注意：在 UTC 時區的機器上 toLocal() 是 no-op，此測試退化為恆真；
    // 它只在非 UTC 開發機（如 UTC+8）上釘住回歸。
    final localNow = DateTime(2026, 7, 16, 7, 0);
    final utcNow = localNow.toUtc();
    final input = [
      article('a', DateTime(2026, 7, 15, 9), symbols: {'2330'}),
      article('b', DateTime(2026, 7, 9, 9), symbols: {'2330'}),
    ];
    final fromLocal = calc.compute(input, now: localNow).stocks.single;
    final fromUtc = calc.compute(input, now: utcNow).stocks.single;
    expect(fromUtc.mentions7d, fromLocal.mentions7d);
    expect(fromUtc.mentionsPrev21d, fromLocal.mentionsPrev21d);
  });
}
