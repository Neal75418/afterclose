import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/models/twse/twse_declared_dividend.dart';

void main() {
  group('TwseDeclaredDividend.fromJson', () {
    // 真實 TWSE ap45_L 的現金/股票股利為「多組成欄」。舊 code 讀不存在的
    // '現金股利(元/股)'/'股票股利(元/股)' → 全 fallback 成 0（bug）。key 已對 live API 核實。
    Map<String, dynamic> realRow() => <String, dynamic>{
      '公司代號': '1101',
      '公司名稱': '台泥',
      '股利年度': '114',
      '股東配發-盈餘分配之現金股利(元/股)': '0.8',
      '股東配發-法定盈餘公積發放之現金(元/股)': '0.1',
      '股東配發-資本公積發放之現金(元/股)': '0.0',
      '股東配發-盈餘轉增資配股(元/股)': '0.2',
      '股東配發-法定盈餘公積轉增資配股(元/股)': '0.0',
      '股東配發-資本公積轉增資配股(元/股)': '0.0',
    };

    test('現金/股票股利為多組成欄加總', () {
      final d = TwseDeclaredDividend.fromJson(realRow());

      expect(d.symbol, '1101');
      expect(d.dividendYear, 2025); // ROC 114 + 1911
      expect(
        d.cashDividend,
        closeTo(0.9, 1e-9),
        reason: '現金 = 盈餘 0.8 + 法定公積 0.1 + 資本公積 0.0',
      );
      expect(
        d.stockDividend,
        closeTo(0.2, 1e-9),
        reason: '股票 = 盈餘轉增資 0.2 + 法定 + 資本',
      );
      expect(d.exDividendDate, isNull, reason: 'ap45_L 不提供除權息交易日');
      expect(d.exRightsDate, isNull);
    });

    test('防回歸：舊版不存在的 key 會讀成 0（即原 bug 來源）', () {
      final d = TwseDeclaredDividend.fromJson(<String, dynamic>{
        '公司代號': '1101',
        '股利年度': '114',
        // 舊 key（API 不存在）
        '現金股利(元/股)': '0.9',
        '股票股利(元/股)': '0.2',
      });

      expect(d.cashDividend, 0.0, reason: '舊無前綴 key 不該被讀到');
      expect(d.stockDividend, 0.0);
    });
  });
}
