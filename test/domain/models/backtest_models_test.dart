import 'dart:math';

import 'package:afterclose/domain/models/backtest_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Helper: create a BacktestTrade with minimal required fields
  BacktestTrade createTrade({double returnPercent = 0.0, String symbol = 'A'}) {
    return BacktestTrade(
      symbol: symbol,
      entryDate: DateTime(2025, 1, 1),
      entryPrice: 100.0,
      exitDate: DateTime(2025, 1, 6),
      exitPrice: 100.0 + returnPercent,
      holdingDays: 5,
      returnPercent: returnPercent,
    );
  }

  // ==========================================
  // BacktestSummary.fromTrades
  // ==========================================
  group('BacktestSummary.fromTrades', () {
    test('returns zeros for empty trades', () {
      final summary = BacktestSummary.fromTrades([]);

      expect(summary.totalTrades, equals(0));
      expect(summary.winningTrades, equals(0));
      expect(summary.losingTrades, equals(0));
      expect(summary.avgReturn, equals(0));
      expect(summary.medianReturn, equals(0));
      expect(summary.maxReturn, equals(0));
      expect(summary.minReturn, equals(0));
      expect(summary.stdDeviation, equals(0));
      expect(summary.winRate, equals(0));
      expect(summary.sharpeRatio, isNull);
    });

    test('calculates avgReturn correctly', () {
      final trades = [
        createTrade(returnPercent: 10.0),
        createTrade(returnPercent: -5.0),
        createTrade(returnPercent: 15.0),
      ];

      final summary = BacktestSummary.fromTrades(trades);

      // avg = (10 + -5 + 15) / 3 ≈ 6.67
      expect(summary.avgReturn, closeTo(6.67, 0.01));
    });

    test('calculates medianReturn for odd count', () {
      final trades = [
        createTrade(returnPercent: 10.0),
        createTrade(returnPercent: -5.0),
        createTrade(returnPercent: 15.0),
      ];

      final summary = BacktestSummary.fromTrades(trades);

      // sorted: [-5, 10, 15] → median = 10
      expect(summary.medianReturn, equals(10.0));
    });

    test('calculates medianReturn for even count', () {
      final trades = [
        createTrade(returnPercent: 10.0),
        createTrade(returnPercent: -5.0),
        createTrade(returnPercent: 15.0),
        createTrade(returnPercent: 20.0),
      ];

      final summary = BacktestSummary.fromTrades(trades);

      // sorted: [-5, 10, 15, 20] → median = (10 + 15) / 2 = 12.5
      expect(summary.medianReturn, equals(12.5));
    });

    test('calculates winRate correctly', () {
      final trades = [
        createTrade(returnPercent: 10.0), // win
        createTrade(returnPercent: -5.0), // lose
        createTrade(returnPercent: 0.0), // neither (not > 0)
        createTrade(returnPercent: 3.0), // win
      ];

      final summary = BacktestSummary.fromTrades(trades);

      expect(summary.winningTrades, equals(2));
      expect(summary.losingTrades, equals(1));
      expect(summary.winRate, equals(0.5)); // 2/4
    });

    test('calculates stdDeviation correctly', () {
      final trades = [
        createTrade(returnPercent: 10.0),
        createTrade(returnPercent: 20.0),
        createTrade(returnPercent: 30.0),
      ];

      final summary = BacktestSummary.fromTrades(trades);

      // avg = 20, variance = ((10-20)^2 + (20-20)^2 + (30-20)^2) / 3 = 200/3
      // stdDev = sqrt(200/3) ≈ 8.165
      expect(summary.stdDeviation, closeTo(sqrt(200.0 / 3), 0.01));
    });

    test('calculates sharpeRatio (risk-free = 0)', () {
      final trades = [
        createTrade(returnPercent: 10.0),
        createTrade(returnPercent: 20.0),
        createTrade(returnPercent: 30.0),
      ];

      final summary = BacktestSummary.fromTrades(trades);

      // sharpe = avgReturn / stdDev = 20 / sqrt(200/3) ≈ 2.449
      expect(summary.sharpeRatio, isNotNull);
      expect(summary.sharpeRatio!, closeTo(20.0 / sqrt(200.0 / 3), 0.01));
    });

    test('sharpeRatio is null when stdDev is 0', () {
      final trades = [
        createTrade(returnPercent: 5.0),
        createTrade(returnPercent: 5.0),
        createTrade(returnPercent: 5.0),
      ];

      final summary = BacktestSummary.fromTrades(trades);

      // All same → stdDev = 0 → sharpe = null
      expect(summary.stdDeviation, equals(0.0));
      expect(summary.sharpeRatio, isNull);
    });

    test('tracks maxReturn and minReturn', () {
      final trades = [
        createTrade(returnPercent: -15.0),
        createTrade(returnPercent: 5.0),
        createTrade(returnPercent: 25.0),
      ];

      final summary = BacktestSummary.fromTrades(trades);

      expect(summary.maxReturn, equals(25.0));
      expect(summary.minReturn, equals(-15.0));
    });
  });

  // ==========================================
  // BacktestResult.returnDistribution
  // ==========================================
  group('BacktestResult.returnDistribution', () {
    BacktestResult createResult(List<BacktestTrade> trades) {
      return BacktestResult(
        config: const BacktestConfig(periodMonths: 3, holdingDays: 5),
        trades: trades,
        summary: BacktestSummary.fromTrades(trades),
        executionTime: const Duration(milliseconds: 100),
        tradingDaysScanned: 60,
      );
    }

    test('returns all-zero buckets for empty trades', () {
      final result = createResult([]);

      final dist = result.returnDistribution;
      expect(dist.values.every((v) => v == 0), isTrue);
      expect(dist.length, equals(6));
    });

    test('distributes trades into correct buckets', () {
      final trades = [
        createTrade(returnPercent: -15.0), // < -10%
        createTrade(returnPercent: -7.0), // -10~-5%
        createTrade(returnPercent: -2.0), // -5~0%
        createTrade(returnPercent: 3.0), // 0~5%
        createTrade(returnPercent: 8.0), // 5~10%
        createTrade(returnPercent: 12.0), // > 10%
      ];

      final result = createResult(trades);
      final dist = result.returnDistribution;

      expect(dist['< -10%'], equals(1));
      expect(dist['-10~-5%'], equals(1));
      expect(dist['-5~0%'], equals(1));
      expect(dist['0~5%'], equals(1));
      expect(dist['5~10%'], equals(1));
      expect(dist['> 10%'], equals(1));
    });

    test('handles boundary values correctly', () {
      final trades = [
        createTrade(returnPercent: -10.0), // -10 → -10~-5% bucket (>= -10)
        createTrade(returnPercent: -5.0), // -5 → -5~0% bucket (>= -5)
        createTrade(returnPercent: 0.0), // 0 → 0~5% bucket (>= 0)
        createTrade(returnPercent: 5.0), // 5 → 5~10% bucket (>= 5)
        createTrade(returnPercent: 10.0), // 10 → > 10% bucket (>= 10)
      ];

      final result = createResult(trades);
      final dist = result.returnDistribution;

      expect(dist['< -10%'], equals(0));
      expect(dist['-10~-5%'], equals(1));
      expect(dist['-5~0%'], equals(1));
      expect(dist['0~5%'], equals(1));
      expect(dist['5~10%'], equals(1));
      expect(dist['> 10%'], equals(1));
    });
  });

  // ==========================================
  // BacktestConfig
  // ==========================================
  group('BacktestConfig', () {
    test('totalDaysBack calculated from periodMonths', () {
      const config = BacktestConfig(periodMonths: 6, holdingDays: 5);
      expect(config.totalDaysBack, equals(186)); // 6 * 31
    });
  });
}
