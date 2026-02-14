import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/chip/chip_helpers.dart'
    show formatLots;

/// Displays today's OHLCV (Open, High, Low, Close, Volume) trading data.
class OhlcvCard extends StatelessWidget {
  const OhlcvCard({
    super.key,
    required this.latestPrice,
    required this.priceChange,
  });

  final DailyPriceEntry? latestPrice;
  final double? priceChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUp = (priceChange ?? 0) >= 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, theme, isUp),
            const SizedBox(height: 16),
            // 價格格線
            Row(
              children: [
                Expanded(
                  child: _PriceCell(
                    label: 'stockDetail.open'.tr(),
                    value: latestPrice?.open,
                    valueColor: theme.colorScheme.onSurface,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: theme.colorScheme.outlineVariant,
                ),
                Expanded(
                  child: _PriceCell(
                    label: 'stockDetail.high'.tr(),
                    value: latestPrice?.high,
                    valueColor: AppTheme.upColor,
                  ),
                ),
              ],
            ),
            Divider(height: 24, color: theme.colorScheme.outlineVariant),
            Row(
              children: [
                Expanded(
                  child: _PriceCell(
                    label: 'stockDetail.low'.tr(),
                    value: latestPrice?.low,
                    valueColor: AppTheme.downColor,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: theme.colorScheme.outlineVariant,
                ),
                Expanded(
                  child: _PriceCell(
                    label: 'stockDetail.close'.tr(),
                    value: latestPrice?.close,
                    valueColor: isUp ? AppTheme.upColor : AppTheme.downColor,
                    isBold: true,
                  ),
                ),
              ],
            ),
            Divider(height: 24, color: theme.colorScheme.outlineVariant),
            // 成交量
            Row(
              children: [
                Icon(
                  Icons.bar_chart,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'stockDetail.volume'.tr(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatVolumeOrDash(latestPrice?.volume),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme, bool isUp) {
    return Row(
      children: [
        Icon(
          Icons.candlestick_chart,
          size: 20,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          'stockDetail.todayTrading'.tr(),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        if (priceChange != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (isUp ? AppTheme.upColor : AppTheme.downColor).withValues(
                alpha: 0.1,
              ),
              borderRadius: BorderRadius.circular(DesignTokens.radiusXs),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isUp ? Icons.trending_up : Icons.trending_down,
                  size: 14,
                  color: isUp ? AppTheme.upColor : AppTheme.downColor,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatChangeBadge(isUp),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isUp ? AppTheme.upColor : AppTheme.downColor,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// 格式化 OHLCV 卡片標題的漲跌 badge
  String _formatChangeBadge(bool isUp) {
    final sign = isUp ? '+' : '';
    final pctText = '$sign${priceChange!.toStringAsFixed(2)}%';
    final close = latestPrice?.close;
    if (close != null && priceChange != 0) {
      final absChange = close * priceChange! / (100 + priceChange!);
      final absText = '${isUp ? '+' : ''}${absChange.toStringAsFixed(2)}';
      return '$absText ($pctText)';
    }
    return pctText;
  }

  /// 格式化成交量（處理 null）
  String _formatVolumeOrDash(double? volume) {
    if (volume == null) return '-';
    return _formatVolume(volume);
  }

  /// 格式化成交量為台灣習慣的「張」單位
  ///
  /// API 回傳單位為「股」，台灣股市習慣用「張」（1張 = 1000股）
  String _formatVolume(double volume) {
    final lots = volume / 1000;
    if (lots < 1) return volume.toStringAsFixed(0);
    return formatLots(lots);
  }
}

class _PriceCell extends StatelessWidget {
  const _PriceCell({
    required this.label,
    required this.value,
    required this.valueColor,
    this.isBold = false,
  });

  final String label;
  final double? value;
  final Color valueColor;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value?.toStringAsFixed(2) ?? '-',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
