import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/domain/models/models.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';

// ==========================================
// 第 6 階段：基本面分析規則
// ==========================================

// 輔助函數：計算 MA
double? _calculateMA(List<dynamic> prices, int period) {
  if (prices.length < period) return null;
  double sum = 0;
  int count = 0;
  for (int i = prices.length - 1; i >= prices.length - period; i--) {
    final close = prices[i].close;
    if (close != null) {
      sum += close;
      count++;
    }
  }
  return count == period ? sum / count : null;
}

// 輔助函數：計算 RSI
double? _calculateRSI(List<dynamic> prices, int period) {
  if (prices.length < period + 1) return null;
  double gains = 0;
  double losses = 0;
  for (int i = prices.length - period; i < prices.length; i++) {
    final current = prices[i].close;
    final previous = prices[i - 1].close;
    if (current == null || previous == null) continue;
    final change = current - previous;
    if (change > 0) {
      gains += change;
    } else {
      losses += -change;
    }
  }
  final avgGain = gains / period;
  final avgLoss = losses / period;
  if (avgLoss == 0) return 100;
  final rs = avgGain / avgLoss;
  return 100 - (100 / (1 + rs));
}

/// 規則：營收年增暴增
///
/// 當月營收年增率 > 50% 且股價站上 MA60 時觸發
class RevenueYoYSurgeRule extends StockRule {
  const RevenueYoYSurgeRule();

  @override
  String get id => 'revenue_yoy_surge';

  @override
  String get name => '營收年增暴增';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final revenue = data.latestRevenue;
    if (revenue == null) return null;

    final yoyGrowth = revenue.yoyGrowth ?? 0;

    if (yoyGrowth >= RuleParams.revenueYoySurgeThreshold) {
      // 技術面過濾：須站上 MA60 且漲幅 > 1.5%
      final ma60 = _calculateMA(data.prices, 60);

      final today = data.prices.isNotEmpty ? data.prices.last : null;
      final prev = data.prices.length >= 2
          ? data.prices[data.prices.length - 2]
          : null;

      if (ma60 != null &&
          today != null &&
          prev != null &&
          prev.close != null &&
          prev.close! > 0) {
        final close = today.close ?? 0;
        final prevClose = prev.close!;
        final changePct = (close - prevClose) / prevClose;

        // 兩個過濾條件都須通過
        if (close > ma60 && changePct > 0.015) {
          return TriggeredReason(
            type: ReasonType.revenueYoySurge,
            score: RuleScores.revenueYoySurge,
            description: '營收年增 ${yoyGrowth.toStringAsFixed(1)}% (站上季線且長紅)',
            evidence: {
              'yoyGrowth': yoyGrowth,
              'revenueMonth': revenue.revenueMonth,
              'ma60': ma60,
              'changePct': changePct * 100,
            },
          );
        }
      }
    }

    return null;
  }
}

/// 規則：營收年減警示
///
/// v0.1.2：移除 MA60 過濾，只看營收年減率 < -20% 即可
class RevenueYoYDeclineRule extends StockRule {
  const RevenueYoYDeclineRule();

  @override
  String get id => 'revenue_yoy_decline';

  @override
  String get name => '營收年減警示';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final revenue = data.latestRevenue;
    if (revenue == null) return null;

    final yoyGrowth = revenue.yoyGrowth ?? 0;

    if (yoyGrowth <= -RuleParams.revenueYoyDeclineThreshold) {
      return TriggeredReason(
        type: ReasonType.revenueYoyDecline,
        score: RuleScores.revenueYoyDecline,
        description: '營收年減 ${yoyGrowth.abs().toStringAsFixed(1)}%',
        evidence: {
          'yoyGrowth': yoyGrowth,
          'revenueMonth': revenue.revenueMonth,
        },
      );
    }

    return null;
  }
}

/// 規則：營收月增持續
///
/// 當月營收月增為正且股價站上 MA20 時觸發
class RevenueMomGrowthRule extends StockRule {
  const RevenueMomGrowthRule();

  @override
  String get id => 'revenue_mom_growth';

  @override
  String get name => '營收月增持續';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final history = data.revenueHistory;
    if (history == null ||
        history.length < RuleParams.revenueMomConsecutiveMonths) {
      return null;
    }

    // 檢查連續月增長
    int consecutiveMonths = 0;
    final growthRates = <double>[];

    for (
      int i = 0;
      i < history.length && i < RuleParams.revenueMomConsecutiveMonths;
      i++
    ) {
      final momGrowth = history[i].momGrowth ?? 0;
      if (momGrowth >= RuleParams.revenueMomGrowthThreshold) {
        consecutiveMonths++;
        growthRates.add(momGrowth);
      } else {
        break;
      }
    }

    if (consecutiveMonths >= RuleParams.revenueMomConsecutiveMonths) {
      // 技術面過濾：須站上 MA20
      final ma20 = _calculateMA(data.prices, 20);
      final close = data.prices.isNotEmpty ? data.prices.last.close : null;

      // 技術面過濾：站上 MA20 且漲幅 > 1.5%
      final today = data.prices.isNotEmpty ? data.prices.last : null;
      final prev = data.prices.length >= 2
          ? data.prices[data.prices.length - 2]
          : null;
      final changePct =
          (today != null &&
              today.close != null &&
              prev != null &&
              prev.close != null &&
              prev.close! > 0)
          ? (today.close! - prev.close!) / prev.close!
          : 0.0;

      if (ma20 != null && close != null && close > ma20 && changePct > 0.015) {
        final avgGrowth =
            growthRates.reduce((a, b) => a + b) / growthRates.length;
        final description = consecutiveMonths == 1
            ? '本月營收月增 ${avgGrowth.toStringAsFixed(1)}% (站上月線)'
            : '營收月增連續 $consecutiveMonths 個月 (站上月線)';

        return TriggeredReason(
          type: ReasonType.revenueMomGrowth,
          score: RuleScores.revenueMomGrowth,
          description: description,
          evidence: {
            'consecutiveMonths': consecutiveMonths,
            'avgMomGrowth': avgGrowth,
            'ma20': ma20,
          },
        );
      }
    }
    return null;
  }
}

/// 規則：高殖利率
class HighDividendYieldRule extends StockRule {
  const HighDividendYieldRule();

  @override
  String get id => 'high_dividend_yield';

  @override
  String get name => '高殖利率';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final valuation = data.latestValuation;
    if (valuation == null) return null;

    // 資料新鮮度檢查：確保估值資料在有效期限內
    // TWSE 並非每日更新所有股票，過時資料可能導致誤判
    final dataAge = DateTime.now().difference(valuation.date).inDays;
    if (dataAge > RuleParams.valuationMaxStaleDays) {
      AppLogger.debug(
        'HighYieldRule',
        '${data.symbol}: 資料過時 ($dataAge 天)，跳過評估',
      );
      return null;
    }

    // TWSE 和 FinMind 的殖利率已經是百分比格式（5.23 = 5.23%）
    // 不需要額外正規化
    final dividendYield = valuation.dividendYield ?? 0;

    // 診斷日誌：記錄所有被評估的殖利率數值（僅記錄 >= 4% 的以減少雜訊）
    if (dividendYield >= 4.0) {
      AppLogger.debug(
        'HighYieldRule',
        '${data.symbol}: 殖利率=${dividendYield.toStringAsFixed(2)}%, '
            '日期=${valuation.date.toIso8601String().substring(0, 10)}',
      );
    }

    // 過濾無效或過低殖利率（< 5%）
    if (dividendYield < RuleParams.highDividendYieldThreshold) {
      return null;
    }

    // 過濾異常高殖利率（> 20% 通常為資料錯誤或特殊情況）
    if (dividendYield > 20) {
      return null;
    }

    return TriggeredReason(
      type: ReasonType.highDividendYield,
      score: RuleScores.highDividendYield,
      description: '殖利率 ${dividendYield.toStringAsFixed(2)}%',
      evidence: {
        'dividendYield': dividendYield,
        'date': valuation.date.toIso8601String(),
      },
    );
  }
}

/// 規則：PE 低估
class PEUndervaluedRule extends StockRule {
  const PEUndervaluedRule();

  @override
  String get id => 'pe_undervalued';

  @override
  String get name => 'PE 低估';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final valuation = data.latestValuation;
    if (valuation == null) return null;

    // 資料新鮮度檢查
    final dataAge = DateTime.now().difference(valuation.date).inDays;
    if (dataAge > RuleParams.valuationMaxStaleDays) {
      return null;
    }

    final pe = valuation.per ?? 0;

    if (pe > 0 && pe <= RuleParams.peUndervaluedThreshold) {
      // 過濾條件：須顯示強勢跡象（股價 > MA20）
      final ma20 = _calculateMA(data.prices, 20);
      final close = data.prices.isNotEmpty ? data.prices.last.close : null;

      if (ma20 != null && close != null && close > ma20) {
        return TriggeredReason(
          type: ReasonType.peUndervalued,
          score: RuleScores.peUndervalued,
          description: 'PE 僅 ${pe.toStringAsFixed(2)} 倍 (站上月線)',
          evidence: {'pe': pe, 'ma20': ma20},
        );
      }
    }
    return null;
  }
}

/// 規則：PE 偏高
class PEOvervaluedRule extends StockRule {
  const PEOvervaluedRule();

  @override
  String get id => 'pe_overvalued';

  @override
  String get name => 'PE 偏高';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final valuation = data.latestValuation;
    if (valuation == null) return null;

    // 資料新鮮度檢查
    final dataAge = DateTime.now().difference(valuation.date).inDays;
    if (dataAge > RuleParams.valuationMaxStaleDays) {
      return null;
    }

    final pe = valuation.per ?? 0;

    if (pe >= RuleParams.peOvervaluedThreshold) {
      // 過濾條件：須處於過熱狀態（RSI > 70）
      final rsi = _calculateRSI(data.prices, 14);
      if (rsi != null && rsi > 75) {
        return TriggeredReason(
          type: ReasonType.peOvervalued,
          score: RuleScores.peOvervalued,
          description: 'PE 高達 ${pe.toStringAsFixed(1)} 倍 (RSI過熱)',
          evidence: {'pe': pe, 'rsi': rsi},
        );
      }
    }
    return null;
  }
}

/// 規則：PBR 低估
class PBRUndervaluedRule extends StockRule {
  const PBRUndervaluedRule();

  @override
  String get id => 'pbr_undervalued';

  @override
  String get name => '股價淨值比低於 0.8';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final valuation = data.latestValuation;
    if (valuation == null) return null;

    // 資料新鮮度檢查
    final dataAge = DateTime.now().difference(valuation.date).inDays;
    if (dataAge > RuleParams.valuationMaxStaleDays) {
      return null;
    }

    final pbr = valuation.pbr ?? 0;

    if (pbr > 0 && pbr <= RuleParams.pbrUndervaluedThreshold) {
      return TriggeredReason(
        type: ReasonType.pbrUndervalued,
        score: RuleScores.pbrUndervalued,
        description: 'PBR 僅 ${pbr.toStringAsFixed(2)} 倍',
        evidence: {'pbr': pbr},
      );
    }
    return null;
  }
}
