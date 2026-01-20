import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:afterclose/presentation/providers/today_provider.dart';
import 'package:afterclose/presentation/widgets/stock_card.dart';

/// Today screen - shows daily recommendations and watchlist status
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  @override
  void initState() {
    super.initState();
    // Load data on first build
    Future.microtask(() {
      ref.read(todayProvider.notifier).loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(todayProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AfterClose'),
        actions: [
          if (state.isUpdating)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _runUpdate,
              tooltip: '更新資料',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(todayProvider.notifier).loadData(),
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.error != null
            ? _buildError(state.error!)
            : _buildContent(state),
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('載入失敗', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.read(todayProvider.notifier).loadData(),
              child: const Text('重試'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(TodayState state) {
    final theme = Theme.of(context);

    return CustomScrollView(
      slivers: [
        // Update progress banner
        if (state.isUpdating && state.updateProgress != null)
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              color: theme.colorScheme.primaryContainer,
              child: Column(
                children: [
                  Text(
                    state.updateProgress!.message,
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: state.updateProgress!.progress,
                  ),
                ],
              ),
            ),
          ),

        // Last update time
        if (state.lastUpdate != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                '最後更新: ${_formatDateTime(state.lastUpdate!)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),

        // Top 10 section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.trending_up, size: 20),
                const SizedBox(width: 8),
                Text(
                  '今日推薦 Top 10',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Recommendations
        if (state.recommendations.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '尚無今日推薦',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: _runUpdate,
                      child: const Text('立即更新'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverList.builder(
            itemCount: state.recommendations.length,
            itemBuilder: (context, index) {
              final rec = state.recommendations[index];
              return StockCard(
                symbol: rec.symbol,
                stockName: rec.stockName,
                latestClose: rec.latestClose,
                priceChange: rec.priceChange,
                score: rec.score,
                reasons: rec.reasons.map((r) => r.reasonType).toList(),
                trendState: rec.trendState,
                onTap: () => context.push('/stock/${rec.symbol}'),
              );
            },
          ),

        // Watchlist section
        if (state.watchlistStatus.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.star, size: 20, color: Colors.amber),
                  const SizedBox(width: 8),
                  Text(
                    '自選狀態',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverList.builder(
            itemCount: state.watchlistStatus.length,
            itemBuilder: (context, index) {
              final entry = state.watchlistStatus.entries.elementAt(index);
              final status = entry.value;
              return ListTile(
                leading: Text(
                  status.statusIcon,
                  style: const TextStyle(fontSize: 24),
                ),
                title: Row(
                  children: [
                    Text(
                      status.symbol,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    if (status.stockName != null)
                      Expanded(
                        child: Text(
                          status.stockName!,
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
                subtitle: status.hasSignal
                    ? Text(
                        '有訊號: ${status.signalType ?? "異常"}',
                        style: TextStyle(color: theme.colorScheme.primary),
                      )
                    : null,
                trailing: status.priceChange != null
                    ? Text(
                        '${status.priceChange! >= 0 ? '+' : ''}${status.priceChange!.toStringAsFixed(2)}%',
                        style: TextStyle(
                          color: status.priceChange! >= 0
                              ? Colors.red.shade700
                              : Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
                onTap: () => context.push('/stock/${status.symbol}'),
              );
            },
          ),
        ],

        // Bottom padding
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Future<void> _runUpdate() async {
    try {
      final result = await ref.read(todayProvider.notifier).runUpdate();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.summary),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('更新失敗: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
