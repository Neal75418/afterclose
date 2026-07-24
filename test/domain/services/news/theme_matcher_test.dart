import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/domain/services/news/theme_matcher.dart';

void main() {
  final matcher = ThemeMatcher();

  test('中文題材詞命中', () {
    expect(matcher.match('記憶體漲價 南亞科受惠'), contains('記憶體'));
  });

  test('同義詞命中同一題材', () {
    expect(matcher.match('HBM 需求爆發'), contains('記憶體'));
    expect(matcher.match('CoWoS 產能滿載'), contains('先進封裝'));
  });

  test('英文詞不分大小寫', () {
    expect(matcher.match('ai 伺服器需求強勁'), contains('AI'));
    expect(matcher.match('AI晶片大單'), contains('AI'));
  });

  test('一篇可命中多題材', () {
    final r = matcher.match('AI 帶動記憶體與散熱需求');
    expect(r, containsAll(['AI', '記憶體', '散熱']));
  });

  group('ASCII 短詞不被英文字母/數字夾（防子字串誤配）', () {
    test('Taiwan 不觸發 AI、7-Eleven/revenue 不觸發電動車', () {
      expect(matcher.match('The Taiwan Fund 第三季報酬領先'), isEmpty);
      expect(matcher.match('魏哲家：不是去 7-Eleven 買牛奶'), isEmpty);
      expect(matcher.match('本季 revenue 創高'), isNot(contains('電動車')));
      // 「新藥」合法命中生技；此處只驗 CAMCEVI 的 ev 不誤觸發電動車
      expect(matcher.match('CAMCEVI 新藥獲許可'), isNot(contains('電動車')));
      expect(matcher.match('AIO 一體機亮相'), isNot(contains('AI')));
    });

    test('合法命中不被誤殺（CJK/空白/標點/端點相鄰）', () {
      expect(matcher.match('AI 需求續強'), contains('AI'));
      expect(matcher.match('AI晶片大單'), contains('AI'));
      expect(matcher.match('報導AI'), contains('AI'));
      expect(matcher.match('燃油車廠誤判EV戰略'), contains('電動車'));
      expect(matcher.match('NAND飆漲三倍'), contains('記憶體'));
      expect(matcher.match('CoWoS設備代工'), contains('先進封裝'));
      expect(matcher.match('PCB設備巨頭'), contains('PCB'));
      expect(matcher.match('iPhone 17 上市'), contains('蘋概'));
    });

    test('中文題材詞不受影響（本就無子字串問題）', () {
      expect(matcher.match('散熱液冷需求'), contains('散熱'));
      expect(matcher.match('台塑化石化行情'), contains('塑化'));
    });
  });

  test('無命中回空集合', () {
    expect(matcher.match('台股大盤震盪'), isEmpty);
  });
}
