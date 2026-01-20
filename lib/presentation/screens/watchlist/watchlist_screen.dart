import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:afterclose/presentation/providers/watchlist_provider.dart';
import 'package:afterclose/presentation/widgets/empty_state.dart';
import 'package:afterclose/presentation/widgets/score_ring.dart';
import 'package:afterclose/presentation/widgets/shimmer_loading.dart';
import 'package:afterclose/presentation/widgets/themed_refresh_indicator.dart';

/// Watchlist screen - shows user's selected stocks
class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({super.key});

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen> {
  @override
  void initState() {
    super.initState();
    // Load data on first build
    Future.microtask(() => ref.read(watchlistProvider.notifier).loadData());
  }

  Future<void> _onRefresh() async {
    await ref.read(watchlistProvider.notifier).loadData();
  }

  Future<void> _removeFromWatchlist(String symbol) async {
    final notifier = ref.read(watchlistProvider.notifier);
    await notifier.removeStock(symbol);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已從自選移除 $symbol'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: '復原',
            onPressed: () async {
              await notifier.restoreStock(symbol);
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(watchlistProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('自選股票'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddDialog,
            tooltip: '新增股票',
          ),
        ],
      ),
      body: ThemedRefreshIndicator(
        onRefresh: _onRefresh,
        child: state.isLoading
            ? const StockListShimmer(itemCount: 5)
            : state.error != null
                ? EmptyStates.error(
                    message: state.error!,
                    onRetry: _onRefresh,
                  )
                : state.items.isEmpty
                    ? EmptyStates.emptyWatchlist(onAdd: _showAddDialog)
                    : ListView.builder(
                        // Performance optimizations
                        cacheExtent: 500,
                        addAutomaticKeepAlives: false,
                        itemCount: state.items.length,
                        itemBuilder: (context, index) {
                          final item = state.items[index];
                          return RepaintBoundary(
                            child: _buildWatchlistTile(item),
                          );
                        },
                      ),
      ),
    );
  }

  Widget _buildWatchlistTile(WatchlistItemData item) {
    final theme = Theme.of(context);
    final isPositive = (item.priceChange ?? 0) >= 0;
    final priceColor = isPositive ? Colors.red.shade700 : Colors.green.shade700;

    return Dismissible(
      key: Key(item.symbol),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        _removeFromWatchlist(item.symbol);
      },
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: item.hasSignal
                ? Colors.amber.withValues(alpha: 0.2)
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(item.statusIcon, style: const TextStyle(fontSize: 20)),
          ),
        ),
        title: Row(
          children: [
            Text(
              item.symbol,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (item.score != null && item.score! > 0) ...[
              const SizedBox(width: 8),
              ScoreRing(score: item.score!, size: ScoreRingSize.small),
            ],
          ],
        ),
        subtitle: item.stockName != null ? Text(item.stockName!) : null,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (item.latestClose != null)
              Text(
                item.latestClose!.toStringAsFixed(2),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            if (item.priceChange != null)
              Text(
                '${isPositive ? '+' : ''}${item.priceChange!.toStringAsFixed(2)}%',
                style: TextStyle(color: priceColor, fontSize: 12),
              ),
          ],
        ),
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/stock/${item.symbol}');
        },
      ),
    );
  }

  void _showAddDialog() {
    final controller = TextEditingController();
    // Capture the messenger before showing dialog
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        var isLoading = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('新增自選'),
              content: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: '股票代號',
                  hintText: '例如: 2330',
                ),
                autofocus: true,
                enabled: !isLoading,
                textCapitalization: TextCapitalization.characters,
              ),
              actions: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          controller.dispose();
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final symbol = controller.text.trim().toUpperCase();
                          if (symbol.isEmpty) return;

                          setDialogState(() => isLoading = true);

                          final notifier = ref.read(watchlistProvider.notifier);
                          final success = await notifier.addStock(symbol);

                          // Check if dialog is still mounted
                          if (!dialogContext.mounted) return;

                          controller.dispose();
                          Navigator.pop(dialogContext);

                          if (mounted) {
                            if (success) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('已加入 $symbol'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            } else {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('找不到股票 $symbol'),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('新增'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      // Fallback disposal if dialog is dismissed by tapping outside
      try {
        controller.dispose();
      } catch (_) {
        // Already disposed, ignore
      }
    });
  }
}
