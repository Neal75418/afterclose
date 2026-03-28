import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import 'package:afterclose/core/extensions/trend_state_extension.dart';
import 'package:afterclose/core/l10n/app_strings.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/presentation/providers/stock_detail_provider.dart';
import 'package:afterclose/presentation/widgets/reason_tags.dart';

/// Header 所需的最小資料集，用於 `.select()` 精確 rebuild
class StockHeaderData {
  const StockHeaderData({
    this.stockName,
    this.stockMarket,
    this.stockIndustry,
    this.latestClose,
    this.priceChange,
    this.trendState,
    this.support,
    this.resistance,
    this.reasons = const [],
    this.dataDate,
    this.hasDataMismatch = false,
  });

  final String? stockName;
  final String? stockMarket;
  final String? stockIndustry;
  final double? latestClose;
  final double? priceChange;
  final String? trendState;
  final double? support;
  final double? resistance;
  final List<String> reasons;
  final DateTime? dataDate;
  final bool hasDataMismatch;

  /// 從完整 StockDetailState 投影
  factory StockHeaderData.fromState(StockDetailState s) => StockHeaderData(
    stockName: s.stockName,
    stockMarket: s.stockMarket,
    stockIndustry: s.stockIndustry,
    latestClose: s.latestClose,
    priceChange: s.priceChange,
    trendState: s.price.analysis?.trendState,
    support: s.price.analysis?.supportLevel,
    resistance: s.price.analysis?.resistanceLevel,
    reasons: s.reasons.map((r) => r.reasonType).toList(),
    dataDate: s.dataDate,
    hasDataMismatch: s.hasDataMismatch,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StockHeaderData &&
          stockName == other.stockName &&
          stockMarket == other.stockMarket &&
          stockIndustry == other.stockIndustry &&
          latestClose == other.latestClose &&
          priceChange == other.priceChange &&
          trendState == other.trendState &&
          support == other.support &&
          resistance == other.resistance &&
          listEquals(reasons, other.reasons) &&
          dataDate == other.dataDate &&
          hasDataMismatch == other.hasDataMismatch;

  @override
  int get hashCode => Object.hash(
    stockName,
    stockMarket,
    latestClose,
    priceChange,
    trendState,
    dataDate,
    hasDataMismatch,
  );
}

/// 股票詳情頁的 Header 區塊
///
/// 顯示股票名稱、價格、漲跌幅、趨勢與支撐壓力等資訊
class StockDetailHeader extends StatelessWidget {
  const StockDetailHeader({
    super.key,
    required this.data,
    required this.symbol,
  });

  final StockHeaderData data;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priceChange = data.priceChange;
    final isPositive = (priceChange ?? 0) >= 0;
    final priceColor = AppTheme.getPriceColor(priceChange, theme.brightness);

    return Semantics(
      label: _buildSemanticLabel(),
      container: true,
      child: Container(
        padding: const EdgeInsets.all(DesignTokens.spacing16),
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
                      const SizedBox(height: DesignTokens.spacing4),
                      if (data.reasons.isNotEmpty) _buildReasonTags(theme),
                    ],
                  ),
                ),
                _buildPriceColumn(theme, priceChange, isPositive, priceColor),
              ],
            ),
            const SizedBox(height: DesignTokens.spacing12),
            _buildTrendRow(theme),
          ],
        ),
      ),
    );
  }

  String _buildSemanticLabel() {
    final parts = <String>[];
    final name = data.stockName;
    if (name != null) parts.add(name);
    parts.add(symbol);
    final close = data.latestClose;
    if (close != null) {
      parts.add(S.accessibilityClosePrice(close.toStringAsFixed(2)));
    }
    final change = data.priceChange;
    if (change != null) {
      final absChange = _calculateAbsoluteChange(close, change);
      final absText = absChange != null
          ? '${S.accessibilityAbsoluteChange('${absChange >= 0 ? "+" : ""}${absChange.toStringAsFixed(2)}')}, '
          : '';
      final pctText = '${change >= 0 ? "+" : ""}${change.toStringAsFixed(2)}%';
      parts.add(S.accessibilityPriceChangeDetail(absText, pctText));
    }
    final trend = data.trendState;
    if (trend != null) parts.add(S.accessibilityTrend(trend.trendKey));
    return parts.join(', ');
  }

  Widget _buildNameRow(ThemeData theme) {
    return Row(
      children: [
        Flexible(
          child: Text(
            data.stockName ?? symbol,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (data.stockMarket == 'TPEx') ...[
          const SizedBox(width: DesignTokens.spacing8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spacing6,
              vertical: DesignTokens.spacing2,
            ),
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
        if (data.stockIndustry != null && data.stockIndustry!.isNotEmpty) ...[
          const SizedBox(width: DesignTokens.spacing8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.spacing6,
                vertical: DesignTokens.spacing2,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(DesignTokens.radiusXs),
              ),
              child: Text(
                data.stockIndustry!,
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
      spacing: DesignTokens.spacing6,
      runSpacing: DesignTokens.spacing4,
      children: data.reasons.take(3).map((reason) {
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spacing8,
            vertical: DesignTokens.spacing2,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
          ),
          child: Text(
            ReasonTags.translateReasonCode(reason),
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
    final absChange = _calculateAbsoluteChange(data.latestClose, priceChange);
    final isNeutral = priceChange == null || priceChange == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          data.latestClose?.toStringAsFixed(2) ?? '-',
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            fontFamily: 'RobotoMono',
            fontSize: 32,
            letterSpacing: -1,
          ),
        ),
        if (priceChange != null)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spacing10,
              vertical: DesignTokens.spacing4,
            ),
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
                const SizedBox(width: DesignTokens.spacing4),
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
        if (data.dataDate != null)
          Padding(
            padding: const EdgeInsets.only(top: DesignTokens.spacing4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (data.hasDataMismatch)
                  Padding(
                    padding: const EdgeInsets.only(
                      right: DesignTokens.spacing4,
                    ),
                    child: Icon(
                      Icons.sync_problem,
                      size: 12,
                      color: theme.colorScheme.error,
                    ),
                  ),
                Text(
                  _formatDataDate(data.dataDate!),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: data.hasDataMismatch
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
    final trendState = data.trendState;

    return Row(
      children: [
        _InfoChip(
          label: 'trend.${trendState?.trendKey ?? 'sideways'}'.tr(),
          icon: trendState?.trendIconData ?? Icons.trending_flat,
          color: trendState?.trendColor ?? AppTheme.neutralColor,
        ),
        const SizedBox(width: DesignTokens.spacing8),
        if (data.support case final supportLevel?)
          _LevelChip(
            label: 'stockDetail.support'.tr(),
            value: supportLevel,
            color: AppTheme.downColor,
          ),
        const SizedBox(width: DesignTokens.spacing8),
        if (data.resistance case final resistanceLevel?)
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
    final today = DateContext.normalize(now);
    final dataDay = DateContext.normalize(date);

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
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spacing10,
        vertical: DesignTokens.spacing6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: DesignTokens.spacing6),
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
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spacing10,
        vertical: DesignTokens.spacing6,
      ),
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
          const SizedBox(width: DesignTokens.spacing6),
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
