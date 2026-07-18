import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/mini_trend_chart.dart';
import 'package:afterclose/presentation/widgets/section_header.dart';

import 'package:afterclose/presentation/screens/stock_detail/tabs/chip/chip_helpers.dart';
import 'package:afterclose/core/theme/design_tokens.dart';

/// 顯示法人進出資料：摘要卡片、趨勢圖與明細表。
class InstitutionalSection extends StatelessWidget {
  const InstitutionalSection({super.key, required this.history});

  final List<DailyInstitutionalEntry> history;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 摘要卡片
        if (history.isNotEmpty) _buildSummary(context),

        if (history.isNotEmpty) const SizedBox(height: DesignTokens.spacing12),

        SectionHeader(
          title: 'chip.sectionInstitutional'.tr(),
          icon: Icons.business,
        ),
        const SizedBox(height: DesignTokens.spacing12),

        if (history.isEmpty)
          buildEmptyState(context, 'chip.noData'.tr())
        else ...[
          _buildTrendChart(context),
          const SizedBox(height: DesignTokens.spacing12),
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
          ),
        ),
        const SizedBox(width: DesignTokens.spacing8),
        Expanded(
          child: buildSummaryCard(
            context,
            'stockDetail.investment'.tr(),
            trustNet,
            Icons.account_balance,
          ),
        ),
        const SizedBox(width: DesignTokens.spacing8),
        Expanded(
          child: buildSummaryCard(
            context,
            'stockDetail.dealer'.tr(),
            dealerNet,
            Icons.store,
          ),
        ),
      ],
    );
  }

  Widget _buildTrendChart(BuildContext context) {
    final deduped = _getDeduplicatedData(history);
    if (deduped.length < 2) return const SizedBox.shrink();

    // 顯示法人（外資＋投信）合計趨勢
    final sorted = deduped.reversed.toList(); // chronological order
    final totalNets = sorted
        .map((e) => (e.foreignNet ?? 0) + (e.investmentTrustNet ?? 0))
        .toList();

    // 這裡不在 Card 內、直接坐落在 ChipTab 的 surface 底色上（非白色）——
    // 不得沿用 CategoryColors.neutral（對 surface 底僅 2.43:1，圖形物件
    // 3.0:1 門檻不過）。改走主題 onSurfaceVariant，理由同 insider_section.dart。
    return MiniTrendChart(
      dataPoints: totalNets,
      lineColor: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }

  Widget _buildTable(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spacing12),
        child: Column(
          children: [
            // 標題列
            Container(
              padding: const EdgeInsets.symmetric(
                vertical: DesignTokens.spacing8,
                horizontal: DesignTokens.spacing4,
              ),
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
                  buildColumnHeader(theme, 'stockDetail.foreign'.tr()),
                  buildColumnHeader(theme, 'stockDetail.investment'.tr()),
                  buildColumnHeader(theme, 'stockDetail.dealer'.tr()),
                ],
              ),
            ),
            const SizedBox(height: DesignTokens.spacing8),
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

  /// 依日期去重並排序法人資料
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
