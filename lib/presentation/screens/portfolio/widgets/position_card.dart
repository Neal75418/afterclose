import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/presentation/providers/portfolio_provider.dart';

/// 單一持倉卡片
class PositionCard extends StatelessWidget {
  const PositionCard({super.key, required this.position, required this.onTap});

  final PortfolioPositionData position;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = position.unrealizedPnl >= 0;
    final pnlColor = position.unrealizedPnl == 0
        ? theme.colorScheme.onSurface
        : (isPositive ? AppTheme.upColor : AppTheme.downColor);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // 左側：股票資訊
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        position.symbol,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          position.stockName ?? '',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${'portfolio.avgCost'.tr()}: \$${position.avgCost.toStringAsFixed(1)}'
                    '  ${'portfolio.currentPrice'.tr()}: \$${(position.currentPrice ?? 0).toStringAsFixed(1)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),

            // 右側：損益
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${position.quantity.toStringAsFixed(0)} ${'portfolio.quantity'.tr()}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${isPositive ? "+" : ""}${position.unrealizedPnl.toStringAsFixed(0)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: pnlColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '(${isPositive ? "+" : ""}${position.unrealizedPnlPct.toStringAsFixed(1)}%)',
                  style: theme.textTheme.labelSmall?.copyWith(color: pnlColor),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: theme.colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}
