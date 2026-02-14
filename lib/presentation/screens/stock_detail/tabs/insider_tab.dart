import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/providers/stock_detail_provider.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/presentation/widgets/metric_card.dart';
import 'package:afterclose/presentation/widgets/section_header.dart';

// ==================================================
// UI 常數
// ==================================================

/// 表格顯示的最大月數
const _kMaxDisplayMonths = 12;

/// 判定持股變化為「顯著」的門檻（百分點）
const _kSignificantChangeThreshold = 1.0;

/// 顏色常數
const _kInsiderRatioColor = Color(0xFF3498DB);
const _kPledgeRatioColor = Color(0xFF9B59B6);

/// Insider Holdings Tab - 董監持股比例、質押比例、持股變化
class InsiderTab extends ConsumerStatefulWidget {
  const InsiderTab({super.key, required this.symbol});

  final String symbol;

  @override
  ConsumerState<InsiderTab> createState() => _InsiderTabState();
}

class _InsiderTabState extends ConsumerState<InsiderTab> {
  @override
  void initState() {
    super.initState();
    // Tab 初始化時載入內部人資料
    Future.microtask(() {
      ref.read(stockDetailProvider(widget.symbol).notifier).loadInsiderData();
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
          // 關鍵指標卡片
          _buildMetricsRow(context, state),
          const SizedBox(height: 24),

          // 內部人持股歷史區段
          SectionHeader(
            title: 'stockDetail.insiderHistory'.tr(),
            icon: Icons.history,
          ),
          const SizedBox(height: 12),

          if (state.loading.isLoadingInsider)
            _buildLoadingState(context)
          else if (state.chip.insiderHistory.isEmpty)
            _buildEmptyState(context, 'stockDetail.insiderComingSoon'.tr())
          else
            _buildInsiderTable(context, state.chip.insiderHistory),
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
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildMetricsRow(BuildContext context, StockDetailState state) {
    final latest = state.chip.insiderHistory.isNotEmpty
        ? state.chip.insiderHistory.first
        : null;
    final previous = state.chip.insiderHistory.length >= 2
        ? state.chip.insiderHistory[1]
        : null;

    // 計算變動
    double? change;
    if (latest?.insiderRatio != null && previous?.insiderRatio != null) {
      change = latest!.insiderRatio! - previous!.insiderRatio!;
    }

    // 判斷質押比是否為高風險
    final pledgeRatio = latest?.pledgeRatio ?? 0;
    final isHighPledge = pledgeRatio >= RuleParams.highPledgeRatioThreshold;

    return Row(
      children: [
        Expanded(
          child: MetricCard(
            label: 'stockDetail.insiderRatio'.tr(),
            value: latest?.insiderRatio != null
                ? '${latest!.insiderRatio!.toStringAsFixed(1)}%'
                : '-',
            icon: Icons.people_alt,
            accentColor: _kInsiderRatioColor,
            subtitle: 'stockDetail.insiderRatioLabel'.tr(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: MetricCard(
            label: 'stockDetail.pledgeRatio'.tr(),
            value: latest?.pledgeRatio != null
                ? '${latest!.pledgeRatio!.toStringAsFixed(1)}%'
                : '-',
            icon: Icons.account_balance,
            accentColor: isHighPledge
                ? AppTheme.errorColor
                : _kPledgeRatioColor,
            subtitle: 'stockDetail.pledgeRatioLabel'.tr(),
            isWarning: isHighPledge,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: MetricCard(
            label: 'stockDetail.insiderChange'.tr(),
            value: change != null
                ? '${change > 0 ? '+' : ''}${change.toStringAsFixed(2)}%'
                : '-',
            icon: _getChangeIcon(change),
            accentColor: _getChangeColor(change),
            subtitle: 'stockDetail.insiderChangeLabel'.tr(),
          ),
        ),
      ],
    );
  }

  /// 根據變化值取得對應的圖示
  ///
  /// - 正數: 向上趨勢
  /// - 負數: 向下趨勢
  /// - 零或 null: 持平/無資料
  IconData _getChangeIcon(double? change) {
    if (change == null || change == 0) return Icons.trending_flat;
    return change > 0 ? Icons.trending_up : Icons.trending_down;
  }

  /// 根據變化值取得對應的顏色
  ///
  /// - 正數: upColor（增持為正面訊號）
  /// - 負數: downColor（減持為負面訊號）
  /// - 零或 null: 灰色（無變化）
  Color _getChangeColor(double? change) {
    if (change == null || change == 0) return Colors.grey;
    return change > 0 ? AppTheme.upColor : AppTheme.downColor;
  }

  Widget _buildInsiderTable(
    BuildContext context,
    List<InsiderHoldingEntry> holdings,
  ) {
    final theme = Theme.of(context);

    // 取最近 N 筆（已依日期降冪排序）
    final displayData = holdings.take(_kMaxDisplayMonths).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // 含樣式背景的標題列
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'stockDetail.insiderDate'.tr(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'stockDetail.insiderRatioShort'.tr(),
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
                      'stockDetail.pledgeRatioShort'.tr(),
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
                      'stockDetail.insiderChangeShort'.tr(),
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
            // 資料列
            ...displayData.asMap().entries.map((entry) {
              final index = entry.key;
              final holding = entry.value;

              // 計算與前一筆的變動
              double? change;
              if (index < displayData.length - 1) {
                final prev = displayData[index + 1];
                if (holding.insiderRatio != null && prev.insiderRatio != null) {
                  change = holding.insiderRatio! - prev.insiderRatio!;
                }
              }

              final isHighPledge =
                  (holding.pledgeRatio ?? 0) >=
                  RuleParams.highPledgeRatioThreshold;

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
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        _formatDate(holding.date),
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
                        holding.insiderRatio != null
                            ? '${holding.insiderRatio!.toStringAsFixed(1)}%'
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
                        holding.pledgeRatio != null
                            ? '${holding.pledgeRatio!.toStringAsFixed(1)}%'
                            : '-',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: isHighPledge ? AppTheme.errorColor : null,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: _buildChangeBadge(context, change),
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

  Widget _buildChangeBadge(BuildContext context, double? change) {
    final theme = Theme.of(context);

    if (change == null) {
      return Text(
        '-',
        textAlign: TextAlign.end,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      );
    }

    // 使用與 _getChangeColor 一致的邏輯：0 為中性
    final color = _getChangeColor(change);
    final prefix = change > 0 ? '+' : '';
    final isSignificant = change.abs() >= _kSignificantChangeThreshold;

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isSignificant
              ? color.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(DesignTokens.radiusXs),
        ),
        child: Text(
          '$prefix${change.toStringAsFixed(2)}%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSignificant ? FontWeight.bold : FontWeight.w500,
            color: color,
          ),
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
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
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

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}';
  }
}
