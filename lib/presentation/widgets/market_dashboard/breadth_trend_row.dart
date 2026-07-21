import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/semantic_colors.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/domain/services/market_reading_service.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/mini_trend_chart.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/market_reading_line.dart';

/// 市場廣度趨勢（Market Breadth Trend）
///
/// 與「漲跌家數」當日廣度快照互補，呈現廣度的**趨勢**面：
/// 1. 52 週新高 / 新低家數（新高用上漲色、新低用下跌色，台股慣例）。
/// 2. AD 騰落線 sparkline（累積 (上漲−下跌)，依淨方向上色）。
/// 3. P2 判讀行：結合新高新低與指數方向，偵測廣度確認 / 背離。
///
/// 資料缺失時優雅留白（回傳 [SizedBox.shrink]）。
class BreadthTrendRow extends StatelessWidget {
  const BreadthTrendRow({
    super.key,
    this.newHighLow,
    this.adLine,
    this.indexChangePercent,
  });

  /// 52 週新高 / 新低家數；null 時不顯示新高新低行。
  final ({int newHighs, int newLows})? newHighLow;

  /// AD 騰落線累積序列（oldest→newest）；不足 2 點時不顯示 sparkline。
  final List<double>? adLine;

  /// 大盤（對應市場 Hero 指數）漲跌幅（%），供廣度趨勢判讀；
  /// null 或無新高新低資料時不顯示判讀行。
  final double? indexChangePercent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final nhl = newHighLow;
    final line = adLine;

    final hasNewHighLow = nhl != null;
    final hasAdLine = line != null && line.length >= 2;

    // 兩項資料皆無 → 整區留白
    if (!hasNewHighLow && !hasAdLine) return const SizedBox.shrink();

    // 廣度趨勢判讀：需新高新低 + 指數漲跌幅，缺則不顯示判讀行
    final changePct = indexChangePercent;
    final reading = (hasNewHighLow && changePct != null)
        ? MarketReadingService.interpretBreadthTrend(
            newHighs: nhl.newHighs,
            newLows: nhl.newLows,
            indexChangePercent: changePct,
          )
        : null;

    // AD 騰落線淨方向：末值 ≥ 首值視為上升（多方累積），用上漲色
    final adRising = hasAdLine && line.last >= line.first;
    final adColor = adRising ? AppTheme.upColor : AppTheme.downColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 標題
        Text(
          'marketOverview.breadthTrend.title'.tr(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),

        // 52 週新高 / 新低
        if (hasNewHighLow) ...[
          const SizedBox(height: DesignTokens.spacing10),
          Row(
            children: [
              _CountChip(
                label: 'marketOverview.breadthTrend.newHigh'.tr(),
                count: nhl.newHighs,
                color: AppTheme.upColor,
              ),
              const SizedBox(width: DesignTokens.spacing16),
              _CountChip(
                label: 'marketOverview.breadthTrend.newLow'.tr(),
                count: nhl.newLows,
                color: AppTheme.downColor,
              ),
            ],
          ),
        ],

        // AD 騰落線 sparkline
        //
        // 次要輔助圖線（相對 Hero 指數 sparkline 為 primary）：縮小高度並降
        // 低不透明度，視覺上明確退居輔助角色，不與指數走勢圖搶焦點。
        if (hasAdLine) ...[
          const SizedBox(height: DesignTokens.spacing10),
          Text(
            'marketOverview.breadthTrend.adLine'.tr(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: DesignTokens.fontSizeXs,
            ),
          ),
          const SizedBox(height: DesignTokens.spacing6),
          Opacity(
            opacity: 0.6,
            child: MiniTrendChart(
              dataPoints: line,
              height: 25,
              lineColor: adColor,
            ),
          ),
        ],

        // 判讀層（廣度趨勢）
        MarketReadingLine(reading: reading),
      ],
    );
  }
}

/// 新高 / 新低家數 chip（label + 數字，依漲跌色上色）
class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spacing10,
        vertical: DesignTokens.spacing4,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
        color: color.withValues(alpha: 0.1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: PriceColors.onTintOf(color, Theme.of(context).brightness),
              fontWeight: FontWeight.w600,
              fontSize: DesignTokens.fontSizeXs,
            ),
          ),
          const SizedBox(width: DesignTokens.spacing4),
          Text(
            '$count',
            style: theme.textTheme.labelSmall?.copyWith(
              color: PriceColors.onTintOf(color, Theme.of(context).brightness),
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
