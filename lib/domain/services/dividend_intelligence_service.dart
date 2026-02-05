import 'package:afterclose/data/database/app_database.dart';

/// 股利智慧分析服務
///
/// 提供股利相關的計算與預測：
/// - 持倉預期年度股利
/// - 個人殖利率（以成本計算）
/// - 股利趨勢分析
class DividendIntelligenceService {
  const DividendIntelligenceService();

  /// 計算持倉的股利預測資訊
  ///
  /// [positions] 持倉列表
  /// [dividendHistories] symbol -> 股利歷史
  /// [currentPrices] symbol -> 目前價格
  DividendAnalysis analyzeDividends({
    required List<PortfolioPositionEntry> positions,
    required Map<String, List<DividendHistoryEntry>> dividendHistories,
    required Map<String, double> currentPrices,
  }) {
    if (positions.isEmpty) return DividendAnalysis.empty;

    double totalExpectedDividend = 0;
    double totalCostBasis = 0;
    double totalMarketValue = 0;
    final stockDividends = <StockDividendInfo>[];

    for (final pos in positions) {
      if (pos.quantity <= 0) continue;

      final history = dividendHistories[pos.symbol] ?? [];
      final currentPrice = currentPrices[pos.symbol] ?? pos.avgCost;
      final costBasis = pos.quantity * pos.avgCost;
      final marketValue = pos.quantity * currentPrice;

      totalCostBasis += costBasis;
      totalMarketValue += marketValue;

      // 預估年度股利（使用最近一年或平均）
      final estimatedDividend = _estimateAnnualDividend(history);
      final expectedYearlyAmount = estimatedDividend * pos.quantity;
      totalExpectedDividend += expectedYearlyAmount;

      // 計算殖利率
      final personalYield = costBasis > 0
          ? (expectedYearlyAmount / costBasis) * 100
          : 0.0;
      final marketYield = marketValue > 0
          ? (expectedYearlyAmount / marketValue) * 100
          : 0.0;

      // 股利趨勢
      final trend = _analyzeTrend(history);

      stockDividends.add(
        StockDividendInfo(
          symbol: pos.symbol,
          shares: pos.quantity,
          avgCost: pos.avgCost,
          currentPrice: currentPrice,
          estimatedDividendPerShare: estimatedDividend,
          expectedYearlyAmount: expectedYearlyAmount,
          personalYield: personalYield,
          marketYield: marketYield,
          trend: trend,
          lastDividend: history.isNotEmpty ? history.first : null,
        ),
      );
    }

    // 計算組合整體殖利率
    final portfolioYieldOnCost = totalCostBasis > 0
        ? (totalExpectedDividend / totalCostBasis) * 100
        : 0.0;
    final portfolioYieldOnMarket = totalMarketValue > 0
        ? (totalExpectedDividend / totalMarketValue) * 100
        : 0.0;

    // 按預期股利金額排序
    stockDividends.sort(
      (a, b) => b.expectedYearlyAmount.compareTo(a.expectedYearlyAmount),
    );

    return DividendAnalysis(
      totalExpectedDividend: totalExpectedDividend,
      portfolioYieldOnCost: portfolioYieldOnCost,
      portfolioYieldOnMarket: portfolioYieldOnMarket,
      stockDividends: stockDividends,
    );
  }

  /// 預估年度股利（每股）
  ///
  /// 策略：
  /// 1. 如果有當年度資料，使用當年度
  /// 2. 否則使用最近 3 年平均
  /// 3. 若資料不足，使用最近一年
  double _estimateAnnualDividend(List<DividendHistoryEntry> history) {
    if (history.isEmpty) return 0;

    final currentYear = DateTime.now().year;

    // 嘗試找當年度資料
    final thisYearData = history.where((h) => h.year == currentYear).toList();
    if (thisYearData.isNotEmpty) {
      final entry = thisYearData.first;
      return entry.cashDividend + entry.stockDividend;
    }

    // 計算最近 3 年平均
    final recentYears = history.take(3).toList();
    if (recentYears.isEmpty) return 0;

    double totalDividend = 0;
    for (final entry in recentYears) {
      totalDividend += entry.cashDividend + entry.stockDividend;
    }

    return totalDividend / recentYears.length;
  }

  /// 分析股利趨勢
  DividendTrend _analyzeTrend(List<DividendHistoryEntry> history) {
    if (history.length < 2) return DividendTrend.stable;

    // 比較最近兩年的股利變化
    final recent = history.first;
    final previous = history[1];

    final recentTotal = recent.cashDividend + recent.stockDividend;
    final previousTotal = previous.cashDividend + previous.stockDividend;

    if (previousTotal == 0) {
      return recentTotal > 0 ? DividendTrend.increasing : DividendTrend.stable;
    }

    final changePercent = ((recentTotal - previousTotal) / previousTotal) * 100;

    if (changePercent > 10) {
      return DividendTrend.increasing;
    } else if (changePercent < -10) {
      return DividendTrend.decreasing;
    } else {
      return DividendTrend.stable;
    }
  }

  /// 找出即將除息的持股
  ///
  /// [positions] 持倉列表
  /// [dividendHistories] symbol -> 股利歷史
  /// [daysAhead] 往後查詢天數（預設 60 天）
  List<UpcomingDividend> findUpcomingDividends({
    required List<PortfolioPositionEntry> positions,
    required Map<String, List<DividendHistoryEntry>> dividendHistories,
    int daysAhead = 60,
  }) {
    final upcoming = <UpcomingDividend>[];
    final now = DateTime.now();
    final cutoffDate = now.add(Duration(days: daysAhead));

    for (final pos in positions) {
      if (pos.quantity <= 0) continue;

      final history = dividendHistories[pos.symbol] ?? [];
      if (history.isEmpty) continue;

      // 找最近的除息日（可能是今年或去年的資料）
      for (final entry in history) {
        if (entry.exDividendDate == null) continue;

        try {
          final exDate = DateTime.parse(entry.exDividendDate!);
          if (exDate.isAfter(now) && exDate.isBefore(cutoffDate)) {
            upcoming.add(
              UpcomingDividend(
                symbol: pos.symbol,
                exDividendDate: exDate,
                cashDividend: entry.cashDividend,
                stockDividend: entry.stockDividend,
                shares: pos.quantity,
                estimatedAmount: entry.cashDividend * pos.quantity,
              ),
            );
          }
        } on FormatException {
          // 忽略無效日期格式
        }
      }
    }

    // 按除息日排序
    upcoming.sort((a, b) => a.exDividendDate.compareTo(b.exDividendDate));
    return upcoming;
  }
}

/// 股利分析結果
class DividendAnalysis {
  const DividendAnalysis({
    required this.totalExpectedDividend,
    required this.portfolioYieldOnCost,
    required this.portfolioYieldOnMarket,
    required this.stockDividends,
  });

  /// 預期年度股利總額
  final double totalExpectedDividend;

  /// 組合殖利率（以成本計算）
  final double portfolioYieldOnCost;

  /// 組合殖利率（以市價計算）
  final double portfolioYieldOnMarket;

  /// 各持股的股利資訊
  final List<StockDividendInfo> stockDividends;

  static const empty = DividendAnalysis(
    totalExpectedDividend: 0,
    portfolioYieldOnCost: 0,
    portfolioYieldOnMarket: 0,
    stockDividends: [],
  );
}

/// 單一持股的股利資訊
class StockDividendInfo {
  const StockDividendInfo({
    required this.symbol,
    required this.shares,
    required this.avgCost,
    required this.currentPrice,
    required this.estimatedDividendPerShare,
    required this.expectedYearlyAmount,
    required this.personalYield,
    required this.marketYield,
    required this.trend,
    this.lastDividend,
  });

  final String symbol;
  final double shares;
  final double avgCost;
  final double currentPrice;

  /// 預估每股股利
  final double estimatedDividendPerShare;

  /// 預期年度股利金額
  final double expectedYearlyAmount;

  /// 個人殖利率（以成本計算）
  final double personalYield;

  /// 市場殖利率（以現價計算）
  final double marketYield;

  /// 股利趨勢
  final DividendTrend trend;

  /// 最近一筆股利記錄
  final DividendHistoryEntry? lastDividend;
}

/// 股利趨勢
enum DividendTrend { increasing, stable, decreasing }

/// 即將到來的除息
class UpcomingDividend {
  const UpcomingDividend({
    required this.symbol,
    required this.exDividendDate,
    required this.cashDividend,
    required this.stockDividend,
    required this.shares,
    required this.estimatedAmount,
  });

  final String symbol;
  final DateTime exDividendDate;
  final double cashDividend;
  final double stockDividend;
  final double shares;

  /// 預估股利金額
  final double estimatedAmount;

  /// 距離除息日天數
  int get daysUntil => exDividendDate.difference(DateTime.now()).inDays;
}
