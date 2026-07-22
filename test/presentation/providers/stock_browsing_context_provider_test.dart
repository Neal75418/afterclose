// 瀏覽脈絡：清單頁 push 詳情前記下有序 symbols，詳情頁底部導航列
// 據此提供「上一檔/下一檔」。13 個清單入口共用同一機制。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/constants/app_routes.dart';
import 'package:afterclose/presentation/providers/stock_browsing_context_provider.dart';

void main() {
  group('browsingNeighbors', () {
    const list = ['2330', '3231', '8046'];

    test('中間：前後皆有', () {
      final n = browsingNeighbors(list, '3231');
      expect(n, isNotNull);
      expect(n!.prev, '2330');
      expect(n.next, '8046');
      expect(n.position, 2);
      expect(n.total, 3);
    });

    test('首檔：無上一檔', () {
      final n = browsingNeighbors(list, '2330')!;
      expect(n.prev, isNull);
      expect(n.next, '3231');
      expect(n.position, 1);
    });

    test('尾檔：無下一檔', () {
      final n = browsingNeighbors(list, '8046')!;
      expect(n.prev, '3231');
      expect(n.next, isNull);
      expect(n.position, 3);
    });

    test('不在清單（搜尋/深連結進入）→ null（不顯示導航列）', () {
      expect(browsingNeighbors(list, '9999'), isNull);
      expect(browsingNeighbors(const [], '2330'), isNull);
    });

    test('單檔清單 → null（無可導航對象）', () {
      expect(browsingNeighbors(const ['2330'], '2330'), isNull);
    });
  });

  group('stockBrowsingContextProvider', () {
    test('set 覆寫舊脈絡', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(stockBrowsingContextProvider.notifier).set(const [
        '2330',
        '3231',
      ]);
      expect(container.read(stockBrowsingContextProvider), ['2330', '3231']);

      container.read(stockBrowsingContextProvider.notifier).set(const ['8046']);
      expect(container.read(stockBrowsingContextProvider), ['8046']);
    });
  });

  group('AppRoutes.isStockDetailSwap（換股無轉場契約）', () {
    test('僅換股標記為 true，其他 extra 一律 false', () {
      expect(
        AppRoutes.isStockDetailSwap(AppRoutes.stockDetailSwapExtra),
        isTrue,
      );
      expect(AppRoutes.isStockDetailSwap(null), isFalse);
      expect(AppRoutes.isStockDetailSwap('other'), isFalse);
      expect(AppRoutes.isStockDetailSwap(['2330']), isFalse);
    });
  });
}
