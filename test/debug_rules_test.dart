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
      // Build prices that satisfy:
      // 1. Today's volume > 5-day MA (last day has spike volume)
      // 2. Price change >= 1% (last day close > prev close by 2%)
      final prices = List.generate(20, (i) {
        final isLastDay = i == 19;
        const baseClose = 100.0;
        return DailyPriceEntry(
          symbol: '2330',
          date: DateTime.now().subtract(Duration(days: 20 - i)),
          open: baseClose,
          close: isLastDay ? 102.0 : baseClose, // 2% rise on last day
          high: isLastDay ? 103.0 : baseClose + 1,
          low: baseClose - 1,
          volume: isLastDay ? 5000 : 1000, // Volume spike on last day
        );
      }).toList();

      // Mock indicators
      // Yesterday: K < D (e.g. 15 < 18)
      // Today: K > D (e.g. 22 > 20)
      const indicators = TechnicalIndicators(
        kdK: 22,
        kdD: 20,
        prevKdK: 15,
        prevKdD: 18,
        rsi: 50,
      );

      const context = AnalysisContext(
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
        date: DateTime.now(),
        per: 8.5, // Low PE
        dividendYield: 4.0,
        pbr: 1.2,
      );

      const context = AnalysisContext(trendState: TrendState.range);

      // Need at least 20 price entries to calculate MA20
      // And close must be > ma20 to pass the filter
      // Base prices at 100, last price at 110 (above MA20)
      final prices = List.generate(25, (i) {
        final isRecent = i >= 20; // Last 5 days rise
        return DailyPriceEntry(
          symbol: '2330',
          date: DateTime.now().subtract(Duration(days: 25 - i)),
          open: 100.0,
          close: isRecent ? 110.0 : 100.0, // Last 5 days above MA20
          high: isRecent ? 112.0 : 102.0,
          low: 98.0,
          volume: 1000000,
        );
      });

      final reasons = ruleEngine.evaluateStock(
        priceHistory: prices,
        context: context,
        symbol: '2330',
        latestValuation: valuation,
      );

      expect(reasons.any((r) => r.type == ReasonType.peUndervalued), isTrue);
    });
  });
}
