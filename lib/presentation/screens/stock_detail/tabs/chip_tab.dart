import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/providers/stock_detail_provider.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/chip_strength_indicator.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/day_trading_section.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/mini_trend_chart.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/shareholding_section.dart';
import 'package:afterclose/presentation/widgets/section_header.dart';

/// Comprehensive chip (籌碼) analysis tab with 6 sections.
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
    Future.microtask(() {
      ref.read(stockDetailProvider(widget.symbol).notifier).loadChipData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stockDetailProvider(widget.symbol));

    if (state.isLoadingChip && state.chipStrength == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      primary: false,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Chip strength indicator
          if (state.chipStrength != null)
            ChipStrengthIndicator(strength: state.chipStrength!),

          if (state.chipStrength != null) const SizedBox(height: 20),

          // 2. Institutional flow section
          _buildInstitutionalSection(context, state),

          const SizedBox(height: 24),

          // 3. Foreign shareholding section
          ShareholdingSection(history: state.shareholdingHistory),

          const SizedBox(height: 24),

          // 4. Margin trading section (from DB)
          _buildMarginSection(context, state),

          const SizedBox(height: 24),

          // 5. Day trading section
          DayTradingSection(history: state.dayTradingHistory),

          const SizedBox(height: 24),

          // 6. Holding distribution section
          _buildDistributionSection(context, state),

          const SizedBox(height: 24),

          // 7. Insider holding section
          _buildInsiderSection(context, state),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ==================================================
  // Section 1: Institutional flow
  // ==================================================

  Widget _buildInstitutionalSection(
    BuildContext context,
    StockDetailState state,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary cards
        if (state.institutionalHistory.isNotEmpty)
          _buildInstitutionalSummary(context, state),

        if (state.institutionalHistory.isNotEmpty) const SizedBox(height: 12),

        SectionHeader(
          title: 'chip.sectionInstitutional'.tr(),
          icon: Icons.business,
        ),
        const SizedBox(height: 12),

        if (state.institutionalHistory.isEmpty)
          _buildEmptyState(theme)
        else ...[
          // Trend chart
          _buildInstitutionalTrendChart(state),
          const SizedBox(height: 12),
          // Table
          _buildInstitutionalTable(context, state),
        ],
      ],
    );
  }

  Widget _buildInstitutionalSummary(
    BuildContext context,
    StockDetailState state,
  ) {
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
            AppTheme.foreignColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            context,
            'stockDetail.investment'.tr(),
            trustNet,
            Icons.account_balance,
            AppTheme.investmentTrustColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            context,
            'stockDetail.dealer'.tr(),
            dealerNet,
            Icons.store,
            AppTheme.dealerColor,
          ),
        ),
      ],
    );
  }

  Widget _buildInstitutionalTrendChart(StockDetailState state) {
    final deduped = _getDeduplicatedInstitutionalData(
      state.institutionalHistory,
    );
    if (deduped.length < 2) return const SizedBox.shrink();

    // Show total net (foreign + trust) trend
    final sorted = deduped.reversed.toList(); // chronological order
    final totalNets = sorted
        .map((e) => (e.foreignNet ?? 0) + (e.investmentTrustNet ?? 0))
        .toList();

    return MiniTrendChart(
      dataPoints: totalNets,
      lineColor: const Color(0xFF3498DB),
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
        border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1),
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

  Widget _buildInstitutionalTable(
    BuildContext context,
    StockDetailState state,
  ) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Header row
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
                  _buildColoredHeader(
                    theme,
                    'stockDetail.foreign'.tr(),
                    const Color(0xFF3498DB),
                  ),
                  _buildColoredHeader(
                    theme,
                    'stockDetail.investment'.tr(),
                    const Color(0xFF9B59B6),
                  ),
                  _buildColoredHeader(
                    theme,
                    'stockDetail.dealer'.tr(),
                    const Color(0xFFE67E22),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ..._getDeduplicatedInstitutionalData(
              state.institutionalHistory,
            ).asMap().entries.map((entry) {
              final index = entry.key;
              final inst = entry.value;
              return _buildDataRow(
                theme,
                index,
                '${inst.date.month}/${inst.date.day}',
                [
                  inst.foreignNet ?? 0,
                  inst.investmentTrustNet ?? 0,
                  inst.dealerNet ?? 0,
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  // ==================================================
  // Section 4: Margin trading (DB-backed)
  // ==================================================

  Widget _buildMarginSection(BuildContext context, StockDetailState state) {
    final theme = Theme.of(context);
    final history = state.marginTradingHistory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary cards
        if (history.isNotEmpty) _buildMarginSummary(context, history),

        if (history.isNotEmpty) const SizedBox(height: 12),

        SectionHeader(title: 'chip.sectionMargin'.tr(), icon: Icons.swap_horiz),
        const SizedBox(height: 12),

        if (history.isEmpty)
          _buildEmptyState(theme)
        else ...[
          // Trend chart (margin balance)
          _buildMarginTrendChart(history),
          const SizedBox(height: 12),
          _buildMarginTable(context, history),
        ],
      ],
    );
  }

  Widget _buildMarginSummary(
    BuildContext context,
    List<MarginTradingEntry> history,
  ) {
    final theme = Theme.of(context);

    final sorted = List<MarginTradingEntry>.from(history)
      ..sort((a, b) => b.date.compareTo(a.date));
    final latest = sorted.first;
    final marginBal = latest.marginBalance ?? 0;
    final shortBal = latest.shortBalance ?? 0;

    // Compute short/margin ratio
    final shortMarginRatio = marginBal > 0 ? (shortBal / marginBal * 100) : 0.0;
    final isHighRatio = shortMarginRatio > 10;

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
                    const Icon(
                      Icons.trending_up,
                      size: 14,
                      color: AppTheme.upColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'chip.marginBalance'.tr(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _formatBalance(marginBal),
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
                color:
                    (isHighRatio
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
                      color: isHighRatio
                          ? AppTheme.downColor
                          : theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'chip.shortMarginRatio'.tr(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${shortMarginRatio.toStringAsFixed(1)}%',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isHighRatio
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

  Widget _buildMarginTrendChart(List<MarginTradingEntry> history) {
    final sorted = List<MarginTradingEntry>.from(history)
      ..sort((a, b) => a.date.compareTo(b.date));
    if (sorted.length < 2) return const SizedBox.shrink();

    final data = sorted.map((e) => (e.marginBalance ?? 0).toDouble()).toList();
    return MiniTrendChart(
      dataPoints: data,
      lineColor: AppTheme.upColor,
      minY: 0,
    );
  }

  Widget _buildMarginTable(
    BuildContext context,
    List<MarginTradingEntry> history,
  ) {
    final theme = Theme.of(context);

    final sorted = List<MarginTradingEntry>.from(history)
      ..sort((a, b) => b.date.compareTo(a.date));
    final displayData = sorted.take(10).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Header
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
                      'chip.marginBalance'.tr(),
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
                      'chip.shortBalance'.tr(),
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
                      'chip.shortMarginRatio'.tr(),
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
            ...displayData.asMap().entries.map((entry) {
              final index = entry.key;
              final margin = entry.value;
              final marginBal = margin.marginBalance ?? 0;
              final shortBal = margin.shortBalance ?? 0;
              final ratio = marginBal > 0 ? (shortBal / marginBal * 100) : 0.0;

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
                        '${margin.date.month}/${margin.date.day}',
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
                        _formatBalance(marginBal),
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        _formatBalance(shortBal),
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: ratio > 10
                              ? AppTheme.downColor.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${ratio.toStringAsFixed(1)}%',
                          textAlign: TextAlign.end,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: ratio > 10
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: ratio > 10
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

  // ==================================================
  // Section 5: Holding distribution
  // ==================================================

  Widget _buildDistributionSection(
    BuildContext context,
    StockDetailState state,
  ) {
    final theme = Theme.of(context);
    final dist = state.holdingDistribution;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'chip.sectionDistribution'.tr(),
          icon: Icons.pie_chart_outline,
        ),
        const SizedBox(height: 12),
        if (dist.isEmpty)
          _buildEmptyState(theme)
        else
          _buildDistributionBars(context, dist),
      ],
    );
  }

  Widget _buildDistributionBars(
    BuildContext context,
    List<HoldingDistributionEntry> entries,
  ) {
    final theme = Theme.of(context);

    // Group and display top levels by percent
    final sorted = List<HoldingDistributionEntry>.from(entries)
      ..sort((a, b) => (b.percent ?? 0).compareTo(a.percent ?? 0));

    // Take top 8 levels for display
    final display = sorted.take(8).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: display.map((entry) {
            final pct = entry.percent ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(entry.level, style: theme.textTheme.bodySmall),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: (pct / 100).clamp(0.0, 1.0),
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          pct > 20
                              ? theme.colorScheme.primary
                              : theme.colorScheme.primary.withValues(
                                  alpha: 0.6,
                                ),
                        ),
                        minHeight: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 50,
                    child: Text(
                      '${pct.toStringAsFixed(1)}%',
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ==================================================
  // Section 6: Insider holding
  // ==================================================

  Widget _buildInsiderSection(BuildContext context, StockDetailState state) {
    final theme = Theme.of(context);
    final history = state.insiderHistory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'chip.sectionInsider'.tr(),
          icon: Icons.shield_outlined,
        ),
        const SizedBox(height: 12),
        if (history.isEmpty)
          _buildEmptyState(theme)
        else
          _buildInsiderCard(context, history),
      ],
    );
  }

  Widget _buildInsiderCard(
    BuildContext context,
    List<InsiderHoldingEntry> history,
  ) {
    final theme = Theme.of(context);
    final sorted = List<InsiderHoldingEntry>.from(history)
      ..sort((a, b) => b.date.compareTo(a.date));
    final latest = sorted.first;

    final insiderRatio = latest.insiderRatio ?? 0;
    final pledgeRatio = latest.pledgeRatio ?? 0;
    final sharesChange = latest.sharesChange ?? 0;
    final isHighPledge = pledgeRatio >= 30;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ratio row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'chip.insiderRatio'.tr(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${insiderRatio.toStringAsFixed(2)}%',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'chip.pledgeRatio'.tr(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${pledgeRatio.toStringAsFixed(2)}%',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isHighPledge ? AppTheme.downColor : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Shares change
            Row(
              children: [
                Text(
                  'chip.sharesChange'.tr(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatSharesChange(sharesChange),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: sharesChange > 0
                        ? AppTheme.upColor
                        : sharesChange < 0
                        ? AppTheme.downColor
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),

            // Pledge warning
            if (isHighPledge) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.downColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: AppTheme.downColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'chip.pledgeWarning'.tr(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.downColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================================================
  // Shared helpers
  // ==================================================

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          'chip.noData'.tr(),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ),
    );
  }

  Widget _buildColoredHeader(ThemeData theme, String label, Color color) {
    return Expanded(
      flex: 2,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(
    ThemeData theme,
    int index,
    String dateLabel,
    List<double> values,
  ) {
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
              dateLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: index == 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          for (final v in values)
            Expanded(flex: 2, child: _buildNetValue(context, v)),
        ],
      ),
    );
  }

  Widget _buildNetValue(BuildContext context, double value) {
    final isPositive = value >= 0;
    final color = isPositive ? AppTheme.upColor : AppTheme.downColor;

    return Text(
      _formatNet(value),
      textAlign: TextAlign.end,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color),
    );
  }

  /// 依日期去重並排序法人資料
  List<DailyInstitutionalEntry> _getDeduplicatedInstitutionalData(
    List<DailyInstitutionalEntry> history,
  ) {
    if (history.isEmpty) return [];

    final Map<String, DailyInstitutionalEntry> dedupMap = {};
    for (final entry in history) {
      final dateKey =
          '${entry.date.year}-${entry.date.month}-${entry.date.day}';
      dedupMap[dateKey] = entry;
    }

    final dedupList = dedupMap.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return dedupList.take(10).toList();
  }

  /// Format net value with Chinese units (shares → 張)
  String _formatNet(double value) {
    final prefix = value >= 0 ? '+' : '';
    final absValue = value.abs();
    final lots = absValue / 1000;

    if (lots >= 10000) {
      return '$prefix${(value / 1000 / 10000).toStringAsFixed(1)}${'stockDetail.unitTenThousand'.tr()}${'stockDetail.unitShares'.tr()}';
    } else if (lots >= 1000) {
      return '$prefix${(value / 1000 / 1000).toStringAsFixed(1)}${'stockDetail.unitThousand'.tr()}${'stockDetail.unitShares'.tr()}';
    } else if (lots >= 1) {
      return '$prefix${(value / 1000).toStringAsFixed(0)}${'stockDetail.unitShares'.tr()}';
    }
    return '$prefix${value.toStringAsFixed(0)}';
  }

  /// Format balance with Chinese units (already in 張)
  String _formatBalance(double value) {
    if (value >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}${'stockDetail.unitTenThousand'.tr()}${'stockDetail.unitShares'.tr()}';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}${'stockDetail.unitThousand'.tr()}${'stockDetail.unitShares'.tr()}';
    }
    return '${value.toStringAsFixed(0)}${'stockDetail.unitShares'.tr()}';
  }

  /// Format shares change (in 千股)
  String _formatSharesChange(double value) {
    final prefix = value >= 0 ? '+' : '';
    final absValue = value.abs();
    if (absValue >= 1000) {
      return '$prefix${(value / 1000).toStringAsFixed(1)}${'stockDetail.unitThousand'.tr()}${'stockDetail.unitShares'.tr()}';
    }
    return '$prefix${value.toStringAsFixed(0)}${'stockDetail.unitShares'.tr()}';
  }
}
