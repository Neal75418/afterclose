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
import 'package:afterclose/presentation/widgets/metric_card.dart';

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
    // Tab 初始化時載入基本面資料
    Future.microtask(() {
      ref.read(stockDetailProvider(widget.symbol).notifier).loadFundamentals();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stockDetailProvider(widget.symbol));
    final showROCYear = ref.watch(
      settingsProvider.select((s) => s.showROCYear),
    );

    return SingleChildScrollView(
      primary: false,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 關鍵指標卡片
          _buildMetricsRow(context, state),
          const SizedBox(height: 24),

          // 月營收區段
          SectionHeader(
            title: 'stockDetail.monthlyRevenue'.tr(),
            icon: Icons.trending_up,
          ),
          const SizedBox(height: 12),

          if (state.loading.isLoadingFundamentals)
            buildLoadingState(context)
          else if (state.fundamentals.revenueHistory.isEmpty)
            buildEmptyState(context, 'stockDetail.revenueComingSoon'.tr())
          else
            RevenueTable(
              revenues: state.fundamentals.revenueHistory,
              showROCYear: showROCYear,
            ),

          const SizedBox(height: 24),

          // EPS 歷史區段
          SectionHeader(
            title: 'stockDetail.epsHistory'.tr(),
            icon: Icons.bar_chart,
          ),
          const SizedBox(height: 12),

          if (state.loading.isLoadingFundamentals)
            buildLoadingState(context)
          else if (state.fundamentals.epsHistory.isEmpty)
            buildEmptyState(context, 'stockDetail.epsComingSoon'.tr())
          else
            EpsTable(
              epsHistory: state.fundamentals.epsHistory,
              showROCYear: showROCYear,
            ),

          // 獲利能力卡片
          if (state.fundamentals.latestQuarterMetrics.isNotEmpty) ...[
            const SizedBox(height: 16),
            ProfitabilityCard(metrics: state.fundamentals.latestQuarterMetrics),
          ],

          const SizedBox(height: 24),

          // 股利區段
          SectionHeader(
            title: 'stockDetail.dividendHistory'.tr(),
            icon: Icons.payments,
          ),
          const SizedBox(height: 12),

          if (state.loading.isLoadingFundamentals)
            buildLoadingState(context)
          else if (state.fundamentals.dividendHistory.isEmpty)
            buildEmptyState(context, 'stockDetail.dividendComingSoon'.tr())
          else
            DividendTable(
              dividends: state.fundamentals.dividendHistory,
              showROCYear: showROCYear,
            ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow(BuildContext context, StockDetailState state) {
    final per = state.fundamentals.latestPER;

    return Row(
      children: [
        Expanded(
          child: MetricCard(
            label: 'P/E',
            value: per != null && per.per > 0
                ? per.per.toStringAsFixed(1)
                : '-',
            icon: Icons.analytics,
            accentColor: const Color(0xFF3498DB),
            subtitle: 'stockDetail.perLabel'.tr(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: MetricCard(
            label: 'P/B',
            value: per != null && per.pbr > 0
                ? per.pbr.toStringAsFixed(2)
                : '-',
            icon: Icons.account_balance,
            accentColor: const Color(0xFF9B59B6),
            subtitle: 'stockDetail.pbrLabel'.tr(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: MetricCard(
            label: 'stockDetail.yield'.tr(),
            value: per != null && per.dividendYield > 0
                ? '${per.dividendYield.toStringAsFixed(2)}%'
                : '-',
            icon: Icons.percent,
            accentColor: const Color(0xFF27AE60),
            subtitle: 'stockDetail.yieldLabel'.tr(),
          ),
        ),
      ],
    );
  }
}
