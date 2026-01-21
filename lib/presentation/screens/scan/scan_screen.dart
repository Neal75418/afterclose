import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/presentation/providers/scan_provider.dart';
import 'package:afterclose/presentation/widgets/empty_state.dart';
import 'package:afterclose/presentation/widgets/shimmer_loading.dart';
import 'package:afterclose/presentation/widgets/stock_card.dart';
import 'package:afterclose/presentation/widgets/stock_preview_sheet.dart';
import 'package:afterclose/presentation/widgets/themed_refresh_indicator.dart';

/// Scan screen - shows all analyzed stocks with filters
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(scanProvider.notifier).loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scanProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('scan.title'.tr()),
        actions: [
          PopupMenuButton<ScanSort>(
            icon: const Icon(Icons.sort),
            tooltip: 'scan.sort'.tr(),
            initialValue: state.sort,
            onSelected: (sort) {
              ref.read(scanProvider.notifier).setSort(sort);
            },
            itemBuilder: (context) {
              return ScanSort.values.map((sort) {
                return PopupMenuItem(
                  value: sort,
                  child: Row(
                    children: [
                      if (state.sort == sort)
                        const Icon(Icons.check, size: 18)
                      else
                        const SizedBox(width: 18),
                      const SizedBox(width: 8),
                      Text(sort.label),
                    ],
                  ),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: ThemedRefreshIndicator(
        onRefresh: () => ref.read(scanProvider.notifier).loadData(),
        child: Column(
          children: [
            // Filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: ScanFilter.values.map((filter) {
                  final isSelected = state.filter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(filter.label),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? theme.colorScheme.onSecondaryContainer
                            : theme.colorScheme.onSurface,
                      ),
                      selected: isSelected,
                      onSelected: (_) {
                        ref.read(scanProvider.notifier).setFilter(filter);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            // Stock count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    'scan.stockCount'.tr(
                      namedArgs: {'count': state.stocks.length.toString()},
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // Stock list
            Expanded(
              child: state.isLoading
                  ? const StockListShimmer(itemCount: 8)
                  : state.error != null
                  ? EmptyStates.error(
                      message: state.error!,
                      onRetry: () => ref.read(scanProvider.notifier).loadData(),
                    )
                  : state.stocks.isEmpty
                  ? EmptyStates.noFilterResults(
                      onClearFilter: () {
                        ref
                            .read(scanProvider.notifier)
                            .setFilter(ScanFilter.all);
                      },
                    )
                  : ListView.builder(
                      // Performance optimizations
                      cacheExtent:
                          500, // Pre-render more items for smoother scroll
                      addAutomaticKeepAlives: false, // Reduce memory usage
                      itemCount: state.stocks.length,
                      itemBuilder: (context, index) {
                        final stock = state.stocks[index];
                        // RepaintBoundary isolates each card for better scroll performance
                        final card = RepaintBoundary(
                          child: Slidable(
                            key: ValueKey(stock.symbol),
                            // Left swipe → View details
                            startActionPane: ActionPane(
                              motion: const BehindMotion(),
                              extentRatio: 0.25,
                              children: [
                                SlidableAction(
                                  onPressed: (_) {
                                    HapticFeedback.lightImpact();
                                    context.push('/stock/${stock.symbol}');
                                  },
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  icon: Icons.visibility_outlined,
                                  label: 'scan.view'.tr(),
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(16),
                                    bottomRight: Radius.circular(16),
                                  ),
                                ),
                              ],
                            ),
                            // Right swipe → Toggle watchlist
                            endActionPane: ActionPane(
                              motion: const BehindMotion(),
                              extentRatio: 0.25,
                              children: [
                                SlidableAction(
                                  onPressed: (_) {
                                    HapticFeedback.lightImpact();
                                    ref
                                        .read(scanProvider.notifier)
                                        .toggleWatchlist(stock.symbol);
                                  },
                                  backgroundColor: stock.isInWatchlist
                                      ? Colors.red.shade400
                                      : Colors.amber,
                                  foregroundColor: Colors.white,
                                  icon: stock.isInWatchlist
                                      ? Icons.star_outline
                                      : Icons.star,
                                  label: stock.isInWatchlist
                                      ? 'scan.remove'.tr()
                                      : 'scan.favorite'.tr(),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    bottomLeft: Radius.circular(16),
                                  ),
                                ),
                              ],
                            ),
                            child: StockCard(
                              symbol: stock.symbol,
                              stockName: stock.stockName,
                              latestClose: stock.latestClose,
                              priceChange: stock.priceChange,
                              score: stock.score,
                              reasons: stock.reasons
                                  .map((r) => r.reasonType)
                                  .toList(),
                              trendState: stock.trendState,
                              isInWatchlist: stock.isInWatchlist,
                              recentPrices: stock.recentPrices,
                              onTap: () =>
                                  context.push('/stock/${stock.symbol}'),
                              onLongPress: () {
                                showStockPreviewSheet(
                                  context: context,
                                  data: StockPreviewData(
                                    symbol: stock.symbol,
                                    stockName: stock.stockName,
                                    latestClose: stock.latestClose,
                                    priceChange: stock.priceChange,
                                    score: stock.score,
                                    trendState: stock.trendState,
                                    reasons: stock.reasons
                                        .map((r) => r.reasonType)
                                        .toList(),
                                    isInWatchlist: stock.isInWatchlist,
                                  ),
                                  onViewDetails: () =>
                                      context.push('/stock/${stock.symbol}'),
                                  onToggleWatchlist: () {
                                    ref
                                        .read(scanProvider.notifier)
                                        .toggleWatchlist(stock.symbol);
                                  },
                                );
                              },
                              onWatchlistTap: () {
                                HapticFeedback.lightImpact();
                                ref
                                    .read(scanProvider.notifier)
                                    .toggleWatchlist(stock.symbol);
                              },
                            ),
                          ),
                        );

                        // Staggered entry animation for first 10 items
                        if (index < 10) {
                          return card
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
                        return card;
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
