import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/domain/services/market_reading_service.dart';
import 'package:afterclose/domain/services/technical_indicator_service.dart'
    show MarketStage;

void main() {
  group('MarketReadingService.interpretVolumePrice', () {
    // turnoverDeltaPct = (today - avg5d) / avg5d * 100；門檻 kVolumeSurgePct = 10

    test('UP & 量增 (>+10%) → positive healthyUp', () {
      final r = MarketReadingService.interpretVolumePrice(
        todayTurnover: 130,
        avg5dTurnover: 100, // delta = +30%
        indexChangePercent: 1.0,
      );
      expect(r.tone, InterpretationTone.positive);
      expect(r.messageKey, 'marketOverview.reading.volumePrice.healthyUp');
    });

    test('UP & 量縮 (<-10%) → warning weakUp', () {
      final r = MarketReadingService.interpretVolumePrice(
        todayTurnover: 80,
        avg5dTurnover: 100, // delta = -20%
        indexChangePercent: 0.5,
      );
      expect(r.tone, InterpretationTone.warning);
      expect(r.messageKey, 'marketOverview.reading.volumePrice.weakUp');
    });

    test('DOWN & 量增 (>+10%) → negative heavySelloff', () {
      final r = MarketReadingService.interpretVolumePrice(
        todayTurnover: 150,
        avg5dTurnover: 100, // delta = +50%
        indexChangePercent: -1.2,
      );
      expect(r.tone, InterpretationTone.negative);
      expect(r.messageKey, 'marketOverview.reading.volumePrice.heavySelloff');
    });

    test('DOWN & 量縮 (<-10%) → neutral quietConsolidation', () {
      final r = MarketReadingService.interpretVolumePrice(
        todayTurnover: 70,
        avg5dTurnover: 100, // delta = -30%
        indexChangePercent: -0.4,
      );
      expect(r.tone, InterpretationTone.neutral);
      expect(
        r.messageKey,
        'marketOverview.reading.volumePrice.quietConsolidation',
      );
    });

    test('|delta| 在門檻內 → neutral flat (UP side)', () {
      final r = MarketReadingService.interpretVolumePrice(
        todayTurnover: 105,
        avg5dTurnover: 100, // delta = +5%
        indexChangePercent: 0.3,
      );
      expect(r.tone, InterpretationTone.neutral);
      expect(r.messageKey, 'marketOverview.reading.volumePrice.flat');
    });

    test('|delta| 在門檻內 → neutral flat (DOWN side)', () {
      final r = MarketReadingService.interpretVolumePrice(
        todayTurnover: 95,
        avg5dTurnover: 100, // delta = -5%
        indexChangePercent: -0.3,
      );
      expect(r.tone, InterpretationTone.neutral);
      expect(r.messageKey, 'marketOverview.reading.volumePrice.flat');
    });

    test('恰在門檻 (+10%) 視為持平 (非 strictly > threshold)', () {
      final r = MarketReadingService.interpretVolumePrice(
        todayTurnover: 110,
        avg5dTurnover: 100, // delta = +10% (boundary)
        indexChangePercent: 1.0,
      );
      expect(r.messageKey, 'marketOverview.reading.volumePrice.flat');
    });

    test('indexChangePercent == 0 視為非 UP (走 DOWN 分支)', () {
      final r = MarketReadingService.interpretVolumePrice(
        todayTurnover: 150,
        avg5dTurnover: 100, // delta = +50%
        indexChangePercent: 0.0,
      );
      expect(r.tone, InterpretationTone.negative);
      expect(r.messageKey, 'marketOverview.reading.volumePrice.heavySelloff');
    });

    test('guard: avg5d == 0 → delta=0 → flat', () {
      final r = MarketReadingService.interpretVolumePrice(
        todayTurnover: 9999,
        avg5dTurnover: 0,
        indexChangePercent: 2.0,
      );
      expect(r.tone, InterpretationTone.neutral);
      expect(r.messageKey, 'marketOverview.reading.volumePrice.flat');
    });
  });

  group('MarketReadingService.interpretMarginLeverage', () {
    test('融資增 & UP → warning overheating', () {
      final r = MarketReadingService.interpretMarginLeverage(
        marginChange: 500,
        indexChangePercent: 1.0,
      );
      expect(r.tone, InterpretationTone.warning);
      expect(r.messageKey, 'marketOverview.reading.marginLeverage.overheating');
    });

    test('融資減 & UP → positive healthyWashout', () {
      final r = MarketReadingService.interpretMarginLeverage(
        marginChange: -500,
        indexChangePercent: 1.0,
      );
      expect(r.tone, InterpretationTone.positive);
      expect(
        r.messageKey,
        'marketOverview.reading.marginLeverage.healthyWashout',
      );
    });

    test('融資增 & DOWN → negative trapped', () {
      final r = MarketReadingService.interpretMarginLeverage(
        marginChange: 500,
        indexChangePercent: -1.0,
      );
      expect(r.tone, InterpretationTone.negative);
      expect(r.messageKey, 'marketOverview.reading.marginLeverage.trapped');
    });

    test('融資減 & DOWN → neutral deleveraging', () {
      final r = MarketReadingService.interpretMarginLeverage(
        marginChange: -500,
        indexChangePercent: -1.0,
      );
      expect(r.tone, InterpretationTone.neutral);
      expect(
        r.messageKey,
        'marketOverview.reading.marginLeverage.deleveraging',
      );
    });

    test('融資變動 == 0 → neutral stable (不論指數方向)', () {
      final up = MarketReadingService.interpretMarginLeverage(
        marginChange: 0,
        indexChangePercent: 2.0,
      );
      expect(up.tone, InterpretationTone.neutral);
      expect(up.messageKey, 'marketOverview.reading.marginLeverage.stable');

      final down = MarketReadingService.interpretMarginLeverage(
        marginChange: 0,
        indexChangePercent: -2.0,
      );
      expect(down.messageKey, 'marketOverview.reading.marginLeverage.stable');
    });

    test('indexChangePercent == 0 視為非 UP (融資增 → trapped)', () {
      final r = MarketReadingService.interpretMarginLeverage(
        marginChange: 100,
        indexChangePercent: 0.0,
      );
      expect(r.tone, InterpretationTone.negative);
      expect(r.messageKey, 'marketOverview.reading.marginLeverage.trapped');
    });
  });

  group('MarketReadingService.interpretBreadth', () {
    // ratio = advance / (advance + decline)；門檻 0.60 / 0.40

    test('ratio > 0.60 → positive broadUp', () {
      final r = MarketReadingService.interpretBreadth(advance: 70, decline: 30);
      expect(r.tone, InterpretationTone.positive);
      expect(r.messageKey, 'marketOverview.reading.breadth.broadUp');
    });

    test('ratio < 0.40 → negative broadDown', () {
      final r = MarketReadingService.interpretBreadth(advance: 30, decline: 70);
      expect(r.tone, InterpretationTone.negative);
      expect(r.messageKey, 'marketOverview.reading.breadth.broadDown');
    });

    test('0.40 <= ratio <= 0.60 → neutral mixed', () {
      final r = MarketReadingService.interpretBreadth(advance: 50, decline: 50);
      expect(r.tone, InterpretationTone.neutral);
      expect(r.messageKey, 'marketOverview.reading.breadth.mixed');
    });

    test('恰在 0.60 邊界 → mixed (非 strictly >)', () {
      // 60/(60+40) = 0.60
      final r = MarketReadingService.interpretBreadth(advance: 60, decline: 40);
      expect(r.messageKey, 'marketOverview.reading.breadth.mixed');
    });

    test('恰在 0.40 邊界 → mixed (非 strictly <)', () {
      // 40/(40+60) = 0.40
      final r = MarketReadingService.interpretBreadth(advance: 40, decline: 60);
      expect(r.messageKey, 'marketOverview.reading.breadth.mixed');
    });

    test('guard: denom == 0 → ratio=0.5 → mixed', () {
      final r = MarketReadingService.interpretBreadth(advance: 0, decline: 0);
      expect(r.tone, InterpretationTone.neutral);
      expect(r.messageKey, 'marketOverview.reading.breadth.mixed');
    });
  });

  group('MarketReadingService.interpretBreadthTrend', () {
    // threshold-free：純比較 newHighs vs newLows + 指數方向

    test('指數漲 & 新高 > 新低 → positive confirmUp', () {
      final r = MarketReadingService.interpretBreadthTrend(
        newHighs: 156,
        newLows: 29,
        indexChangePercent: 0.8,
      );
      expect(r.tone, InterpretationTone.positive);
      expect(r.messageKey, 'marketOverview.reading.breadthTrend.confirmUp');
    });

    test('指數漲 & 新低 > 新高 → warning divergence', () {
      final r = MarketReadingService.interpretBreadthTrend(
        newHighs: 20,
        newLows: 80,
        indexChangePercent: 0.5,
      );
      expect(r.tone, InterpretationTone.warning);
      expect(r.messageKey, 'marketOverview.reading.breadthTrend.divergence');
    });

    test('指數漲 & 新低 == 新高 → warning divergence (新低未縮)', () {
      final r = MarketReadingService.interpretBreadthTrend(
        newHighs: 40,
        newLows: 40,
        indexChangePercent: 0.3,
      );
      expect(r.tone, InterpretationTone.warning);
      expect(r.messageKey, 'marketOverview.reading.breadthTrend.divergence');
    });

    test('指數跌 & 新低 > 新高 → negative weakDown', () {
      final r = MarketReadingService.interpretBreadthTrend(
        newHighs: 15,
        newLows: 90,
        indexChangePercent: -1.1,
      );
      expect(r.tone, InterpretationTone.negative);
      expect(r.messageKey, 'marketOverview.reading.breadthTrend.weakDown');
    });

    test('指數跌 & 新高 >= 新低 → neutral (else 分支)', () {
      final r = MarketReadingService.interpretBreadthTrend(
        newHighs: 60,
        newLows: 30,
        indexChangePercent: -0.4,
      );
      expect(r.tone, InterpretationTone.neutral);
      expect(r.messageKey, 'marketOverview.reading.breadthTrend.neutral');
    });

    test('指數跌 & 新高 == 新低 → neutral (else 分支)', () {
      final r = MarketReadingService.interpretBreadthTrend(
        newHighs: 30,
        newLows: 30,
        indexChangePercent: -0.7,
      );
      expect(r.tone, InterpretationTone.neutral);
      expect(r.messageKey, 'marketOverview.reading.breadthTrend.neutral');
    });

    test('indexChangePercent == 0 視為非 UP（新高多→走 else neutral）', () {
      final r = MarketReadingService.interpretBreadthTrend(
        newHighs: 100,
        newLows: 10,
        indexChangePercent: 0.0,
      );
      // isUp=false、newLows(10) > newHighs(100) 為 false → else neutral
      expect(r.tone, InterpretationTone.neutral);
      expect(r.messageKey, 'marketOverview.reading.breadthTrend.neutral');
    });
  });

  group('MarketReadingService.interpretStageBias', () {
    // 門檻 kBiasOverheatPct = 15

    test('bullish & biasMa60 > 15 → warning overheated', () {
      final r = MarketReadingService.interpretStageBias(
        stage: MarketStage.bullish,
        biasMa60: 20,
      );
      expect(r, isNotNull);
      expect(r!.tone, InterpretationTone.warning);
      expect(r.messageKey, 'marketOverview.reading.stageBias.overheated');
    });

    test('bearish & biasMa60 < -15 → positive oversold', () {
      final r = MarketReadingService.interpretStageBias(
        stage: MarketStage.bearish,
        biasMa60: -20,
      );
      expect(r, isNotNull);
      expect(r!.tone, InterpretationTone.positive);
      expect(r.messageKey, 'marketOverview.reading.stageBias.oversold');
    });

    test('bullish 但乖離未達門檻 → null', () {
      final r = MarketReadingService.interpretStageBias(
        stage: MarketStage.bullish,
        biasMa60: 10,
      );
      expect(r, isNull);
    });

    test('bearish 但乖離未達門檻 → null', () {
      final r = MarketReadingService.interpretStageBias(
        stage: MarketStage.bearish,
        biasMa60: -10,
      );
      expect(r, isNull);
    });

    test('neutral 不論乖離大小 → null', () {
      expect(
        MarketReadingService.interpretStageBias(
          stage: MarketStage.neutral,
          biasMa60: 30,
        ),
        isNull,
      );
      expect(
        MarketReadingService.interpretStageBias(
          stage: MarketStage.neutral,
          biasMa60: -30,
        ),
        isNull,
      );
    });

    test('恰在門檻 (bullish +15) → null (非 strictly >)', () {
      final r = MarketReadingService.interpretStageBias(
        stage: MarketStage.bullish,
        biasMa60: 15,
      );
      expect(r, isNull);
    });

    test('恰在門檻 (bearish -15) → null (非 strictly <)', () {
      final r = MarketReadingService.interpretStageBias(
        stage: MarketStage.bearish,
        biasMa60: -15,
      );
      expect(r, isNull);
    });

    test('bullish 但負乖離 → null (方向不符)', () {
      final r = MarketReadingService.interpretStageBias(
        stage: MarketStage.bullish,
        biasMa60: -20,
      );
      expect(r, isNull);
    });

    test('insufficient stage → null', () {
      final r = MarketReadingService.interpretStageBias(
        stage: MarketStage.insufficient,
        biasMa60: 30,
      );
      expect(r, isNull);
    });
  });
}
