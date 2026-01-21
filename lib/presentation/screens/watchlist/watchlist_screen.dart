import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:afterclose/core/theme/app_theme.dart';
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
          content: Text('watchlist.removed'.tr(namedArgs: {'symbol': symbol})),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          showCloseIcon: true,
          dismissDirection: DismissDirection.horizontal,
          action: SnackBarAction(
            label: 'watchlist.undo'.tr(),
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
        title: Text('watchlist.title'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddDialog,
            tooltip: 'watchlist.add'.tr(),
          ),
        ],
      ),
      body: ThemedRefreshIndicator(
        onRefresh: _onRefresh,
        child: state.isLoading
            ? const StockListShimmer(itemCount: 5)
            : state.error != null
            ? EmptyStates.error(message: state.error!, onRetry: _onRefresh)
            : state.items.isEmpty
            ? EmptyStates.emptyWatchlist(onAdd: _showAddDialog)
            : ListView.builder(
                // Performance optimizations
                cacheExtent: 500,
                addAutomaticKeepAlives: false,
                itemCount: state.items.length,
                itemBuilder: (context, index) {
                  final item = state.items[index];
                  final tile = RepaintBoundary(
                    child: _buildWatchlistTile(item),
                  );

                  // Staggered entry animation for first 10 items
                  if (index < 10) {
                    return tile
                        .animate()
                        .fadeIn(
                          delay: Duration(milliseconds: 50 * index),
                          duration: 400.ms,
                        )
                        .slideX(
                          begin: 0.05,
                          duration: 400.ms,
                          curve: Curves.easeOutQuart,
                        );
                  }
                  return tile;
                },
              ),
      ),
    );
  }

  Widget _buildWatchlistTile(WatchlistItemData item) {
    final theme = Theme.of(context);
    final priceColor = AppTheme.getPriceColor(item.priceChange);
    final isPositive = (item.priceChange ?? 0) >= 0;

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
              title: Text('watchlist.addDialog'.tr()),
              content: TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'watchlist.symbolLabel'.tr(),
                  hintText: 'watchlist.symbolHint'.tr(),
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
                  child: Text('common.cancel'.tr()),
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
                                  content: Text('watchlist.added'.tr(namedArgs: {'symbol': symbol})),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            } else {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('watchlist.notFound'.tr(namedArgs: {'symbol': symbol})),
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
                      : Text('common.add'.tr()),
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
