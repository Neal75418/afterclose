import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/domain/models/screening_condition.dart';
import 'package:afterclose/presentation/providers/backtest_provider.dart';
import 'package:afterclose/presentation/screens/custom_screening/backtest/widgets/backtest_summary_card.dart';
import 'package:afterclose/presentation/screens/custom_screening/backtest/widgets/return_distribution_chart.dart';

/// 策略回測畫面
///
/// 上半：回測設定（期間、持有天數、採樣間隔）
/// 下半：結果（摘要 + 報酬分佈圖）
class BacktestScreen extends ConsumerStatefulWidget {
  const BacktestScreen({super.key, required this.conditions});

  final List<ScreeningCondition> conditions;

  @override
  ConsumerState<BacktestScreen> createState() => _BacktestScreenState();
}

class _BacktestScreenState extends ConsumerState<BacktestScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(backtestProvider);

    return Scaffold(
      appBar: AppBar(title: Text('backtest.title'.tr())),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 設定區
            _buildConfigSection(theme, state),

            // 執行按鈕 + 進度條
            _buildExecuteSection(theme, state),

            // 結果區
            if (state.result != null) _buildResultsSection(theme, state),

            // 警語
            if (state.result != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'backtest.warning'.tr(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 設定區
  // ==========================================

  Widget _buildConfigSection(ThemeData theme, BacktestState state) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 回測期間
          Text('backtest.period'.tr(), style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 3, label: Text('backtest.period3m'.tr())),
              ButtonSegment(value: 6, label: Text('backtest.period6m'.tr())),
              ButtonSegment(value: 12, label: Text('backtest.period12m'.tr())),
            ],
            selected: {state.config.periodMonths},
            onSelectionChanged: state.isExecuting
                ? null
                : (values) {
                    ref
                        .read(backtestProvider.notifier)
                        .updatePeriod(values.first);
                  },
          ),
          const SizedBox(height: 16),

          // 持有天數
          Row(
            children: [
              Text(
                'backtest.holdingDays'.tr(),
                style: theme.textTheme.labelLarge,
              ),
              const Spacer(),
              Text(
                'backtest.holdingDaysValue'.tr(
                  namedArgs: {'days': state.config.holdingDays.toString()},
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _HoldingDaysSlider(
            value: state.config.holdingDays,
            enabled: !state.isExecuting,
            onChanged: (days) {
              ref.read(backtestProvider.notifier).updateHoldingDays(days);
            },
          ),
          const SizedBox(height: 16),

          // 採樣間隔
          Text(
            'backtest.samplingInterval'.tr(),
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: [
              ButtonSegment(
                value: 1,
                label: Text('backtest.samplingEveryDay'.tr()),
              ),
              ButtonSegment(
                value: 5,
                label: Text('backtest.samplingEvery5Days'.tr()),
              ),
            ],
            selected: {state.config.samplingInterval},
            onSelectionChanged: state.isExecuting
                ? null
                : (values) {
                    ref
                        .read(backtestProvider.notifier)
                        .updateSamplingInterval(values.first);
                  },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 執行區
  // ==========================================

  Widget _buildExecuteSection(ThemeData theme, BacktestState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: state.isExecuting
                  ? null
                  : () => ref
                        .read(backtestProvider.notifier)
                        .executeBacktest(widget.conditions),
              icon: state.isExecuting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.analytics_outlined),
              label: Text(
                state.isExecuting
                    ? 'backtest.executing'.tr()
                    : 'backtest.startBacktest'.tr(),
              ),
            ),
          ),

          // 進度條
          if (state.isExecuting) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: state.progress),
            const SizedBox(height: 4),
            Text(
              'backtest.progress'.tr(
                namedArgs: {
                  'current': state.progressCurrent.toString(),
                  'total': state.progressTotal.toString(),
                },
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],

          // 錯誤訊息
          if (state.error != null) ...[
            const SizedBox(height: 8),
            Text(
              state.error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // 結果區
  // ==========================================

  Widget _buildResultsSection(ThemeData theme, BacktestState state) {
    final result = state.result!;

    if (result.trades.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            'backtest.noResults'.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        const SizedBox(height: 8),

        // 統計摘要
        BacktestSummaryCard(
          summary: result.summary,
          tradingDaysScanned: result.tradingDaysScanned,
          executionTime: result.executionTime,
          skippedTrades: result.skippedTrades,
        ),

        // 報酬分佈圖
        ReturnDistributionChart(distribution: result.returnDistribution),
      ],
    );
  }
}

// ==========================================
// 持有天數 Slider
// ==========================================

class _HoldingDaysSlider extends StatelessWidget {
  const _HoldingDaysSlider({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  // 離散刻度值
  static const _stops = [1, 3, 5, 10, 20];

  @override
  Widget build(BuildContext context) {
    final index = _stops.indexOf(value).clamp(0, _stops.length - 1);

    return Slider(
      value: index.toDouble(),
      min: 0,
      max: (_stops.length - 1).toDouble(),
      divisions: _stops.length - 1,
      onChanged: enabled
          ? (v) {
              final newIndex = v.round();
              onChanged(_stops[newIndex]);
            }
          : null,
    );
  }
}
