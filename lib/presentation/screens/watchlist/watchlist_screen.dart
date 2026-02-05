import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:afterclose/presentation/providers/settings_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/core/utils/responsive_helper.dart';
import 'package:afterclose/presentation/providers/watchlist_provider.dart';
import 'package:afterclose/presentation/screens/portfolio/portfolio_tab.dart';
import 'package:afterclose/presentation/widgets/empty_state.dart';
import 'package:afterclose/presentation/widgets/shimmer_loading.dart';
import 'package:afterclose/presentation/widgets/stock_card.dart';
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
      onViewDetails: () => context.push('/stock/${item.symbol}'),
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
                  ref.read(watchlistProvider.notifier).setSearchQuery(value);
                },
              )
            : Text('watchlist.title'.tr()),
        actions: [
          // Calendar icon (both tabs)
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () {
              HapticFeedback.selectionClick();
              context.push('/calendar');
            },
            tooltip: 'calendar.title'.tr(),
          ),
          // Export button (both tabs)
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () => _exportCsv(isWatchlistTab),
            tooltip: isWatchlistTab
                ? 'export.exportWatchlist'.tr()
                : 'export.exportPortfolio'.tr(),
          ),
          if (isWatchlistTab) ...[
            // Search toggle
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              onPressed: _toggleSearch,
              tooltip: _isSearching
                  ? 'common.close'.tr()
                  : 'common.search'.tr(),
            ),
            // Group menu
            PopupMenuButton<WatchlistGroup>(
              icon: const Icon(Icons.workspaces_outlined),
              tooltip: 'watchlist.group'.tr(),
              initialValue: state.group,
              onSelected: (group) {
                ref.read(watchlistProvider.notifier).setGroup(group);
              },
              itemBuilder: (context) {
                return WatchlistGroup.values.map((group) {
                  return PopupMenuItem(
                    value: group,
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
                }).toList();
              },
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
                  context.push('/compare', extra: symbols);
                },
                tooltip: 'comparison.compare'.tr(),
              ),
            // Add button
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                HapticFeedback.selectionClick();
                _showAddDialog();
              },
              tooltip: 'watchlist.add'.tr(),
            ),
          ],
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
          ? EmptyStates.emptyWatchlist(onAdd: _showAddDialog)
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
                            borderRadius: BorderRadius.circular(12),
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
    switch (state.group) {
      case WatchlistGroup.none:
        return _buildFlatList(state.filteredItems);
      case WatchlistGroup.status:
        return _buildGroupedByStatusList(state);
      case WatchlistGroup.trend:
        return _buildGroupedByTrendList(state);
    }
  }

  Widget _buildFlatList(List<WatchlistItemData> items) {
    final columns = context.responsiveGridColumns;
    final useGrid = columns > 1;

    if (useGrid) {
      return _buildFlatGrid(items, columns);
    }

    return ListView.builder(
      cacheExtent: 500,
      addAutomaticKeepAlives: false,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildStockItem(item, index);
      },
    );
  }

  Widget _buildFlatGrid(List<WatchlistItemData> items, int columns) {
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
        return _buildStockItemForGrid(item, index);
      },
    );
  }

  Widget _buildGroupedByStatusList(WatchlistState state) {
    final grouped = state.groupedByStatus;

    return ListView(
      children: [
        for (final status in WatchlistStatus.values)
          if (grouped[status]!.isNotEmpty) ...[
            _GroupHeader(
              icon: status.icon,
              title: status.label,
              count: grouped[status]!.length,
            ),
            ...grouped[status]!.asMap().entries.map((entry) {
              return _buildStockItem(entry.value, entry.key);
            }),
          ],
      ],
    );
  }

  Widget _buildGroupedByTrendList(WatchlistState state) {
    final grouped = state.groupedByTrend;

    return ListView(
      children: [
        for (final trend in WatchlistTrend.values)
          if (grouped[trend]!.isNotEmpty) ...[
            _GroupHeader(
              icon: trend.icon,
              title: trend.label,
              count: grouped[trend]!.length,
            ),
            ...grouped[trend]!.asMap().entries.map((entry) {
              return _buildStockItem(entry.value, entry.key);
            }),
          ],
      ],
    );
  }

  Widget _buildStockItem(WatchlistItemData item, int index) {
    final card = RepaintBoundary(
      child: Slidable(
        key: ValueKey(item.symbol),
        // Left swipe → View details
        startActionPane: ActionPane(
          motion: const BehindMotion(),
          extentRatio: 0.25,
          children: [
            SlidableAction(
              onPressed: (_) {
                HapticFeedback.lightImpact();
                context.push('/stock/${item.symbol}');
              },
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              icon: Icons.visibility_outlined,
              label: 'watchlist.view'.tr(),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
          ],
        ),
        // Right swipe → Remove from watchlist
        endActionPane: ActionPane(
          motion: const BehindMotion(),
          extentRatio: 0.25,
          children: [
            SlidableAction(
              onPressed: (_) {
                HapticFeedback.mediumImpact();
                _removeFromWatchlist(item.symbol);
              },
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              icon: Icons.delete_outline,
              label: 'watchlist.remove'.tr(),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
          ],
        ),
        child: StockCard(
          symbol: item.symbol,
          stockName: item.stockName,
          market: item.market,
          latestClose: item.latestClose,
          priceChange: item.priceChange,
          score: item.score,
          reasons: item.reasons,
          trendState: item.trendState,
          isInWatchlist: true,
          recentPrices: item.recentPrices,
          warningType: item.warningType,
          showLimitMarkers: ref.watch(settingsProvider).limitAlerts,
          onTap: () => context.push('/stock/${item.symbol}'),
          onLongPress: () => _showStockPreview(item),
          onWatchlistTap: () {
            HapticFeedback.lightImpact();
            _removeFromWatchlist(item.symbol);
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
          .slideX(begin: 0.05, duration: 400.ms, curve: Curves.easeOutQuart);
    }
    return card;
  }

  /// Grid 佈局用的股票卡片（無 Slidable，改用長按選單）
  Widget _buildStockItemForGrid(WatchlistItemData item, int index) {
    final card = RepaintBoundary(
      child: StockCard(
        symbol: item.symbol,
        stockName: item.stockName,
        market: item.market,
        latestClose: item.latestClose,
        priceChange: item.priceChange,
        score: item.score,
        reasons: item.reasons,
        trendState: item.trendState,
        isInWatchlist: true,
        recentPrices: item.recentPrices,
        warningType: item.warningType,
        showLimitMarkers: ref.watch(settingsProvider).limitAlerts,
        onTap: () => context.push('/stock/${item.symbol}'),
        onLongPress: () => _showStockPreview(item),
        onWatchlistTap: () {
          HapticFeedback.lightImpact();
          _removeFromWatchlist(item.symbol);
        },
      ),
    );

    // Grid 動畫：前 20 筆項目使用交錯進場
    if (index < 20) {
      return card
          .animate()
          .fadeIn(
            delay: Duration(milliseconds: 30 * index),
            duration: 300.ms,
          )
          .scale(
            begin: const Offset(0.95, 0.95),
            duration: 300.ms,
            curve: Curves.easeOutQuart,
          );
    }
    return card;
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
                      : () => Navigator.pop(dialogContext),
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

                          Navigator.pop(dialogContext);

                          if (mounted) {
                            // 清除現有的 SnackBar，避免堆積
                            messenger.clearSnackBars();
                            if (success) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'watchlist.added'.tr(
                                      namedArgs: {'symbol': symbol},
                                    ),
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            } else {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'watchlist.notFound'.tr(
                                      namedArgs: {'symbol': symbol},
                                    ),
                                  ),
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
    ).then((_) => controller.dispose());
  }
}

// ==================================================
// Group Header
// ==================================================

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.icon,
    required this.title,
    required this.count,
  });

  final String icon;
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceContainerLow,
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
