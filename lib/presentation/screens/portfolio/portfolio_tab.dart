import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:afterclose/presentation/providers/portfolio_provider.dart';
import 'package:afterclose/presentation/screens/portfolio/widgets/allocation_pie_chart.dart';
import 'package:afterclose/presentation/screens/portfolio/widgets/portfolio_summary_card.dart';
import 'package:afterclose/presentation/screens/portfolio/widgets/position_card.dart';
import 'package:afterclose/presentation/screens/portfolio/widgets/add_transaction_sheet.dart';

/// 投資組合 Tab（嵌入 Watchlist 頁面）
class PortfolioTab extends ConsumerStatefulWidget {
  const PortfolioTab({super.key});

  @override
  ConsumerState<PortfolioTab> createState() => _PortfolioTabState();
}

class _PortfolioTabState extends ConsumerState<PortfolioTab> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(portfolioProvider.notifier).loadPositions(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(portfolioProvider);
    final theme = Theme.of(context);

    if (state.isLoading && state.positions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.positions.isEmpty) {
      return _buildEmpty(theme);
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => ref.read(portfolioProvider.notifier).loadPositions(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            children: [
              // 總覽卡片
              PortfolioSummaryCard(summary: state.summary),
              const SizedBox(height: 16),

              // 配置圓餅圖
              if (state.allocationMap.isNotEmpty) ...[
                Semantics(
                  label: '投資組合配置圓餅圖，共 ${state.allocationMap.length} 檔持股',
                  image: true,
                  child: AllocationPieChart(allocationMap: state.allocationMap),
                ),
                const SizedBox(height: 20),
              ],

              // 持倉列表
              Row(
                children: [
                  Text(
                    'portfolio.positions'.tr(),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'portfolio.positionCount'.tr(
                      namedArgs: {
                        'count': state.summary.positionCount.toString(),
                      },
                    ),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              for (final position in state.positions) ...[
                PositionCard(
                  position: position,
                  onTap: () => context.push('/portfolio/${position.symbol}'),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),

        // FAB
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: _showAddTransaction,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: theme.colorScheme.outline.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'portfolio.noPositions'.tr(),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'portfolio.noPositionsHint'.tr(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _showAddTransaction,
            icon: const Icon(Icons.add),
            label: Text('portfolio.addTransaction'.tr()),
          ),
        ],
      ),
    );
  }

  void _showAddTransaction() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const AddTransactionSheet(),
    );
  }
}
