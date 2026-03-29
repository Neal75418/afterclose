import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/domain/services/analysis/trend_detection_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/price_data_generators.dart';

void main() {
  final service = TrendDetectionService();

  // ==========================================
  // detectTrendState
  // ==========================================
  group('detectTrendState', () {
    test('returns range when insufficient data', () {
      final prices = generateFlatPrices(
        days: RuleParams.swingWindow - 1,
        basePrice: 100,
      );
      expect(service.detectTrendState(prices), TrendState.range);
    });

    test('detects uptrend from rising prices', () {
      // 每天漲 1%，20 天 → normalizedSlope 應 > 0.08
      final prices = generateUptrendPrices(
        days: 30,
        startPrice: 100,
        dailyGain: 1.0,
      );
      expect(service.detectTrendState(prices), TrendState.up);
    });

    test('detects downtrend from falling prices', () {
      final prices = generateDowntrendPrices(
        days: 30,
        startPrice: 100,
        dailyLoss: 1.0,
      );
      expect(service.detectTrendState(prices), TrendState.down);
    });

    test('detects range for flat prices', () {
      final prices = generateFlatPrices(days: 30, basePrice: 100);
      expect(service.detectTrendState(prices), TrendState.range);
    });

    test('detects range for constant prices', () {
      // 完全固定價格，斜率為零
      final prices = generateConstantPrices(days: 30, basePrice: 100);
      expect(service.detectTrendState(prices), TrendState.range);
    });
  });

  // ==========================================
  // checkWeakToStrong
  // ==========================================
  group('checkWeakToStrong', () {
    test('returns false when trend is up', () {
      final prices = generateFlatPrices(days: 50, basePrice: 100);
      final result = service.checkWeakToStrong(
        prices,
        110.0,
        trendState: TrendState.up,
        rangeTop: 105.0,
      );
      expect(result, isFalse);
    });

    test('triggers on breakout above range top in down trend', () {
      final prices = generateFlatPrices(days: 50, basePrice: 100);
      // rangeTop=100, breakoutLevel = 100 * 1.03 = 103
      // todayClose=104 > 103 → true
      final result = service.checkWeakToStrong(
        prices,
        104.0,
        trendState: TrendState.down,
        rangeTop: 100.0,
      );
      expect(result, isTrue);
    });

    test('does not trigger when close is below breakout level', () {
      final prices = generateFlatPrices(days: 50, basePrice: 100);
      // rangeTop=100, breakoutLevel = 103, todayClose=102 < 103
      final result = service.checkWeakToStrong(
        prices,
        102.0,
        trendState: TrendState.down,
        rangeTop: 100.0,
      );
      // 仍可能因 higherLow 觸發，但 flat prices 不會
      expect(result, isFalse);
    });

    test('does not trigger higher low with insufficient data', () {
      // 需要 40 天資料才能做 higherLow 判斷
      final prices = generateFlatPrices(days: 30, basePrice: 100);
      final result = service.checkWeakToStrong(
        prices,
        100.0,
        trendState: TrendState.range,
      );
      expect(result, isFalse);
    });
  });

  // ==========================================
  // checkStrongToWeak
  // ==========================================
  group('checkStrongToWeak', () {
    test('triggers on breakdown below support', () {
      final prices = generateFlatPrices(days: 50, basePrice: 100);
      // support=100, breakdownLevel = 100 * 0.97 = 97
      // todayClose=96 < 97 → true
      final result = service.checkStrongToWeak(
        prices,
        96.0,
        trendState: TrendState.up,
        support: 100.0,
      );
      expect(result, isTrue);
    });

    test('triggers on breakdown below range bottom', () {
      final prices = generateFlatPrices(days: 50, basePrice: 100);
      // rangeBottom=100, breakdownLevel = 97, todayClose=96
      final result = service.checkStrongToWeak(
        prices,
        96.0,
        trendState: TrendState.range,
        rangeBottom: 100.0,
      );
      expect(result, isTrue);
    });

    test('does not trigger above breakdown level', () {
      final prices = generateFlatPrices(days: 50, basePrice: 100);
      // support=100, breakdownLevel = 97, todayClose=98 > 97
      final result = service.checkStrongToWeak(
        prices,
        98.0,
        trendState: TrendState.up,
        support: 100.0,
      );
      // 可能因 lowerHigh 觸發，但 flat prices 不會
      expect(result, isFalse);
    });

    test('does not check lower high in down trend', () {
      final prices = generateFlatPrices(days: 50, basePrice: 100);
      final result = service.checkStrongToWeak(
        prices,
        99.0,
        trendState: TrendState.down,
      );
      // down trend 不檢查 lowerHigh，且無 support/rangeBottom
      expect(result, isFalse);
    });
  });
}
