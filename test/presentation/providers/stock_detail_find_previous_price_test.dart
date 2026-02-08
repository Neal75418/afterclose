import 'package:afterclose/presentation/providers/stock_detail_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/price_data_generators.dart';

void main() {
  // ==========================================
  // findPreviousPrice 回歸測試
  //
  // 驗證 P1 修正：data mismatch 時使用 sync-aligned 價格
  // 而非 recentPrices.first，並從 priceHistory 正確找到前一日
  // ==========================================
  group('findPreviousPrice', () {
    test('returns null when targetPrice is null', () {
      final history = [
        createTestPrice(date: DateTime(2025, 1, 13), close: 99.0),
        createTestPrice(date: DateTime(2025, 1, 14), close: 100.0),
      ];

      final result = StockDetailNotifier.findPreviousPrice(history, null);

      expect(result, isNull);
    });

    test('returns null when history has fewer than 2 entries', () {
      final singleEntry = createTestPrice(
        date: DateTime(2025, 1, 15),
        close: 100.0,
      );

      final result = StockDetailNotifier.findPreviousPrice([
        singleEntry,
      ], singleEntry);

      expect(result, isNull);
    });

    test('returns null for empty history', () {
      final target = createTestPrice(date: DateTime(2025, 1, 15), close: 100.0);

      final result = StockDetailNotifier.findPreviousPrice([], target);

      expect(result, isNull);
    });

    test('returns previous entry when target date exists in history', () {
      final history = [
        createTestPrice(date: DateTime(2025, 1, 13), close: 98.0),
        createTestPrice(date: DateTime(2025, 1, 14), close: 99.0),
        createTestPrice(date: DateTime(2025, 1, 15), close: 100.0),
      ];
      final target = history[2]; // 1/15

      final result = StockDetailNotifier.findPreviousPrice(history, target);

      expect(result, isNotNull);
      expect(result!.date, equals(DateTime(2025, 1, 14)));
      expect(result.close, equals(99.0));
    });

    test('returns second-to-last when target is the last entry', () {
      final history = [
        createTestPrice(date: DateTime(2025, 1, 13), close: 98.0),
        createTestPrice(date: DateTime(2025, 1, 14), close: 99.0),
        createTestPrice(date: DateTime(2025, 1, 15), close: 100.0),
      ];
      final target = history.last;

      final result = StockDetailNotifier.findPreviousPrice(history, target);

      expect(result, isNotNull);
      expect(result!.close, equals(99.0));
    });

    test('returns null when target date is not in history', () {
      final history = [
        createTestPrice(date: DateTime(2025, 1, 13), close: 98.0),
        createTestPrice(date: DateTime(2025, 1, 14), close: 99.0),
        createTestPrice(date: DateTime(2025, 1, 15), close: 100.0),
      ];
      // 1/16 不在 history 中
      final target = createTestPrice(date: DateTime(2025, 1, 16), close: 101.0);

      final result = StockDetailNotifier.findPreviousPrice(history, target);

      expect(result, isNull);
    });

    test('regression: returns correct previous when target is a middle date '
        '(data mismatch scenario)', () {
      // 迴歸場景：價格有 1/13~1/15，法人只到 1/14
      // syncResult.latestPrice 會是 1/14（非最新的 1/15）
      // _findPreviousPrice 應回傳 1/13，而非 1/14
      final history = [
        createTestPrice(date: DateTime(2025, 1, 13), close: 98.0),
        createTestPrice(date: DateTime(2025, 1, 14), close: 99.0),
        createTestPrice(date: DateTime(2025, 1, 15), close: 100.0),
      ];
      // 模擬 syncResult.latestPrice：日期對齊後是 1/14（非最新的 1/15）
      final syncAlignedPrice = history[1]; // 1/14, close=99.0

      final result = StockDetailNotifier.findPreviousPrice(
        history,
        syncAlignedPrice,
      );

      // 應回傳 1/13（syncAlignedPrice 的前一筆），而非 1/14
      expect(result, isNotNull);
      expect(result!.date, equals(DateTime(2025, 1, 13)));
      expect(result.close, equals(98.0));
    });

    test('regression: longer history with mismatch finds correct previous', () {
      // 更長的歷史，mismatch 在中間位置
      final history = [
        createTestPrice(date: DateTime(2025, 1, 10), close: 95.0),
        createTestPrice(date: DateTime(2025, 1, 13), close: 96.0),
        createTestPrice(date: DateTime(2025, 1, 14), close: 97.0),
        createTestPrice(date: DateTime(2025, 1, 15), close: 98.0),
        createTestPrice(date: DateTime(2025, 1, 16), close: 99.0),
        createTestPrice(date: DateTime(2025, 1, 17), close: 100.0),
      ];
      // syncResult 對齊到 1/14
      final syncAlignedPrice = history[2]; // 1/14, close=97.0

      final result = StockDetailNotifier.findPreviousPrice(
        history,
        syncAlignedPrice,
      );

      expect(result, isNotNull);
      expect(result!.date, equals(DateTime(2025, 1, 13)));
      expect(result.close, equals(96.0));
    });
  });
}
