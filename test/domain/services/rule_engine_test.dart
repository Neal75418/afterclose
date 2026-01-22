import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/domain/services/analysis_service.dart';
import 'package:afterclose/domain/services/rule_engine.dart';
import 'package:afterclose/domain/services/rules/fundamental_rules.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';
import 'package:afterclose/domain/services/rules/technical_rules.dart';
import 'package:afterclose/domain/services/rules/volume_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/price_data_generators.dart';

void main() {
  late RuleEngine ruleEngine;

  setUp(() {
    ruleEngine = RuleEngine();
  });

  group('RuleEngine Strategy', () {
    test('evaluateStock should run all rules and return reasons', () {
      // 1. Setup Data that triggers multiple rules
      // - Volume Spike (5x)
      // - Breakout (Close > Resistance)
      final prices = generatePricesWithVolumeSpike(
        days: 30,
        normalVolume: 1000,
        spikeVolume: 5000,
      );
      // Ensure breakout: base 100, close 103 (from generator), resistance 100
      final context = AnalysisContext(
        trendState: TrendState.range,
        resistanceLevel: 100.0,
      );

      // 2. Run Engine
      final reasons = ruleEngine.evaluateStock(
        priceHistory: prices,
        context: context,
        symbol: 'TEST',
      );

      // 3. Verify Rules Triggered
      expect(reasons, isNotEmpty);
      expect(reasons.any((r) => r.type == ReasonType.volumeSpike), isTrue);
      expect(reasons.any((r) => r.type == ReasonType.techBreakout), isTrue);

      // 4. Verify Score Calculation
      final score = ruleEngine.calculateScore(reasons);
      expect(score, greaterThan(50)); // Should be high due to bonuses
    });
  });

  group('Individual Rules', () {
    group('WeakToStrongRule', () {
      final rule = const WeakToStrongRule();

      test('should trigger on breakout above range top', () {
        final prices = generateDowntrendPrices(days: 60);
        // Manual breakout
        final pricesWithBreakout = [
          ...prices.take(prices.length - 1),
          createTestPrice(date: DateTime.now(), close: 102.0),
        ];

        final context = AnalysisContext(
          trendState: TrendState.down,
          rangeTop: 100.0,
        );

        final data = StockData(symbol: 'TEST', prices: pricesWithBreakout);
        final result = rule.evaluate(context, data);

        expect(result, isNotNull);
        expect(result!.type, ReasonType.reversalW2S);
      });
    });

    group('VolumeSpikeRule', () {
      final rule = const VolumeSpikeRule();

      test('should trigger when volume is 4x average', () {
        final prices = generatePricesWithVolumeSpike(
          days: 30,
          normalVolume: 1000,
          spikeVolume: 5000,
        );
        final context = AnalysisContext(trendState: TrendState.range);
        final data = StockData(symbol: 'TEST', prices: prices);

        final result = rule.evaluate(context, data);

        expect(result, isNotNull);
        expect(result!.type, ReasonType.volumeSpike);
      });
    });

    group('InstitutionalShiftRule', () {
      final rule = const InstitutionalShiftRule();

      test('should trigger when foreign investors switch to buy', () {
        final history = generateInstitutionalHistory(
          days: 15,
          prevDirection: -1000, // Sell before (avg ~ -333)
          todayDirection: 1000, // Buy today
        );
        final context = AnalysisContext(trendState: TrendState.range);
        final data = StockData(
          symbol: 'TEST',
          prices: [],
          institutional: history,
        );

        final result = rule.evaluate(context, data);

        expect(result, isNotNull);
        expect(result!.type, ReasonType.institutionalShift);
      });
    });
  });
}
