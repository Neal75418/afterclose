import 'dart:convert';

import 'package:collection/collection.dart';

import 'package:afterclose/core/constants/analysis_params.dart';
import 'package:afterclose/core/constants/calibrated_scores/horizon.dart';
import 'package:afterclose/core/constants/rule_enums.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/price_limit.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/domain/models/stock_summary.dart';
import 'package:afterclose/domain/services/signal_confluence.dart';
import 'package:afterclose/domain/services/technical_indicator_service.dart';
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
  ///
  /// Stage 5c dual-horizon: [horizon] 決定 service 讀取 `scoreShort` /
  /// `scoreLong` 及 `ruleScoreShort` / `ruleScoreLong`。Placeholder JSON
  /// 為空時兩個 horizon 產生相同結果（invariant：pre-calibration 期間切換
  /// 不會產生 user-visible 變化）。
  SummaryData generate({
    required DailyAnalysisEntry? analysis,
    required List<DailyReasonEntry> reasons,
    required DailyPriceEntry? latestPrice,
    required double? priceChange,
    required List<DailyInstitutionalEntry> institutionalHistory,
    required List<FinMindRevenue> revenueHistory,
    required FinMindPER? latestPER,
    required Horizon horizon,
    MarketStage? marketStage,
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
      horizon: horizon,
      marketStage: marketStage,
    );

    // 匯流整合的關鍵訊號 & 風險因子
    final keySignals = _buildKeySignals(
      reasons,
      bullishConfluence,
      priceChange: priceChange,
      horizon: horizon,
    );
    final riskFactors = _buildRiskFactors(
      reasons,
      bearishConfluence,
      priceChange: priceChange,
      horizon: horizon,
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
      horizon: horizon,
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
      horizon: horizon,
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
    required Horizon horizon,
    MarketStage? marketStage,
  }) {
    final parts = <LocalizableString>[];

    // 大盤位階 context：讓個股多空 read 有 regime 脈絡（順勢 vs 逆勢）。
    // insufficient / null（大盤資料未載入）時不顯示，graceful degrade。
    final marketKey = switch (marketStage) {
      MarketStage.bullish => 'summary.marketBullish',
      MarketStage.bearish => 'summary.marketBearish',
      MarketStage.neutral => 'summary.marketNeutral',
      _ => null,
    };
    if (marketKey != null) {
      parts.add(LocalizableString(marketKey));
    }

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
        TrendState.upCode => 'summary.overallUp',
        TrendState.downCode => 'summary.overallDown',
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
    if (analysis?.reversalState == ReversalState.w2sCode &&
        !confluenceConsumed.contains(SignalName.reversalW2S)) {
      parts.add(const LocalizableString('summary.reversalW2S'));
    } else if (analysis?.reversalState == ReversalState.s2wCode &&
        !confluenceConsumed.contains(SignalName.reversalS2W)) {
      parts.add(const LocalizableString('summary.reversalS2W'));
    }

    // 支撐/壓力（含距離百分比 + 風險報酬比）
    final support = analysis?.supportLevel;
    final resistance = analysis?.resistanceLevel;
    if (support != null && resistance != null) {
      final closeVal = latestPrice?.close;
      if (closeVal != null && closeVal > 0) {
        final supportDist = ((closeVal - support) / closeVal * 100).abs();
        final resistanceDist = ((resistance - closeVal) / closeVal * 100).abs();
        parts.add(
          LocalizableString('summary.supportResistanceWithDist', {
            'support': support.toStringAsFixed(1),
            'resistance': resistance.toStringAsFixed(1),
            'supportDist': supportDist.toStringAsFixed(1),
            'resistanceDist': resistanceDist.toStringAsFixed(1),
          }),
        );

        // 風險報酬比（upside / downside）
        final downside = closeVal - support;
        final upside = resistance - closeVal;
        if (downside > 0 && upside > 0) {
          final rr = upside / downside;
          parts.add(
            LocalizableString('summary.riskReward', {
              'ratio': rr.toStringAsFixed(1),
            }),
          );
          // RR 判讀：上檔空間 vs 下檔風險（賠率高/低提示）
          if (rr >= AnalysisParams.riskRewardFavorableThreshold) {
            parts.add(const LocalizableString('summary.riskRewardFavorable'));
          } else if (rr < 1) {
            parts.add(const LocalizableString('summary.riskRewardPoor'));
          }
        }
      } else {
        parts.add(
          LocalizableString('summary.supportResistance', {
            'support': support.toStringAsFixed(1),
            'resistance': resistance.toStringAsFixed(1),
          }),
        );
      }
    }

    // 分數評語（Stage 5c: 依 horizon 讀對應欄位）
    final score = _analysisScoreFor(analysis, horizon).toInt();
    final scoreKey = switch (score) {
      >= AnalysisParams.scoreExceptionalThreshold => 'summary.scoreExceptional',
      >= AnalysisParams.scoreStrongThreshold => 'summary.scoreStrong',
      >= AnalysisParams.scoreWorthwatchingThreshold =>
        'summary.scoreWorthwatching',
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
    required Horizon horizon,
  }) {
    // mergeSort 保證 stable — 同分時保留輸入順序（= [reasons] 註冊順序），
    // 避免不同 build 摘要顯示的 chip 順序漂移。
    final positive = reasons
        .where((r) => _ruleScoreFor(r, horizon) > 0)
        .toList();
    mergeSort<DailyReasonEntry>(
      positive,
      compare: (a, b) =>
          _ruleScoreFor(b, horizon).compareTo(_ruleScoreFor(a, horizon)),
    );

    const maxItems = AnalysisParams.summaryMaxItems;
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
    required Horizon horizon,
  }) {
    final negative = reasons
        .where((r) => _ruleScoreFor(r, horizon) < 0)
        .toList();
    mergeSort<DailyReasonEntry>(
      negative,
      compare: (a, b) =>
          _ruleScoreFor(a, horizon).compareTo(_ruleScoreFor(b, horizon)),
    );

    const maxItems = AnalysisParams.summaryMaxItems;
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
      // DAO 回傳 ascending order，.last 才是最新一天
      final latest = institutionalHistory.last;
      final foreign = _formatNetLocalizable(latest.foreignNet);
      final trust = _formatNetLocalizable(latest.investmentTrustNet);
      data.add(
        LocalizableString('summary.institutionalFlow', const {}, {
          'foreign': foreign,
          'trust': trust,
        }),
      );

      // 多日趨勢：從最新往回算連買/連賣天數
      if (institutionalHistory.length >= 3) {
        final consecutiveBuyDays = _countConsecutiveDays(
          institutionalHistory.reversed,
          (e) => (e.foreignNet ?? 0) + (e.investmentTrustNet ?? 0) > 0,
        );
        if (consecutiveBuyDays >= 3) {
          data.add(
            LocalizableString('summary.institutionalBuyTrend', {
              'days': consecutiveBuyDays.toString(),
            }),
          );
        } else {
          final consecutiveSellDays = _countConsecutiveDays(
            institutionalHistory.reversed,
            (e) => (e.foreignNet ?? 0) + (e.investmentTrustNet ?? 0) < 0,
          );
          if (consecutiveSellDays >= 3) {
            data.add(
              LocalizableString('summary.institutionalSellTrend', {
                'days': consecutiveSellDays.toString(),
              }),
            );
          }
        }
      }
    }

    final pe = latestPER?.per;
    if (pe != null && pe > 0) {
      final key = pe <= AnalysisParams.peSummaryLowLabelThreshold
          ? 'summary.peUndervalued'
          : 'summary.peOvervalued';
      data.add(LocalizableString(key, {'pe': pe.toStringAsFixed(1)}));
    }

    final yield_ = latestPER?.dividendYield;
    if (yield_ != null &&
        yield_ >= AnalysisParams.dividendYieldSummaryLabelThreshold) {
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
    required Horizon horizon,
  }) {
    // Stage 5c: 依 horizon 讀對應的 score + ruleScore
    final score = _analysisScoreFor(analysis, horizon).toInt();

    // 加權計算（依 horizon 讀 per-rule 分數）
    final positiveWeight = reasons
        .where((r) => _ruleScoreFor(r, horizon) > 0)
        .fold<double>(0, (sum, r) => sum + _ruleScoreFor(r, horizon));
    final negativeWeight = reasons
        .where((r) => _ruleScoreFor(r, horizon) < 0)
        .fold<double>(0, (sum, r) => sum + _ruleScoreFor(r, horizon).abs());

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

    // 衝突時提高判斷門檻（不產生 strong 級別）
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

    // 5 級情緒梯度：先檢查 strong 門檻
    if (bullRatio >= AnalysisParams.strongBullRatioThreshold &&
        score >= AnalysisParams.strongBullScoreThreshold) {
      return SummarySentiment.strongBullish;
    }
    if (bullRatio >= AnalysisParams.bullRatioThreshold &&
        score >= AnalysisParams.bullScoreThreshold) {
      return SummarySentiment.bullish;
    }
    if (bullRatio <= AnalysisParams.strongBearRatioThreshold &&
        score < AnalysisParams.strongBearScoreThreshold) {
      return SummarySentiment.strongBearish;
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
    required Horizon horizon,
  }) {
    var points = 0;

    final totalSignals = reasons.length;
    if (totalSignals >= AnalysisParams.manySignalsThreshold) {
      points += 2;
    } else if (totalSignals >= AnalysisParams.someSignalsThreshold) {
      points += 1;
    }

    // 高分訊號品質加權：有 2+ 個 |ruleScore| ≥ 15 的訊號（依當前 horizon）
    final highScoreSignals = reasons
        .where(
          (r) =>
              _ruleScoreFor(r, horizon).abs() >=
              AnalysisParams.highQualitySignalThreshold,
        )
        .length;
    if (highScoreSignals >= 2) points += 1;

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
        'AnalysisSummaryService',
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

  /// 從最新往回數，符合條件的連續天數
  int _countConsecutiveDays(
    Iterable<DailyInstitutionalEntry> entries,
    bool Function(DailyInstitutionalEntry) predicate,
  ) {
    var count = 0;
    for (final e in entries) {
      if (predicate(e)) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  // ==================================================
  // 映射表：ReasonType 代碼 → LocalizableString 建構
  // ==================================================

  // ==================================================
  // 核心訊號
  // ==================================================
  static final _coreSignals =
      <String, LocalizableString Function(Map<String, dynamic>)>{
        SignalName.reversalW2S: (_) =>
            const LocalizableString('summary.reversalW2S'),
        SignalName.reversalS2W: (_) =>
            const LocalizableString('summary.reversalS2W'),
        SignalName.techBreakout: (_) =>
            const LocalizableString('summary.breakout'),
        SignalName.techBreakdown: (_) =>
            const LocalizableString('summary.breakdown'),
        SignalName.volumeSpike: (e) =>
            LocalizableString('summary.volumeSpike', {
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
      };

  // ==================================================
  // KD 訊號
  // ==================================================
  static final _kdSignals =
      <String, LocalizableString Function(Map<String, dynamic>)>{
        SignalName.kdGoldenCross: (_) =>
            const LocalizableString('summary.kdGoldenCross'),
        SignalName.kdDeathCross: (_) =>
            const LocalizableString('summary.kdDeathCross'),
      };

  // ==================================================
  // 法人連續買賣
  // ==================================================
  static final _institutionalStreakSignals =
      <String, LocalizableString Function(Map<String, dynamic>)>{
        SignalName.institutionalBuyStreak: (e) {
          final days = e['streakDays'];
          if (days != null) {
            return LocalizableString('summary.institutionalBuyStreakDays', {
              'days': _numStr(days, fractionDigits: 0),
            });
          }
          return const LocalizableString('summary.institutionalBuyStreak');
        },
        SignalName.institutionalSellStreak: (e) {
          final days = e['streakDays'];
          if (days != null) {
            return LocalizableString('summary.institutionalSellStreakDays', {
              'days': _numStr(days, fractionDigits: 0),
            });
          }
          return const LocalizableString('summary.institutionalSellStreak');
        },
      };

  // ==================================================
  // K 線型態
  // ==================================================
  static final _candlestickPatterns =
      <String, LocalizableString Function(Map<String, dynamic>)>{
        SignalName.patternDoji: (_) =>
            const LocalizableString('summary.patternDoji'),
        SignalName.patternDojiBearish: (_) =>
            const LocalizableString('summary.patternDojiBearish'),
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
      };

  // ==================================================
  // 技術指標訊號
  // ==================================================
  static final _technicalIndicators =
      <String, LocalizableString Function(Map<String, dynamic>)>{
        SignalName.week52High: (_) =>
            const LocalizableString('summary.week52High'),
        SignalName.week52Low: (_) =>
            const LocalizableString('summary.week52Low'),
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
      };

  // ==================================================
  // 延伸市場資料
  // ==================================================
  static final _extendedMarketData =
      <String, LocalizableString Function(Map<String, dynamic>)>{
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
      };

  // ==================================================
  // 價量背離
  // ==================================================
  static final _priceVolumeDivergence =
      <String, LocalizableString Function(Map<String, dynamic>)>{
        SignalName.priceVolumeWeakRally: (_) =>
            const LocalizableString('summary.priceVolumeWeakRally'),
        SignalName.priceVolumeBearishDivergence: (_) =>
            const LocalizableString('summary.bearishDivergence'),
        SignalName.highVolumeBreakout: (_) =>
            const LocalizableString('summary.highVolumeBreakout'),
        SignalName.lowVolumeAccumulation: (_) =>
            const LocalizableString('summary.lowVolumeAccumulation'),
      };

  // ==================================================
  // 基本面
  // ==================================================
  static final _fundamentalSignals =
      <String, LocalizableString Function(Map<String, dynamic>)>{
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
        SignalName.revenueNewHigh: (e) => LocalizableString(
          'summary.revenueNewHigh',
          {'surpassPct': _numStr(e['surpassPct'])},
        ),
        SignalName.highDividendYield: (e) => LocalizableString(
          'summary.highDividendYield',
          {'yield': _numStr(e['dividendYield'])},
        ),
        SignalName.peUndervalued: (e) => LocalizableString(
          'summary.peUndervalued',
          {'pe': _numStr(e['pe'])},
        ),
        SignalName.peOvervalued: (e) =>
            LocalizableString('summary.peOvervalued', {'pe': _numStr(e['pe'])}),
        SignalName.pbrUndervalued: (e) => LocalizableString(
          'summary.pbrUndervalued',
          {'pbr': _numStr(e['pbr'])},
        ),
      };

  // ==================================================
  // Killer Features
  // ==================================================
  static final _killerFeatures =
      <String, LocalizableString Function(Map<String, dynamic>)>{
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
      };

  // ==================================================
  // EPS 訊號
  // ==================================================
  static final _epsSignals =
      <String, LocalizableString Function(Map<String, dynamic>)>{
        SignalName.epsYoySurge: (e) => LocalizableString(
          'summary.epsYoYSurge',
          {'growth': _numStr(e['yoyGrowth'])},
        ),
        SignalName.epsConsecutiveGrowth: (e) => LocalizableString(
          'summary.epsConsecutiveGrowth',
          {'quarters': _numStr(e['consecutiveQuarters'], fractionDigits: 0)},
        ),
        SignalName.epsTurnaround: (_) =>
            const LocalizableString('summary.epsTurnaround'),
        SignalName.epsDeclineWarning: (_) =>
            const LocalizableString('summary.epsDecline'),
      };

  // ==================================================
  // ROE 訊號
  // ==================================================
  static final _roeSignals =
      <String, LocalizableString Function(Map<String, dynamic>)>{
        SignalName.roeExcellent: (e) => LocalizableString(
          'summary.roeExcellent',
          {'roe': _numStr(e['roe'])},
        ),
        SignalName.roeImproving: (_) =>
            const LocalizableString('summary.roeImproving'),
        SignalName.roeDeclining: (_) =>
            const LocalizableString('summary.roeDeclining'),
      };

  /// 回檔模式 v2 主訊號（2026-07-23 稽核修復：v2 上線時漏接摘要層，
  /// 只靠回檔訊號上榜的股票摘要會不提核心訊號）
  static final _pullbackSignals =
      <String, LocalizableString Function(Map<String, dynamic>)>{
        SignalName.pullbackToMa20: (e) => LocalizableString(
          'summary.pullbackToMa20',
          {'distance': _numStr(e['distanceToMa20Pct'])},
        ),
        SignalName.pullbackToMa10: (_) =>
            const LocalizableString('summary.pullbackToMa10'),
        SignalName.hammerAtSupport: (_) =>
            const LocalizableString('summary.hammerAtSupport'),
        SignalName.kdHighPullback: (_) =>
            const LocalizableString('summary.kdHighPullback'),
      };

  /// 合併所有分類的 signal builders
  static final Map<String, LocalizableString Function(Map<String, dynamic>)>
  _signalBuilders = {
    ..._coreSignals,
    ..._kdSignals,
    ..._institutionalStreakSignals,
    ..._candlestickPatterns,
    ..._pullbackSignals,
    ..._technicalIndicators,
    ..._extendedMarketData,
    ..._priceVolumeDivergence,
    ..._fundamentalSignals,
    ..._killerFeatures,
    ..._epsSignals,
    ..._roeSignals,
  };

  static String _numStr(dynamic value, {int fractionDigits = 1}) {
    if (value == null) return '-';
    if (value is num) return value.toStringAsFixed(fractionDigits);
    return value.toString();
  }

  // ==================================================
  // Horizon resolvers (Stage 5c)
  // ==================================================

  /// 依 [horizon] 讀取 [DailyAnalysisEntry] 對應欄位的 score
  ///
  /// 空 analysis → 0，與既有的 `analysis?.scoreShort ?? 0` 行為一致。
  static double _analysisScoreFor(
    DailyAnalysisEntry? analysis,
    Horizon horizon,
  ) {
    if (analysis == null) return 0;
    return switch (horizon) {
      Horizon.short => analysis.scoreShort,
      Horizon.long => analysis.scoreLong,
    };
  }

  /// 依 [horizon] 讀取 [DailyReasonEntry] 對應欄位的 per-rule score
  static double _ruleScoreFor(DailyReasonEntry reason, Horizon horizon) {
    return switch (horizon) {
      Horizon.short => reason.ruleScoreShort,
      Horizon.long => reason.ruleScoreLong,
    };
  }
}
