import 'package:afterclose/data/database/app_database.dart';

/// 訊號匯流模式定義
///
/// 當多個相關訊號同時觸發時，合成為一個更有洞察力的結論，
/// 而非獨立列出每條訊號。
class SignalConfluence {
  const SignalConfluence({
    required this.id,
    required this.signalGroups,
    required this.summaryKey,
    this.isBullish = true,
  });

  /// 模式識別 ID
  final String id;

  /// 訊號群組：每個群組中至少須匹配一個 reasonType
  ///
  /// 所有群組都必須被滿足，才算匹配此匯流模式。
  /// 例如 `[{'TECH_BREAKOUT'}, {'VOLUME_SPIKE'}]`
  /// 表示需要同時有突破 + 量能放大。
  final List<Set<String>> signalGroups;

  /// 匯流摘要的 localization key
  final String summaryKey;

  /// 是否為偏多模式（用於分類到 keySignals vs riskFactors）
  final bool isBullish;

  /// 檢查此模式是否被觸發
  ///
  /// 回傳匹配的 reasonType 集合（用於消耗已匹配的訊號），
  /// 若未匹配則回傳 null。
  Set<String>? match(Set<String> activeTypes) {
    final matched = <String>{};
    for (final group in signalGroups) {
      final hit = group.intersection(activeTypes);
      if (hit.isEmpty) return null; // 此群組無匹配 → 整體不匹配
      matched.addAll(hit);
    }
    return matched;
  }
}

/// 匯流偵測結果
class ConfluenceResult {
  const ConfluenceResult({
    required this.summaryKeys,
    required this.consumedTypes,
    required this.matchedCount,
  }) : assert(matchedCount == summaryKeys.length);

  /// 匯流摘要的 localization key 列表（由 presentation 層負責翻譯）
  final List<String> summaryKeys;

  /// 被匯流模式消耗的 reasonType 集合
  final Set<String> consumedTypes;

  /// 匹配到的匯流模式數量
  final int matchedCount;
}

/// 訊號匯流偵測器
class SignalConfluenceDetector {
  const SignalConfluenceDetector();

  /// 偵測匯流模式
  ///
  /// [reasons] 觸發的規則列表
  /// [bullish] true = 只偵測多頭模式，false = 只偵測空頭模式
  ConfluenceResult detect(
    List<DailyReasonEntry> reasons, {
    required bool bullish,
  }) {
    final activeTypes = reasons.map((r) => r.reasonType).toSet();
    final keys = <String>[];
    final consumed = <String>{};

    final patterns = bullish ? _bullishPatterns : _bearishPatterns;

    for (final pattern in patterns) {
      final remaining = activeTypes.difference(consumed);
      final matched = pattern.match(remaining);
      if (matched != null) {
        keys.add(pattern.summaryKey);
        consumed.addAll(matched);
      }
    }

    return ConfluenceResult(
      summaryKeys: keys,
      consumedTypes: consumed,
      matchedCount: keys.length,
    );
  }

  // ──────────────────────────────────────────
  // 多頭匯流模式
  // ──────────────────────────────────────────

  static const _bullishPatterns = [
    // 量價齊揚：突破 + 量能放大
    SignalConfluence(
      id: 'volume_price_breakout',
      signalGroups: [
        {'TECH_BREAKOUT', 'HIGH_VOLUME_BREAKOUT'},
        {'VOLUME_SPIKE'},
      ],
      summaryKey: 'summary.confluenceVolumeBreakout',
    ),

    // 法人認同：法人買超 + 技術面轉強
    SignalConfluence(
      id: 'institutional_confirmation',
      signalGroups: [
        {'INSTITUTIONAL_BUY', 'INSTITUTIONAL_BUY_STREAK'},
        {'TECH_BREAKOUT', 'REVERSAL_W2S', 'MA_ALIGNMENT_BULLISH'},
      ],
      summaryKey: 'summary.confluenceInstitutional',
    ),

    // 底部反轉：弱轉強 + KD 黃金交叉
    SignalConfluence(
      id: 'bottom_reversal',
      signalGroups: [
        {'REVERSAL_W2S'},
        {
          'KD_GOLDEN_CROSS',
          'PATTERN_HAMMER',
          'PATTERN_MORNING_STAR',
          'RSI_EXTREME_OVERSOLD',
        },
      ],
      summaryKey: 'summary.confluenceBottomReversal',
    ),

    // 基本面+技術面共振
    SignalConfluence(
      id: 'fundamental_technical',
      signalGroups: [
        {'REVENUE_YOY_SURGE', 'EPS_YOY_SURGE', 'EPS_CONSECUTIVE_GROWTH'},
        {'TECH_BREAKOUT', 'REVERSAL_W2S', 'MA_ALIGNMENT_BULLISH'},
      ],
      summaryKey: 'summary.confluenceFundamentalTechnical',
    ),
  ];

  // ──────────────────────────────────────────
  // 空頭匯流模式
  // ──────────────────────────────────────────

  static const _bearishPatterns = [
    // 頭部反轉：強轉弱 + KD 死亡交叉
    SignalConfluence(
      id: 'top_reversal',
      signalGroups: [
        {'REVERSAL_S2W'},
        {
          'KD_DEATH_CROSS',
          'PATTERN_HANGING_MAN',
          'PATTERN_EVENING_STAR',
          'RSI_EXTREME_OVERBOUGHT',
        },
      ],
      summaryKey: 'summary.confluenceTopReversal',
      isBullish: false,
    ),

    // 技術面崩跌：跌破支撐 + 空頭排列
    SignalConfluence(
      id: 'bearish_breakdown',
      signalGroups: [
        {'TECH_BREAKDOWN'},
        {'MA_ALIGNMENT_BEARISH', 'KD_DEATH_CROSS'},
      ],
      summaryKey: 'summary.confluenceBearishBreakdown',
      isBullish: false,
    ),

    // 低估陷阱：估值偏低但趨勢轉弱
    SignalConfluence(
      id: 'value_trap',
      signalGroups: [
        {'PE_UNDERVALUED', 'PBR_UNDERVALUED'},
        {
          'REVERSAL_S2W',
          'TECH_BREAKDOWN',
          'EPS_DECLINE_WARNING',
          'MA_ALIGNMENT_BEARISH',
        },
      ],
      summaryKey: 'summary.confluenceValueTrap',
      isBullish: false,
    ),
  ];
}
