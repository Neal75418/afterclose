import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/mini_trend_chart.dart';
import 'package:afterclose/presentation/widgets/section_header.dart';

import 'package:afterclose/presentation/screens/stock_detail/tabs/chip/chip_helpers.dart';
import 'package:afterclose/core/theme/design_tokens.dart';

/// Displays institutional investor flow data: summary cards, trend chart, and table.
class InstitutionalSection extends StatelessWidget {
  const InstitutionalSection({super.key, required this.history});

  final List<DailyInstitutionalEntry> history;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary cards
        if (history.isNotEmpty) _buildSummary(context),

        if (history.isNotEmpty) const SizedBox(height: 12),

        SectionHeader(
          title: 'chip.sectionInstitutional'.tr(),
          icon: Icons.business,
        ),
        const SizedBox(height: 12),

        if (history.isEmpty)
          buildEmptyState(context, 'chip.noData'.tr())
        else ...[
          _buildTrendChart(),
          const SizedBox(height: 12),
          _buildTable(context),
        ],
      ],
    );
  }

  Widget _buildSummary(BuildContext context) {
    final latest = history.last;

    final foreignNet = latest.foreignNet ?? 0;
    final trustNet = latest.investmentTrustNet ?? 0;
    final dealerNet = latest.dealerNet ?? 0;

    return Row(
      children: [
        Expanded(
          child: buildSummaryCard(
            context,
            'stockDetail.foreign'.tr(),
            foreignNet,
            Icons.language,
            AppTheme.foreignColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: buildSummaryCard(
            context,
            'stockDetail.investment'.tr(),
            trustNet,
            Icons.account_balance,
            AppTheme.investmentTrustColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: buildSummaryCard(
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

  Widget _buildTrendChart() {
    final deduped = _getDeduplicatedData(history);
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

  Widget _buildTable(BuildContext context) {
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
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
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
                  buildColoredHeader(
                    theme,
                    'stockDetail.foreign'.tr(),
                    const Color(0xFF3498DB),
                  ),
                  buildColoredHeader(
                    theme,
                    'stockDetail.investment'.tr(),
                    const Color(0xFF9B59B6),
                  ),
                  buildColoredHeader(
                    theme,
                    'stockDetail.dealer'.tr(),
                    const Color(0xFFE67E22),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ..._getDeduplicatedData(history).asMap().entries.map((entry) {
              final index = entry.key;
              final inst = entry.value;
              return buildDataRow(
                context,
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

  /// Deduplicate and sort institutional data by date.
  List<DailyInstitutionalEntry> _getDeduplicatedData(
    List<DailyInstitutionalEntry> data,
  ) {
    if (data.isEmpty) return [];

    final Map<String, DailyInstitutionalEntry> dedupMap = {};
    for (final entry in data) {
      final dateKey =
          '${entry.date.year}-${entry.date.month}-${entry.date.day}';
      dedupMap[dateKey] = entry;
    }

    final dedupList = dedupMap.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return dedupList.take(10).toList();
  }
}
