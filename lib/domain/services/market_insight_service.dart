import 'package:afterclose/domain/services/chip_anomaly_service.dart';
import 'package:afterclose/domain/services/market_sentiment_service.dart';
import 'package:afterclose/presentation/providers/market_overview_provider.dart';

/// 智慧摘要洞察類型
enum InsightType {
  sentimentExtreme,
  institutionalStreak,
  volumeAnomaly,
  chipAlert,
  limitImbalance,
  marginSurge,
  industryConcentration,
}

/// 洞察嚴重度
enum InsightSeverity { warning, info }

/// 單筆市場洞察
class MarketInsight {
  const MarketInsight({
    required this.type,
    required this.severity,
    required this.priority,
    required this.titleKey,
    required this.descKey,
    this.descArgs = const {},
    this.isPositive = true,
  });

  final InsightType type;
  final InsightSeverity severity;

  /// 優先級（數字越大越重要）
  final int priority;

  /// i18n title key
  final String titleKey;

  /// i18n description key
  final String descKey;

  /// i18n description named arguments
  final Map<String, String> descArgs;

  /// 方向性：true = 偏多/正面，false = 偏空/負面
  /// 用於 UI 色條判斷（upColor vs downColor），與 i18n key 命名解耦。
  final bool isPositive;
}

/// 智慧摘要偵測服務
///
/// 純計算，從現有 [MarketOverviewState] 資料中偵測最重要的市場訊號。
/// Top 4 顯示，至少 2 條才顯示區塊。
class MarketInsightService {
  const MarketInsightService._();

  /// 偵測當前市場洞察
  ///
  /// 回傳按 priority 降序排列的前 4 條洞察。
  /// 若符合條件不足 2 條，回傳空 list。
  static List<MarketInsight> detect({
    MarketSentiment? sentiment,
    InstitutionalStreak? streak,
    TurnoverComparison? turnoverComparison,
    List<ChipAnomaly> chipAnomalies = const [],
    LimitUpDown? limitUpDown,
    MarginTradingTotals? margin,
    List<IndustrySummary> industries = const [],
  }) {
    final candidates = <MarketInsight>[];

    // Rule 1: 情緒極端 (priority 10)
    _checkSentimentExtreme(sentiment, candidates);

    // Rule 2: 法人連續買賣 (priority 8)
    _checkInstitutionalStreak(streak, candidates);

    // Rule 3: 量能異常 (priority 7)
    _checkVolumeAnomaly(turnoverComparison, candidates);

    // Rule 4: 籌碼警示 (priority 6)
    _checkChipAlert(chipAnomalies, candidates);

    // Rule 5: 漲停跌停失衡 (priority 5)
    _checkLimitImbalance(limitUpDown, candidates);

    // Rule 6: 融資融券異動 (priority 4)
    _checkMarginSurge(margin, candidates);

    // Rule 7: 產業集中 (priority 3)
    _checkIndustryConcentration(industries, candidates);

    // 不足 2 條 → 不顯示
    if (candidates.length < 2) return [];

    // 按 priority 降序排序，取前 4 條
    candidates.sort((a, b) => b.priority.compareTo(a.priority));
    return candidates.take(4).toList();
  }

  /// Rule 1: 情緒極端
  static void _checkSentimentExtreme(
    MarketSentiment? sentiment,
    List<MarketInsight> candidates,
  ) {
    if (sentiment == null) return;

    if (sentiment.level == SentimentLevel.extremeFear) {
      candidates.add(
        MarketInsight(
          type: InsightType.sentimentExtreme,
          severity: InsightSeverity.warning,
          priority: 10,
          titleKey: 'marketOverview.keyInsights.sentimentExtreme.title',
          descKey: 'marketOverview.keyInsights.sentimentExtreme.descFear',
          descArgs: {'score': sentiment.score.toStringAsFixed(0)},
          isPositive: false,
        ),
      );
    } else if (sentiment.level == SentimentLevel.extremeGreed) {
      candidates.add(
        MarketInsight(
          type: InsightType.sentimentExtreme,
          severity: InsightSeverity.warning,
          priority: 10,
          titleKey: 'marketOverview.keyInsights.sentimentExtreme.title',
          descKey: 'marketOverview.keyInsights.sentimentExtreme.descGreed',
          descArgs: {'score': sentiment.score.toStringAsFixed(0)},
          isPositive: true,
        ),
      );
    }
  }

  /// Rule 2: 法人連續買賣超 ≥ 5 天
  static void _checkInstitutionalStreak(
    InstitutionalStreak? streak,
    List<MarketInsight> candidates,
  ) {
    if (streak == null) return;

    // 檢查外資和投信（取絕對值最大的那個）
    // 使用 foreignBuy/foreignSell/trustBuy/trustSell 分別的 desc key
    final entries = [
      (streak.foreignStreak, 'Foreign'),
      (streak.trustStreak, 'Trust'),
    ];

    for (final (days, who) in entries) {
      if (days.abs() >= 5) {
        final isBuy = days > 0;
        final direction = isBuy ? 'Buy' : 'Sell';
        candidates.add(
          MarketInsight(
            type: InsightType.institutionalStreak,
            severity: InsightSeverity.warning,
            priority: 8,
            titleKey: 'marketOverview.keyInsights.institutionalStreak.title',
            descKey:
                'marketOverview.keyInsights.institutionalStreak.desc$who$direction',
            descArgs: {'days': days.abs().toString()},
            isPositive: isBuy,
          ),
        );
        break; // 只取最重要的一條
      }
    }
  }

  /// Rule 3: 量能異常（> 50% 或 < -30%）
  static void _checkVolumeAnomaly(
    TurnoverComparison? turnoverComparison,
    List<MarketInsight> candidates,
  ) {
    if (turnoverComparison == null) return;

    final pct = turnoverComparison.changePercent;
    if (pct > 50) {
      candidates.add(
        MarketInsight(
          type: InsightType.volumeAnomaly,
          severity: InsightSeverity.warning,
          priority: 7,
          titleKey: 'marketOverview.keyInsights.volumeAnomaly.title',
          descKey: 'marketOverview.keyInsights.volumeAnomaly.descHigh',
          descArgs: {'pct': pct.toStringAsFixed(0)},
          isPositive: true,
        ),
      );
    } else if (pct < -30) {
      candidates.add(
        MarketInsight(
          type: InsightType.volumeAnomaly,
          severity: InsightSeverity.info,
          priority: 7,
          titleKey: 'marketOverview.keyInsights.volumeAnomaly.title',
          descKey: 'marketOverview.keyInsights.volumeAnomaly.descLow',
          descArgs: {'pct': pct.abs().toStringAsFixed(0)},
          isPositive: false,
        ),
      );
    }
  }

  /// Rule 4: 籌碼警示（有 high severity 異動）
  static void _checkChipAlert(
    List<ChipAnomaly> chipAnomalies,
    List<MarketInsight> candidates,
  ) {
    final highCount = chipAnomalies
        .where((a) => a.severity == ChipSeverity.high)
        .length;
    if (highCount > 0) {
      candidates.add(
        MarketInsight(
          type: InsightType.chipAlert,
          severity: InsightSeverity.warning,
          priority: 6,
          titleKey: 'marketOverview.keyInsights.chipAlert.title',
          descKey: 'marketOverview.keyInsights.chipAlert.desc',
          descArgs: {'count': highCount.toString()},
          isPositive: false,
        ),
      );
    }
  }

  /// Rule 5: 漲停跌停失衡（≥ 30 家）
  static void _checkLimitImbalance(
    LimitUpDown? limitUpDown,
    List<MarketInsight> candidates,
  ) {
    if (limitUpDown == null) return;

    if (limitUpDown.limitUp >= 30 || limitUpDown.limitDown >= 30) {
      final isUpDominant = limitUpDown.limitUp >= limitUpDown.limitDown;
      candidates.add(
        MarketInsight(
          type: InsightType.limitImbalance,
          severity: InsightSeverity.warning,
          priority: 5,
          titleKey: 'marketOverview.keyInsights.limitImbalance.title',
          descKey: isUpDominant
              ? 'marketOverview.keyInsights.limitImbalance.descUp'
              : 'marketOverview.keyInsights.limitImbalance.descDown',
          descArgs: {
            'up': limitUpDown.limitUp.toString(),
            'down': limitUpDown.limitDown.toString(),
          },
          isPositive: isUpDominant,
        ),
      );
    }
  }

  /// Rule 6: 融資融券異動（融資 > 3% 或融券 > 5%）
  static void _checkMarginSurge(
    MarginTradingTotals? margin,
    List<MarketInsight> candidates,
  ) {
    if (margin == null) return;

    // 融資變化率
    if (margin.marginBalance != 0) {
      final marginPct = (margin.marginChange / margin.marginBalance * 100)
          .abs();
      if (marginPct > 3) {
        candidates.add(
          MarketInsight(
            type: InsightType.marginSurge,
            severity: InsightSeverity.info,
            priority: 4,
            titleKey: 'marketOverview.keyInsights.marginSurge.title',
            descKey: 'marketOverview.keyInsights.marginSurge.descMargin',
            descArgs: {
              'pct': (margin.marginChange / margin.marginBalance * 100)
                  .toStringAsFixed(1),
            },
          ),
        );
        return; // 融資和融券只取一個
      }
    }

    // 融券變化率
    if (margin.shortBalance != 0) {
      final shortPct = (margin.shortChange / margin.shortBalance * 100).abs();
      if (shortPct > 5) {
        candidates.add(
          MarketInsight(
            type: InsightType.marginSurge,
            severity: InsightSeverity.info,
            priority: 4,
            titleKey: 'marketOverview.keyInsights.marginSurge.title',
            descKey: 'marketOverview.keyInsights.marginSurge.descShort',
            descArgs: {
              'pct': (margin.shortChange / margin.shortBalance * 100)
                  .toStringAsFixed(1),
            },
          ),
        );
      }
    }
  }

  /// Rule 7: 產業集中（> 70% 同向漲/跌）
  static void _checkIndustryConcentration(
    List<IndustrySummary> industries,
    List<MarketInsight> candidates,
  ) {
    if (industries.isEmpty) return;

    final upCount = industries.where((i) => i.avgChangePct > 0).length;
    final downCount = industries.where((i) => i.avgChangePct < 0).length;
    final total = industries.length;

    final upPct = upCount / total * 100;
    final downPct = downCount / total * 100;

    if (upPct > 70) {
      candidates.add(
        MarketInsight(
          type: InsightType.industryConcentration,
          severity: InsightSeverity.info,
          priority: 3,
          titleKey: 'marketOverview.keyInsights.industryConcentration.title',
          descKey: 'marketOverview.keyInsights.industryConcentration.descUp',
          descArgs: {'pct': upPct.toStringAsFixed(0)},
          isPositive: true,
        ),
      );
    } else if (downPct > 70) {
      candidates.add(
        MarketInsight(
          type: InsightType.industryConcentration,
          severity: InsightSeverity.warning,
          priority: 3,
          titleKey: 'marketOverview.keyInsights.industryConcentration.title',
          descKey: 'marketOverview.keyInsights.industryConcentration.descDown',
          descArgs: {'pct': downPct.toStringAsFixed(0)},
          isPositive: false,
        ),
      );
    }
  }
}
