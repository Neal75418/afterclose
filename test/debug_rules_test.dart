import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/analysis_service.dart';
import 'package:afterclose/domain/services/rule_engine.dart';
import 'package:afterclose/domain/services/rules/candlestick_rules.dart';
import 'package:afterclose/domain/services/rules/indicator_rules.dart';
import 'package:afterclose/domain/services/rules/technical_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late RuleEngine ruleEngine;

  setUp(() {
    ruleEngine = RuleEngine(
      customRules: [
        const WeakToStrongRule(),
        const DojiRule(),
        const BullishEngulfingRule(),
        const Week52HighRule(),
      ],
    );
  });

  group('Rule Reproduction Tests', () {
    test('DojiRule triggers on doji candle', () async {
      final prices = [
        DailyPriceEntry(
          symbol: '2330',
          date: DateTime(2024, 1, 1),
          open: 100,
          high: 105,
          low: 95,
          close: 100, // Doji
          volume: 1000,
        ),
      ];

      final context = AnalysisContext(trendState: TrendState.down);
      final reasons = ruleEngine.evaluateStock(
        priceHistory: prices,
        context: context,
        symbol: '2330',
      );

      expect(reasons.any((r) => r.type == ReasonType.patternDoji), isTrue);
    });

    test(
      'WeakToStrongRule triggers when context.reversalState is weakToStrong',
      () async {
        final prices = [
          DailyPriceEntry(
            symbol: '2330',
            date: DateTime(2024, 1, 1),
            open: 100,
            high: 105,
            low: 95,
            close: 102,
            volume: 1000,
          ),
        ];

        // Manually set reversalState to weakToStrong
        final context = AnalysisContext(
          trendState: TrendState.down,
          reversalState: ReversalState.weakToStrong,
        );

        final reasons = ruleEngine.evaluateStock(
          priceHistory: prices,
          context: context,
          symbol: '2330',
        );

        expect(reasons.any((r) => r.type == ReasonType.reversalW2S), isTrue);
      },
    );

    test('Week52HighRule triggers when price is near high', () async {
      // Create data with 250 days history
      final prices = List.generate(
        249,
        (i) => DailyPriceEntry(
          symbol: '2330',
          date: DateTime(2023, 1, 1).add(Duration(days: i)),
          open: 100,
          high: 100,
          low: 90,
          close: 100,
          volume: 1000,
        ),
      ).toList();

      // Add today as new high
      prices.add(
        DailyPriceEntry(
          symbol: '2330',
          date: DateTime(2023, 1, 1).add(Duration(days: 250)),
          open: 105,
          high: 110,
          low: 100,
          close: 110, // New High
          volume: 2000,
        ),
      );

      final context = AnalysisContext(trendState: TrendState.up);

      final reasons = ruleEngine.evaluateStock(
        priceHistory: prices,
        context: context,
        symbol: '2330',
      );

      expect(reasons.any((r) => r.type == ReasonType.week52High), isTrue);
    });
  });
}
