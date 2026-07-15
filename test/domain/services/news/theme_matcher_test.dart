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

  test('無命中回空集合', () {
    expect(matcher.match('台股大盤震盪'), isEmpty);
  });
}
