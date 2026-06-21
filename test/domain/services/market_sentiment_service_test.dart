import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/domain/models/market_overview_models.dart';
import 'package:afterclose/domain/services/market_sentiment_service.dart';

void main() {
  group('MarketSentimentService.calculate', () {
    // 固定輸入：5 項子指標皆可計算，且各自分數不同以便辨識權重變動。
    //
    // - advanceRatio: ratio 0.5 → _linearMap(0.5, 0.2, 0.8) = 50.0
    // - institutional: 常數序列 std=0、last>0 → 75.0
    // - volumeMomentum: today/avg = 1.0 → _linearMap(1.0, 0.5, 2.0) = 33.333…
    // - marginChange: 無變動 changePct=0 → _linearMap(0, -0.05, 0.05) = 50.0
    // - industryBreadth: 2 產業 1 上漲 → 50.0
    MarketSentiment computeFixedInput() {
      return MarketSentimentService.calculate(
        advanceDecline: const AdvanceDecline(advance: 500, decline: 500),
        institutionalNetHistory: const [100, 100, 100, 100, 100],
        turnoverHistory: const [100, 100, 100, 100, 100, 100],
        marginBalanceHistory: const [100, 100, 100, 100, 100],
        industries: const [
          IndustrySummary(
            industry: 'A',
            stockCount: 1,
            avgChangePct: 1.0,
            advance: 1,
            decline: 0,
          ),
          IndustrySummary(
            industry: 'B',
            stockCount: 1,
            avgChangePct: -1.0,
            advance: 0,
            decline: 1,
          ),
        ],
      );
    }

    test('composite 恰好包含 5 項子指標（漲停比已移除）', () {
      final result = computeFixedInput();

      expect(result.subScores.length, 5);
      expect(
        result.subScores.keys,
        containsAll(<String>[
          'advanceRatio',
          'institutional',
          'volumeMomentum',
          'marginChange',
          'industryBreadth',
        ]),
      );
      // 漲停比已自情緒綜合移除
      expect(result.subScores.containsKey('limitRatio'), isFalse);
    });

    test('權重總和為 1.0（5 項全到齊時 totalWeight 正規化不縮放）', () {
      final result = computeFixedInput();

      // 5 項全到齊 ⇒ totalWeight=1.0 ⇒ 綜合分數 == 加權平均（無正規化放大）。
      // 以已知子分數手算加權平均驗證權重總和為 1.0：
      // 0.35*50 + 0.25*75 + 0.15*(100/3) + 0.15*50 + 0.10*50
      const expected =
          0.35 * 50.0 +
          0.25 * 75.0 +
          0.15 * (100.0 / 3.0) +
          0.15 * 50.0 +
          0.10 * 50.0;

      expect(result.score, closeTo(expected, 1e-9));
    });

    test('固定輸入回歸：綜合分數 = 53.75', () {
      final result = computeFixedInput();

      // 權重重新分配後（advanceRatio 0.25→0.35、移除 limitRatio 0.10）的定錨值
      expect(result.score, closeTo(53.75, 1e-9));
      expect(result.level, SentimentLevel.neutral);
    });

    test('子指標缺漏時有效權重自動正規化', () {
      // 僅提供漲跌比與法人，缺量能/融資/產業
      final result = MarketSentimentService.calculate(
        advanceDecline: const AdvanceDecline(advance: 800, decline: 200),
        institutionalNetHistory: const [100, 100, 100, 100, 100],
        turnoverHistory: const [],
        marginBalanceHistory: const [],
      );

      // advanceRatio ratio=0.8 → 100.0；institutional → 75.0
      // 有效權重 = 0.35 + 0.25 = 0.60
      // (0.35*100 + 0.25*75) / 0.60 = (35 + 18.75) / 0.60 = 89.5833…
      expect(result.subScores.length, 2);
      expect(result.score, closeTo((0.35 * 100 + 0.25 * 75) / 0.60, 1e-9));
    });
  });

  group('MarketSentimentService.calculateHistoricalScores', () {
    // 以基準日 + 偏移天數建構帶日期序列（oldest→newest）。
    final base = DateTime(2026, 1, 1);
    DateTime day(int offset) => base.add(Duration(days: offset));

    /// 將 (dayOffset, value) 配對轉為帶日期序列。
    List<DatedValue> series(List<({int day, double value})> points) => [
      for (final p in points) (date: day(p.day), value: p.value),
    ];

    // 八個共同交易日（day 0..7）的對齊基準輸入。
    // advanceRatio 用遞增比值讓每日分數不同，便於辨識錯位。
    final advanceRatioCommon = series(const [
      (day: 0, value: 0.30),
      (day: 1, value: 0.40),
      (day: 2, value: 0.50),
      (day: 3, value: 0.55),
      (day: 4, value: 0.60),
      (day: 5, value: 0.65),
      (day: 6, value: 0.70),
      (day: 7, value: 0.75),
    ]);
    final turnoverCommon = series(const [
      (day: 0, value: 1000),
      (day: 1, value: 1100),
      (day: 2, value: 1200),
      (day: 3, value: 1300),
      (day: 4, value: 1250),
      (day: 5, value: 1400),
      (day: 6, value: 1500),
      (day: 7, value: 1600),
    ]);
    final institutionalCommon = series(const [
      (day: 0, value: 50),
      (day: 1, value: 80),
      (day: 2, value: -20),
      (day: 3, value: 60),
      (day: 4, value: 90),
      (day: 5, value: 30),
      (day: 6, value: 70),
      (day: 7, value: 100),
    ]);
    final marginCommon = series(const [
      (day: 0, value: 10000),
      (day: 1, value: 10100),
      (day: 2, value: 10050),
      (day: 3, value: 10200),
      (day: 4, value: 10300),
      (day: 5, value: 10250),
      (day: 6, value: 10400),
      (day: 7, value: 10500),
    ]);

    test('輸入皆對齊時（同一組日期）正常產生分數序列', () {
      final scores = MarketSentimentService.calculateHistoricalScores(
        advanceRatioHistory: advanceRatioCommon,
        institutionalNetHistory: institutionalCommon,
        turnoverHistory: turnoverCommon,
        marginBalanceHistory: marginCommon,
      );

      // 8 共同日，從第 5 日（index 4）起逐日計分 ⇒ 4 筆。
      expect(scores.length, advanceRatioCommon.length - 4);
      expect(scores, everyElement(inInclusiveRange(0.0, 100.0)));
    });

    test('日期錯位：法人/融資多出 2 個較舊日，結果只用共同日（排除錯位日）', () {
      // institutional 與 margin 在前面多 2 個 advanceRatio/turnover 沒有的舊日。
      // 若仍按 array index 拼接，這 2 個舊日會把不同交易日的資料混進同一筆分數。
      final institutionalExtra = series(const [
        (day: -2, value: 999), // advanceRatio/turnover 無此日
        (day: -1, value: 888), // advanceRatio/turnover 無此日
        (day: 0, value: 50),
        (day: 1, value: 80),
        (day: 2, value: -20),
        (day: 3, value: 60),
        (day: 4, value: 90),
        (day: 5, value: 30),
        (day: 6, value: 70),
        (day: 7, value: 100),
      ]);
      final marginExtra = series(const [
        (day: -2, value: 1), // advanceRatio/turnover 無此日
        (day: -1, value: 2), // advanceRatio/turnover 無此日
        (day: 0, value: 10000),
        (day: 1, value: 10100),
        (day: 2, value: 10050),
        (day: 3, value: 10200),
        (day: 4, value: 10300),
        (day: 5, value: 10250),
        (day: 6, value: 10400),
        (day: 7, value: 10500),
      ]);

      final misaligned = MarketSentimentService.calculateHistoricalScores(
        advanceRatioHistory: advanceRatioCommon,
        institutionalNetHistory: institutionalExtra,
        turnoverHistory: turnoverCommon,
        marginBalanceHistory: marginExtra,
      );

      // 對照組：把多出的舊日剔除，只留共同日的「正確對齊」輸入。
      final alignedReference = MarketSentimentService.calculateHistoricalScores(
        advanceRatioHistory: advanceRatioCommon,
        institutionalNetHistory: institutionalCommon,
        turnoverHistory: turnoverCommon,
        marginBalanceHistory: marginCommon,
      );

      // inner-join 後兩者必須完全相同：錯位的 day -2 / day -1 被排除，
      // 共同日的分數逐筆相等（證明未把不同日資料拼在一起）。
      expect(misaligned, hasLength(alignedReference.length));
      for (var i = 0; i < misaligned.length; i++) {
        expect(misaligned[i], closeTo(alignedReference[i], 1e-9));
      }
    });

    test('傳入順序被打亂時仍依日期重排（不依賴輸入順序）', () {
      // 將其中一個序列順序反轉（newest→oldest），結果應與正常順序一致。
      final shuffledTurnover = turnoverCommon.reversed.toList();

      final fromShuffled = MarketSentimentService.calculateHistoricalScores(
        advanceRatioHistory: advanceRatioCommon,
        institutionalNetHistory: institutionalCommon,
        turnoverHistory: shuffledTurnover,
        marginBalanceHistory: marginCommon,
      );
      final fromOrdered = MarketSentimentService.calculateHistoricalScores(
        advanceRatioHistory: advanceRatioCommon,
        institutionalNetHistory: institutionalCommon,
        turnoverHistory: turnoverCommon,
        marginBalanceHistory: marginCommon,
      );

      expect(fromShuffled, hasLength(fromOrdered.length));
      for (var i = 0; i < fromShuffled.length; i++) {
        expect(fromShuffled[i], closeTo(fromOrdered[i], 1e-9));
      }
    });

    test('共同日少於 5 天時回傳空列表（Z-score 樣本不足）', () {
      // 僅 4 個共同日（day 0..3），其餘日期各序列不重疊。
      final adShort = series(const [
        (day: 0, value: 0.4),
        (day: 1, value: 0.5),
        (day: 2, value: 0.6),
        (day: 3, value: 0.55),
      ]);
      final instShort = series(const [
        (day: 0, value: 10),
        (day: 1, value: 20),
        (day: 2, value: 30),
        (day: 3, value: 25),
      ]);
      final turnShort = series(const [
        (day: 0, value: 100),
        (day: 1, value: 110),
        (day: 2, value: 120),
        (day: 3, value: 115),
      ]);
      final marginShort = series(const [
        (day: 0, value: 1000),
        (day: 1, value: 1010),
        (day: 2, value: 1005),
        (day: 3, value: 1020),
      ]);

      final scores = MarketSentimentService.calculateHistoricalScores(
        advanceRatioHistory: adShort,
        institutionalNetHistory: instShort,
        turnoverHistory: turnShort,
        marginBalanceHistory: marginShort,
      );

      expect(scores, isEmpty);
    });

    test('完全無共同日時回傳空列表', () {
      final scores = MarketSentimentService.calculateHistoricalScores(
        advanceRatioHistory: advanceRatioCommon, // day 0..7
        institutionalNetHistory: series(const [
          (day: 100, value: 1),
          (day: 101, value: 2),
          (day: 102, value: 3),
          (day: 103, value: 4),
          (day: 104, value: 5),
        ]),
        turnoverHistory: turnoverCommon,
        marginBalanceHistory: marginCommon,
      );

      expect(scores, isEmpty);
    });
  });
}
