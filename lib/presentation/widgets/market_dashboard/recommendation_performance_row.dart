import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/constants/reason_type.dart';
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/presentation/providers/market_overview_provider.dart';

/// 推薦績效看板（精簡版，用於大盤總覽 dashboard）
///
/// 包含：
/// 1. 勝負走勢 dot strip（近 30 筆）
/// 2. 統計摘要列（勝率 / 平均報酬 / 總筆數）
/// 3. 最強規則 Top 3
class RecommendationPerformanceRow extends StatelessWidget {
  const RecommendationPerformanceRow({super.key, required this.data});

  final RecommendationPerformance data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'marketOverview.recPerformance.title'.tr(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),

        // 勝負走勢 dot strip
        if (data.recentResults.isNotEmpty) ...[
          _DotStrip(results: data.recentResults),
          const SizedBox(height: 10),
        ],

        // 統計摘要列
        _StatBadgesRow(
          winRate: data.winRate,
          avgReturn: data.avgReturn,
          totalCount: data.totalCount,
        ),

        // Top 3 規則
        if (data.topRules.isNotEmpty) ...[
          const SizedBox(height: 10),
          _TopRulesList(rules: data.topRules),
        ],
      ],
    );
  }
}

/// 勝負走勢 dot strip — 近 30 筆驗證結果以圓點呈現
class _DotStrip extends StatelessWidget {
  const _DotStrip({required this.results});

  final List<bool> results;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 反轉為 oldest→newest（左→右）
    final ordered = results.reversed.toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        color: theme.colorScheme.surfaceContainerLowest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'marketOverview.recPerformance.recentResults'.tr(
              namedArgs: {'count': '${ordered.length}'},
            ),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              fontSize: DesignTokens.fontSizeXs,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 3,
            runSpacing: 3,
            children: ordered.map((isWin) {
              return Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isWin
                      ? AppTheme.upColor.withValues(alpha: 0.8)
                      : AppTheme.downColor.withValues(alpha: 0.8),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// 統計摘要列 — 勝率 / 平均報酬 / 總筆數
class _StatBadgesRow extends StatelessWidget {
  const _StatBadgesRow({
    required this.winRate,
    required this.avgReturn,
    required this.totalCount,
  });

  final double winRate;
  final double avgReturn;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: _StatBadge(
            label: 'marketOverview.recPerformance.winRate'.tr(),
            value: '${winRate.toStringAsFixed(1)}%',
            valueColor: winRate >= 50 ? AppTheme.upColor : AppTheme.downColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatBadge(
            label: 'marketOverview.recPerformance.avgReturn'.tr(),
            value:
                '${avgReturn >= 0 ? '+' : ''}${avgReturn.toStringAsFixed(2)}%',
            valueColor: avgReturn >= 0 ? AppTheme.upColor : AppTheme.downColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatBadge(
            label: 'marketOverview.recPerformance.totalCount'.tr(),
            value: '$totalCount',
            valueColor: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        color: theme.colorScheme.surfaceContainerLowest,
      ),
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: DesignTokens.fontSizeXs,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Top 3 規則列表
class _TopRulesList extends StatelessWidget {
  const _TopRulesList({required this.rules});

  final List<TopRule> rules;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        color: theme.colorScheme.surfaceContainerLowest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'marketOverview.recPerformance.topRules'.tr(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: DesignTokens.fontSizeXs,
            ),
          ),
          const SizedBox(height: 6),
          ...rules.asMap().entries.map((entry) {
            final idx = entry.key;
            final rule = entry.value;
            return Padding(
              padding: EdgeInsets.only(top: idx > 0 ? 4 : 0),
              child: _TopRuleItem(rule: rule, rank: idx + 1),
            );
          }),
        ],
      ),
    );
  }
}

class _TopRuleItem extends StatelessWidget {
  const _TopRuleItem({required this.rule, required this.rank});

  final TopRule rule;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 透過 ReasonType i18n 取得規則顯示名稱
    final reasonType = reasonTypeFromCode(rule.ruleId);
    final displayName = reasonType != null
        ? reasonType.i18nLabelKey.tr()
        : rule.ruleId;

    return Row(
      children: [
        // 排名圓圈
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
          ),
          alignment: Alignment.center,
          child: Text(
            '$rank',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
              fontSize: DesignTokens.fontSizeXs,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 規則名
        Expanded(
          child: Text(
            displayName,
            style: theme.textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // 勝率
        Text(
          '${rule.winRate.toStringAsFixed(0)}%',
          style: theme.textTheme.bodySmall?.copyWith(
            color: rule.winRate >= 50 ? AppTheme.upColor : AppTheme.downColor,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 8),
        // 平均報酬
        Text(
          '${rule.avgReturn >= 0 ? '+' : ''}${rule.avgReturn.toStringAsFixed(1)}%',
          style: theme.textTheme.labelSmall?.copyWith(
            color: rule.avgReturn >= 0 ? AppTheme.upColor : AppTheme.downColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
