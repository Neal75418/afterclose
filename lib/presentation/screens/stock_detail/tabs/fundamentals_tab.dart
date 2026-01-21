import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/presentation/providers/stock_detail_provider.dart';
import 'package:afterclose/presentation/widgets/section_header.dart';

/// Fundamentals tab - P/E, P/B, Revenue, Dividends
class FundamentalsTab extends ConsumerStatefulWidget {
  const FundamentalsTab({super.key, required this.symbol});

  final String symbol;

  @override
  ConsumerState<FundamentalsTab> createState() => _FundamentalsTabState();
}

class _FundamentalsTabState extends ConsumerState<FundamentalsTab> {
  @override
  void initState() {
    super.initState();
    // Load fundamentals data when tab is initialized
    Future.microtask(() {
      ref.read(stockDetailProvider(widget.symbol).notifier).loadFundamentals();
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
          // Key metrics cards
          _buildMetricsRow(context, state),
          const SizedBox(height: 24),

          // Monthly revenue section
          SectionHeader(
            title: 'stockDetail.monthlyRevenue'.tr(),
            icon: Icons.trending_up,
          ),
          const SizedBox(height: 12),

          if (state.isLoadingFundamentals)
            _buildLoadingState(context)
          else if (state.revenueHistory.isEmpty)
            _buildEmptyState(context, 'stockDetail.revenueComingSoon'.tr())
          else
            _buildRevenueTable(context, state.revenueHistory),

          const SizedBox(height: 24),

          // Dividend section
          SectionHeader(
            title: 'stockDetail.dividendHistory'.tr(),
            icon: Icons.payments,
          ),
          const SizedBox(height: 12),

          if (state.isLoadingFundamentals)
            _buildLoadingState(context)
          else if (state.dividendHistory.isEmpty)
            _buildEmptyState(context, 'stockDetail.dividendComingSoon'.tr())
          else
            _buildDividendTable(context, state.dividendHistory),
        ],
      ),
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
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildMetricsRow(BuildContext context, StockDetailState state) {
    final per = state.latestPER;

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            context,
            'P/E',
            per != null && per.per > 0 ? per.per.toStringAsFixed(1) : '-',
            Icons.analytics,
            accentColor: const Color(0xFF3498DB),
            subtitle: 'stockDetail.perLabel'.tr(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricCard(
            context,
            'P/B',
            per != null && per.pbr > 0 ? per.pbr.toStringAsFixed(2) : '-',
            Icons.account_balance,
            accentColor: const Color(0xFF9B59B6),
            subtitle: 'stockDetail.pbrLabel'.tr(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricCard(
            context,
            'stockDetail.yield'.tr(),
            per != null && per.dividendYield > 0
                ? '${per.dividendYield.toStringAsFixed(2)}%'
                : '-',
            Icons.percent,
            accentColor: const Color(0xFF27AE60),
            subtitle: 'stockDetail.yieldLabel'.tr(),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    String? subtitle,
    Color accentColor = Colors.blue,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: accentColor),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle ?? label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueTable(
    BuildContext context,
    List<FinMindRevenue> revenues,
  ) {
    final theme = Theme.of(context);

    // Sort by date descending and take last 12
    final sortedData = List<FinMindRevenue>.from(revenues)
      ..sort((a, b) {
        final yearCompare = b.revenueYear.compareTo(a.revenueYear);
        if (yearCompare != 0) return yearCompare;
        return b.revenueMonth.compareTo(a.revenueMonth);
      });
    final displayData = sortedData.take(12).toList();

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
                    flex: 3,
                    child: Text(
                      'stockDetail.revenueMonth'.tr(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'stockDetail.revenueAmount'.tr(),
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
                      'stockDetail.revenueMoM'.tr(),
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
                      'stockDetail.revenueYoY'.tr(),
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
              final rev = entry.value;

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: index == 0
                      ? theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.3,
                        )
                      : (index.isEven
                            ? theme.colorScheme.surface
                            : Colors.transparent),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        '${rev.revenueYear}/${rev.revenueMonth.toString().padLeft(2, '0')}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: index == 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        _formatRevenue(rev.revenue),
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: _buildGrowthBadge(context, rev.momGrowth),
                    ),
                    Expanded(
                      flex: 2,
                      child: _buildGrowthBadge(context, rev.yoyGrowth),
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

  Widget _buildGrowthBadge(BuildContext context, double? growth) {
    final theme = Theme.of(context);

    if (growth == null) {
      return Text(
        '-',
        textAlign: TextAlign.end,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      );
    }

    final isPositive = growth >= 0;
    final color = isPositive ? AppTheme.upColor : AppTheme.downColor;
    final prefix = isPositive ? '+' : '';
    final isSignificant = growth.abs() >= 10;

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isSignificant
              ? color.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '$prefix${growth.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSignificant ? FontWeight.bold : FontWeight.w500,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildDividendTable(
    BuildContext context,
    List<FinMindDividend> dividends,
  ) {
    final theme = Theme.of(context);

    // Sort by year descending and take last 5
    final sortedData = List<FinMindDividend>.from(dividends)
      ..sort((a, b) => b.year.compareTo(a.year));
    final displayData = sortedData.take(5).toList();

    // Calculate average cash dividend for summary
    double totalCash = 0;
    for (final div in displayData) {
      totalCash += div.cashDividend;
    }
    final avgCash = displayData.isNotEmpty ? totalCash / displayData.length : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Average summary row
            if (displayData.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF27AE60).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF27AE60).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.payments,
                      size: 16,
                      color: Color(0xFF27AE60),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${displayData.length}年平均: ',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    Text(
                      '\$${avgCash.toStringAsFixed(2)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF27AE60),
                      ),
                    ),
                  ],
                ),
              ),
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
                      'stockDetail.dividendYear'.tr(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'stockDetail.cashDividend'.tr(),
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
                      'stockDetail.stockDividend'.tr(),
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                  const Expanded(
                    flex: 2,
                    child: SizedBox(), // Total column placeholder
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Data rows
            ...displayData.asMap().entries.map((entry) {
              final index = entry.key;
              final div = entry.value;
              final total = div.cashDividend + div.stockDividend;

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: index == 0
                      ? theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.3,
                        )
                      : (index.isEven
                            ? theme.colorScheme.surface
                            : Colors.transparent),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        div.year.toString(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: index == 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        div.cashDividend > 0
                            ? '\$${div.cashDividend.toStringAsFixed(2)}'
                            : '-',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: div.cashDividend > 0
                              ? const Color(0xFF27AE60)
                              : null,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        div.stockDividend > 0
                            ? div.stockDividend.toStringAsFixed(2)
                            : '-',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        total > 0 ? '\$${total.toStringAsFixed(2)}' : '-',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
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

  String _formatRevenue(double revenue) {
    // Revenue is in thousands (千元), convert to 億
    if (revenue >= 100000) {
      return '${(revenue / 100000).toStringAsFixed(1)}${'stockDetail.unitBillion'.tr()}';
    } else if (revenue >= 10000) {
      return '${(revenue / 10000).toStringAsFixed(1)}${'stockDetail.unitTenThousand'.tr()}';
    }
    return '${revenue.toStringAsFixed(0)}${'stockDetail.unitThousand'.tr()}';
  }
}
