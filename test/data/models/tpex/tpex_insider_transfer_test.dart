import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/models/tpex/tpex_insider_transfer.dart';

void main() {
  group('TpexInsiderTransfer.fromJson', () {
    // 真實 TPEx OpenAPI (mopsfin_t187ap12_O) 的 key 帶群組前綴。
    // 舊版誤讀無前綴的 '轉讓股數'/'目前持有股數'/'轉讓方式' → 全 fallback 成 0
    // （DB 實測 17/17 筆皆 0 的 bug）。以下 key 已對 live API 核實。
    Map<String, dynamic> realRow() => <String, dynamic>{
      'SecuritiesCompanyCode': '2061',
      'CompanyName': '風青',
      'Date': '1150618',
      '申請人身分': '董事',
      '姓名': '陳信宇',
      '預定轉讓方式及股數-轉讓方式': ' 一般交易(每日得轉讓股數限制)',
      '預定轉讓方式及股數-轉讓股數': ' 500000',
      '目前持有股數-自有持股': '3232155',
      '有效轉讓期間': '1150620~1150719',
    };

    test('讀對 TPEx OpenAPI 群組前綴 key（含逗號/空白容錯）', () {
      final t = TpexInsiderTransfer.fromJson(realRow());

      expect(t.symbol, '2061');
      expect(t.name, '陳信宇');
      expect(t.transferShares, 500000, reason: '轉讓股數須來自「預定轉讓方式及股數-轉讓股數」');
      expect(t.currentHolding, 3232155, reason: '目前持有須來自「目前持有股數-自有持股」');
      expect(t.transferMethod.trim(), '一般交易(每日得轉讓股數限制)');
    });

    test('防回歸：誤用舊版無前綴 key 會讀成 0（即原 bug 來源）', () {
      final t = TpexInsiderTransfer.fromJson(<String, dynamic>{
        'SecuritiesCompanyCode': '2061',
        'Date': '1150618',
        // 只有舊 key（模擬誤改回舊版）→ 新 key 不存在 → 0
        '轉讓股數': '500000',
        '目前持有股數': '3232155',
      });

      expect(
        t.transferShares,
        0,
        reason: '舊無前綴 key 不該被讀到（證明 17/17 全 0 的 bug 根因）',
      );
      expect(t.currentHolding, 0);
    });
  });
}
