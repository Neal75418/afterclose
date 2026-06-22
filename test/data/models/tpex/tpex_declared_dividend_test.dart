import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/models/tpex/tpex_declared_dividend.dart';

void main() {
  group('TpexDeclaredDividend.fromJson', () {
    // 真實 TPEx ap39_O：現金/股票股利為多組成欄，且法定盈餘公積、資本公積合併成一欄。
    // 舊 code 讀不存在的 '現金股利(元/股)'/'股票股利(元/股)' → 全 0（bug）。key 已對 live API 核實。
    Map<String, dynamic> realRow() => <String, dynamic>{
      '公司代號': '1240',
      '公司名稱': '茂生農經',
      '股利年度': '114',
      '股東配發內容-盈餘分配之現金股利(元/股)': '1.5',
      '股東配發內容-法定盈餘公積、資本公積發放之現金(元/股)': '0.3',
      '股東配發內容-盈餘轉增資配股(元/股)': '0.1',
      '股東配發內容-法定盈餘公積、資本公積轉增資配股(元/股)': '0.0',
    };

    test('現金/股票股利為多組成欄加總（TPEx 公積合併欄）', () {
      final d = TpexDeclaredDividend.fromJson(realRow());

      expect(d.symbol, '1240');
      expect(d.dividendYear, 2025);
      expect(
        d.cashDividend,
        closeTo(1.8, 1e-9),
        reason: '現金 = 盈餘 1.5 + 公積 0.3',
      );
      expect(
        d.stockDividend,
        closeTo(0.1, 1e-9),
        reason: '股票 = 盈餘轉增資 0.1 + 公積轉增資 0.0',
      );
      expect(d.exDividendDate, isNull, reason: 'ap39_O 不提供除權息交易日');
      expect(d.exRightsDate, isNull);
    });

    test('防回歸：舊版不存在的 key 會讀成 0', () {
      final d = TpexDeclaredDividend.fromJson(<String, dynamic>{
        '公司代號': '1240',
        '股利年度': '114',
        '現金股利(元/股)': '1.8',
        '股票股利(元/股)': '0.1',
      });

      expect(d.cashDividend, 0.0);
      expect(d.stockDividend, 0.0);
    });
  });
}
