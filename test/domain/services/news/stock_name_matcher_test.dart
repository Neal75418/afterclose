// test/domain/services/news/stock_name_matcher_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/news/stock_name_matcher.dart';

StockMasterEntry stock(String symbol, String name) => StockMasterEntry(
  symbol: symbol,
  name: name,
  market: 'TWSE',
  industry: '電子工業',
  isActive: true,
  updatedAt: DateTime(2026, 7, 15),
);

void main() {
  late StockNameMatcher matcher;

  setUp(() {
    matcher = StockNameMatcher.fromStocks([
      stock('2330', '台積電'),
      stock('2603', '長榮'), // 2 字、在白名單
      stock('2618', '長榮航'), // 3 字
      stock('2454', '聯發科'),
      stock('1210', '大成'), // 2 字、不在白名單
      stock('2317', '鴻海'), // 2 字、在白名單
      stock('3665', '貿聯-KY'),
      stock('2882', '國泰金'),
    ]);
  });

  test('3 字以上名稱直接匹配', () {
    expect(matcher.match('台積電法說會登場'), {'2330'});
  });

  test('最長優先：長榮航不重複計入長榮', () {
    expect(matcher.match('長榮航獲利創高'), {'2618'});
  });

  test('位置消耗後其餘出現仍可匹配：標題同時有長榮航與長榮', () {
    expect(matcher.match('長榮航與長榮海運齊漲'), {'2618', '2603'});
  });

  test('聯發科不會讓白名單外的子字串重複計分', () {
    // 聯發科匹配後消耗位置；「聯發」非獨立出現
    expect(matcher.match('聯發科營收創高'), {'2454'});
  });

  test('2 字名僅白名單匹配：鴻海可、大成不可', () {
    expect(matcher.match('鴻海進軍機器人'), {'2317'});
    expect(matcher.match('明基材料醫材將成最大成長動能'), isEmpty);
  });

  test('-KY 名稱照原樣匹配', () {
    expect(matcher.match('貿聯-KY 6月營收85.18億元'), {'3665'});
  });

  test('同篇多次出現計 1（Set 語意）', () {
    expect(matcher.match('台積電漲！台積電再創高'), {'2330'});
  });

  test('無命中回空集合', () {
    expect(matcher.match('今彩539頭獎開出'), isEmpty);
  });

  test('金融股 3 字名', () {
    expect(matcher.match('國泰金股東會通過配息'), {'2882'});
  });
}
