// test/domain/services/news/heat_calculator_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/domain/services/news/heat_calculator.dart';

ArticleTags article(
  String id,
  DateTime publishedAt, {
  Set<String> symbols = const {},
  Set<String> themes = const {},
}) => ArticleTags(
  newsId: id,
  publishedAt: publishedAt,
  symbols: symbols,
  themes: themes,
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
