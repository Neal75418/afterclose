import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/presentation/providers/market_overview_provider.dart';

/// 漲跌家數水平分段條
///
/// 以水平 SegmentedBar 呈現上漲/持平/下跌比例，下方顯示數字
class AdvanceDeclineGauge extends StatelessWidget {
  const AdvanceDeclineGauge({super.key, required this.data, this.limitUpDown});

  final AdvanceDecline data;
  final LimitUpDown? limitUpDown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = data.total;
    if (total == 0) return const SizedBox.shrink();

    final advPct = data.advance / total;
    final unchPct = data.unchanged / total;
    final declPct = data.decline / total;

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
        const SizedBox(height: 10),

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
                    child: Container(
                      color: AppTheme.neutralColor.withValues(alpha: 0.3),
                    ),
                  ),
                if (declPct > 0)
                  Flexible(
                    flex: (declPct * 1000).round(),
                    child: Container(color: AppTheme.downColor),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

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
              color: AppTheme.neutralColor,
              label: 'marketOverview.unchanged'.tr(),
              value: data.unchanged,
              percentage: unchPct * 100,
              center: true,
            ),
            const Spacer(),
            _StatChip(
              color: AppTheme.downColor,
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
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LimitBadge(
                label: 'marketOverview.limitUp'.tr(),
                count: limitUpDown!.limitUp,
                color: AppTheme.upColor,
              ),
              const SizedBox(width: 16),
              _LimitBadge(
                label: 'marketOverview.limitDown'.tr(),
                count: limitUpDown!.limitDown,
                color: AppTheme.downColor,
              ),
            ],
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          const SizedBox(width: 4),
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
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: DesignTokens.fontSizeXs,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
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
            fontSize: 10,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
