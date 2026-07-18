import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/semantic_colors.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/domain/services/market_reading_service.dart';
import 'package:afterclose/presentation/providers/market_overview_provider.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/mini_trend_chart.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/market_reading_line.dart';

/// 漲跌家數水平分段條
///
/// 以水平 SegmentedBar 呈現上漲/持平/下跌比例，下方顯示數字
class AdvanceDeclineGauge extends StatelessWidget {
  const AdvanceDeclineGauge({
    super.key,
    required this.data,
    this.limitUpDown,
    this.advanceRatioHistory,
  });

  final AdvanceDecline data;
  final LimitUpDown? limitUpDown;

  /// 30日漲幅比歷史（advance/total，0~1，oldest→newest）
  final List<double>? advanceRatioHistory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 「上漲／持平／下跌」是固定語意分類（非由數值解出），故直接取對應的
    // 方向色；平盤與下跌需依主題解析——深色主題的 #A1A1A1／#2ED573 對白底
    // 僅 2.58:1／1.93:1，連圖形物件 3.0:1 門檻都不到。
    final flatColor = PriceColors.flatFor(theme.brightness);
    final declineColor = PriceColors.downFor(theme.brightness);
    final total = data.total;
    if (total == 0) return const SizedBox.shrink();

    final advPct = data.advance / total;
    final unchPct = data.unchanged / total;
    final declPct = data.decline / total;

    // 廣度判讀（僅需漲跌家數，service 內部 guard 分母）
    final reading = MarketReadingService.interpretBreadth(
      advance: data.advance,
      decline: data.decline,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 標題行 + 總家數
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'marketOverview.advanceDecline'.tr(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'marketOverview.totalStocks'.tr(namedArgs: {'count': '$total'}),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.6,
                ),
                fontSize: DesignTokens.fontSizeXs,
              ),
            ),
          ],
        ),
        const SizedBox(height: DesignTokens.spacing10),

        // 水平分段條
        ClipRRect(
          borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
          child: SizedBox(
            height: DesignTokens.barHeight,
            child: Row(
              children: [
                if (advPct > 0)
                  Flexible(
                    flex: (advPct * 1000).round(),
                    child: Container(color: AppTheme.upColor),
                  ),
                if (unchPct > 0)
                  Flexible(
                    flex: (unchPct * 1000).round(),
                    child: Container(color: flatColor.withValues(alpha: 0.3)),
                  ),
                if (declPct > 0)
                  Flexible(
                    flex: (declPct * 1000).round(),
                    child: Container(color: declineColor),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: DesignTokens.spacing10),

        // 數字行
        Row(
          children: [
            _StatChip(
              color: AppTheme.upColor,
              label: 'marketOverview.advance'.tr(),
              value: data.advance,
              percentage: advPct * 100,
            ),
            const Spacer(),
            _StatChip(
              color: flatColor,
              label: 'marketOverview.unchanged'.tr(),
              value: data.unchanged,
              percentage: unchPct * 100,
              center: true,
            ),
            const Spacer(),
            _StatChip(
              color: declineColor,
              label: 'marketOverview.decline'.tr(),
              value: data.decline,
              percentage: declPct * 100,
              alignRight: true,
            ),
          ],
        ),

        // 漲停/跌停家數
        if (limitUpDown != null &&
            (limitUpDown!.limitUp > 0 || limitUpDown!.limitDown > 0)) ...[
          const SizedBox(height: DesignTokens.spacing8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LimitBadge(
                label: 'marketOverview.limitUp'.tr(),
                count: limitUpDown!.limitUp,
                color: AppTheme.upColor,
              ),
              const SizedBox(width: DesignTokens.spacing16),
              _LimitBadge(
                label: 'marketOverview.limitDown'.tr(),
                count: limitUpDown!.limitDown,
                color: declineColor,
              ),
            ],
          ),
        ],

        // 30日漲幅比趨勢 sparkline
        //
        // 次要輔助圖線（相對 Hero 指數 sparkline 為 primary）：縮小高度並降
        // 低不透明度，視覺上明確退居輔助角色，不與指數走勢圖搶焦點。
        if (advanceRatioHistory != null &&
            advanceRatioHistory!.length >= 2) ...[
          const SizedBox(height: DesignTokens.spacing10),
          Opacity(
            opacity: 0.6,
            child: MiniTrendChart(
              dataPoints: advanceRatioHistory!,
              height: 25,
              lineColor: AppTheme.upColor,
            ),
          ),
        ],

        // 判讀層（廣度）
        MarketReadingLine(reading: reading),
      ],
    );
  }
}

class _LimitBadge extends StatelessWidget {
  const _LimitBadge({
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
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: DesignTokens.fontSizeXs,
            ),
          ),
          const SizedBox(width: DesignTokens.spacing4),
          Text(
            '$count',
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.color,
    required this.label,
    required this.value,
    required this.percentage,
    this.center = false,
    this.alignRight = false,
  });

  final Color color;
  final String label;
  final int value;
  final double percentage;
  final bool center;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alignment = alignRight
        ? CrossAxisAlignment.end
        : center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: DesignTokens.spacing4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: DesignTokens.fontSizeXs,
              ),
            ),
          ],
        ),
        const SizedBox(height: DesignTokens.spacing2),
        Text(
          '$value',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          '${percentage.toStringAsFixed(0)}%',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            fontSize: DesignTokens.fontSizeXs,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
