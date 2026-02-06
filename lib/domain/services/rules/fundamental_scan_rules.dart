import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/domain/models/models.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';
import 'package:afterclose/domain/services/technical_indicator_service.dart';

// ==========================================
// 第 6 階段：基本面分析規則
// ==========================================

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
      final ma60 = TechnicalIndicatorService.latestSMA(data.prices, 60);

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
        if (close > ma60 && changePct > RuleParams.minPriceChangeForVolume) {
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
      final ma20 = TechnicalIndicatorService.latestSMA(data.prices, 20);
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

      if (ma20 != null &&
          close != null &&
          close > ma20 &&
          changePct > RuleParams.minPriceChangeForVolume) {
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
    if (dividendYield >= RuleParams.scanDividendYieldMin) {
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
    if (dividendYield > RuleParams.scanDividendYieldMax) {
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
      final ma20 = TechnicalIndicatorService.latestSMA(data.prices, 20);
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
      final rsi = TechnicalIndicatorService.latestRSI(data.prices);
      if (rsi != null && rsi > RuleParams.scanRsiOverboughtThreshold) {
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

// ==========================================
// 第 7 階段：EPS 分析規則
// ==========================================

/// 規則：EPS 年增暴增
///
/// 最新一季 EPS 年增率 ≥ 50%，搭配站上季線(MA60) + 長紅
class EPSYoYSurgeRule extends StockRule {
  const EPSYoYSurgeRule();

  @override
  String get id => 'eps_yoy_surge';

  @override
  String get name => 'EPS年增暴增';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final eps = data.epsHistory;
    if (eps == null || eps.length < RuleParams.epsYearLookback) return null;

    // 最新一季 & 去年同季（降序排列，index 0 = 最新）
    final latest = eps[0];
    final latestEps = latest.value;
    if (latestEps == null || latestEps <= 0) return null;

    // 找去年同季（同季 = 同月份）
    double? lastYearEps;
    for (int i = RuleParams.epsQuarterOffset; i < eps.length; i++) {
      if (eps[i].date.month == latest.date.month) {
        lastYearEps = eps[i].value;
        break;
      }
    }
    if (lastYearEps == null || lastYearEps <= 0) return null;

    final yoyGrowth = (latestEps - lastYearEps) / lastYearEps * 100;
    if (yoyGrowth < RuleParams.epsYoYSurgeThreshold) return null;

    // 技術面過濾：站上 MA60 + 長紅
    final ma60 = TechnicalIndicatorService.latestSMA(data.prices, 60);
    final today = data.prices.isNotEmpty ? data.prices.last : null;
    final prev = data.prices.length >= 2
        ? data.prices[data.prices.length - 2]
        : null;

    if (ma60 == null ||
        today == null ||
        prev == null ||
        today.close == null ||
        prev.close == null ||
        prev.close! <= 0) {
      return null;
    }

    final close = today.close!;
    final changePct = (close - prev.close!) / prev.close!;

    if (close > ma60 && changePct > RuleParams.minPriceChangeForVolume) {
      return TriggeredReason(
        type: ReasonType.epsYoYSurge,
        score: RuleScores.epsYoYSurge,
        description:
            'EPS 年增 ${yoyGrowth.toStringAsFixed(1)}% '
            '(${latestEps.toStringAsFixed(2)} 元, 站上季線)',
        evidence: {
          'eps': latestEps,
          'lastYearEps': lastYearEps,
          'yoyGrowth': yoyGrowth,
          'ma60': ma60,
          'changePct': changePct * 100,
        },
      );
    }
    return null;
  }
}

/// 規則：EPS 連續成長
///
/// 連續 ≥ 2 季 EPS 季增 ≥ 10%，搭配站上月線(MA20)
class EPSConsecutiveGrowthRule extends StockRule {
  const EPSConsecutiveGrowthRule();

  @override
  String get id => 'eps_consecutive_growth';

  @override
  String get name => 'EPS連續成長';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final eps = data.epsHistory;
    if (eps == null || eps.length < RuleParams.epsConsecutiveQuarters + 1) {
      return null;
    }

    // 檢查連續季增
    int consecutive = 0;
    final growthRates = <double>[];

    for (int i = 0; i < eps.length - 1; i++) {
      final current = eps[i].value;
      final previous = eps[i + 1].value;
      if (current == null || previous == null || previous <= 0) break;

      final growth = (current - previous) / previous * 100;
      if (growth >= RuleParams.epsGrowthThreshold) {
        consecutive++;
        growthRates.add(growth);
      } else {
        break;
      }
    }

    if (consecutive < RuleParams.epsConsecutiveQuarters) return null;

    // 技術面過濾：站上 MA20
    final ma20 = TechnicalIndicatorService.latestSMA(data.prices, 20);
    final close = data.prices.isNotEmpty ? data.prices.last.close : null;

    if (ma20 != null && close != null && close > ma20) {
      final avgGrowth =
          growthRates.reduce((a, b) => a + b) / growthRates.length;
      return TriggeredReason(
        type: ReasonType.epsConsecutiveGrowth,
        score: RuleScores.epsConsecutiveGrowth,
        description:
            'EPS 連續 $consecutive 季成長 '
            '(平均 ${avgGrowth.toStringAsFixed(1)}%, 站上月線)',
        evidence: {
          'consecutiveQuarters': consecutive,
          'avgGrowth': avgGrowth,
          'latestEps': eps[0].value,
          'ma20': ma20,
        },
      );
    }
    return null;
  }
}

/// 規則：EPS 由負轉正
///
/// 前季虧損、本季 EPS ≥ 0.3 元，搭配站上月線或 RSI > 50
class EPSTurnaroundRule extends StockRule {
  const EPSTurnaroundRule();

  @override
  String get id => 'eps_turnaround';

  @override
  String get name => 'EPS由負轉正';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final eps = data.epsHistory;
    if (eps == null || eps.length < 2) return null;

    final latestEps = eps[0].value;
    final previousEps = eps[1].value;
    if (latestEps == null || previousEps == null) return null;

    // 前季虧損，本季獲利 ≥ 門檻
    if (previousEps >= 0 || latestEps < RuleParams.epsTurnaroundThreshold) {
      return null;
    }

    // 技術面過濾：站上 MA20 或 RSI > 50
    final ma20 = TechnicalIndicatorService.latestSMA(data.prices, 20);
    final close = data.prices.isNotEmpty ? data.prices.last.close : null;
    final rsi = TechnicalIndicatorService.latestRSI(data.prices);

    final aboveMA20 = ma20 != null && close != null && close > ma20;
    final rsiPositive =
        rsi != null && rsi > RuleParams.scanRsiMomentumThreshold;

    if (aboveMA20 || rsiPositive) {
      return TriggeredReason(
        type: ReasonType.epsTurnaround,
        score: RuleScores.epsTurnaround,
        description:
            'EPS 由虧轉盈 '
            '(${previousEps.toStringAsFixed(2)} → ${latestEps.toStringAsFixed(2)} 元)',
        evidence: {
          'latestEps': latestEps,
          'previousEps': previousEps,
          'aboveMA20': aboveMA20,
          'rsi': rsi,
        },
      );
    }
    return null;
  }
}

/// 規則：EPS 衰退警示（扣分）
///
/// 連續 2 季 EPS 季減 ≥ 20%
class EPSDeclineWarningRule extends StockRule {
  const EPSDeclineWarningRule();

  @override
  String get id => 'eps_decline_warning';

  @override
  String get name => 'EPS衰退警示';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final eps = data.epsHistory;
    if (eps == null || eps.length < 3) return null;

    // 檢查連續 2 季衰退
    int declineCount = 0;
    final declineRates = <double>[];

    for (int i = 0; i < eps.length - 1 && declineCount < 2; i++) {
      final current = eps[i].value;
      final previous = eps[i + 1].value;
      if (current == null || previous == null || previous <= 0) break;

      final decline = (previous - current) / previous * 100;
      if (decline >= RuleParams.epsDeclineThreshold) {
        declineCount++;
        declineRates.add(decline);
      } else {
        break;
      }
    }

    if (declineCount >= 2) {
      final avgDecline =
          declineRates.reduce((a, b) => a + b) / declineRates.length;
      return TriggeredReason(
        type: ReasonType.epsDeclineWarning,
        score: RuleScores.epsDeclineWarning,
        description:
            'EPS 連續 $declineCount 季衰退 '
            '(平均衰退 ${avgDecline.toStringAsFixed(1)}%)',
        evidence: {
          'declineQuarters': declineCount,
          'avgDecline': avgDecline,
          'latestEps': eps[0].value,
        },
      );
    }
    return null;
  }
}

// ==========================================
// ROE 分析規則
// ==========================================

/// 規則：ROE 優異
///
/// 最新季 ROE ≥ 15%，搭配站上 MA20
class ROEExcellentRule extends StockRule {
  const ROEExcellentRule();

  @override
  String get id => 'roe_excellent';

  @override
  String get name => 'ROE優異';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final roe = data.roeHistory;
    if (roe == null || roe.isEmpty) return null;

    final latestRoe = roe[0].value;
    if (latestRoe == null || latestRoe < RuleParams.roeExcellentThreshold) {
      return null;
    }

    // 技術面過濾：站上 MA20
    final ma20 = TechnicalIndicatorService.latestSMA(data.prices, 20);
    final close = data.latestClose;
    if (ma20 == null || close == null || close <= ma20) return null;

    return TriggeredReason(
      type: ReasonType.roeExcellent,
      score: RuleScores.roeExcellent,
      description:
          'ROE ${latestRoe.toStringAsFixed(1)}% '
          '(≥${RuleParams.roeExcellentThreshold.toInt()}%, 站上月線)',
      evidence: {'roe': latestRoe, 'ma20': ma20, 'close': close},
    );
  }
}

/// 規則：ROE 持續改善
///
/// 連續 ≥ 2 季 ROE 改善 ≥ 5pt，搭配站上 MA20
class ROEImprovingRule extends StockRule {
  const ROEImprovingRule();

  @override
  String get id => 'roe_improving';

  @override
  String get name => 'ROE改善';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final roe = data.roeHistory;
    if (roe == null || roe.length < RuleParams.roeMinQuarters + 1) {
      return null;
    }

    // 檢查連續改善
    int improvingCount = 0;
    double totalImprovement = 0;

    for (int i = 0; i < roe.length - 1; i++) {
      final current = roe[i].value;
      final previous = roe[i + 1].value;
      if (current == null || previous == null) break;

      final improvement = current - previous;
      if (improvement >= RuleParams.roeImprovingThreshold) {
        improvingCount++;
        totalImprovement += improvement;
      } else {
        break;
      }
    }

    if (improvingCount < RuleParams.roeMinQuarters) return null;

    // 技術面過濾：站上 MA20
    final ma20 = TechnicalIndicatorService.latestSMA(data.prices, 20);
    final close = data.latestClose;
    if (ma20 == null || close == null || close <= ma20) return null;

    final avgImprovement = totalImprovement / improvingCount;
    return TriggeredReason(
      type: ReasonType.roeImproving,
      score: RuleScores.roeImproving,
      description:
          'ROE 連續 $improvingCount 季改善 '
          '(平均 +${avgImprovement.toStringAsFixed(1)}pt)',
      evidence: {
        'improvingQuarters': improvingCount,
        'avgImprovement': avgImprovement,
        'latestRoe': roe[0].value,
      },
    );
  }
}

/// 規則：ROE 衰退
///
/// 連續 ≥ 2 季 ROE 衰退 ≥ 5pt（扣分規則）
class ROEDecliningRule extends StockRule {
  const ROEDecliningRule();

  @override
  String get id => 'roe_declining';

  @override
  String get name => 'ROE衰退';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    final roe = data.roeHistory;
    if (roe == null || roe.length < RuleParams.roeMinQuarters + 1) {
      return null;
    }

    // 檢查連續衰退
    int decliningCount = 0;
    double totalDecline = 0;

    for (int i = 0; i < roe.length - 1; i++) {
      final current = roe[i].value;
      final previous = roe[i + 1].value;
      if (current == null || previous == null) break;

      final decline = previous - current;
      if (decline >= RuleParams.roeDecliningThreshold) {
        decliningCount++;
        totalDecline += decline;
      } else {
        break;
      }
    }

    if (decliningCount < RuleParams.roeMinQuarters) return null;

    final avgDecline = totalDecline / decliningCount;
    return TriggeredReason(
      type: ReasonType.roeDeclining,
      score: RuleScores.roeDeclining,
      description:
          'ROE 連續 $decliningCount 季衰退 '
          '(平均 -${avgDecline.toStringAsFixed(1)}pt)',
      evidence: {
        'decliningQuarters': decliningCount,
        'avgDecline': avgDecline,
        'latestRoe': roe[0].value,
      },
    );
  }
}
