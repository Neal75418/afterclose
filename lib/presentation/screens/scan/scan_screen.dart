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
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(scanProvider.notifier).loadData();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Trigger loadMore when user scrolls near the bottom
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(scanProvider.notifier).loadMore();
    }
  }

  /// Show bottom sheet with grouped filters
  void _showFilterBottomSheet(
    BuildContext context,
    WidgetRef ref,
    ScanFilter currentFilter,
  ) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.4,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'scan.moreFilters'.tr(),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                // Filter groups
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: ScanFilterGroup.values
                        .where((group) => group != ScanFilterGroup.all)
                        .map((group) {
                          final filters = group.filters;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Group header
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 16,
                                  bottom: 8,
                                ),
                                child: Text(
                                  group.labelKey.tr(),
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              // Filter chips in wrap
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: filters.map((filter) {
                                  final isSelected = currentFilter == filter;
                                  return FilterChip(
                                    label: Text(filter.labelKey.tr()),
                                    selected: isSelected,
                                    onSelected: (_) {
                                      ref
                                          .read(scanProvider.notifier)
                                          .setFilter(filter);
                                      Navigator.pop(context);
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          );
                        })
                        .toList(),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
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
                      Text(sort.labelKey.tr()),
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
            // Filter chips - show quick filters + "More" button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // "All" chip
                  FilterChip(
                    label: Text(ScanFilter.all.labelKey.tr()),
                    labelStyle: TextStyle(
                      color: state.filter == ScanFilter.all
                          ? theme.colorScheme.onSecondaryContainer
                          : theme.colorScheme.onSurface,
                    ),
                    selected: state.filter == ScanFilter.all,
                    onSelected: (_) {
                      ref.read(scanProvider.notifier).setFilter(ScanFilter.all);
                    },
                  ),
                  const SizedBox(width: 8),
                  // Current selected filter (if not "All")
                  if (state.filter != ScanFilter.all)
                    FilterChip(
                      label: Text(state.filter.labelKey.tr()),
                      selected: true,
                      onSelected: (_) {
                        // Tapping again clears the filter
                        ref
                            .read(scanProvider.notifier)
                            .setFilter(ScanFilter.all);
                      },
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        ref
                            .read(scanProvider.notifier)
                            .setFilter(ScanFilter.all);
                      },
                    ),
                  if (state.filter != ScanFilter.all) const SizedBox(width: 8),
                  // "More Filters" button
                  ActionChip(
                    avatar: const Icon(Icons.filter_list, size: 18),
                    label: Text('scan.moreFilters'.tr()),
                    onPressed: () =>
                        _showFilterBottomSheet(context, ref, state.filter),
                  ),
                ],
              ),
            ),

            // Stock count (show loaded/total when paginating)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    state.hasMore
                        ? 'scan.stockCountLoaded'.tr(
                            namedArgs: {
                              'loaded': state.stocks.length.toString(),
                              'total': state.totalCount.toString(),
                            },
                          )
                        : 'scan.stockCount'.tr(
                            namedArgs: {
                              'count': state.stocks.length.toString(),
                            },
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
                      controller: _scrollController,
                      // Performance optimizations
                      cacheExtent:
                          500, // Pre-render more items for smoother scroll
                      addAutomaticKeepAlives: false, // Reduce memory usage
                      // +1 for loading indicator when loading more
                      itemCount: state.stocks.length + (state.hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Show loading indicator at the bottom
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
