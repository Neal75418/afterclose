import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/domain/models/backtest_models.dart';

/// 回測統計摘要卡片
class BacktestSummaryCard extends StatelessWidget {
  const BacktestSummaryCard({
    super.key,
    required this.summary,
    required this.tradingDaysScanned,
    required this.executionTime,
    this.skippedTrades = 0,
  });

  final BacktestSummary summary;
  final int tradingDaysScanned;
  final Duration executionTime;
  final int skippedTrades;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('backtest.summary'.tr(), style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),

            // 第一列：總交易數 + 勝率
            Row(
              children: [
                _StatItem(
                  label: 'backtest.totalTrades'.tr(),
                  value: summary.totalTrades.toString(),
                ),
                _StatItem(
                  label: 'backtest.winRate'.tr(),
                  value: '${(summary.winRate * 100).toStringAsFixed(1)}%',
                  valueColor: summary.winRate >= 0.5
                      ? AppTheme.upColor
                      : AppTheme.downColor,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 第二列：平均報酬 + 夏普比率
            Row(
              children: [
                _StatItem(
                  label: 'backtest.avgReturn'.tr(),
                  value: _formatReturn(summary.avgReturn),
                  valueColor: _returnColor(summary.avgReturn),
                ),
                _StatItem(
                  label: 'backtest.sharpeRatio'.tr(),
                  value: summary.sharpeRatio != null
                      ? summary.sharpeRatio!.toStringAsFixed(2)
                      : '-',
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 第三列：最大報酬 + 最小報酬
            Row(
              children: [
                _StatItem(
                  label: 'backtest.maxReturn'.tr(),
                  value: _formatReturn(summary.maxReturn),
                  valueColor: _returnColor(summary.maxReturn),
                ),
                _StatItem(
                  label: 'backtest.minReturn'.tr(),
                  value: _formatReturn(summary.minReturn),
                  valueColor: _returnColor(summary.minReturn),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 第四列：中位數 + 標準差
            Row(
              children: [
                _StatItem(
                  label: 'backtest.medianReturn'.tr(),
                  value: _formatReturn(summary.medianReturn),
                  valueColor: _returnColor(summary.medianReturn),
                ),
                _StatItem(
                  label: 'backtest.stdDeviation'.tr(),
                  value: '${summary.stdDeviation.toStringAsFixed(2)}%',
                ),
              ],
            ),

            const Divider(height: 24),

            // 執行資訊
            Text(
              'backtest.executionInfo'.tr(
                namedArgs: {
                  'days': tradingDaysScanned.toString(),
                  'seconds': (executionTime.inMilliseconds / 1000)
                      .toStringAsFixed(1),
                },
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (skippedTrades > 0)
              Text(
                'backtest.skippedTrades'.tr(
                  namedArgs: {'count': skippedTrades.toString()},
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatReturn(double value) {
    final sign = value >= 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(2)}%';
  }

  Color _returnColor(double value) {
    if (value > 0) return AppTheme.upColor;
    if (value < 0) return AppTheme.downColor;
    return AppTheme.neutralColor;
  }
}

/// 單一統計項目
class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
