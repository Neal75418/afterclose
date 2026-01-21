import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/presentation/providers/stock_detail_provider.dart';
import 'package:afterclose/presentation/widgets/section_header.dart';

/// Chip analysis tab - Institutional investors + Margin trading
class ChipTab extends ConsumerStatefulWidget {
  const ChipTab({super.key, required this.symbol});

  final String symbol;

  @override
  ConsumerState<ChipTab> createState() => _ChipTabState();
}

class _ChipTabState extends ConsumerState<ChipTab> {
  @override
  void initState() {
    super.initState();
    // Load margin data when tab is initialized
    Future.microtask(() {
      ref.read(stockDetailProvider(widget.symbol).notifier).loadMarginData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stockDetailProvider(widget.symbol));

    return SingleChildScrollView(
      primary: false,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Institutional summary cards
          if (state.institutionalHistory.isNotEmpty)
            _buildInstitutionalSummary(context, state),

          const SizedBox(height: 16),

          // Institutional investors section
          SectionHeader(
            title: 'stockDetail.institutional'.tr(),
            icon: Icons.business,
          ),
          const SizedBox(height: 12),

          if (state.institutionalHistory.isEmpty)
            _buildEmptyState(context, 'stockDetail.noInstitutionalData'.tr())
          else
            _buildInstitutionalTable(context, state),

          const SizedBox(height: 24),

          // Margin summary cards
          if (state.marginHistory.isNotEmpty)
            _buildMarginSummary(context, state.marginHistory),

          if (state.marginHistory.isNotEmpty) const SizedBox(height: 16),

          // Margin trading section
          SectionHeader(
            title: 'stockDetail.marginTrading'.tr(),
            icon: Icons.swap_horiz,
          ),
          const SizedBox(height: 12),

          if (state.isLoadingMargin)
            _buildLoadingState(context)
          else if (state.marginHistory.isEmpty)
            _buildEmptyState(context, 'stockDetail.marginComingSoon'.tr())
          else
            _buildMarginTable(context, state.marginHistory),
        ],
      ),
    );
  }

  /// Build institutional summary cards showing latest day totals
  Widget _buildInstitutionalSummary(BuildContext context, StockDetailState state) {
    final latest = state.institutionalHistory.last;

    final foreignNet = latest.foreignNet ?? 0;
    final trustNet = latest.investmentTrustNet ?? 0;
    final dealerNet = latest.dealerNet ?? 0;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            context,
            'stockDetail.foreign'.tr(),
            foreignNet,
            Icons.language,
            const Color(0xFF3498DB),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            context,
            'stockDetail.investment'.tr(),
            trustNet,
            Icons.account_balance,
            const Color(0xFF9B59B6),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            context,
            'stockDetail.dealer'.tr(),
            dealerNet,
            Icons.store,
            const Color(0xFFE67E22),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String label,
    double value,
    IconData icon,
    Color accentColor,
  ) {
    final theme = Theme.of(context);
    final isPositive = value >= 0;
    final valueColor = isPositive ? AppTheme.upColor : AppTheme.downColor;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accentColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _formatNet(value),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Build margin summary cards
  Widget _buildMarginSummary(BuildContext context, List<FinMindMarginData> marginHistory) {
    final theme = Theme.of(context);

    // Sort by date and get latest
    final sorted = List<FinMindMarginData>.from(marginHistory)
      ..sort((a, b) => b.date.compareTo(a.date));
    final latest = sorted.first;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.upColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.trending_up, size: 14, color: AppTheme.upColor),
                    const SizedBox(width: 4),
                    Text(
                      'stockDetail.marginBalance'.tr(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _formatBalance(latest.marginBalance),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (latest.shortMarginRatio > 10
                        ? AppTheme.downColor
                        : theme.colorScheme.outline)
                    .withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.percent,
                      size: 14,
                      color: latest.shortMarginRatio > 10
                          ? AppTheme.downColor
                          : theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'stockDetail.shortSellRatio'.tr(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${latest.shortMarginRatio.toStringAsFixed(1)}%',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: latest.shortMarginRatio > 10
                        ? AppTheme.downColor
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ),
    );
  }

  Widget _buildInstitutionalTable(BuildContext context, StockDetailState state) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Header row with colored indicators
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'stockDetail.date'.tr(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF3498DB),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'stockDetail.foreign'.tr(),
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF9B59B6),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'stockDetail.investment'.tr(),
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE67E22),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'stockDetail.dealer'.tr(),
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Data rows
            ...state.institutionalHistory.reversed.take(10).toList().asMap().entries.map((entry) {
              final index = entry.key;
              final inst = entry.value;
              final foreignNet = inst.foreignNet ?? 0;
              final trustNet = inst.investmentTrustNet ?? 0;
              final dealerNet = inst.dealerNet ?? 0;

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: index == 0
                      ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                      : (index.isEven ? theme.colorScheme.surface : Colors.transparent),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${inst.date.month}/${inst.date.day}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: index == 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: _buildNetValue(context, foreignNet),
                    ),
                    Expanded(
                      flex: 2,
                      child: _buildNetValue(context, trustNet),
                    ),
                    Expanded(
                      flex: 2,
                      child: _buildNetValue(context, dealerNet),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMarginTable(BuildContext context, List<FinMindMarginData> marginHistory) {
    final theme = Theme.of(context);

    // Sort by date descending and take last 10
    final sortedData = List<FinMindMarginData>.from(marginHistory)
      ..sort((a, b) => b.date.compareTo(a.date));
    final displayData = sortedData.take(10).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Header row with styled background
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'stockDetail.date'.tr(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'stockDetail.marginBuy'.tr(),
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'stockDetail.marginBalance'.tr(),
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'stockDetail.shortSellRatio'.tr(),
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Data rows
            ...displayData.asMap().entries.map((entry) {
              final index = entry.key;
              final margin = entry.value;
              final marginNet = margin.marginNet;
              final shortMarginRatio = margin.shortMarginRatio;

              // Parse date for display
              final dateParts = margin.date.split('-');
              final displayDate = dateParts.length >= 3
                  ? '${int.parse(dateParts[1])}/${int.parse(dateParts[2])}'
                  : margin.date;

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: index == 0
                      ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                      : (index.isEven ? theme.colorScheme.surface : Colors.transparent),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        displayDate,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: index == 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: _buildNetValue(context, marginNet),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        _formatBalance(margin.marginBalance),
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: shortMarginRatio > 10
                              ? AppTheme.downColor.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${shortMarginRatio.toStringAsFixed(1)}%',
                          textAlign: TextAlign.end,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: shortMarginRatio > 10 ? FontWeight.bold : FontWeight.normal,
                            color: shortMarginRatio > 10
                                ? AppTheme.downColor
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildNetValue(BuildContext context, double value) {
    final isPositive = value >= 0;
    final color = isPositive ? AppTheme.upColor : AppTheme.downColor;

    return Text(
      _formatNet(value),
      textAlign: TextAlign.end,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color,
      ),
    );
  }

  /// Format net value with Chinese units
  /// API returns values in shares (股), 1張 = 1000股
  String _formatNet(double value) {
    final prefix = value >= 0 ? '+' : '';
    final absValue = value.abs();

    // Convert to 張 (1張 = 1000股)
    final lots = absValue / 1000;

    if (lots >= 10000) {
      // Show as 萬張
      return '$prefix${(value / 1000 / 10000).toStringAsFixed(1)}${'stockDetail.unitTenThousand'.tr()}${'stockDetail.unitShares'.tr()}';
    } else if (lots >= 1000) {
      // Show as 千張
      return '$prefix${(value / 1000 / 1000).toStringAsFixed(1)}${'stockDetail.unitThousand'.tr()}${'stockDetail.unitShares'.tr()}';
    } else if (lots >= 1) {
      // Show as 張
      return '$prefix${(value / 1000).toStringAsFixed(0)}${'stockDetail.unitShares'.tr()}';
    }
    // Less than 1 張, show raw value
    return '$prefix${value.toStringAsFixed(0)}';
  }

  /// Format margin balance with Chinese units (already in 張)
  String _formatBalance(double value) {
    if (value >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}${'stockDetail.unitTenThousand'.tr()}${'stockDetail.unitShares'.tr()}';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}${'stockDetail.unitThousand'.tr()}${'stockDetail.unitShares'.tr()}';
    }
    return '${value.toStringAsFixed(0)}${'stockDetail.unitShares'.tr()}';
  }
}
