import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/analysis_service.dart';
import 'package:afterclose/domain/services/rule_engine.dart';
import 'package:afterclose/domain/services/rules/candlestick_rules.dart';
import 'package:afterclose/domain/services/rules/indicator_rules.dart';
import 'package:afterclose/domain/services/rules/technical_rules.dart';
import 'package:afterclose/domain/services/rules/fundamental_scan_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late RuleEngine ruleEngine;

  setUp(() {
    ruleEngine = RuleEngine(
      customRules: [
        const WeakToStrongRule(),
        const DojiRule(),
        const Week52HighRule(),
        const KDGoldenCrossRule(),
        const PEUndervaluedRule(),
      ],
    );
  });

  group('Rule Reproduction Tests', () {
    test('KDGoldenCrossRule triggers on cross', () async {
      final prices = List.generate(
        20,
        (i) => DailyPriceEntry(
          symbol: '2330',
          date: DateTime(2024, 1, 1).add(Duration(days: i)),
          open: 100,
          close: 100,
          high: 100,
          low: 100,
          volume: 1000,
        ),
      ).toList();

      // Mock indicators
      // Yesterday: K < D (e.g. 15 < 18)
      // Today: K > D (e.g. 22 > 20)
      final indicators = TechnicalIndicators(
        kdK: 22,
        kdD: 20,
        prevKdK: 15,
        prevKdD: 18,
        rsi: 50,
      );

      final context = AnalysisContext(
        trendState: TrendState.range,
        indicators: indicators,
      );

      final reasons = ruleEngine.evaluateStock(
        priceHistory: prices,
        context: context,
        symbol: '2330',
      );

      expect(reasons.any((r) => r.type == ReasonType.kdGoldenCross), isTrue);
    });

    test('PEUndervaluedRule triggers on low PE', () async {
      final valuation = StockValuationEntry(
        symbol: '2330',
        date: DateTime(2024, 1, 1),
        per: 8.5, // Low PE
        dividendYield: 4.0,
        pbr: 1.2,
      );

      final context = AnalysisContext(trendState: TrendState.range);

      final reasons = ruleEngine.evaluateStock(
        priceHistory: [
          DailyPriceEntry(
            symbol: '2330',
            date: DateTime.now(),
            open: 1,
            close: 1,
            high: 1,
            low: 1,
            volume: 1,
          ),
        ], // Dummy
        context: context,
        symbol: '2330',
        latestValuation: valuation,
      );

      expect(reasons.any((r) => r.type == ReasonType.peUndervalued), isTrue);
    });
  });
}
