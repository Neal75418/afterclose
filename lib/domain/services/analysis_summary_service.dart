import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/domain/models/stock_summary.dart';

/// 個股 AI 智慧分析摘要生成服務
///
/// 純 Dart 類別，以模板式 NLG 將規則引擎結果轉化為結構化自然語言摘要。
class AnalysisSummaryService {
  const AnalysisSummaryService();

  /// 從個股分析資料生成 [StockSummary]
  StockSummary generate({
    required DailyAnalysisEntry? analysis,
    required List<DailyReasonEntry> reasons,
    required DailyPriceEntry? latestPrice,
    required double? priceChange,
    required List<DailyInstitutionalEntry> institutionalHistory,
    required List<FinMindRevenue> revenueHistory,
    required FinMindPER? latestPER,
  }) {
    if (analysis == null && reasons.isEmpty) {
      return StockSummary(
        overallAssessment: 'summary.noSignals'.tr(),
        sentiment: SummarySentiment.neutral,
      );
    }

    final overall = _buildOverallAssessment(analysis, latestPrice, priceChange);
    final keySignals = _buildKeySignals(reasons);
    final riskFactors = _buildRiskFactors(reasons);
    final supporting = _buildSupportingData(
      institutionalHistory,
      revenueHistory,
      latestPER,
    );
    final sentiment = _determineSentiment(analysis, reasons);

    return StockSummary(
      overallAssessment: overall,
      keySignals: keySignals,
      riskFactors: riskFactors,
      supportingData: supporting,
      sentiment: sentiment,
    );
  }

  // ──────────────────────────────────────────
  // 總體評估
  // ──────────────────────────────────────────

  String _buildOverallAssessment(
    DailyAnalysisEntry? analysis,
    DailyPriceEntry? latestPrice,
    double? priceChange,
  ) {
    final parts = <String>[];

    // 趨勢 + 價格
    final close = latestPrice?.close?.toStringAsFixed(1) ?? '-';
    final change = priceChange?.abs().toStringAsFixed(1) ?? '0.0';

    final trendKey = switch (analysis?.trendState) {
      'UP' => 'summary.overallUp',
      'DOWN' => 'summary.overallDown',
      _ => 'summary.overallRange',
    };
    parts.add(trendKey.tr(namedArgs: {'close': close, 'change': change}));

    // 反轉訊號
    if (analysis?.reversalState == 'W2S') {
      parts.add('summary.reversalW2S'.tr());
    } else if (analysis?.reversalState == 'S2W') {
      parts.add('summary.reversalS2W'.tr());
    }

    // 支撐/壓力
    final support = analysis?.supportLevel;
    final resistance = analysis?.resistanceLevel;
    if (support != null && resistance != null) {
      parts.add(
        'summary.supportResistance'.tr(
          namedArgs: {
            'support': support.toStringAsFixed(1),
            'resistance': resistance.toStringAsFixed(1),
          },
        ),
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
    parts.add(scoreKey.tr(namedArgs: {'score': score.toString()}));

    return parts.join('');
  }

  // ──────────────────────────────────────────
  // 關鍵訊號（正面）
  // ──────────────────────────────────────────

  List<String> _buildKeySignals(List<DailyReasonEntry> reasons) {
    final positive = reasons.where((r) => r.ruleScore > 0).toList()
      ..sort((a, b) => b.ruleScore.compareTo(a.ruleScore));

    return positive
        .take(5)
        .map((r) => _reasonToSentence(r.reasonType, r.evidenceJson))
        .where((s) => s != null)
        .cast<String>()
        .toList();
  }

  // ──────────────────────────────────────────
  // 風險因子（負面）
  // ──────────────────────────────────────────

  List<String> _buildRiskFactors(List<DailyReasonEntry> reasons) {
    final negative = reasons.where((r) => r.ruleScore < 0).toList()
      ..sort((a, b) => a.ruleScore.compareTo(b.ruleScore)); // 最負排最前

    return negative
        .take(5)
        .map((r) => _reasonToSentence(r.reasonType, r.evidenceJson))
        .where((s) => s != null)
        .cast<String>()
        .toList();
  }

  // ──────────────────────────────────────────
  // 輔助數據
  // ──────────────────────────────────────────

  List<String> _buildSupportingData(
    List<DailyInstitutionalEntry> institutionalHistory,
    List<FinMindRevenue> revenueHistory,
    FinMindPER? latestPER,
  ) {
    final data = <String>[];

    // 法人動向（最近一筆）
    if (institutionalHistory.isNotEmpty) {
      final latest = institutionalHistory.first;
      final foreign = _formatNet(latest.foreignNet);
      final trust = _formatNet(latest.investmentTrustNet);
      data.add(
        'summary.institutionalFlow'.tr(
          namedArgs: {'foreign': foreign, 'trust': trust},
        ),
      );
    }

    // 估值指標
    final pe = latestPER?.per;
    if (pe != null && pe > 0) {
      final key = pe <= 15.0 ? 'summary.peUndervalued' : 'summary.peOvervalued';
      data.add(key.tr(namedArgs: {'pe': pe.toStringAsFixed(1)}));
    }

    final yield_ = latestPER?.dividendYield;
    if (yield_ != null && yield_ >= 4.0) {
      data.add(
        'summary.highDividendYield'.tr(
          namedArgs: {'yield': yield_.toStringAsFixed(1)},
        ),
      );
    }

    // 營收年增率
    if (revenueHistory.isNotEmpty) {
      final latest = revenueHistory.first;
      final yoy = latest.yoyGrowth;
      if (yoy != null && yoy.abs() >= 20) {
        final key = yoy > 0
            ? 'summary.revenueYoySurge'
            : 'summary.revenueYoyDecline';
        data.add(key.tr(namedArgs: {'growth': yoy.toStringAsFixed(1)}));
      }
    }

    return data;
  }

  // ──────────────────────────────────────────
  // Sentiment 判斷
  // ──────────────────────────────────────────

  SummarySentiment _determineSentiment(
    DailyAnalysisEntry? analysis,
    List<DailyReasonEntry> reasons,
  ) {
    final score = analysis?.score.toInt() ?? 0;
    final positiveCount = reasons.where((r) => r.ruleScore > 0).length;
    final negativeCount = reasons.where((r) => r.ruleScore < 0).length;

    if (score >= 35 && positiveCount > negativeCount) {
      return SummarySentiment.bullish;
    }
    if (score < 15 && negativeCount >= positiveCount) {
      return SummarySentiment.bearish;
    }
    return SummarySentiment.neutral;
  }

  // ──────────────────────────────────────────
  // ReasonType → 自然語言句子
  // ──────────────────────────────────────────

  String? _reasonToSentence(String reasonType, String evidenceJson) {
    final evidence = _parseEvidence(evidenceJson);
    return _sentenceBuilders[reasonType]?.call(evidence);
  }

  Map<String, dynamic> _parseEvidence(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return const {};
  }

  String _formatNet(double? net) {
    if (net == null) return '-';
    final lots = (net / 1000).round(); // 張
    if (lots == 0) return 'summary.netNeutral'.tr();
    if (lots > 0) {
      return 'summary.netBuy'.tr(namedArgs: {'lots': lots.toString()});
    }
    return 'summary.netSell'.tr(namedArgs: {'lots': lots.abs().toString()});
  }

  // ──────────────────────────────────────────
  // Dispatch map: ReasonType code → sentence builder
  // ──────────────────────────────────────────

  static final Map<String, String Function(Map<String, dynamic>)>
  _sentenceBuilders = {
    // 核心訊號
    'REVERSAL_W2S': (_) => 'summary.reversalW2S'.tr(),
    'REVERSAL_S2W': (_) => 'summary.reversalS2W'.tr(),
    'TECH_BREAKOUT': (_) => 'summary.breakout'.tr(),
    'TECH_BREAKDOWN': (_) => 'summary.breakdown'.tr(),
    'VOLUME_SPIKE': (e) => 'summary.volumeSpike'.tr(
      namedArgs: {
        'multiple': _numStr(
          e['multiple'] ?? e['volumeMultiple'],
          fractionDigits: 1,
        ),
      },
    ),
    'PRICE_SPIKE': (e) => 'summary.priceSpike'.tr(
      namedArgs: {'pctChange': _numStr(e['pctChange'] ?? e['changePct'])},
    ),
    'INSTITUTIONAL_BUY': (_) => 'summary.institutionalBuy'.tr(),
    'INSTITUTIONAL_SELL': (_) => 'summary.institutionalSell'.tr(),
    'NEWS_RELATED': (_) => 'summary.newsRelated'.tr(),

    // KD
    'KD_GOLDEN_CROSS': (_) => 'summary.kdGoldenCross'.tr(),
    'KD_DEATH_CROSS': (_) => 'summary.kdDeathCross'.tr(),

    // 法人連續
    'INSTITUTIONAL_BUY_STREAK': (_) => 'summary.institutionalBuyStreak'.tr(),
    'INSTITUTIONAL_SELL_STREAK': (_) => 'summary.institutionalSellStreak'.tr(),

    // K 線型態
    'PATTERN_DOJI': (_) => 'summary.patternDoji'.tr(),
    'PATTERN_BULLISH_ENGULFING': (_) => 'summary.patternBullishEngulfing'.tr(),
    'PATTERN_BEARISH_ENGULFING': (_) => 'summary.patternBearishEngulfing'.tr(),
    'PATTERN_HAMMER': (_) => 'summary.patternHammer'.tr(),
    'PATTERN_HANGING_MAN': (_) => 'summary.patternHangingMan'.tr(),
    'PATTERN_GAP_UP': (_) => 'summary.patternGapUp'.tr(),
    'PATTERN_GAP_DOWN': (_) => 'summary.patternGapDown'.tr(),
    'PATTERN_MORNING_STAR': (_) => 'summary.patternMorningStar'.tr(),
    'PATTERN_EVENING_STAR': (_) => 'summary.patternEveningStar'.tr(),
    'PATTERN_THREE_WHITE_SOLDIERS': (_) =>
        'summary.patternThreeWhiteSoldiers'.tr(),
    'PATTERN_THREE_BLACK_CROWS': (_) => 'summary.patternThreeBlackCrows'.tr(),

    // 技術訊號
    'WEEK_52_HIGH': (_) => 'summary.week52High'.tr(),
    'WEEK_52_LOW': (_) => 'summary.week52Low'.tr(),
    'MA_ALIGNMENT_BULLISH': (_) => 'summary.maAlignmentBullish'.tr(),
    'MA_ALIGNMENT_BEARISH': (_) => 'summary.maAlignmentBearish'.tr(),
    'RSI_EXTREME_OVERBOUGHT': (e) => 'summary.rsiOverbought'.tr(
      namedArgs: {'rsi': _numStr(e['rsi'], fractionDigits: 0)},
    ),
    'RSI_EXTREME_OVERSOLD': (e) => 'summary.rsiOversold'.tr(
      namedArgs: {'rsi': _numStr(e['rsi'], fractionDigits: 0)},
    ),

    // 延伸市場資料
    'FOREIGN_SHAREHOLDING_INCREASING': (_) => 'summary.foreignIncreasing'.tr(),
    'FOREIGN_SHAREHOLDING_DECREASING': (_) => 'summary.foreignDecreasing'.tr(),
    'DAY_TRADING_HIGH': (e) => 'summary.dayTradingHigh'.tr(
      namedArgs: {'ratio': _numStr(e['dayTradingRatio'] ?? e['ratio'])},
    ),
    'DAY_TRADING_EXTREME': (e) => 'summary.dayTradingExtreme'.tr(
      namedArgs: {'ratio': _numStr(e['dayTradingRatio'] ?? e['ratio'])},
    ),
    'CONCENTRATION_HIGH': (_) => 'summary.concentrationHigh'.tr(),

    // 價量背離
    'PRICE_VOLUME_BULLISH_DIVERGENCE': (_) => 'summary.bullishDivergence'.tr(),
    'PRICE_VOLUME_BEARISH_DIVERGENCE': (_) => 'summary.bearishDivergence'.tr(),
    'HIGH_VOLUME_BREAKOUT': (_) => 'summary.highVolumeBreakout'.tr(),
    'LOW_VOLUME_ACCUMULATION': (_) => 'summary.lowVolumeAccumulation'.tr(),

    // 基本面
    'REVENUE_YOY_SURGE': (e) => 'summary.revenueYoySurge'.tr(
      namedArgs: {'growth': _numStr(e['yoyGrowth'])},
    ),
    'REVENUE_YOY_DECLINE': (e) => 'summary.revenueYoyDecline'.tr(
      namedArgs: {'growth': _numStr(e['yoyGrowth'])},
    ),
    'REVENUE_MOM_GROWTH': (e) => 'summary.revenueMomGrowth'.tr(
      namedArgs: {'months': _numStr(e['consecutiveMonths'], fractionDigits: 0)},
    ),
    'HIGH_DIVIDEND_YIELD': (e) => 'summary.highDividendYield'.tr(
      namedArgs: {'yield': _numStr(e['dividendYield'])},
    ),
    'PE_UNDERVALUED': (e) =>
        'summary.peUndervalued'.tr(namedArgs: {'pe': _numStr(e['pe'])}),
    'PE_OVERVALUED': (e) =>
        'summary.peOvervalued'.tr(namedArgs: {'pe': _numStr(e['pe'])}),
    'PBR_UNDERVALUED': (e) =>
        'summary.pbrUndervalued'.tr(namedArgs: {'pbr': _numStr(e['pbr'])}),

    // Killer Features
    'TRADING_WARNING_ATTENTION': (_) => 'summary.warningAttention'.tr(),
    'TRADING_WARNING_DISPOSAL': (_) => 'summary.warningDisposal'.tr(),
    'INSIDER_SELLING_STREAK': (e) => 'summary.insiderSelling'.tr(
      namedArgs: {
        'months': _numStr(e['sellingStreakMonths'], fractionDigits: 0),
      },
    ),
    'INSIDER_SIGNIFICANT_BUYING': (_) => 'summary.insiderBuying'.tr(),
    'HIGH_PLEDGE_RATIO': (_) => 'summary.highPledge'.tr(),
    'FOREIGN_CONCENTRATION_WARNING': (_) => 'summary.foreignConcentration'.tr(),
    'FOREIGN_EXODUS': (_) => 'summary.foreignExodus'.tr(),

    // EPS
    'EPS_YOY_SURGE': (e) => 'summary.epsYoYSurge'.tr(
      namedArgs: {'growth': _numStr(e['yoyGrowth'])},
    ),
    'EPS_CONSECUTIVE_GROWTH': (e) => 'summary.epsConsecutiveGrowth'.tr(
      namedArgs: {
        'quarters': _numStr(e['consecutiveQuarters'], fractionDigits: 0),
      },
    ),
    'EPS_TURNAROUND': (_) => 'summary.epsTurnaround'.tr(),
    'EPS_DECLINE_WARNING': (_) => 'summary.epsDecline'.tr(),

    // ROE
    'ROE_EXCELLENT': (e) =>
        'summary.roeExcellent'.tr(namedArgs: {'roe': _numStr(e['roe'])}),
    'ROE_IMPROVING': (_) => 'summary.roeImproving'.tr(),
    'ROE_DECLINING': (_) => 'summary.roeDeclining'.tr(),
  };

  static String _numStr(dynamic value, {int fractionDigits = 1}) {
    if (value == null) return '-';
    if (value is num) return value.toStringAsFixed(fractionDigits);
    return value.toString();
  }
}
