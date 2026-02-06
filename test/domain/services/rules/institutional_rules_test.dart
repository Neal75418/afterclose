import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/models.dart';
import 'package:afterclose/domain/services/rules/institutional_rules.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// 建構法人買超連續資料
List<DailyInstitutionalEntry> _generateBuyStreak({
  required int days,
  double foreignNet = 400000,
  double trustNet = 200000,
  String symbol = 'TEST',
}) {
  final now = DateTime.now();
  return List.generate(days, (i) {
    return DailyInstitutionalEntry(
      symbol: symbol,
      date: now.subtract(Duration(days: days - i - 1)),
      foreignNet: foreignNet,
      investmentTrustNet: trustNet,
      dealerNet: 0,
    );
  });
}

/// 建構法人賣超連續資料
List<DailyInstitutionalEntry> _generateSellStreak({
  required int days,
  double foreignNet = -400000,
  double trustNet = -200000,
  String symbol = 'TEST',
}) {
  final now = DateTime.now();
  return List.generate(days, (i) {
    return DailyInstitutionalEntry(
      symbol: symbol,
      date: now.subtract(Duration(days: days - i - 1)),
      foreignNet: foreignNet,
      investmentTrustNet: trustNet,
      dealerNet: 0,
    );
  });
}

void main() {
  // ==========================================
  // InstitutionalBuyStreakRule
  // ==========================================
  group('InstitutionalBuyStreakRule', () {
    const rule = InstitutionalBuyStreakRule();

    test('triggers with consecutive buy days meeting all thresholds', () {
      // 5 days, each: foreign 400000 + trust 200000 = 600000 > 50000 (min)
      // totalNet = 600000 * 5 = 3000000 > 2000000 (totalThreshold)
      // dailyAvg = 600000 > 300000 (dailyAvgThreshold)
      // significantDays: 600000 > 150000 → all 5 days significant (5 >= 5/2)
      final institutional = _generateBuyStreak(days: 5);
      const context = AnalysisContext(trendState: TrendState.range);
      final data = StockData(
        symbol: 'TEST',
        prices: [],
        institutional: institutional,
      );

      final result = rule.evaluate(context, data);

      expect(result, isNotNull);
      expect(result!.type, equals(ReasonType.institutionalBuyStreak));
      expect(result.evidence!['streakDays'], equals(5));
    });

    test('applies trust-dominant bonus when trust > foreign', () {
      // trust 400000 > foreign 200000 → isTrustDominant = true
      final institutional = _generateBuyStreak(
        days: 5,
        foreignNet: 200000,
        trustNet: 400000,
      );
      const context = AnalysisContext(trendState: TrendState.range);
      final data = StockData(
        symbol: 'TEST',
        prices: [],
        institutional: institutional,
      );

      final result = rule.evaluate(context, data);

      expect(result, isNotNull);
      expect(result!.score, equals(RuleScores.institutionalBuyStreak + 5));
      expect(result.evidence!['trustDominant'], isTrue);
    });

    test('does not trigger when total net is below threshold', () {
      // Each day combined = 80000, 5 days total = 400000 < 2000000
      final institutional = _generateBuyStreak(
        days: 5,
        foreignNet: 50000,
        trustNet: 30000,
      );
      const context = AnalysisContext(trendState: TrendState.range);
      final data = StockData(
        symbol: 'TEST',
        prices: [],
        institutional: institutional,
      );

      expect(rule.evaluate(context, data), isNull);
    });

    test('does not trigger when daily avg is below threshold', () {
      // 10 days, each 250000 combined → total 2500000 > 2000000
      // dailyAvg = 250000 < 300000
      final institutional = _generateBuyStreak(
        days: 10,
        foreignNet: 150000,
        trustNet: 100000,
      );
      const context = AnalysisContext(trendState: TrendState.range);
      final data = StockData(
        symbol: 'TEST',
        prices: [],
        institutional: institutional,
      );

      expect(rule.evaluate(context, data), isNull);
    });

    test('does not trigger when significant days are too few', () {
      // 6 days with combined between 50000-150000 (streak continues but not significant)
      // Only last 2 days are significant (combined > 150000)
      final now = DateTime.now();
      const context = AnalysisContext(trendState: TrendState.range);

      final institutional = List.generate(6, (i) {
        final isSignificant = i >= 4; // Only last 2 are significant
        return DailyInstitutionalEntry(
          symbol: 'TEST',
          date: now.subtract(Duration(days: 5 - i)),
          foreignNet: isSignificant ? 600000 : 70000,
          investmentTrustNet: isSignificant ? 300000 : 30000,
          dealerNet: 0,
        );
      });
      // non-sig combined = 100000 > 50000 (streak continues)
      // but 100000 < 150000 (not significant)
      // significant days: 2 of 6 → 2 < 3 → fails
      // total = 4*100000 + 2*900000 = 2200000 > 2000000
      // dailyAvg = 366666 > 300000
      final data = StockData(
        symbol: 'TEST',
        prices: [],
        institutional: institutional,
      );

      expect(rule.evaluate(context, data), isNull);
    });

    test('does not trigger with insufficient history', () {
      final institutional = _generateBuyStreak(days: 2);
      const context = AnalysisContext(trendState: TrendState.range);
      final data = StockData(
        symbol: 'TEST',
        prices: [],
        institutional: institutional,
      );

      expect(rule.evaluate(context, data), isNull);
    });

    test('does not trigger when institutional data is null', () {
      const context = AnalysisContext(trendState: TrendState.range);
      const data = StockData(symbol: 'TEST', prices: []);

      expect(rule.evaluate(context, data), isNull);
    });
  });

  // ==========================================
  // InstitutionalSellStreakRule
  // ==========================================
  group('InstitutionalSellStreakRule', () {
    const rule = InstitutionalSellStreakRule();

    test('triggers with consecutive sell days meeting all thresholds', () {
      // 5 days, each: foreign -400000 + trust -200000 = -600000 < -50000
      // totalNet = -3000000 < -2000000
      // dailyAvg = -600000 < -300000
      // significantDays: |-600000| > 150000 → all 5 significant
      final institutional = _generateSellStreak(days: 5);
      const context = AnalysisContext(trendState: TrendState.range);
      final data = StockData(
        symbol: 'TEST',
        prices: [],
        institutional: institutional,
      );

      final result = rule.evaluate(context, data);

      expect(result, isNotNull);
      expect(result!.type, equals(ReasonType.institutionalSellStreak));
      expect(result.evidence!['streakDays'], equals(5));
    });

    test(
      'applies trust-dominant penalty when trust sells more than foreign',
      () {
        final institutional = _generateSellStreak(
          days: 5,
          foreignNet: -200000,
          trustNet: -400000,
        );
        const context = AnalysisContext(trendState: TrendState.range);
        final data = StockData(
          symbol: 'TEST',
          prices: [],
          institutional: institutional,
        );

        final result = rule.evaluate(context, data);

        expect(result, isNotNull);
        expect(result!.score, equals(RuleScores.institutionalSellStreak - 5));
        expect(result.evidence!['trustDominant'], isTrue);
      },
    );

    test('does not trigger when total net is above threshold', () {
      // Small sells: combined = -80000 per day, 5 days = -400000 > -2000000
      final institutional = _generateSellStreak(
        days: 5,
        foreignNet: -50000,
        trustNet: -30000,
      );
      const context = AnalysisContext(trendState: TrendState.range);
      final data = StockData(
        symbol: 'TEST',
        prices: [],
        institutional: institutional,
      );

      expect(rule.evaluate(context, data), isNull);
    });

    test('does not trigger when institutional data is null', () {
      const context = AnalysisContext(trendState: TrendState.range);
      const data = StockData(symbol: 'TEST', prices: []);

      expect(rule.evaluate(context, data), isNull);
    });

    test('streak breaks on non-sell day', () {
      // 5 days of sell, then 1 buy day, then 2 sells at end
      // Streak from end: only 2 days < 4 minimum
      final now = DateTime.now();
      final institutional = List.generate(8, (i) {
        final isBuyDay = i == 5; // Day 5 is a buy (breaks streak)
        return DailyInstitutionalEntry(
          symbol: 'TEST',
          date: now.subtract(Duration(days: 7 - i)),
          foreignNet: isBuyDay ? 200000 : -400000,
          investmentTrustNet: isBuyDay ? 100000 : -200000,
          dealerNet: 0,
        );
      });
      const context = AnalysisContext(trendState: TrendState.range);
      final data = StockData(
        symbol: 'TEST',
        prices: [],
        institutional: institutional,
      );

      // From end: day 7(-600k), day 6(-600k), day 5(+300k → breaks)
      // Streak = 2 < 4 → no trigger
      expect(rule.evaluate(context, data), isNull);
    });
  });
}
