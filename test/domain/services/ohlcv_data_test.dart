import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/ohlcv_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// 建立測試用價格列，未指定欄位維持 null（用於模擬停牌/無成交列）。
DailyPriceEntry _price({
  required DateTime date,
  double? close,
  double? high,
  double? low,
  double? volume,
  String symbol = 'TEST',
}) {
  return DailyPriceEntry(
    symbol: symbol,
    date: date,
    close: close,
    high: high,
    low: low,
    volume: volume,
  );
}

void main() {
  group('extractOhlcv', () {
    test('drops rows with null close/high/low together (halt rows)', () {
      final prices = [
        _price(
          date: DateTime(2026, 1, 1),
          close: 100,
          high: 101,
          low: 99,
          volume: 1000,
        ),
        // TWSE/TPEx 無成交列：close/high/low 皆為 null，但 volume = 0（非 null）
        _price(
          date: DateTime(2026, 1, 2),
          close: null,
          high: null,
          low: null,
          volume: 0,
        ),
        _price(
          date: DateTime(2026, 1, 3),
          close: 102,
          high: 103,
          low: 101,
          volume: 1200,
        ),
      ];

      final result = prices.extractOhlcv();

      expect(result.closes, equals([100.0, 102.0]));
      expect(result.highs, equals([101.0, 103.0]));
      expect(result.lows, equals([99.0, 101.0]));
      expect(result.volumes, equals([1000.0, 1200.0]));
    });

    test(
      'closes/highs/lows/volumes/gapBefore always share the same length',
      () {
        final prices = [
          _price(
            date: DateTime(2026, 1, 1),
            close: 100,
            high: 101,
            low: 99,
            volume: 1000,
          ),
          _price(
            date: DateTime(2026, 1, 2),
            close: null,
            high: null,
            low: null,
            volume: 0,
          ),
          _price(
            date: DateTime(2026, 1, 3),
            close: null,
            high: null,
            low: null,
            volume: 0,
          ),
          _price(
            date: DateTime(2026, 1, 4),
            close: 105,
            high: 106,
            low: 104,
            volume: 900,
          ),
        ];

        final result = prices.extractOhlcv();

        expect(result.highs.length, equals(result.closes.length));
        expect(result.lows.length, equals(result.closes.length));
        expect(result.volumes.length, equals(result.closes.length));
        expect(result.gapBefore.length, equals(result.closes.length));
      },
    );

    test(
      'gapBefore is false for the first valid row and consecutive no-gap rows',
      () {
        final prices = [
          _price(
            date: DateTime(2026, 1, 1),
            close: 100,
            high: 101,
            low: 99,
            volume: 1000,
          ),
          _price(
            date: DateTime(2026, 1, 2),
            close: 101,
            high: 102,
            low: 100,
            volume: 1000,
          ),
        ];

        final result = prices.extractOhlcv();

        expect(result.gapBefore, equals([false, false]));
      },
    );

    test('gapBefore is true immediately after one or more halt rows', () {
      final prices = [
        _price(
          date: DateTime(2026, 1, 1),
          close: 100,
          high: 101,
          low: 99,
          volume: 1000,
        ),
        _price(
          date: DateTime(2026, 1, 2),
          close: null,
          high: null,
          low: null,
          volume: 0,
        ),
        _price(
          date: DateTime(2026, 1, 3),
          close: null,
          high: null,
          low: null,
          volume: 0,
        ),
        _price(
          date: DateTime(2026, 1, 4),
          close: 105,
          high: 106,
          low: 104,
          volume: 900,
        ),
        _price(
          date: DateTime(2026, 1, 5),
          close: 106,
          high: 107,
          low: 105,
          volume: 950,
        ),
      ];

      final result = prices.extractOhlcv();

      // index0=day1(首筆,無缺口) index1=day4(前有2列停牌→缺口) index2=day5(緊接day4,無缺口)
      expect(result.gapBefore, equals([false, true, false]));
    });

    test('volume defaults to 0 when null on an otherwise-valid row', () {
      final prices = [
        _price(
          date: DateTime(2026, 1, 1),
          close: 100,
          high: 101,
          low: 99,
          volume: null,
        ),
      ];

      final result = prices.extractOhlcv();

      expect(result.volumes, equals([0.0]));
    });

    test('returns empty lists for empty input', () {
      final result = <DailyPriceEntry>[].extractOhlcv();

      expect(result.closes, isEmpty);
      expect(result.gapBefore, isEmpty);
    });
  });
}
