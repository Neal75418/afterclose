import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/presentation/providers/settings_provider.dart';
import 'package:afterclose/presentation/providers/stock_detail_provider.dart';
import 'package:afterclose/presentation/widgets/section_header.dart';

import 'package:afterclose/presentation/screens/stock_detail/tabs/fundamentals/dividend_table.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/fundamentals/eps_table.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/fundamentals/fundamentals_helpers.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/fundamentals/profitability_card.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/fundamentals/revenue_table.dart';

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
    final showROCYear = ref.watch(settingsProvider).showROCYear;

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
            buildLoadingState(context)
          else if (state.revenueHistory.isEmpty)
            buildEmptyState(context, 'stockDetail.revenueComingSoon'.tr())
          else
            RevenueTable(
              revenues: state.revenueHistory,
              showROCYear: showROCYear,
            ),

          const SizedBox(height: 24),

          // EPS history section
          SectionHeader(
            title: 'stockDetail.epsHistory'.tr(),
            icon: Icons.bar_chart,
          ),
          const SizedBox(height: 12),

          if (state.isLoadingFundamentals)
            buildLoadingState(context)
          else if (state.epsHistory.isEmpty)
            buildEmptyState(context, 'stockDetail.epsComingSoon'.tr())
          else
            EpsTable(epsHistory: state.epsHistory, showROCYear: showROCYear),

          // Profitability card
          if (state.latestQuarterMetrics.isNotEmpty) ...[
            const SizedBox(height: 16),
            ProfitabilityCard(metrics: state.latestQuarterMetrics),
          ],

          const SizedBox(height: 24),

          // Dividend section
          SectionHeader(
            title: 'stockDetail.dividendHistory'.tr(),
            icon: Icons.payments,
          ),
          const SizedBox(height: 12),

          if (state.isLoadingFundamentals)
            buildLoadingState(context)
          else if (state.dividendHistory.isEmpty)
            buildEmptyState(context, 'stockDetail.dividendComingSoon'.tr())
          else
            DividendTable(
              dividends: state.dividendHistory,
              showROCYear: showROCYear,
            ),
        ],
      ),
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
}
