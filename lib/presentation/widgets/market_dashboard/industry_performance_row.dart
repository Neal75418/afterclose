import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/core/theme/breakpoints.dart';
import 'package:afterclose/presentation/providers/market_overview_provider.dart';

/// 產業表現區域
///
/// 顯示各產業的平均漲跌幅、漲跌家數。
/// 桌面版使用 Wrap 排列，手機版水平捲動。
class IndustryPerformanceRow extends StatelessWidget {
  const IndustryPerformanceRow({super.key, required this.industries});

  final List<IndustrySummary> industries;

  /// 桌面 Wrap 模式最多顯示的產業數量（前 N + 後 N，對稱）
  static const _desktopMaxItems = 8;

  @override
  Widget build(BuildContext context) {
    if (industries.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= Breakpoints.mobile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'marketOverview.industryPerformance'.tr(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            // 桌面模式有截斷時顯示提示
            if (isDesktop && industries.length > _desktopMaxItems) ...[
              const SizedBox(width: DesignTokens.spacing6),
              Text(
                'marketOverview.industryTopBottom'.tr(
                  namedArgs: {'count': '${_desktopMaxItems ~/ 2}'},
                ),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                  fontSize: DesignTokens.fontSizeXs,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: DesignTokens.spacing10),
        if (isDesktop)
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = DesignTokens.spacing8;
              const minCardWidth = 120.0;
              final items = _desktopItems();
              final width = constraints.maxWidth;
              // 依實際可用寬度（非整個視窗，避免 paired 欄位誤判）決定欄數，
              // 卡片等寬填滿整列 → 不留右側空隙、版面對稱。8 張卡用 1/2/4 欄皆整除。
              final fit = ((width + gap) / (minCardWidth + gap)).floor();
              final cols = fit >= 4
                  ? 4
                  : fit >= 2
                  ? 2
                  : 1;
              final cardWidth = (width - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: items
                    .map(
                      (ind) => SizedBox(
                        width: cardWidth,
                        height: 72,
                        child: _IndustryCard(industry: ind),
                      ),
                    )
                    .toList(),
              );
            },
          )
        else
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: industries.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: DesignTokens.spacing8),
              itemBuilder: (context, index) {
                return SizedBox(
                  width: 120,
                  child: _IndustryCard(industry: industries[index]),
                );
              },
            ),
          ),
      ],
    );
  }

  /// 桌面模式取 top + bottom 產業（已按 avgChangePct DESC 排序）
  List<IndustrySummary> _desktopItems() {
    if (industries.length <= _desktopMaxItems) return industries;
    // 取前半 + 後半，保持排序順序
    const half = _desktopMaxItems ~/ 2;
    final top = industries.take(half).toList();
    final bottom = industries.skip(industries.length - half).toList();
    // 去重（如果列表很短可能重疊）
    final seen = <String>{};
    final result = <IndustrySummary>[];
    for (final item in [...top, ...bottom]) {
      if (seen.add(item.industry)) result.add(item);
    }
    return result;
  }
}

class _IndustryCard extends StatelessWidget {
  const _IndustryCard({required this.industry});

  final IndustrySummary industry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUp = industry.avgChangePct > 0;
    final color = isUp
        ? AppTheme.upColor
        : industry.avgChangePct < 0
        ? AppTheme.downColor
        : AppTheme.neutralColor;
    final sign = isUp ? '+' : '';

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          // 頂部色條（依漲跌方向）
          Container(height: 2, color: color),
          // 內容
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                DesignTokens.spacing10,
                DesignTokens.spacing6,
                DesignTokens.spacing10,
                DesignTokens.spacing8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    industry.industry,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Text(
                        '$sign${industry.avgChangePct.toStringAsFixed(2)}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: DesignTokens.spacing4),
                      // 漲/跌家數（帶 ▲▼ 標記）
                      // 用 Expanded + FittedBox 防止大數字溢出
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                AppTheme.upSymbol,
                                style: TextStyle(
                                  fontSize: 8,
                                  color: AppTheme.upColor.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              ),
                              Text(
                                '${industry.advance}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.7),
                                  fontSize: DesignTokens.fontSizeXs,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              Text(
                                ' ${AppTheme.downSymbol}',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: AppTheme.downColor.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              ),
                              Text(
                                '${industry.decline}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.7),
                                  fontSize: DesignTokens.fontSizeXs,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
