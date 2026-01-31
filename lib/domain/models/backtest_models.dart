import 'dart:math';

// ==================================================
// Backtest Config
// ==================================================

/// 回測設定
class BacktestConfig {
  const BacktestConfig({
    required this.periodMonths,
    required this.holdingDays,
    this.samplingInterval = 1,
  });

  /// 回測期間（月）：3, 6, 12
  final int periodMonths;

  /// 持有天數（交易日）：1, 3, 5, 10, 20
  final int holdingDays;

  /// 採樣間隔（交易日）：1 = 每天, 5 = 每 5 天
  final int samplingInterval;

  /// 回推日數
  int get totalDaysBack => periodMonths * 31;
}

// ==================================================
// Backtest Trade
// ==================================================

/// 單筆回測交易記錄
class BacktestTrade {
  const BacktestTrade({
    required this.symbol,
    required this.entryDate,
    required this.entryPrice,
    required this.exitDate,
    required this.exitPrice,
    required this.holdingDays,
    required this.returnPercent,
  });

  final String symbol;
  final DateTime entryDate;
  final double entryPrice;
  final DateTime exitDate;
  final double exitPrice;

  /// 持有交易日數
  final int holdingDays;

  /// 報酬率 %：(exit - entry) / entry * 100
  final double returnPercent;
}

// ==================================================
// Backtest Summary
// ==================================================

/// 回測統計摘要
class BacktestSummary {
  const BacktestSummary({
    required this.totalTrades,
    required this.winningTrades,
    required this.losingTrades,
    required this.avgReturn,
    required this.medianReturn,
    required this.maxReturn,
    required this.minReturn,
    required this.stdDeviation,
    required this.winRate,
    this.sharpeRatio,
  });

  final int totalTrades;
  final int winningTrades;
  final int losingTrades;
  final double avgReturn;
  final double medianReturn;
  final double maxReturn;
  final double minReturn;
  final double stdDeviation;
  final double winRate;
  final double? sharpeRatio;

  /// 從交易清單計算統計摘要
  factory BacktestSummary.fromTrades(List<BacktestTrade> trades) {
    if (trades.isEmpty) {
      return const BacktestSummary(
        totalTrades: 0,
        winningTrades: 0,
        losingTrades: 0,
        avgReturn: 0,
        medianReturn: 0,
        maxReturn: 0,
        minReturn: 0,
        stdDeviation: 0,
        winRate: 0,
      );
    }

    final returns = trades.map((t) => t.returnPercent).toList()..sort();
    final winning = trades.where((t) => t.returnPercent > 0).length;
    final losing = trades.where((t) => t.returnPercent < 0).length;

    final avgReturn = returns.reduce((a, b) => a + b) / returns.length;

    // 中位數
    final mid = returns.length ~/ 2;
    final medianReturn = returns.length.isOdd
        ? returns[mid]
        : (returns[mid - 1] + returns[mid]) / 2;

    // 標準差
    final variance =
        returns
            .map((r) => (r - avgReturn) * (r - avgReturn))
            .reduce((a, b) => a + b) /
        returns.length;
    final stdDev = sqrt(variance);

    // 夏普比率（假設無風險利率 = 0）
    final sharpe = stdDev > 0 ? avgReturn / stdDev : null;

    return BacktestSummary(
      totalTrades: trades.length,
      winningTrades: winning,
      losingTrades: losing,
      avgReturn: avgReturn,
      medianReturn: medianReturn,
      maxReturn: returns.last,
      minReturn: returns.first,
      stdDeviation: stdDev,
      winRate: winning / trades.length,
      sharpeRatio: sharpe,
    );
  }
}

// ==================================================
// Backtest Result
// ==================================================

/// 回測結果
class BacktestResult {
  const BacktestResult({
    required this.config,
    required this.trades,
    required this.summary,
    required this.executionTime,
    required this.tradingDaysScanned,
    this.skippedTrades = 0,
  });

  final BacktestConfig config;
  final List<BacktestTrade> trades;
  final BacktestSummary summary;
  final Duration executionTime;
  final int tradingDaysScanned;

  /// 因價格資料缺失而跳過的交易數
  final int skippedTrades;

  /// 報酬分佈 histogram (6 buckets)
  Map<String, int> get returnDistribution {
    final buckets = <String, int>{
      '< -10%': 0,
      '-10~-5%': 0,
      '-5~0%': 0,
      '0~5%': 0,
      '5~10%': 0,
      '> 10%': 0,
    };

    for (final trade in trades) {
      final ret = trade.returnPercent;
      if (ret < -10) {
        buckets['< -10%'] = buckets['< -10%']! + 1;
      } else if (ret < -5) {
        buckets['-10~-5%'] = buckets['-10~-5%']! + 1;
      } else if (ret < 0) {
        buckets['-5~0%'] = buckets['-5~0%']! + 1;
      } else if (ret < 5) {
        buckets['0~5%'] = buckets['0~5%']! + 1;
      } else if (ret < 10) {
        buckets['5~10%'] = buckets['5~10%']! + 1;
      } else {
        buckets['> 10%'] = buckets['> 10%']! + 1;
      }
    }

    return buckets;
  }
}
