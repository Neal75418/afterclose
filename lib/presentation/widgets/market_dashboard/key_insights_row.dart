import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/domain/services/market_insight_service.dart';

/// 智慧摘要列
///
/// 顯示 2-4 張洞察卡片，每張左邊框色條標示嚴重度。
/// 使用 Wrap 佈局，手機每列 2 張。
class KeyInsightsRow extends StatelessWidget {
  const KeyInsightsRow({super.key, required this.insights});

  final List<MarketInsight> insights;

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'marketOverview.keyInsights.title'.tr(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 8.0;
            final cardWidth = (constraints.maxWidth - spacing) / 2;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: insights
                  .map(
                    (insight) => SizedBox(
                      width: cardWidth,
                      child: _InsightCard(insight: insight),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});

  final MarketInsight insight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = _borderColor(theme, insight);

    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: borderColor, width: 3)),
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            insight.titleKey.tr(),
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            insight.descKey.tr(namedArgs: insight.descArgs),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: DesignTokens.fontSizeXs,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  static Color _borderColor(ThemeData theme, MarketInsight insight) {
    if (insight.severity == InsightSeverity.warning) {
      return insight.isPositive ? AppTheme.upColor : AppTheme.downColor;
    }
    return theme.colorScheme.primary;
  }
}
