// Stage 5b Commit 3 — recommendation splitter (dual topN pure function)
//
// 驗證 [splitScoredStocksIntoHorizons] 把一份 [ScoredStock] 清單切成
// 兩個 horizon 的 Top N 推薦清單，並正確套用流動性門檻。
//
// 此 helper 抽出的動機：`update_service._generateRecommendations` 過去
// 只做單一 horizon 的 sort + take + write，現在需要 dual horizon 版本，
// 把純函式部分獨立測試才能避免把 update_service 拉進測試矩陣。
import 'package:afterclose/domain/services/scoring_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('splitScoredStocksIntoHorizons', () {
    test(
      'produces separate top N per horizon, honoring scoreShort/scoreLong',
      () {
        // A 短線很強、長線弱；B 長線很強、短線弱；C 兩邊都普通
        final stocks = [
          const ScoredStock(
            symbol: 'A',
            scoreShort: 80,
            scoreLong: 20,
            turnover: 1e9,
          ),
          const ScoredStock(
            symbol: 'B',
            scoreShort: 20,
            scoreLong: 80,
            turnover: 1e9,
          ),
          const ScoredStock(
            symbol: 'C',
            scoreShort: 50,
            scoreLong: 50,
            turnover: 1e9,
          ),
        ];

        final (:shortRecs, :longRecs) = splitScoredStocksIntoHorizons(
          stocks,
          dailyTopN: 2,
          minTurnover: 0,
        );

        expect(shortRecs.length, 2);
        expect(shortRecs[0].symbol, 'A'); // 短線最高
        expect(shortRecs[0].score, 80);
        expect(shortRecs[1].symbol, 'C');

        expect(longRecs.length, 2);
        expect(longRecs[0].symbol, 'B'); // 長線最高
        expect(longRecs[0].score, 80);
        expect(longRecs[1].symbol, 'C');
      },
    );

    test('applies minTurnover filter before sorting', () {
      final stocks = [
        const ScoredStock(
          symbol: 'HIGH_SCORE_LOW_LIQ',
          scoreShort: 80,
          scoreLong: 80,
          turnover: 1e6, // 不到門檻
        ),
        const ScoredStock(
          symbol: 'MID_SCORE_OK_LIQ',
          scoreShort: 50,
          scoreLong: 50,
          turnover: 1e9,
        ),
      ];

      final (:shortRecs, :longRecs) = splitScoredStocksIntoHorizons(
        stocks,
        dailyTopN: 5,
        minTurnover: 1e8,
      );

      // HIGH_SCORE_LOW_LIQ 被 turnover 門檻過濾掉
      expect(shortRecs.length, 1);
      expect(shortRecs.first.symbol, 'MID_SCORE_OK_LIQ');
      expect(longRecs.length, 1);
      expect(longRecs.first.symbol, 'MID_SCORE_OK_LIQ');
    });

    test('respects dailyTopN cap per horizon independently', () {
      final stocks = List.generate(
        10,
        (i) => ScoredStock(
          symbol: 'S$i',
          scoreShort: 80 - i, // S0 最高
          scoreLong: 20 + i, // S9 最高
          turnover: 1e9,
        ),
      );

      final (:shortRecs, :longRecs) = splitScoredStocksIntoHorizons(
        stocks,
        dailyTopN: 3,
        minTurnover: 0,
      );

      expect(shortRecs.length, 3);
      expect(shortRecs.map((r) => r.symbol).toList(), ['S0', 'S1', 'S2']);

      expect(longRecs.length, 3);
      expect(longRecs.map((r) => r.symbol).toList(), ['S9', 'S8', 'S7']);
    });

    test('empty input produces empty output for both horizons', () {
      final (:shortRecs, :longRecs) = splitScoredStocksIntoHorizons(
        const [],
        dailyTopN: 20,
        minTurnover: 0,
      );

      expect(shortRecs, isEmpty);
      expect(longRecs, isEmpty);
    });

    test('stable sort ties broken by turnover then symbol', () {
      // 三檔同分（scoreShort=60），用 turnover 然後 symbol 當 tiebreak
      final stocks = [
        const ScoredStock(
          symbol: 'Z',
          scoreShort: 60,
          scoreLong: 0,
          turnover: 3e9,
        ),
        const ScoredStock(
          symbol: 'A',
          scoreShort: 60,
          scoreLong: 0,
          turnover: 3e9,
        ),
        const ScoredStock(
          symbol: 'M',
          scoreShort: 60,
          scoreLong: 0,
          turnover: 5e9, // 流動性最高
        ),
      ];

      final (:shortRecs, :longRecs) = splitScoredStocksIntoHorizons(
        stocks,
        dailyTopN: 3,
        minTurnover: 0,
      );

      // 期望：M（流動性最大）> A（字典序） > Z
      expect(shortRecs.map((r) => r.symbol).toList(), ['M', 'A', 'Z']);
      // longRecs 全部 0 分，tiebreak 相同順序
      expect(longRecs.map((r) => r.symbol).toList(), ['M', 'A', 'Z']);
    });

    test('score field uses correct horizon value', () {
      final stocks = [
        const ScoredStock(
          symbol: 'X',
          scoreShort: 77,
          scoreLong: 33,
          turnover: 1e9,
        ),
      ];

      final (:shortRecs, :longRecs) = splitScoredStocksIntoHorizons(
        stocks,
        dailyTopN: 5,
        minTurnover: 0,
      );

      // shortRecs 的 score 要是 scoreShort，不是 scoreLong
      expect(shortRecs.first.score, 77);
      expect(longRecs.first.score, 33);
    });
  });
}
