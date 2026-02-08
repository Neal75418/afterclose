import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:afterclose/core/constants/app_routes.dart';
import 'package:afterclose/core/constants/ui_constants.dart';
import 'package:afterclose/presentation/providers/settings_provider.dart';

import 'package:afterclose/presentation/providers/custom_screening_provider.dart';
import 'package:afterclose/presentation/widgets/stock_card.dart';
import 'package:afterclose/presentation/screens/custom_screening/widgets/condition_card.dart';
import 'package:afterclose/presentation/screens/custom_screening/widgets/condition_editor_sheet.dart';
import 'package:afterclose/presentation/screens/custom_screening/widgets/strategy_manager_sheet.dart';

class CustomScreeningScreen extends ConsumerStatefulWidget {
  const CustomScreeningScreen({super.key});

  @override
  ConsumerState<CustomScreeningScreen> createState() =>
      _CustomScreeningScreenState();
}

class _CustomScreeningScreenState extends ConsumerState<CustomScreeningScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent -
            UiConstants.scrollLoadMoreThreshold) {
      ref.read(customScreeningProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(customScreeningProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('customScreening.title'.tr()),
        actions: [
          // 回測
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'backtest.title'.tr(),
            onPressed: state.conditions.isEmpty
                ? null
                : () =>
                      context.push(AppRoutes.backtest, extra: state.conditions),
          ),
          // 儲存/載入策略
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'customScreening.loadStrategy'.tr(),
            onPressed: () => StrategyManagerSheet.show(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 條件列表區域
          _buildConditionsSection(theme, state),

          // 執行按鈕
          _buildExecuteButton(theme, state),

          // 結果區域
          if (state.result != null || state.isExecuting)
            Expanded(child: _buildResultsSection(theme, state)),
        ],
      ),
    );
  }

  Widget _buildConditionsSection(ThemeData theme, CustomScreeningState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.conditions.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...state.conditions.asMap().entries.map((entry) {
            return ConditionCard(
              condition: entry.value,
              index: entry.key,
              onEdit: () => _editCondition(entry.key, entry.value),
              onDelete: () => ref
                  .read(customScreeningProvider.notifier)
                  .removeCondition(entry.key),
            );
          }),
        ],

        // 新增條件按鈕
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: OutlinedButton.icon(
            onPressed: _addCondition,
            icon: const Icon(Icons.add),
            label: Text('customScreening.addCondition'.tr()),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExecuteButton(ThemeData theme, CustomScreeningState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: state.conditions.isEmpty || state.isExecuting
              ? null
              : () => ref
                    .read(customScreeningProvider.notifier)
                    .executeScreening(),
          icon: state.isExecuting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.search),
          label: Text(
            state.isExecuting
                ? 'customScreening.executing'.tr()
                : 'customScreening.execute'.tr(
                    namedArgs: {'count': state.conditions.length.toString()},
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsSection(ThemeData theme, CustomScreeningState state) {
    if (state.isExecuting) {
      return const Center(child: CircularProgressIndicator());
    }

    final result = state.result;
    if (result == null) return const SizedBox.shrink();
    final showLimitMarkers = ref.watch(
      settingsProvider.select((s) => s.limitAlerts),
    );

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                state.error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () => ref
                    .read(customScreeningProvider.notifier)
                    .executeScreening(),
                child: Text('common.retry'.tr()),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 結果統計
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                'customScreening.resultCount'.tr(
                  namedArgs: {
                    'count': result.matchCount.toString(),
                    'total': result.totalScanned.toString(),
                  },
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (result.executionTime != null)
                Text(
                  'customScreening.executionTime'.tr(
                    namedArgs: {
                      'ms': result.executionTime!.inMilliseconds.toString(),
                    },
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),

        // 結果列表
        if (state.stocks.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                'customScreening.noResults'.tr(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              cacheExtent: 500,
              itemCount: state.stocks.length + (state.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == state.stocks.length) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: state.isLoadingMore
                          ? const CircularProgressIndicator()
                          : const SizedBox.shrink(),
                    ),
                  );
                }

                final stock = state.stocks[index];
                return StockCard(
                  symbol: stock.symbol,
                  stockName: stock.stockName,
                  market: stock.market,
                  latestClose: stock.latestClose,
                  priceChange: stock.priceChange,
                  score: stock.score,
                  reasons: stock.reasonTypes,
                  trendState: stock.trendState,
                  isInWatchlist: stock.isInWatchlist,
                  recentPrices: stock.recentPrices,
                  showLimitMarkers: showLimitMarkers,
                  onTap: () =>
                      context.push(AppRoutes.stockDetail(stock.symbol)),
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _addCondition() async {
    final condition = await ConditionEditorSheet.show(context);
    if (condition != null) {
      ref.read(customScreeningProvider.notifier).addCondition(condition);
    }
  }

  Future<void> _editCondition(int index, condition) async {
    final updated = await ConditionEditorSheet.show(
      context,
      initial: condition,
    );
    if (updated != null) {
      ref
          .read(customScreeningProvider.notifier)
          .updateCondition(index, updated);
    }
  }
}
