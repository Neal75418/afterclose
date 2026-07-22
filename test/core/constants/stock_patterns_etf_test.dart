import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/constants/stock_patterns.dart';

void main() {
  group('StockPatterns 上櫃 ETF 判定（2026-07-23 稽核修復）', () {
    test('isTpexEtfCode：00 開頭 5-6 碼純數字（實測 14 檔全符合）', () {
      // stock_master 實際上櫃 ETF 樣本
      for (final code in ['006201', '00858', '00928', '009806', '009823']) {
        expect(StockPatterns.isTpexEtfCode(code), isTrue, reason: code);
      }
    });

    test('權證/個股/上市 ETF 4 碼不誤判', () {
      expect(StockPatterns.isTpexEtfCode('712345'), isFalse); // 上櫃權證 7 開頭
      expect(StockPatterns.isTpexEtfCode('8299'), isFalse); // 一般個股
      expect(
        StockPatterns.isTpexEtfCode('0050'),
        isFalse,
      ); // 4 碼（isTpexCode 已涵蓋）
      expect(
        StockPatterns.isTpexEtfCode('00679B'),
        isFalse,
      ); // 帶字尾債券 ETF 不在放行範圍
    });

    test('isTpexPriceCode = 個股 4 碼 或 上櫃 ETF', () {
      expect(StockPatterns.isTpexPriceCode('8299'), isTrue);
      expect(StockPatterns.isTpexPriceCode('006201'), isTrue);
      expect(StockPatterns.isTpexPriceCode('712345'), isFalse);
    });
  });
}
