import 'package:flutter/material.dart';

import 'package:afterclose/presentation/providers/price_alert_provider.dart';

/// AlertType → 圖示的單一來源
///
/// 2026-07-23 稽核修復：原本個股「警示」分頁與全域警示頁各自維護整份
/// switch 複本，changePct 已分岔（percent vs show_chart）——統一取
/// percent（百分比語意較準確），其餘沿用全域警示頁版本。
extension AlertTypeIcon on AlertType {
  IconData get icon => switch (this) {
    AlertType.above => Icons.trending_up,
    AlertType.below => Icons.trending_down,
    AlertType.changePct => Icons.percent,
    AlertType.volumeSpike || AlertType.volumeAbove => Icons.bar_chart,
    AlertType.rsiOverbought => Icons.arrow_upward,
    AlertType.rsiOversold => Icons.arrow_downward,
    AlertType.kdGoldenCross => Icons.add_circle_outline,
    AlertType.kdDeathCross => Icons.remove_circle_outline,
    AlertType.breakResistance => Icons.north_east,
    AlertType.breakSupport => Icons.south_east,
    AlertType.week52High => Icons.emoji_events,
    AlertType.week52Low => Icons.trending_down,
    AlertType.crossAboveMa || AlertType.crossBelowMa => Icons.timeline,
    AlertType.revenueYoySurge ||
    AlertType.highDividendYield ||
    AlertType.peUndervalued => Icons.analytics,
    AlertType.tradingWarning => Icons.warning_amber,
    AlertType.tradingDisposal => Icons.gpp_bad,
    AlertType.insiderSelling => Icons.person_remove,
    AlertType.insiderBuying => Icons.person_add,
    AlertType.highPledgeRatio => Icons.lock,
  };
}
