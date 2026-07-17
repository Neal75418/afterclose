import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/analysis/trend_detection_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/price_data_generators.dart';

/// 45 天平盤價格，近 20 天量能為前期的 2 倍 → 通過 1.5x 量能確認
/// （前 25 天量 1000、近 20 天量 2000；close 平盤使 higherLow/lowerHigh 不獨立觸發）
List<DailyPriceEntry> volumeConfirmedPrices({double basePrice = 100}) {
  final now = DateTime.now();
  return List.generate(45, (i) {
    final recent = i >= 25;
    return createTestPrice(
      date: now.subtract(Duration(days: 45 - i - 1)),
      close: basePrice,
      volume: recent ? 2000 : 1000,
    );
  });
}

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

    test('triggers on breakout above range top in down trend (量能確認)', () {
      final prices = volumeConfirmedPrices();
      // rangeTop=100, breakoutLevel = 100 * 1.03 = 103
      // todayClose=104 > 103 且近期量能達前期 1.5x → true
      final result = service.checkWeakToStrong(
        prices,
        104.0,
        trendState: TrendState.down,
        rangeTop: 100.0,
      );
      expect(result, isTrue);
    });

    test(
      'does not trigger breakout without volume confirmation (audit signal #4)',
      () {
        // 平盤量能（近期 == 前期）→ 未達 1.5x 量能確認 → 無量假突破不觸發
        final prices = generateFlatPrices(days: 50, basePrice: 100);
        final result = service.checkWeakToStrong(
          prices,
          104.0,
          trendState: TrendState.down,
          rangeTop: 100.0,
        );
        expect(result, isFalse);
      },
    );

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
    test('triggers on breakdown below support (量能確認)', () {
      final prices = volumeConfirmedPrices();
      // support=100, breakdownLevel = 100 * 0.97 = 97
      // todayClose=96 < 97 且量能達 1.5x → true
      final result = service.checkStrongToWeak(
        prices,
        96.0,
        trendState: TrendState.up,
        support: 100.0,
      );
      expect(result, isTrue);
    });

    test('triggers on breakdown below range bottom (量能確認)', () {
      final prices = volumeConfirmedPrices();
      // rangeBottom=100, breakdownLevel = 97, todayClose=96
      final result = service.checkStrongToWeak(
        prices,
        96.0,
        trendState: TrendState.range,
        rangeBottom: 100.0,
      );
      expect(result, isTrue);
    });

    test(
      'does not trigger breakdown without volume confirmation (audit signal #4)',
      () {
        // 平盤量能 → 未達 1.5x 量能確認 → 無量假跌破不觸發
        final prices = generateFlatPrices(days: 50, basePrice: 100);
        final result = service.checkStrongToWeak(
          prices,
          96.0,
          trendState: TrendState.up,
          support: 100.0,
        );
        expect(result, isFalse);
      },
    );

    test(
      'does not trigger support breakdown in down trend (需原本強勢, audit signal #4)',
      () {
        // 已在下跌趨勢 → 本就弱勢、跌破支撐屬延續而非強轉弱；即使量能確認也不觸發
        final prices = volumeConfirmedPrices();
        final result = service.checkStrongToWeak(
          prices,
          96.0,
          trendState: TrendState.down,
          support: 100.0,
        );
        expect(result, isFalse);
      },
    );

    test(
      'does not trigger range bottom breakdown in down trend (audit signal #4)',
      () {
        final prices = volumeConfirmedPrices();
        final result = service.checkStrongToWeak(
          prices,
          96.0,
          trendState: TrendState.down,
          rangeBottom: 100.0,
        );
        expect(result, isFalse);
      },
    );

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
