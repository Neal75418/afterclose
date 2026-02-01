import 'dart:convert';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/domain/models/stock_summary.dart';
import 'package:afterclose/domain/services/signal_confluence.dart';

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
    final keySignals = _buildKeySignals(reasons, bullishConfluence);
    final riskFactors = _buildRiskFactors(reasons, bearishConfluence);

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

  // ──────────────────────────────────────────
  // 綜合評估（含匯流敘述升級）
  // ──────────────────────────────────────────

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
        !confluenceConsumed.contains('REVERSAL_W2S')) {
      parts.add(const LocalizableString('summary.reversalW2S'));
    } else if (analysis?.reversalState == 'S2W' &&
        !confluenceConsumed.contains('REVERSAL_S2W')) {
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
      >= 60 => 'summary.scoreStrong',
      >= 35 => 'summary.scoreWatch',
      >= 15 => 'summary.scoreNeutral',
      _ => 'summary.scoreCaution',
    };
    parts.add(LocalizableString(scoreKey, {'score': score.toString()}));

    // 衝突提示
    if (hasConflict) {
      parts.add(const LocalizableString('summary.mixedSignals'));
    }

    return parts;
  }

  // ──────────────────────────────────────────
  // 關鍵訊號（含匯流整合）
  // ──────────────────────────────────────────

  List<LocalizableString> _buildKeySignals(
    List<DailyReasonEntry> reasons,
    ConfluenceResult confluence,
  ) {
    final positive = reasons.where((r) => r.ruleScore > 0).toList()
      ..sort((a, b) => b.ruleScore.compareTo(a.ruleScore));

    const maxItems = 5;
    final signals = <LocalizableString>[
      ...confluence.summaryKeys
          .take(maxItems)
          .map((key) => LocalizableString(key)),
    ];

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

  // ──────────────────────────────────────────
  // 風險因子（含匯流整合）
  // ──────────────────────────────────────────

  List<LocalizableString> _buildRiskFactors(
    List<DailyReasonEntry> reasons,
    ConfluenceResult confluence,
  ) {
    final negative = reasons.where((r) => r.ruleScore < 0).toList()
      ..sort((a, b) => a.ruleScore.compareTo(b.ruleScore));

    const maxItems = 5;
    final risks = <LocalizableString>[
      ...confluence.summaryKeys
          .take(maxItems)
          .map((key) => LocalizableString(key)),
    ];

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

  // ──────────────────────────────────────────
  // 輔助數據
  // ──────────────────────────────────────────

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
      final key = pe <= 15.0 ? 'summary.peUndervalued' : 'summary.peOvervalued';
      data.add(LocalizableString(key, {'pe': pe.toStringAsFixed(1)}));
    }

    final yield_ = latestPER?.dividendYield;
    if (yield_ != null && yield_ >= 4.0) {
      data.add(
        LocalizableString('summary.highDividendYield', {
          'yield': yield_.toStringAsFixed(1),
        }),
      );
    }

    if (revenueHistory.isNotEmpty) {
      final latest = revenueHistory.first;
      final yoy = latest.yoyGrowth;
      if (yoy != null && yoy.abs() >= 20) {
        final key = yoy > 0
            ? 'summary.revenueYoySurge'
            : 'summary.revenueYoyDecline';
        data.add(LocalizableString(key, {'growth': yoy.toStringAsFixed(1)}));
      }
    }

    return data;
  }

  // ──────────────────────────────────────────
  // 加權 Sentiment（含衝突偵測 + 基本面修正）
  // ──────────────────────────────────────────

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
    if (pe != null && pe > 0 && pe <= 10) fundamentalBias += 5;
    final yield_ = latestPER?.dividendYield;
    if (yield_ != null && yield_ >= 5.5) fundamentalBias += 5;
    if (revenueHistory.isNotEmpty) {
      final yoy = revenueHistory.first.yoyGrowth;
      if (yoy != null && yoy > 30) fundamentalBias += 5;
      if (yoy != null && yoy < -20) fundamentalBias -= 5;
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
      if (bullRatio > 0.65 && score >= 35) return SummarySentiment.bullish;
      if (bullRatio < 0.35 && score < 15) return SummarySentiment.bearish;
      return SummarySentiment.neutral;
    }

    if (bullRatio >= 0.6 && score >= 30) return SummarySentiment.bullish;
    if (bullRatio <= 0.4 && score < 20) return SummarySentiment.bearish;
    return SummarySentiment.neutral;
  }

  // ──────────────────────────────────────────
  // 衝突偵測
  // ──────────────────────────────────────────

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
    ({'REVERSAL_W2S'}, {'KD_DEATH_CROSS'}),
    ({'TECH_BREAKOUT'}, {'MA_ALIGNMENT_BEARISH'}),
    ({'INSTITUTIONAL_BUY_STREAK'}, {'FOREIGN_EXODUS'}),
    ({'PE_UNDERVALUED', 'PBR_UNDERVALUED'}, {'EPS_DECLINE_WARNING'}),
    ({'MA_ALIGNMENT_BULLISH'}, {'TECH_BREAKDOWN'}),
  ];

  // ──────────────────────────────────────────
  // 信心度計算
  // ──────────────────────────────────────────

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
    if (totalSignals >= 5) {
      points += 2;
    } else if (totalSignals >= 3) {
      points += 1;
    }

    points += confluenceCount;

    if (!hasConflict) points += 1;

    if (institutionalHistory.isNotEmpty) points += 1;
    if (revenueHistory.isNotEmpty) points += 1;
    if (latestPER != null) points += 1;

    if (points >= 5) return AnalysisConfidence.high;
    if (points >= 3) return AnalysisConfidence.medium;
    return AnalysisConfidence.low;
  }

  // ──────────────────────────────────────────
  // ReasonType → LocalizableString
  // ──────────────────────────────────────────

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
    } catch (_) {}
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

  // ──────────────────────────────────────────
  // Dispatch map: ReasonType code → LocalizableString builder
  // ──────────────────────────────────────────

  static final Map<String, LocalizableString Function(Map<String, dynamic>)>
  _signalBuilders = {
    // 核心訊號
    'REVERSAL_W2S': (_) => const LocalizableString('summary.reversalW2S'),
    'REVERSAL_S2W': (_) => const LocalizableString('summary.reversalS2W'),
    'TECH_BREAKOUT': (_) => const LocalizableString('summary.breakout'),
    'TECH_BREAKDOWN': (_) => const LocalizableString('summary.breakdown'),
    'VOLUME_SPIKE': (e) => LocalizableString('summary.volumeSpike', {
      'multiple': _numStr(
        e['multiple'] ?? e['volumeMultiple'],
        fractionDigits: 1,
      ),
    }),
    'PRICE_SPIKE': (e) => LocalizableString('summary.priceSpike', {
      'pctChange': _numStr(e['pctChange'] ?? e['changePct']),
    }),
    'INSTITUTIONAL_BUY': (_) =>
        const LocalizableString('summary.institutionalBuy'),
    'INSTITUTIONAL_SELL': (_) =>
        const LocalizableString('summary.institutionalSell'),
    'NEWS_RELATED': (_) => const LocalizableString('summary.newsRelated'),

    // KD
    'KD_GOLDEN_CROSS': (_) => const LocalizableString('summary.kdGoldenCross'),
    'KD_DEATH_CROSS': (_) => const LocalizableString('summary.kdDeathCross'),

    // 法人連續
    'INSTITUTIONAL_BUY_STREAK': (_) =>
        const LocalizableString('summary.institutionalBuyStreak'),
    'INSTITUTIONAL_SELL_STREAK': (_) =>
        const LocalizableString('summary.institutionalSellStreak'),

    // K 線型態
    'PATTERN_DOJI': (_) => const LocalizableString('summary.patternDoji'),
    'PATTERN_BULLISH_ENGULFING': (_) =>
        const LocalizableString('summary.patternBullishEngulfing'),
    'PATTERN_BEARISH_ENGULFING': (_) =>
        const LocalizableString('summary.patternBearishEngulfing'),
    'PATTERN_HAMMER': (_) => const LocalizableString('summary.patternHammer'),
    'PATTERN_HANGING_MAN': (_) =>
        const LocalizableString('summary.patternHangingMan'),
    'PATTERN_GAP_UP': (_) => const LocalizableString('summary.patternGapUp'),
    'PATTERN_GAP_DOWN': (_) =>
        const LocalizableString('summary.patternGapDown'),
    'PATTERN_MORNING_STAR': (_) =>
        const LocalizableString('summary.patternMorningStar'),
    'PATTERN_EVENING_STAR': (_) =>
        const LocalizableString('summary.patternEveningStar'),
    'PATTERN_THREE_WHITE_SOLDIERS': (_) =>
        const LocalizableString('summary.patternThreeWhiteSoldiers'),
    'PATTERN_THREE_BLACK_CROWS': (_) =>
        const LocalizableString('summary.patternThreeBlackCrows'),

    // 技術訊號
    'WEEK_52_HIGH': (_) => const LocalizableString('summary.week52High'),
    'WEEK_52_LOW': (_) => const LocalizableString('summary.week52Low'),
    'MA_ALIGNMENT_BULLISH': (_) =>
        const LocalizableString('summary.maAlignmentBullish'),
    'MA_ALIGNMENT_BEARISH': (_) =>
        const LocalizableString('summary.maAlignmentBearish'),
    'RSI_EXTREME_OVERBOUGHT': (e) => LocalizableString(
      'summary.rsiOverbought',
      {'rsi': _numStr(e['rsi'], fractionDigits: 0)},
    ),
    'RSI_EXTREME_OVERSOLD': (e) => LocalizableString('summary.rsiOversold', {
      'rsi': _numStr(e['rsi'], fractionDigits: 0),
    }),

    // 延伸市場資料
    'FOREIGN_SHAREHOLDING_INCREASING': (_) =>
        const LocalizableString('summary.foreignIncreasing'),
    'FOREIGN_SHAREHOLDING_DECREASING': (_) =>
        const LocalizableString('summary.foreignDecreasing'),
    'DAY_TRADING_HIGH': (e) => LocalizableString('summary.dayTradingHigh', {
      'ratio': _numStr(e['dayTradingRatio'] ?? e['ratio']),
    }),
    'DAY_TRADING_EXTREME': (e) => LocalizableString(
      'summary.dayTradingExtreme',
      {'ratio': _numStr(e['dayTradingRatio'] ?? e['ratio'])},
    ),
    'CONCENTRATION_HIGH': (_) =>
        const LocalizableString('summary.concentrationHigh'),

    // 價量背離
    'PRICE_VOLUME_BULLISH_DIVERGENCE': (_) =>
        const LocalizableString('summary.bullishDivergence'),
    'PRICE_VOLUME_BEARISH_DIVERGENCE': (_) =>
        const LocalizableString('summary.bearishDivergence'),
    'HIGH_VOLUME_BREAKOUT': (_) =>
        const LocalizableString('summary.highVolumeBreakout'),
    'LOW_VOLUME_ACCUMULATION': (_) =>
        const LocalizableString('summary.lowVolumeAccumulation'),

    // 基本面
    'REVENUE_YOY_SURGE': (e) => LocalizableString('summary.revenueYoySurge', {
      'growth': _numStr(e['yoyGrowth']),
    }),
    'REVENUE_YOY_DECLINE': (e) => LocalizableString(
      'summary.revenueYoyDecline',
      {'growth': _numStr(e['yoyGrowth'])},
    ),
    'REVENUE_MOM_GROWTH': (e) => LocalizableString('summary.revenueMomGrowth', {
      'months': _numStr(e['consecutiveMonths'], fractionDigits: 0),
    }),
    'HIGH_DIVIDEND_YIELD': (e) => LocalizableString(
      'summary.highDividendYield',
      {'yield': _numStr(e['dividendYield'])},
    ),
    'PE_UNDERVALUED': (e) =>
        LocalizableString('summary.peUndervalued', {'pe': _numStr(e['pe'])}),
    'PE_OVERVALUED': (e) =>
        LocalizableString('summary.peOvervalued', {'pe': _numStr(e['pe'])}),
    'PBR_UNDERVALUED': (e) =>
        LocalizableString('summary.pbrUndervalued', {'pbr': _numStr(e['pbr'])}),

    // Killer Features
    'TRADING_WARNING_ATTENTION': (_) =>
        const LocalizableString('summary.warningAttention'),
    'TRADING_WARNING_DISPOSAL': (_) =>
        const LocalizableString('summary.warningDisposal'),
    'INSIDER_SELLING_STREAK': (e) => LocalizableString(
      'summary.insiderSelling',
      {'months': _numStr(e['sellingStreakMonths'], fractionDigits: 0)},
    ),
    'INSIDER_SIGNIFICANT_BUYING': (_) =>
        const LocalizableString('summary.insiderBuying'),
    'HIGH_PLEDGE_RATIO': (_) => const LocalizableString('summary.highPledge'),
    'FOREIGN_CONCENTRATION_WARNING': (_) =>
        const LocalizableString('summary.foreignConcentration'),
    'FOREIGN_EXODUS': (_) => const LocalizableString('summary.foreignExodus'),

    // EPS
    'EPS_YOY_SURGE': (e) => LocalizableString('summary.epsYoYSurge', {
      'growth': _numStr(e['yoyGrowth']),
    }),
    'EPS_CONSECUTIVE_GROWTH': (e) => LocalizableString(
      'summary.epsConsecutiveGrowth',
      {'quarters': _numStr(e['consecutiveQuarters'], fractionDigits: 0)},
    ),
    'EPS_TURNAROUND': (_) => const LocalizableString('summary.epsTurnaround'),
    'EPS_DECLINE_WARNING': (_) => const LocalizableString('summary.epsDecline'),

    // ROE
    'ROE_EXCELLENT': (e) =>
        LocalizableString('summary.roeExcellent', {'roe': _numStr(e['roe'])}),
    'ROE_IMPROVING': (_) => const LocalizableString('summary.roeImproving'),
    'ROE_DECLINING': (_) => const LocalizableString('summary.roeDeclining'),
  };

  static String _numStr(dynamic value, {int fractionDigits = 1}) {
    if (value == null) return '-';
    if (value is num) return value.toStringAsFixed(fractionDigits);
    return value.toString();
  }
}
