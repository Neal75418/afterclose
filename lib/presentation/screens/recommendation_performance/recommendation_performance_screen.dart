import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:afterclose/core/constants/app_routes.dart';
import 'package:afterclose/core/constants/reason_type.dart';
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/domain/services/rule_accuracy_service.dart';
import 'package:afterclose/presentation/providers/recommendation_performance_provider.dart';

/// 推薦績效畫面（以個股為中心）
class RecommendationPerformanceScreen extends ConsumerWidget {
  const RecommendationPerformanceScreen({super.key});

  static const _periods = ['ALL', '1D', '3D', '5D', '10D', '20D'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recommendationPerformanceProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('recPerf.title'.tr())),
      body: state.isLoading && state.stockRecords.isEmpty
          ? const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
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

                  // 個股驗證列表
                  if (state.stockRecords.isNotEmpty)
                    _buildStockRecordsList(context, theme, state),

                  // 無資料提示
                  if (state.stockRecords.isEmpty && !state.isLoading)
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
    final stats = state.overallStats;
    final winRate = stats?.winRate ?? 0;
    final avgReturn = stats?.avgReturn ?? 0;
    final totalValidated = stats?.totalCount ?? 0;

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
                Expanded(
                  child: _buildStatItem(
                    theme,
                    'recPerf.totalValidated'.tr(),
                    '$totalValidated',
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

  Widget _buildStockRecordsList(
    BuildContext context,
    ThemeData theme,
    RecommendationPerformanceState state,
  ) {
    // 按推薦日期分組
    final groupedByDate = <DateTime, List<StockValidationRecord>>{};
    for (final record in state.stockRecords) {
      final dateKey = DateContext.normalize(record.recommendationDate);
      groupedByDate.putIfAbsent(dateKey, () => []).add(record);
    }

    // 日期降序排列
    final sortedDates = groupedByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'recPerf.stockDetails'.tr(),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...sortedDates.expand(
              (date) => [
                _buildDateHeader(theme, date),
                ...groupedByDate[date]!.map(
                  (record) => _buildStockValidationCard(context, theme, record),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader(ThemeData theme, DateTime date) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today,
            size: 14,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            '${date.year}/${date.month}/${date.day}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockValidationCard(
    BuildContext context,
    ThemeData theme,
    StockValidationRecord record,
  ) {
    final returnRate = record.returnRate;
    final hasResult = returnRate != null;
    final returnColor = hasResult
        ? (returnRate >= 0 ? AppTheme.upColor : AppTheme.downColor)
        : theme.colorScheme.outline;
    final returnSign = hasResult && returnRate >= 0 ? '+' : '';
    final statusIcon = hasResult
        ? (record.isSuccess == true ? Icons.check_circle : Icons.cancel)
        : Icons.schedule;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        onTap: () {
          HapticFeedback.lightImpact();
          context.push(AppRoutes.stockDetail(record.symbol));
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 股票名稱 + 報酬率
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${record.symbol} ${record.stockName}',
                      style: theme.textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(statusIcon, size: 16, color: returnColor),
                  const SizedBox(width: 4),
                  Text(
                    hasResult
                        ? '$returnSign${returnRate.toStringAsFixed(1)}%'
                        : 'recPerf.pendingValidation'.tr(),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: returnColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // 價格區間
              Text(
                'recPerf.priceRange'.tr(
                  namedArgs: {
                    'entry': record.entryPrice.toStringAsFixed(1),
                    'exit': record.exitPrice?.toStringAsFixed(1) ?? '-',
                    'days': '${record.holdingDays}D',
                  },
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              // 主要規則
              Text(
                'recPerf.primaryRule'.tr(
                  namedArgs: {'rule': _translateRuleId(record.primaryRuleId)},
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
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
