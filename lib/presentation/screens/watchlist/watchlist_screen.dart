import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:afterclose/presentation/providers/settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:afterclose/core/constants/app_routes.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/core/utils/responsive_helper.dart';
import 'package:afterclose/presentation/providers/watchlist_provider.dart';
import 'package:afterclose/presentation/screens/portfolio/portfolio_tab.dart';
import 'package:afterclose/presentation/screens/watchlist/add_stock_dialog.dart';
import 'package:afterclose/presentation/screens/watchlist/watchlist_group_header.dart';
import 'package:afterclose/presentation/screens/watchlist/watchlist_stock_item.dart';
import 'package:afterclose/presentation/widgets/empty_state.dart';
import 'package:afterclose/presentation/widgets/shimmer_loading.dart';
import 'package:afterclose/presentation/widgets/stock_preview_sheet.dart';
import 'package:afterclose/presentation/widgets/themed_refresh_indicator.dart';
import 'package:afterclose/core/services/share_service.dart';
import 'package:afterclose/presentation/services/export_service.dart';
import 'package:afterclose/presentation/providers/portfolio_provider.dart';

/// Watchlist screen - shows user's selected stocks
class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({super.key});

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

enum _WatchlistTab { watchlist, portfolio }

class _WatchlistScreenState extends ConsumerState<WatchlistScreen> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _isSearching = false;
  _WatchlistTab _currentTab = _WatchlistTab.watchlist;

  @override
  void initState() {
    super.initState();
    // Load data on first build
    Future.microtask(() => ref.read(watchlistProvider.notifier).loadData());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await ref.read(watchlistProvider.notifier).loadData();
    // Haptic feedback on refresh complete
    HapticFeedback.mediumImpact();
  }

  Future<void> _removeFromWatchlist(String symbol) async {
    final notifier = ref.read(watchlistProvider.notifier);
    await notifier.removeStock(symbol);

    if (mounted) {
      final messenger = ScaffoldMessenger.of(context);
      // 清除現有的 SnackBar，避免堆積卡住 UI
      messenger.clearSnackBars();
      messenger.showSnackBar(
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

  void _showStockPreview(WatchlistItemData item) {
    showStockPreviewSheet(
      context: context,
      data: StockPreviewData(
        symbol: item.symbol,
        stockName: item.stockName,
        latestClose: item.latestClose,
        priceChange: item.priceChange,
        score: item.score,
        trendState: item.trendState,
        reasons: item.reasons,
        isInWatchlist: true,
      ),
      onViewDetails: () => context.push(AppRoutes.stockDetail(item.symbol)),
      onToggleWatchlist: () => _removeFromWatchlist(item.symbol),
    );
  }

  void _toggleSearch() {
    HapticFeedback.selectionClick();
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        ref.read(watchlistProvider.notifier).setSearchQuery('');
      }
    });
  }

  Future<void> _exportCsv(bool isWatchlist) async {
    const exportService = ExportService();
    const shareService = ShareService();

    try {
      if (isWatchlist) {
        final items = ref.read(watchlistProvider).filteredItems;
        final csv = exportService.watchlistToCsv(items);
        await shareService.shareCsv(csv, 'watchlist.csv');
      } else {
        final positions = ref.read(portfolioProvider).positions;
        final csv = exportService.portfolioToCsv(positions);
        await shareService.shareCsv(csv, 'portfolio.csv');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'export.shareFailed'.tr(namedArgs: {'error': e.toString()}),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(watchlistProvider);
    final theme = Theme.of(context);
    final isWatchlistTab = _currentTab == _WatchlistTab.watchlist;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'watchlist.searchHint'.tr(),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(
                    const Duration(milliseconds: 300),
                    () {
                      ref
                          .read(watchlistProvider.notifier)
                          .setSearchQuery(value);
                    },
                  );
                },
              )
            : Text('watchlist.title'.tr()),
        actions: [
          if (isWatchlistTab) ...[
            // Search toggle
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              onPressed: _toggleSearch,
              tooltip: _isSearching
                  ? 'common.close'.tr()
                  : 'common.search'.tr(),
            ),
            // Sort menu
            PopupMenuButton<WatchlistSort>(
              icon: const Icon(Icons.sort),
              tooltip: 'watchlist.sort'.tr(),
              initialValue: state.sort,
              onSelected: (sort) {
                ref.read(watchlistProvider.notifier).setSort(sort);
              },
              itemBuilder: (context) {
                return WatchlistSort.values.map((sort) {
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
            // Compare button
            if (state.filteredItems.length >= 2)
              IconButton(
                icon: const Icon(Icons.compare_arrows),
                onPressed: () {
                  final symbols = state.filteredItems
                      .take(4)
                      .map((e) => e.symbol)
                      .toList();
                  context.push(AppRoutes.compare, extra: symbols);
                },
                tooltip: 'comparison.compare'.tr(),
              ),
            // Add button
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                HapticFeedback.selectionClick();
                showAddStockDialog(context: context, ref: ref);
              },
              tooltip: 'watchlist.add'.tr(),
            ),
          ],
          // More menu (Calendar, Export, Group)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'calendar':
                  HapticFeedback.selectionClick();
                  context.push(AppRoutes.calendar);
                case 'export':
                  _exportCsv(isWatchlistTab);
                case 'group_none':
                  ref
                      .read(watchlistProvider.notifier)
                      .setGroup(WatchlistGroup.none);
                case 'group_status':
                  ref
                      .read(watchlistProvider.notifier)
                      .setGroup(WatchlistGroup.status);
                case 'group_trend':
                  ref
                      .read(watchlistProvider.notifier)
                      .setGroup(WatchlistGroup.trend);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'calendar',
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined, size: 20),
                    const SizedBox(width: 12),
                    Text('calendar.title'.tr()),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    const Icon(Icons.file_download_outlined, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      isWatchlistTab
                          ? 'export.exportWatchlist'.tr()
                          : 'export.exportPortfolio'.tr(),
                    ),
                  ],
                ),
              ),
              if (isWatchlistTab) ...[
                const PopupMenuDivider(),
                ...WatchlistGroup.values.map((group) {
                  final value = 'group_${group.name}';
                  return PopupMenuItem(
                    value: value,
                    child: Row(
                      children: [
                        if (state.group == group)
                          const Icon(Icons.check, size: 18)
                        else
                          const SizedBox(width: 18),
                        const SizedBox(width: 8),
                        Text(group.label),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // SegmentedButton for tab switching
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<_WatchlistTab>(
              segments: [
                ButtonSegment(
                  value: _WatchlistTab.watchlist,
                  label: Text('watchlist.title'.tr()),
                  icon: const Icon(Icons.star_outline, size: 18),
                ),
                ButtonSegment(
                  value: _WatchlistTab.portfolio,
                  label: Text('portfolio.title'.tr()),
                  icon: const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 18,
                  ),
                ),
              ],
              selected: {_currentTab},
              onSelectionChanged: (selected) {
                HapticFeedback.selectionClick();
                setState(() {
                  _currentTab = selected.first;
                  if (_isSearching) {
                    _isSearching = false;
                    _searchController.clear();
                    ref.read(watchlistProvider.notifier).setSearchQuery('');
                  }
                });
              },
            ),
          ),
          // Tab content
          Expanded(
            child: isWatchlistTab
                ? _buildWatchlistBody(state, theme)
                : const PortfolioTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildWatchlistBody(WatchlistState state, ThemeData theme) {
    return ThemedRefreshIndicator(
      onRefresh: _onRefresh,
      child: state.isLoading
          ? const StockListShimmer(itemCount: 5)
          : state.error != null
          ? EmptyStates.error(message: state.error!, onRetry: _onRefresh)
          : state.items.isEmpty
          ? EmptyStates.emptyWatchlist(
              onAdd: () => showAddStockDialog(context: context, ref: ref),
            )
          : Column(
              children: [
                // Stock count
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'watchlist.stockCount'.tr(
                          namedArgs: {
                            'count': state.filteredItems.length.toString(),
                          },
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (state.searchQuery.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(
                              DesignTokens.radiusLg,
                            ),
                          ),
                          child: Text(
                            'watchlist.searching'.tr(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Stock list
                Expanded(
                  child: state.filteredItems.isEmpty
                      ? Center(
                          child: Text(
                            'watchlist.noMatching'.tr(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : _buildListContent(state),
                ),
              ],
            ),
    );
  }

  Widget _buildListContent(WatchlistState state) {
    final showLimitMarkers = ref.watch(
      settingsProvider.select((s) => s.limitAlerts),
    );

    Widget list;
    switch (state.group) {
      case WatchlistGroup.none:
        list = _buildFlatList(state.filteredItems, showLimitMarkers);
      case WatchlistGroup.status:
        list = _buildGroupedByStatusList(state, showLimitMarkers);
      case WatchlistGroup.trend:
        list = _buildGroupedByTrendList(state, showLimitMarkers);
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: KeyedSubtree(key: ValueKey(state.group), child: list),
    );
  }

  Widget _buildFlatList(List<WatchlistItemData> items, bool showLimitMarkers) {
    final columns = context.responsiveGridColumns;
    final useGrid = columns > 1;

    if (useGrid) {
      return _buildFlatGrid(items, columns, showLimitMarkers);
    }

    return ListView.builder(
      cacheExtent: 500,
      addAutomaticKeepAlives: false,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return WatchlistStockItem(
          item: item,
          index: index,
          showLimitMarkers: showLimitMarkers,
          onView: () => context.push(AppRoutes.stockDetail(item.symbol)),
          onRemove: () => _removeFromWatchlist(item.symbol),
          onLongPress: () => _showStockPreview(item),
        );
      },
    );
  }

  Widget _buildFlatGrid(
    List<WatchlistItemData> items,
    int columns,
    bool showLimitMarkers,
  ) {
    final padding = context.responsiveHorizontalPadding;
    final spacing = context.responsiveCardSpacing;

    return GridView.builder(
      cacheExtent: 500,
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: spacing),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        mainAxisExtent: DesignTokens.stockCardHeight,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return WatchlistStockGridItem(
          item: item,
          index: index,
          showLimitMarkers: showLimitMarkers,
          onView: () => context.push(AppRoutes.stockDetail(item.symbol)),
          onRemove: () => _removeFromWatchlist(item.symbol),
          onLongPress: () => _showStockPreview(item),
        );
      },
    );
  }

  Widget _buildGroupedByStatusList(
    WatchlistState state,
    bool showLimitMarkers,
  ) {
    final grouped = state.groupedByStatus;

    return ListView(
      children: [
        for (final status in WatchlistStatus.values)
          if (grouped[status]!.isNotEmpty) ...[
            WatchlistGroupHeader(
              icon: status.icon,
              title: status.label,
              count: grouped[status]!.length,
            ),
            ...grouped[status]!.asMap().entries.map((entry) {
              return WatchlistStockItem(
                item: entry.value,
                index: entry.key,
                showLimitMarkers: showLimitMarkers,
                onView: () =>
                    context.push(AppRoutes.stockDetail(entry.value.symbol)),
                onRemove: () => _removeFromWatchlist(entry.value.symbol),
                onLongPress: () => _showStockPreview(entry.value),
              );
            }),
          ],
      ],
    );
  }

  Widget _buildGroupedByTrendList(WatchlistState state, bool showLimitMarkers) {
    final grouped = state.groupedByTrend;

    return ListView(
      children: [
        for (final trend in WatchlistTrend.values)
          if (grouped[trend]!.isNotEmpty) ...[
            WatchlistGroupHeader(
              icon: trend.icon,
              title: trend.label,
              count: grouped[trend]!.length,
            ),
            ...grouped[trend]!.asMap().entries.map((entry) {
              return WatchlistStockItem(
                item: entry.value,
                index: entry.key,
                showLimitMarkers: showLimitMarkers,
                onView: () =>
                    context.push(AppRoutes.stockDetail(entry.value.symbol)),
                onRemove: () => _removeFromWatchlist(entry.value.symbol),
                onLongPress: () => _showStockPreview(entry.value),
              );
            }),
          ],
      ],
    );
  }
}
