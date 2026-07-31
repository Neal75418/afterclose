// MA 穿越事件 4 條規則(2026-07-31)。
//
// 站回月線/季線=修復期領先者偵測(V 轉後率先修復的股票,60D 報酬還是
// 負的進不了 B tab,落在 A/B 縫隙——這 2 條就是為那個縫隙生的);
// 跌破=持股風控。**刻意不加多頭 regime gate**:修復期偵測器的主場正是
// regime 未翻多時,跌破警示則在轉空時最需要——與回檔規則(接刀防護
// 要 gate)語境相反。neutral ±8 起步,校準實證判決升格或歸零。
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/constants/reason_type.dart';
import 'package:afterclose/core/constants/rule_enums.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/analysis_context.dart';
import 'package:afterclose/domain/models/technical_indicators.dart';
import 'package:afterclose/domain/services/rules/ma_cross_rules.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';

void main() {
  List<DailyPriceEntry> pricesEndingWith({
    required double prevClose,
    required double close,
    int count = 65,
    String symbol = 'TEST',
  }) {
    return [
      for (var i = 0; i < count; i++)
        DailyPriceEntry(
          symbol: symbol,
          date: DateTime(2026, 1, 1).add(Duration(days: i)),
          open: 100,
          high: 101,
          low: 99,
          close: i == count - 1 ? close : (i == count - 2 ? prevClose : 100),
          volume: 1000,
        ),
    ];
  }

  AnalysisContext ctx({double? ma20, double? ma60}) => AnalysisContext(
    trendState: TrendState.range,
    evaluationTime: DateTime(2026, 3, 10),
    indicators: TechnicalIndicators(ma20: ma20, ma60: ma60),
  );

  group('ReclaimMa20Rule(站回月線)', () {
    const rule = ReclaimMa20Rule();

    test('昨收線下、今收線上 → fire,evidence 帶關卡價', () {
      final r = rule.evaluate(
        ctx(ma20: 100),
        StockData(
          symbol: 'TEST',
          prices: pricesEndingWith(prevClose: 98, close: 102),
        ),
      );
      expect(r, isNotNull);
      expect(r!.type, ReasonType.reclaimMa20);
      expect(r.evidence!['ma20'], 100);
      expect(r.evidence!['close'], 102);
    });

    test('昨收恰等於 MA(壓線)、今收上 → fire(含平盤突破)', () {
      final r = rule.evaluate(
        ctx(ma20: 100),
        StockData(
          symbol: 'TEST',
          prices: pricesEndingWith(prevClose: 100, close: 101),
        ),
      );
      expect(r, isNotNull);
    });

    test('兩天都在線上(非穿越)→ null', () {
      final r = rule.evaluate(
        ctx(ma20: 100),
        StockData(
          symbol: 'TEST',
          prices: pricesEndingWith(prevClose: 103, close: 105),
        ),
      );
      expect(r, isNull);
    });

    test('兩天都在線下 → null', () {
      final r = rule.evaluate(
        ctx(ma20: 100),
        StockData(
          symbol: 'TEST',
          prices: pricesEndingWith(prevClose: 95, close: 97),
        ),
      );
      expect(r, isNull);
    });

    test('ETF → null(走勢平滑的穿越是雜訊,與回檔規則同判斷)', () {
      final r = rule.evaluate(
        ctx(ma20: 100),
        StockData(
          symbol: '0050',
          prices: pricesEndingWith(prevClose: 98, close: 102, symbol: '0050'),
        ),
      );
      expect(r, isNull);
    });

    test('ma20 缺(資料不足)→ null', () {
      final r = rule.evaluate(
        ctx(ma20: null),
        StockData(
          symbol: 'TEST',
          prices: pricesEndingWith(prevClose: 98, close: 102),
        ),
      );
      expect(r, isNull);
    });
  });

  group('ReclaimMa60Rule(站回季線)', () {
    const rule = ReclaimMa60Rule();

    test('穿越季線 → fire', () {
      final r = rule.evaluate(
        ctx(ma60: 100),
        StockData(
          symbol: 'TEST',
          prices: pricesEndingWith(prevClose: 99, close: 101),
        ),
      );
      expect(r, isNotNull);
      expect(r!.type, ReasonType.reclaimMa60);
    });

    test('未穿越 → null', () {
      final r = rule.evaluate(
        ctx(ma60: 100),
        StockData(
          symbol: 'TEST',
          prices: pricesEndingWith(prevClose: 101, close: 103),
        ),
      );
      expect(r, isNull);
    });
  });

  group('BreakMa20Rule / BreakMa60Rule(跌破,風控對稱版)', () {
    test('昨收線上、今收線下 → fire 跌破月線', () {
      const rule = BreakMa20Rule();
      final r = rule.evaluate(
        ctx(ma20: 100),
        StockData(
          symbol: 'TEST',
          prices: pricesEndingWith(prevClose: 102, close: 98),
        ),
      );
      expect(r, isNotNull);
      expect(r!.type, ReasonType.breakMa20);
    });

    test('跌破季線 → fire,分數為負(風控警示)', () {
      const rule = BreakMa60Rule();
      final r = rule.evaluate(
        ctx(ma60: 100),
        StockData(
          symbol: 'TEST',
          prices: pricesEndingWith(prevClose: 100.5, close: 99),
        ),
      );
      expect(r, isNotNull);
      expect(r!.type, ReasonType.breakMa60);
      expect(r.type.score, lessThan(0));
    });

    test('兩天都在線下(早已跌破,非事件)→ null', () {
      const rule = BreakMa60Rule();
      final r = rule.evaluate(
        ctx(ma60: 100),
        StockData(
          symbol: 'TEST',
          prices: pricesEndingWith(prevClose: 97, close: 95),
        ),
      );
      expect(r, isNull);
    });
  });
}
