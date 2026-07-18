// 無障礙播報方向迴歸 —— flat-value sign/color 缺陷類第三輪
//
// `S.accessibilityPriceChange` 以 `change >= 0` 二分方向，平盤會播報成
// 「上漲 0.00 百分比」、微負值播報成「下跌 0.00 百分比」——與畫面上已修
// 好的中性 `0.00%` 互相矛盾（stock_card / stock_preview_sheet 兩處都用它）。
//
// 註：測試環境未載入翻譯，`.tr()` 直接回傳 key，所以斷言比對的是 key
// 本身（key 找不到時 easy_localization 也不會代入 namedArgs）。

import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/l10n/app_strings.dart';

import '../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  group('S.accessibilityPriceChange 方向播報', () {
    test('平盤（0）播報「持平」而非「上漲」', () {
      expect(S.accessibilityPriceChange(0), 'accessibility.priceChangeNeutral');
    });

    test('微負值（2 位捨入歸零）播報「持平」而非「下跌」', () {
      expect(
        S.accessibilityPriceChange(-0.004),
        'accessibility.priceChangeNeutral',
      );
    });

    test('微正值（2 位捨入歸零）播報「持平」而非「上漲」', () {
      expect(
        S.accessibilityPriceChange(0.004),
        'accessibility.priceChangeNeutral',
      );
    });

    test('真實上漲仍播報「上漲」（未過度中性化）', () {
      expect(S.accessibilityPriceChange(1.67), 'accessibility.priceChangeUp');
    });

    test('真實下跌仍播報「下跌」', () {
      expect(S.accessibilityPriceChange(-3.0), 'accessibility.priceChangeDown');
    });
  });

  group('S.priceChangeLabel 三分法（既有行為守門）', () {
    test('null / 0 → 中性', () {
      expect(S.priceChangeLabel(null), 'price.neutral');
      expect(S.priceChangeLabel(0), 'price.neutral');
    });

    test('正 → 上漲、負 → 下跌', () {
      expect(S.priceChangeLabel(1.0), 'price.up');
      expect(S.priceChangeLabel(-1.0), 'price.down');
    });
  });
}
