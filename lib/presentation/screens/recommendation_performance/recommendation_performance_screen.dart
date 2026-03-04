import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/constants/reason_type.dart';
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/domain/services/rule_accuracy_service.dart';
import 'package:afterclose/presentation/providers/recommendation_performance_provider.dart';

/// 推薦績效畫面
class RecommendationPerformanceScreen extends ConsumerWidget {
  const RecommendationPerformanceScreen({super.key});

  static const _periods = ['ALL', '1D', '3D', '5D', '10D', '20D'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recommendationPerformanceProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('recPerf.title'.tr())),
      body: state.isLoading && state.ruleStats.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref
                  .read(recommendationPerformanceProvider.notifier)
                  .loadData(),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  // 持有天數選擇器
                  _buildPeriodSelector(context, ref, state),

                  // 整體統計卡
                  _buildOverallStatsCard(context, theme, state),

                  // 回填按鈕 + 進度
                  _buildBackfillSection(context, ref, theme, state),

                  // 規則績效表
                  if (state.ruleStats.isNotEmpty)
                    _buildRuleTable(context, theme, state),

                  // 無資料提示
                  if (state.ruleStats.isEmpty && !state.isLoading)
                    _buildEmptyHint(context, theme),

                  // 免責聲明
                  _buildDisclaimer(context, theme),
                ],
              ),
            ),
    );
  }

  Widget _buildPeriodSelector(
    BuildContext context,
    WidgetRef ref,
    RecommendationPerformanceState state,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: SegmentedButton<String>(
        segments: _periods.map((p) {
          return ButtonSegment<String>(
            value: p,
            label: Text(
              p == 'ALL' ? 'recPerf.periodAll'.tr() : p,
              style: const TextStyle(fontSize: 12),
            ),
          );
        }).toList(),
        selected: {state.selectedPeriod},
        onSelectionChanged: (selected) {
          ref
              .read(recommendationPerformanceProvider.notifier)
              .selectPeriod(selected.first);
        },
        showSelectedIcon: false,
      ),
    );
  }

  Widget _buildOverallStatsCard(
    BuildContext context,
    ThemeData theme,
    RecommendationPerformanceState state,
  ) {
    final winRate = state.overallWinRate;
    final avgReturn = state.overallAvgReturn;
    final totalValidated = state.totalValidated;
    final ruleCount = state.ruleStats.length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'recPerf.overallStats'.tr(),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    theme,
                    'recPerf.winRate'.tr(),
                    '${winRate.toStringAsFixed(1)}%',
                    winRate >= 50 ? AppTheme.upColor : AppTheme.downColor,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    theme,
                    'recPerf.avgReturn'.tr(),
                    '${avgReturn >= 0 ? '+' : ''}${avgReturn.toStringAsFixed(2)}%',
                    avgReturn >= 0 ? AppTheme.upColor : AppTheme.downColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    theme,
                    'recPerf.totalValidated'.tr(),
                    '$totalValidated',
                    theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    theme,
                    'recPerf.ruleCount'.tr(),
                    '$ruleCount',
                    theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    ThemeData theme,
    String label,
    String value,
    Color valueColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: valueColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildBackfillSection(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    RecommendationPerformanceState state,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('recPerf.backfill'.tr(), style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'recPerf.backfillDesc'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (state.isBackfilling) ...[
              LinearProgressIndicator(value: state.backfillProgress),
              const SizedBox(height: 8),
              Text(
                'recPerf.backfillProgress'.tr(
                  namedArgs: {
                    'current': '${state.backfillCurrent}',
                    'total': '${state.backfillTotal}',
                  },
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ] else
              FilledButton.icon(
                onPressed: () => ref
                    .read(recommendationPerformanceProvider.notifier)
                    .runBackfill(),
                icon: const Icon(Icons.history, size: 18),
                label: Text('recPerf.runBackfill'.tr()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleTable(
    BuildContext context,
    ThemeData theme,
    RecommendationPerformanceState state,
  ) {
    // 按觸發次數降序排列
    final sorted = List<RuleStats>.from(state.ruleStats)
      ..sort((a, b) => b.triggerCount.compareTo(a.triggerCount));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'recPerf.ruleBreakdown'.tr(),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            // 表頭
            _buildTableHeader(theme),
            const Divider(height: 1),
            // 表身
            ...sorted.map((rule) => _buildTableRow(theme, rule)),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(ThemeData theme) {
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.bold,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('recPerf.colRule'.tr(), style: style)),
          Expanded(
            flex: 2,
            child: Text(
              'recPerf.colCount'.tr(),
              style: style,
              textAlign: TextAlign.end,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'recPerf.colWinRate'.tr(),
              style: style,
              textAlign: TextAlign.end,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'recPerf.colAvgReturn'.tr(),
              style: style,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(ThemeData theme, RuleStats rule) {
    final returnColor = rule.avgReturn >= 0
        ? AppTheme.upColor
        : AppTheme.downColor;
    final winColor = rule.hitRate >= 50 ? AppTheme.upColor : AppTheme.downColor;

    // 嘗試翻譯規則名稱，無翻譯時直接顯示 ruleId
    final ruleLabel = _translateRuleId(rule.ruleId);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              ruleLabel,
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${rule.triggerCount}',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.end,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${rule.hitRate.toStringAsFixed(0)}%',
              style: theme.textTheme.bodySmall?.copyWith(color: winColor),
              textAlign: TextAlign.end,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${rule.avgReturn >= 0 ? '+' : ''}${rule.avgReturn.toStringAsFixed(1)}%',
              style: theme.textTheme.bodySmall?.copyWith(color: returnColor),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHint(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'recPerf.noData'.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'recPerf.noDataHint'.tr(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              size: 16,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'recPerf.disclaimer'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// UPPER_SNAKE_CASE code → camelCase enum name 對照表
  static final _codeToEnumName = {
    for (final r in ReasonType.values) r.code: r.name,
  };

  String _translateRuleId(String ruleId) {
    // DB 存的是 UPPER_SNAKE_CASE (e.g. WEEK_52_HIGH)，
    // 翻譯 key 是 camelCase (e.g. reasons.week52High)
    final enumName = _codeToEnumName[ruleId] ?? ruleId;
    final key = 'reasons.$enumName';
    final translated = key.tr();
    return translated == key ? ruleId : translated;
  }
}
