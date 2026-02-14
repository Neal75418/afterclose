import 'dart:convert';

import 'package:afterclose/core/constants/analysis_params.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/price_limit.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/domain/models/stock_summary.dart';
import 'package:afterclose/domain/services/signal_confluence.dart';
import 'package:afterclose/domain/models/signal_names.dart';

/// 個股 AI 智慧分析摘要生成服務
///
/// 以模板式 NLG 將規則引擎結果轉化為結構化摘要資料，
/// 具備訊號匯流偵測、衝突偵測、加權情緒判斷與信心度評估。
///
/// 回傳 [SummaryData]（純結構化資料，不含翻譯），
/// 由 presentation 層的 [SummaryLocalizer] 負責翻譯為 [StockSummary]。
class AnalysisSummaryService {
  const AnalysisSummaryService();

  static const _confluenceDetector = SignalConfluenceDetector();

  /// 從個股分析資料生成 [SummaryData]
  SummaryData generate({
    required DailyAnalysisEntry? analysis,
    required List<DailyReasonEntry> reasons,
    required DailyPriceEntry? latestPrice,
    required double? priceChange,
    required List<DailyInstitutionalEntry> institutionalHistory,
    required List<FinMindRevenue> revenueHistory,
    required FinMindPER? latestPER,
  }) {
    if (analysis == null && reasons.isEmpty) {
      return const SummaryData(
        overallParts: [LocalizableString('summary.noSignals')],
        sentiment: SummarySentiment.neutral,
      );
    }

    // 訊號匯流偵測
    final bullishConfluence = _confluenceDetector.detect(
      reasons,
      bullish: true,
    );
    final bearishConfluence = _confluenceDetector.detect(
      reasons,
      bullish: false,
    );

    // 衝突偵測
    final hasConflict = _hasSignificantConflict(reasons);

    // 綜合評估（接收匯流結果）
    final overallParts = _buildOverallAssessment(
      analysis,
      latestPrice,
      priceChange,
      bullishConfluence: bullishConfluence,
      bearishConfluence: bearishConfluence,
      hasConflict: hasConflict,
    );

    // 匯流整合的關鍵訊號 & 風險因子
    final keySignals = _buildKeySignals(
      reasons,
      bullishConfluence,
      priceChange: priceChange,
    );
    final riskFactors = _buildRiskFactors(
      reasons,
      bearishConfluence,
      priceChange: priceChange,
    );

    final supporting = _buildSupportingData(
      institutionalHistory,
      revenueHistory,
      latestPER,
    );

    // 加權情緒（含基本面修正）
    final sentiment = _determineSentiment(
      analysis,
      reasons,
      hasConflict: hasConflict,
      revenueHistory: revenueHistory,
      latestPER: latestPER,
    );

    // 信心度
    final confidence = _calculateConfidence(
      reasons: reasons,
      institutionalHistory: institutionalHistory,
      revenueHistory: revenueHistory,
      latestPER: latestPER,
      hasConflict: hasConflict,
      confluenceCount:
          bullishConfluence.matchedCount + bearishConfluence.matchedCount,
    );

    return SummaryData(
      overallParts: overallParts,
      keySignals: keySignals,
      riskFactors: riskFactors,
      supportingData: supporting,
      sentiment: sentiment,
      confidence: confidence,
      hasConflict: hasConflict,
      confluenceCount:
          bullishConfluence.matchedCount + bearishConfluence.matchedCount,
    );
  }

  // ==================================================
  // 綜合評估（含匯流敘述升級）
  // ==================================================

  List<LocalizableString> _buildOverallAssessment(
    DailyAnalysisEntry? analysis,
    DailyPriceEntry? latestPrice,
    double? priceChange, {
    required ConfluenceResult bullishConfluence,
    required ConfluenceResult bearishConfluence,
    required bool hasConflict,
  }) {
    final parts = <LocalizableString>[];

    final close = latestPrice?.close?.toStringAsFixed(1) ?? '-';
    final change = priceChange?.abs().toStringAsFixed(1) ?? '0.0';

    // 有匯流時用合成敘述開頭
    final hasConfluence =
        bullishConfluence.matchedCount > 0 ||
        bearishConfluence.matchedCount > 0;

    if (hasConfluence) {
      final primaryConfluence = bullishConfluence.matchedCount > 0
          ? bullishConfluence
          : bearishConfluence;
      parts.add(
        LocalizableString(
          'summary.confluenceOverall',
          {'close': close, 'change': change},
          {
            'confluence': LocalizableString(
              primaryConfluence.summaryKeys.first,
            ),
          },
        ),
      );
    } else {
      final trendKey = switch (analysis?.trendState) {
        'UP' => 'summary.overallUp',
        'DOWN' => 'summary.overallDown',
        _ => 'summary.overallRange',
      };
      parts.add(
        LocalizableString(trendKey, {'close': close, 'change': change}),
      );
    }

    // 反轉訊號（匯流未涵蓋時才顯示）
    final confluenceConsumed = {
      ...bullishConfluence.consumedTypes,
      ...bearishConfluence.consumedTypes,
    };
    if (analysis?.reversalState == 'W2S' &&
        !confluenceConsumed.contains(SignalName.reversalW2S)) {
      parts.add(const LocalizableString('summary.reversalW2S'));
    } else if (analysis?.reversalState == 'S2W' &&
        !confluenceConsumed.contains(SignalName.reversalS2W)) {
      parts.add(const LocalizableString('summary.reversalS2W'));
    }

    // 支撐/壓力
    final support = analysis?.supportLevel;
    final resistance = analysis?.resistanceLevel;
    if (support != null && resistance != null) {
      parts.add(
        LocalizableString('summary.supportResistance', {
          'support': support.toStringAsFixed(1),
          'resistance': resistance.toStringAsFixed(1),
        }),
      );
    }

    // 分數評語
    final score = analysis?.score.toInt() ?? 0;
    final scoreKey = switch (score) {
      >= AnalysisParams.scoreStrongThreshold => 'summary.scoreStrong',
      >= AnalysisParams.scoreWatchThreshold => 'summary.scoreWatch',
      >= AnalysisParams.scoreNeutralThreshold => 'summary.scoreNeutral',
      _ => 'summary.scoreCaution',
    };
    parts.add(LocalizableString(scoreKey, {'score': score.toString()}));

    // 衝突提示
    if (hasConflict) {
      parts.add(const LocalizableString('summary.mixedSignals'));
    }

    return parts;
  }

  // ==================================================
  // 關鍵訊號（含匯流整合）
  // ==================================================

  List<LocalizableString> _buildKeySignals(
    List<DailyReasonEntry> reasons,
    ConfluenceResult confluence, {
    double? priceChange,
  }) {
    final positive = reasons.where((r) => r.ruleScore > 0).toList()
      ..sort((a, b) => b.ruleScore.compareTo(a.ruleScore));

    const maxItems = 5;
    final signals = <LocalizableString>[];

    // 漲停板置頂顯示
    if (PriceLimit.isLimitUp(priceChange)) {
      signals.add(const LocalizableString('summary.limitUp'));
    }

    signals.addAll(
      confluence.summaryKeys
          .take(maxItems - signals.length)
          .map((key) => LocalizableString(key)),
    );

    final remainingSlots = maxItems - signals.length;
    if (remainingSlots > 0) {
      final remaining = positive
          .where((r) => !confluence.consumedTypes.contains(r.reasonType))
          .take(remainingSlots)
          .map((r) => _reasonToLocalizable(r.reasonType, r.evidenceJson))
          .whereType<LocalizableString>();
      signals.addAll(remaining);
    }
    return signals;
  }

  // ==================================================
  // 風險因子（含匯流整合）
  // ==================================================

  List<LocalizableString> _buildRiskFactors(
    List<DailyReasonEntry> reasons,
    ConfluenceResult confluence, {
    double? priceChange,
  }) {
    final negative = reasons.where((r) => r.ruleScore < 0).toList()
      ..sort((a, b) => a.ruleScore.compareTo(b.ruleScore));

    const maxItems = 5;
    final risks = <LocalizableString>[];

    // 跌停板置頂顯示
    if (PriceLimit.isLimitDown(priceChange)) {
      risks.add(const LocalizableString('summary.limitDown'));
    }

    risks.addAll(
      confluence.summaryKeys
          .take(maxItems - risks.length)
          .map((key) => LocalizableString(key)),
    );

    final remainingSlots = maxItems - risks.length;
    if (remainingSlots > 0) {
      final remaining = negative
          .where((r) => !confluence.consumedTypes.contains(r.reasonType))
          .take(remainingSlots)
          .map((r) => _reasonToLocalizable(r.reasonType, r.evidenceJson))
          .whereType<LocalizableString>();
      risks.addAll(remaining);
    }
    return risks;
  }

  // ==================================================
  // 輔助數據
  // ==================================================

  List<LocalizableString> _buildSupportingData(
    List<DailyInstitutionalEntry> institutionalHistory,
    List<FinMindRevenue> revenueHistory,
    FinMindPER? latestPER,
  ) {
    final data = <LocalizableString>[];

    if (institutionalHistory.isNotEmpty) {
      final latest = institutionalHistory.first;
      final foreign = _formatNetLocalizable(latest.foreignNet);
      final trust = _formatNetLocalizable(latest.investmentTrustNet);
      data.add(
        LocalizableString('summary.institutionalFlow', const {}, {
          'foreign': foreign,
          'trust': trust,
        }),
      );
    }

    final pe = latestPER?.per;
    if (pe != null && pe > 0) {
      final key = pe <= AnalysisParams.peUndervaluedThreshold
          ? 'summary.peUndervalued'
          : 'summary.peOvervalued';
      data.add(LocalizableString(key, {'pe': pe.toStringAsFixed(1)}));
    }

    final yield_ = latestPER?.dividendYield;
    if (yield_ != null && yield_ >= AnalysisParams.highDividendYieldThreshold) {
      data.add(
        LocalizableString('summary.highDividendYield', {
          'yield': yield_.toStringAsFixed(1),
        }),
      );
    }

    if (revenueHistory.isNotEmpty) {
      final latest = revenueHistory.first;
      final yoy = latest.yoyGrowth;
      if (yoy != null &&
          yoy.abs() >= AnalysisParams.revenueYoySignificantThreshold) {
        final key = yoy > 0
            ? 'summary.revenueYoySurge'
            : 'summary.revenueYoyDecline';
        data.add(LocalizableString(key, {'growth': yoy.toStringAsFixed(1)}));
      }
    }

    return data;
  }

  // ==================================================
  // 加權 Sentiment（含衝突偵測 + 基本面修正）
  // ==================================================

  SummarySentiment _determineSentiment(
    DailyAnalysisEntry? analysis,
    List<DailyReasonEntry> reasons, {
    required bool hasConflict,
    required List<FinMindRevenue> revenueHistory,
    required FinMindPER? latestPER,
  }) {
    final score = analysis?.score.toInt() ?? 0;

    // 加權計算
    final positiveWeight = reasons
        .where((r) => r.ruleScore > 0)
        .fold<double>(0, (sum, r) => sum + r.ruleScore);
    final negativeWeight = reasons
        .where((r) => r.ruleScore < 0)
        .fold<double>(0, (sum, r) => sum + r.ruleScore.abs());

    // 基本面修正
    var fundamentalBias = 0.0;
    final pe = latestPER?.per;
    if (pe != null && pe > 0 && pe <= AnalysisParams.peDeepValueThreshold) {
      fundamentalBias += AnalysisParams.fundamentalBiasPoints;
    }
    final yield_ = latestPER?.dividendYield;
    if (yield_ != null && yield_ >= AnalysisParams.highYieldBiasThreshold) {
      fundamentalBias += AnalysisParams.fundamentalBiasPoints;
    }
    if (revenueHistory.isNotEmpty) {
      final yoy = revenueHistory.first.yoyGrowth;
      if (yoy != null && yoy > AnalysisParams.revenueStrongGrowthThreshold) {
        fundamentalBias += AnalysisParams.fundamentalBiasPoints;
      }
      if (yoy != null &&
          yoy < AnalysisParams.revenueSignificantDeclineThreshold) {
        fundamentalBias -= AnalysisParams.fundamentalBiasPoints;
      }
    }

    final adjustedPositive =
        positiveWeight + (fundamentalBias > 0 ? fundamentalBias : 0);
    final adjustedNegative =
        negativeWeight + (fundamentalBias < 0 ? fundamentalBias.abs() : 0);
    final totalWeight = adjustedPositive + adjustedNegative;

    if (totalWeight == 0) return SummarySentiment.neutral;

    final bullRatio = adjustedPositive / totalWeight;

    // 衝突時提高判斷門檻
    if (hasConflict) {
      if (bullRatio > AnalysisParams.conflictBullRatioThreshold &&
          score >= AnalysisParams.conflictBullScoreThreshold) {
        return SummarySentiment.bullish;
      }
      if (bullRatio < AnalysisParams.conflictBearRatioThreshold &&
          score < AnalysisParams.conflictBearScoreThreshold) {
        return SummarySentiment.bearish;
      }
      return SummarySentiment.neutral;
    }

    if (bullRatio >= AnalysisParams.bullRatioThreshold &&
        score >= AnalysisParams.bullScoreThreshold) {
      return SummarySentiment.bullish;
    }
    if (bullRatio <= AnalysisParams.bearRatioThreshold &&
        score < AnalysisParams.bearScoreThreshold) {
      return SummarySentiment.bearish;
    }
    return SummarySentiment.neutral;
  }

  // ==================================================
  // 衝突偵測
  // ==================================================

  /// 偵測特定矛盾訊號對
  static bool _hasSignificantConflict(List<DailyReasonEntry> reasons) {
    final types = reasons.map((r) => r.reasonType).toSet();

    for (final pair in _conflictPairs) {
      final hasA = pair.$1.any(types.contains);
      final hasB = pair.$2.any(types.contains);
      if (hasA && hasB) return true;
    }
    return false;
  }

  static const _conflictPairs = [
    ({SignalName.reversalW2S}, {SignalName.kdDeathCross}),
    ({SignalName.techBreakout}, {SignalName.maAlignmentBearish}),
    ({SignalName.institutionalBuyStreak}, {SignalName.foreignExodus}),
    (
      {SignalName.peUndervalued, SignalName.pbrUndervalued},
      {SignalName.epsDeclineWarning},
    ),
    ({SignalName.maAlignmentBullish}, {SignalName.techBreakdown}),
  ];

  // ==================================================
  // 信心度計算
  // ==================================================

  AnalysisConfidence _calculateConfidence({
    required List<DailyReasonEntry> reasons,
    required List<DailyInstitutionalEntry> institutionalHistory,
    required List<FinMindRevenue> revenueHistory,
    required FinMindPER? latestPER,
    required bool hasConflict,
    required int confluenceCount,
  }) {
    var points = 0;

    final totalSignals = reasons.length;
    if (totalSignals >= AnalysisParams.manySignalsThreshold) {
      points += 2;
    } else if (totalSignals >= AnalysisParams.someSignalsThreshold) {
      points += 1;
    }

    points += confluenceCount;

    if (!hasConflict) points += 1;

    if (institutionalHistory.isNotEmpty) points += 1;
    if (revenueHistory.isNotEmpty) points += 1;
    if (latestPER != null) points += 1;

    if (points >= AnalysisParams.confidenceHighThreshold) {
      return AnalysisConfidence.high;
    }
    if (points >= AnalysisParams.confidenceMediumThreshold) {
      return AnalysisConfidence.medium;
    }
    return AnalysisConfidence.low;
  }

  // ==================================================
  // ReasonType → LocalizableString
  // ==================================================

  LocalizableString? _reasonToLocalizable(
    String reasonType,
    String evidenceJson,
  ) {
    final evidence = _parseEvidence(evidenceJson);
    return _signalBuilders[reasonType]?.call(evidence);
  }

  Map<String, dynamic> _parseEvidence(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (e) {
      AppLogger.debug(
        'SummaryService',
        'Evidence JSON parse failed: $json ($e)',
      );
    }
    return const {};
  }

  LocalizableString _formatNetLocalizable(double? net) {
    if (net == null) return const LocalizableString('summary.netDash');
    final lots = (net / 1000).round();
    if (lots == 0) return const LocalizableString('summary.netNeutral');
    if (lots > 0) {
      return LocalizableString('summary.netBuy', {'lots': lots.toString()});
    }
    return LocalizableString('summary.netSell', {
      'lots': lots.abs().toString(),
    });
  }

  // ==================================================
  // 映射表：ReasonType 代碼 → LocalizableString 建構
  // ==================================================

  static final Map<String, LocalizableString Function(Map<String, dynamic>)>
  _signalBuilders = {
    // 核心訊號
    SignalName.reversalW2S: (_) =>
        const LocalizableString('summary.reversalW2S'),
    SignalName.reversalS2W: (_) =>
        const LocalizableString('summary.reversalS2W'),
    SignalName.techBreakout: (_) => const LocalizableString('summary.breakout'),
    SignalName.techBreakdown: (_) =>
        const LocalizableString('summary.breakdown'),
    SignalName.volumeSpike: (e) => LocalizableString('summary.volumeSpike', {
      'multiple': _numStr(
        e['multiple'] ?? e['volumeMultiple'],
        fractionDigits: 1,
      ),
    }),
    SignalName.priceSpike: (e) => LocalizableString('summary.priceSpike', {
      'pctChange': _numStr(e['pctChange'] ?? e['changePct']),
    }),
    SignalName.institutionalBuy: (_) =>
        const LocalizableString('summary.institutionalBuy'),
    SignalName.institutionalSell: (_) =>
        const LocalizableString('summary.institutionalSell'),
    SignalName.newsRelated: (_) =>
        const LocalizableString('summary.newsRelated'),

    // KD
    SignalName.kdGoldenCross: (_) =>
        const LocalizableString('summary.kdGoldenCross'),
    SignalName.kdDeathCross: (_) =>
        const LocalizableString('summary.kdDeathCross'),

    // 法人連續
    SignalName.institutionalBuyStreak: (_) =>
        const LocalizableString('summary.institutionalBuyStreak'),
    SignalName.institutionalSellStreak: (_) =>
        const LocalizableString('summary.institutionalSellStreak'),

    // K 線型態
    SignalName.patternDoji: (_) =>
        const LocalizableString('summary.patternDoji'),
    SignalName.patternBullishEngulfing: (_) =>
        const LocalizableString('summary.patternBullishEngulfing'),
    SignalName.patternBearishEngulfing: (_) =>
        const LocalizableString('summary.patternBearishEngulfing'),
    SignalName.patternHammer: (_) =>
        const LocalizableString('summary.patternHammer'),
    SignalName.patternHangingMan: (_) =>
        const LocalizableString('summary.patternHangingMan'),
    SignalName.patternGapUp: (_) =>
        const LocalizableString('summary.patternGapUp'),
    SignalName.patternGapDown: (_) =>
        const LocalizableString('summary.patternGapDown'),
    SignalName.patternMorningStar: (_) =>
        const LocalizableString('summary.patternMorningStar'),
    SignalName.patternEveningStar: (_) =>
        const LocalizableString('summary.patternEveningStar'),
    SignalName.patternThreeWhiteSoldiers: (_) =>
        const LocalizableString('summary.patternThreeWhiteSoldiers'),
    SignalName.patternThreeBlackCrows: (_) =>
        const LocalizableString('summary.patternThreeBlackCrows'),

    // 技術訊號
    SignalName.week52High: (_) => const LocalizableString('summary.week52High'),
    SignalName.week52Low: (_) => const LocalizableString('summary.week52Low'),
    SignalName.maAlignmentBullish: (_) =>
        const LocalizableString('summary.maAlignmentBullish'),
    SignalName.maAlignmentBearish: (_) =>
        const LocalizableString('summary.maAlignmentBearish'),
    SignalName.rsiExtremeOverbought: (e) => LocalizableString(
      'summary.rsiOverbought',
      {'rsi': _numStr(e['rsi'], fractionDigits: 0)},
    ),
    SignalName.rsiExtremeOversold: (e) => LocalizableString(
      'summary.rsiOversold',
      {'rsi': _numStr(e['rsi'], fractionDigits: 0)},
    ),

    // 延伸市場資料
    SignalName.foreignShareholdingIncreasing: (_) =>
        const LocalizableString('summary.foreignIncreasing'),
    SignalName.foreignShareholdingDecreasing: (_) =>
        const LocalizableString('summary.foreignDecreasing'),
    SignalName.dayTradingHigh: (e) => LocalizableString(
      'summary.dayTradingHigh',
      {'ratio': _numStr(e['dayTradingRatio'] ?? e['ratio'])},
    ),
    SignalName.dayTradingExtreme: (e) => LocalizableString(
      'summary.dayTradingExtreme',
      {'ratio': _numStr(e['dayTradingRatio'] ?? e['ratio'])},
    ),
    SignalName.concentrationHigh: (_) =>
        const LocalizableString('summary.concentrationHigh'),

    // 價量背離
    SignalName.priceVolumeBullishDivergence: (_) =>
        const LocalizableString('summary.bullishDivergence'),
    SignalName.priceVolumeBearishDivergence: (_) =>
        const LocalizableString('summary.bearishDivergence'),
    SignalName.highVolumeBreakout: (_) =>
        const LocalizableString('summary.highVolumeBreakout'),
    SignalName.lowVolumeAccumulation: (_) =>
        const LocalizableString('summary.lowVolumeAccumulation'),

    // 基本面
    SignalName.revenueYoySurge: (e) => LocalizableString(
      'summary.revenueYoySurge',
      {'growth': _numStr(e['yoyGrowth'])},
    ),
    SignalName.revenueYoyDecline: (e) => LocalizableString(
      'summary.revenueYoyDecline',
      {'growth': _numStr(e['yoyGrowth'])},
    ),
    SignalName.revenueMomGrowth: (e) => LocalizableString(
      'summary.revenueMomGrowth',
      {'months': _numStr(e['consecutiveMonths'], fractionDigits: 0)},
    ),
    SignalName.highDividendYield: (e) => LocalizableString(
      'summary.highDividendYield',
      {'yield': _numStr(e['dividendYield'])},
    ),
    SignalName.peUndervalued: (e) =>
        LocalizableString('summary.peUndervalued', {'pe': _numStr(e['pe'])}),
    SignalName.peOvervalued: (e) =>
        LocalizableString('summary.peOvervalued', {'pe': _numStr(e['pe'])}),
    SignalName.pbrUndervalued: (e) =>
        LocalizableString('summary.pbrUndervalued', {'pbr': _numStr(e['pbr'])}),

    // Killer Features
    SignalName.tradingWarningAttention: (_) =>
        const LocalizableString('summary.warningAttention'),
    SignalName.tradingWarningDisposal: (_) =>
        const LocalizableString('summary.warningDisposal'),
    SignalName.insiderSellingStreak: (e) => LocalizableString(
      'summary.insiderSelling',
      {'months': _numStr(e['sellingStreakMonths'], fractionDigits: 0)},
    ),
    SignalName.insiderSignificantBuying: (_) =>
        const LocalizableString('summary.insiderBuying'),
    SignalName.highPledgeRatio: (_) =>
        const LocalizableString('summary.highPledge'),
    SignalName.foreignConcentrationWarning: (_) =>
        const LocalizableString('summary.foreignConcentration'),
    SignalName.foreignExodus: (_) =>
        const LocalizableString('summary.foreignExodus'),

    // EPS
    SignalName.epsYoySurge: (e) => LocalizableString('summary.epsYoYSurge', {
      'growth': _numStr(e['yoyGrowth']),
    }),
    SignalName.epsConsecutiveGrowth: (e) => LocalizableString(
      'summary.epsConsecutiveGrowth',
      {'quarters': _numStr(e['consecutiveQuarters'], fractionDigits: 0)},
    ),
    SignalName.epsTurnaround: (_) =>
        const LocalizableString('summary.epsTurnaround'),
    SignalName.epsDeclineWarning: (_) =>
        const LocalizableString('summary.epsDecline'),

    // ROE
    SignalName.roeExcellent: (e) =>
        LocalizableString('summary.roeExcellent', {'roe': _numStr(e['roe'])}),
    SignalName.roeImproving: (_) =>
        const LocalizableString('summary.roeImproving'),
    SignalName.roeDeclining: (_) =>
        const LocalizableString('summary.roeDeclining'),
  };

  static String _numStr(dynamic value, {int fractionDigits = 1}) {
    if (value == null) return '-';
    if (value is num) return value.toStringAsFixed(fractionDigits);
    return value.toString();
  }
}
