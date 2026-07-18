import 'package:flutter/material.dart' show Brightness;
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/screens/comparison/utils/comparison_calculator.dart';

void main() {
  final defaultDate = DateTime(2026, 2, 13);

  DailyPriceEntry price(double close, {int daysAgo = 0}) => DailyPriceEntry(
    symbol: '2330',
    date: defaultDate.subtract(Duration(days: daysAgo)),
    open: close,
    high: close,
    low: close,
    close: close,
    volume: 50000,
  );

  group('calculatePriceReturn（帶正負號漲跌幅）', () {
    test('上漲帶 +', () {
      final r = ComparisonCalculator.calculatePriceReturn(
        [price(500, daysAgo: 1), price(550)],
        5,
        Brightness.light,
      );
      expect(r.display, '+10.0%');
    });

    test('平盤（0%）不帶 + 且配色中性（null）', () {
      final r = ComparisonCalculator.calculatePriceReturn(
        [price(600, daysAgo: 1), price(600)],
        5,
        Brightness.light,
      );
      expect(r.display, '0.0%', reason: '平盤不得帶 +');
      expect(r.color, isNull, reason: '平盤不著漲跌方向色');
    });

    test('微負值捨入歸零 → 0.0%（非 -0.0%）且配色中性', () {
      // (100.02 / 100 - 1) * 100 = 0.02% → 取一位小數捨入為 0.0%
      final r = ComparisonCalculator.calculatePriceReturn(
        [price(100, daysAgo: 1), price(100.02)],
        5,
        Brightness.light,
      );
      expect(r.display, '0.0%');
      expect(r.color, isNull);
    });
  });

  group('aggregateInstitutionalNet（帶正負號張數）', () {
    DailyInstitutionalEntry entry() => DailyInstitutionalEntry(
      symbol: '2330',
      date: defaultDate,
      foreignNet: 0,
      investmentTrustNet: 0,
      dealerNet: 0,
    );

    test('平盤（合計捨入為 0 張）不帶 + 且配色中性（null）', () {
      // total 300 股 → /1000 四捨五入為 0 張
      final r = ComparisonCalculator.aggregateInstitutionalNet(
        [entry()],
        (e) => 300.0,
        Brightness.light,
      );
      expect(r.display, '0', reason: '0 張不得帶 +');
      expect(r.color, isNull, reason: '0 張不著漲跌方向色');
    });
  });
}
