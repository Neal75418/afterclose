import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/extensions/trend_state_extension.dart';
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/presentation/providers/stock_detail_provider.dart';
import 'package:afterclose/presentation/widgets/reason_tags.dart';

/// 股票詳情頁的 Header 區塊
///
/// 顯示股票名稱、價格、漲跌幅、趨勢與支撐壓力等資訊
class StockDetailHeader extends StatelessWidget {
  const StockDetailHeader({
    super.key,
    required this.state,
    required this.symbol,
  });

  final StockDetailState state;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priceChange = state.priceChange;
    final isPositive = (priceChange ?? 0) >= 0;
    final priceColor = AppTheme.getPriceColor(priceChange);

    return Semantics(
      label: _buildSemanticLabel(),
      container: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildNameRow(theme),
                      const SizedBox(height: 4),
                      if (state.reasons.isNotEmpty) _buildReasonTags(theme),
                    ],
                  ),
                ),
                _buildPriceColumn(theme, priceChange, isPositive, priceColor),
              ],
            ),
            const SizedBox(height: 12),
            _buildTrendRow(theme),
          ],
        ),
      ),
    );
  }

  String _buildSemanticLabel() {
    final parts = <String>[];
    final name = state.stockName;
    if (name != null) parts.add(name);
    parts.add(symbol);
    final close = state.latestClose;
    if (close != null) parts.add('收盤價 ${close.toStringAsFixed(2)} 元');
    final change = state.priceChange;
    if (change != null) {
      final absChange = _calculateAbsoluteChange(close, change);
      final absText = absChange != null
          ? '${absChange >= 0 ? "+" : ""}${absChange.toStringAsFixed(2)} 元, '
          : '';
      parts.add(
        '漲跌 $absText${change >= 0 ? "+" : ""}${change.toStringAsFixed(2)}%',
      );
    }
    final trend = state.price.analysis?.trendState;
    if (trend != null) parts.add('趨勢 ${trend.trendKey}');
    return parts.join(', ');
  }

  Widget _buildNameRow(ThemeData theme) {
    return Row(
      children: [
        Flexible(
          child: Text(
            state.stockName ?? symbol,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (state.stockMarket == 'TPEx') ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(DesignTokens.radiusXs),
            ),
            child: Text(
              'stockDetail.otcBadge'.tr(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        if (state.stockIndustry != null && state.stockIndustry!.isNotEmpty) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(DesignTokens.radiusXs),
              ),
              child: Text(
                state.stockIndustry!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onTertiaryContainer,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReasonTags(ThemeData theme) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: state.reasons.take(3).map((reason) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
          ),
          child: Text(
            ReasonTags.translateReasonCode(reason.reasonType),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 從收盤價與漲跌幅百分比反算絕對漲跌金額
  double? _calculateAbsoluteChange(double? close, double? pctChange) {
    if (close == null || pctChange == null || pctChange == 0) return null;
    return close * pctChange / (100 + pctChange);
  }

  Widget _buildPriceColumn(
    ThemeData theme,
    double? priceChange,
    bool isPositive,
    Color priceColor,
  ) {
    final absChange = _calculateAbsoluteChange(state.latestClose, priceChange);
    final isNeutral = priceChange == null || priceChange == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          state.latestClose?.toStringAsFixed(2) ?? '-',
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            fontFamily: 'RobotoMono',
            fontSize: 32,
            letterSpacing: -1,
          ),
        ),
        if (priceChange != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isPositive
                    ? [
                        AppTheme.upColor.withValues(alpha: 0.2),
                        AppTheme.upColor.withValues(alpha: 0.1),
                      ]
                    : [
                        AppTheme.downColor.withValues(alpha: 0.2),
                        AppTheme.downColor.withValues(alpha: 0.1),
                      ],
              ),
              borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
              border: Border.all(color: priceColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPositive ? Icons.north : Icons.south,
                  size: 14,
                  color: priceColor,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDetailChangeText(
                    absChange,
                    priceChange,
                    isPositive,
                    isNeutral,
                  ),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: priceColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        if (state.dataDate != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state.hasDataMismatch)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.sync_problem,
                      size: 12,
                      color: theme.colorScheme.error,
                    ),
                  ),
                Text(
                  _formatDataDate(state.dataDate!),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: state.hasDataMismatch
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTrendRow(ThemeData theme) {
    final analysis = state.price.analysis;
    final trendState = analysis?.trendState;

    return Row(
      children: [
        _InfoChip(
          label: 'trend.${trendState?.trendKey ?? 'sideways'}'.tr(),
          icon: trendState?.trendIconData ?? Icons.trending_flat,
          color: trendState?.trendColor ?? AppTheme.neutralColor,
        ),
        const SizedBox(width: 8),
        if (analysis?.supportLevel case final supportLevel?)
          _LevelChip(
            label: 'stockDetail.support'.tr(),
            value: supportLevel,
            color: AppTheme.downColor,
          ),
        const SizedBox(width: 8),
        if (analysis?.resistanceLevel case final resistanceLevel?)
          _LevelChip(
            label: 'stockDetail.resistance'.tr(),
            value: resistanceLevel,
            color: AppTheme.upColor,
          ),
      ],
    );
  }

  /// 格式化詳情頁漲跌文字：有絕對金額時顯示「+2.50 (+1.67%)」
  String _formatDetailChangeText(
    double? absChange,
    double priceChange,
    bool isPositive,
    bool isNeutral,
  ) {
    final sign = isPositive && !isNeutral ? '+' : '';
    final pctText = '$sign${priceChange.toStringAsFixed(2)}%';
    if (absChange != null) {
      final absText = '${isPositive ? '+' : ''}${absChange.toStringAsFixed(2)}';
      return '$absText ($pctText)';
    }
    return pctText;
  }

  String _formatDataDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dataDay = DateTime(date.year, date.month, date.day);

    if (dataDay == today) {
      return 'stockDetail.dataToday'.tr();
    } else if (dataDay == today.subtract(const Duration(days: 1))) {
      return 'stockDetail.dataYesterday'.tr();
    } else {
      return '${date.month}/${date.day} ${'stockDetail.dataLabel'.tr()}';
    }
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
      ),
      child: Row(
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
          const SizedBox(width: 6),
          Text(
            '$label ${value.toStringAsFixed(1)}',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
