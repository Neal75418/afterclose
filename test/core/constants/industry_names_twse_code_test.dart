import 'package:flutter_test/flutter_test.dart';

import 'package:daredevil/core/constants/industry_names.dart';
import 'package:daredevil/data/remote/twse_client.dart';

/// TWSE 官方產業別代碼對照(2026-08-01)。
///
/// 代碼值以 t187ap03_L 實際回傳驗證:24=半導體(2330/2454/2379)、
/// 26=光電(3008/2409)、28=電子零組件(104 檔)——與真實世界檔數吻合。
void main() {
  group('IndustryNames.nameForTwseCode', () {
    test('細分碼→canonical 名稱', () {
      expect(IndustryNames.nameForTwseCode('24'), '半導體業');
      expect(IndustryNames.nameForTwseCode('26'), '光電業');
      expect(IndustryNames.nameForTwseCode('01'), '水泥工業');
    });

    test('名稱經 normalize 收斂(31 其他電子業→其他電子類)', () {
      expect(IndustryNames.nameForTwseCode('31'), '其他電子類');
      expect(IndustryNames.nameForTwseCode('37'), '運動休閒類');
    });

    test('未知代碼回 null(呼叫端 fallback FinMind)', () {
      expect(IndustryNames.nameForTwseCode('99'), isNull);
      expect(IndustryNames.nameForTwseCode(''), isNull);
    });
  });

  group('TwseClient.parseIndustryCodes', () {
    test('抽 (公司代號, 產業別),缺欄跳過', () {
      final map = TwseClient.parseIndustryCodes([
        {'公司代號': '2330', '產業別': '24', '公司簡稱': '台積電'},
        {'公司代號': '1101', '產業別': '01'},
        {'公司代號': '', '產業別': '05'},
        {'公司代號': '9999'},
        'not-a-map',
      ]);
      expect(map, {'2330': '24', '1101': '01'});
    });
  });
}
