import 'package:flutter_test/flutter_test.dart';

import 'package:daredevil/data/models/twse/exright_preannouncement.dart';

/// 除權息預告模型(2026-08-01)。欄位值取自兩端點當日實際回應
/// (2886 兆豐金 1150813 除息 1.75 為停券預告 8/7-8/12 的因果對照組)。
void main() {
  group('tryFromTwseJson', () {
    test('息:2886 兆豐金 2026-08-13 現金 1.75', () {
      final p = ExRightPreannouncement.tryFromTwseJson({
        'Date': '1150813',
        'Code': '2886',
        'Name': '兆豐金',
        'Exdividend': '息',
        'CashDividend': '1.750000',
        'StockDividendRatio': '',
      });
      expect(p, isNotNull);
      expect(p!.symbol, '2886');
      expect(p.date, DateTime(2026, 8, 13));
      expect(p.hasDividend, isTrue);
      expect(p.hasRights, isFalse);
      expect(p.cashDividend, 1.75);
      expect(p.stockDividendRatio, isNull);
    });

    test('權息:兩旗標皆立', () {
      final p = ExRightPreannouncement.tryFromTwseJson({
        'Date': '1150901',
        'Code': '1234',
        'Exdividend': '權息',
        'CashDividend': '2.000000',
        'StockDividendRatio': '10.00000000',
      });
      expect(p!.hasDividend, isTrue);
      expect(p.hasRights, isTrue);
      expect(p.stockDividendRatio, 10.0);
    });

    test('日期無效/缺代碼回 null', () {
      expect(
        ExRightPreannouncement.tryFromTwseJson({
          'Date': '11508',
          'Code': '2886',
          'Exdividend': '息',
        }),
        isNull,
      );
      expect(
        ExRightPreannouncement.tryFromTwseJson({
          'Date': '1150813',
          'Code': '',
          'Exdividend': '息',
        }),
        isNull,
      );
    });
  });

  group('tryFromTpexJson', () {
    test('除息:漢科 2026-07-22 現金 6.00', () {
      final p = ExRightPreannouncement.tryFromTpexJson({
        'ExRrightsExDividendDate': '1150722',
        'SecuritiesCompanyCode': '3402',
        'CompanyName': '漢科',
        'ExRrightsExDividend': '除息',
        'StockDividendRatio': '0.00000000',
        'CashDividend': '6.00000000',
      });
      expect(p, isNotNull);
      expect(p!.symbol, '3402');
      expect(p.date, DateTime(2026, 7, 22));
      expect(p.hasDividend, isTrue);
      expect(p.hasRights, isFalse);
      expect(p.cashDividend, 6.0);
      expect(p.stockDividendRatio, isNull, reason: '0 配股率視為無');
    });

    test('除權息:兩旗標皆立', () {
      final p = ExRightPreannouncement.tryFromTpexJson({
        'ExRrightsExDividendDate': '1150810',
        'SecuritiesCompanyCode': '5678',
        'ExRrightsExDividend': '除權息',
        'CashDividend': '1.00000000',
        'StockDividendRatio': '5.00000000',
      });
      expect(p!.hasDividend, isTrue);
      expect(p.hasRights, isTrue);
    });
  });
}
