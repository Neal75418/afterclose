import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:afterclose/core/constants/animations.dart';
import 'package:afterclose/core/constants/api_config.dart';
import 'package:afterclose/core/constants/app_routes.dart';
import 'package:afterclose/core/utils/error_display.dart';
import 'package:afterclose/core/constants/ui_constants.dart';
import 'package:afterclose/core/services/share_service.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/core/utils/responsive_helper.dart';
import 'package:afterclose/presentation/providers/portfolio_provider.dart';
import 'package:afterclose/presentation/providers/settings_provider.dart';
import 'package:afterclose/presentation/providers/watchlist_provider.dart';
import 'package:afterclose/presentation/screens/watchlist/add_stock_dialog.dart';
import 'package:afterclose/presentation/screens/watchlist/watchlist_group_header.dart';
import 'package:afterclose/presentation/screens/watchlist/watchlist_stock_item.dart';
import 'package:afterclose/presentation/services/export_service.dart';
import 'package:afterclose/presentation/widgets/empty_state.dart';
import 'package:afterclose/presentation/widgets/shimmer_loading.dart';
import 'package:afterclose/presentation/widgets/stock_preview_sheet.dart';
import 'package:afterclose/presentation/widgets/themed_refresh_indicator.dart';

/// Watchlist screen - shows user's selected stocks
class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({super.key});

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _searchDebounce;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    // 首次建構時載入資料
    Future.microtask(() => ref.read(watchlistProvider.notifier).loadData());
    // 加入滾動監聽器（無限滾動）
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// 當使用者捲動接近底部時觸發載入更多
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent -
            UiConstants.infiniteScrollThresholdPx) {
      ref.read(watchlistProvider.notifier).loadMore();
    }
  }

  Future<void> _onRefresh() async {
    await ref.read(watchlistProvider.notifier).loadData();
    // 刷新完成時觸覺回饋
    HapticFeedback.mediumImpact();
  }

  Future<void> _removeFromWatchlist(String symbol) async {
    final notifier = ref.read(watchlistProvider.notifier);
    final success = await notifier.removeStock(symbol);

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    if (!success) {
      final watchlistState = ref.read(watchlistProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(watchlistState.error ?? 'watchlist.removeFailed'.tr()),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text('watchlist.removed'.tr(namedArgs: {'symbol': symbol})),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: ApiConfig.longMessageDurationSec),
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
              'export.shareFailed'.tr(
                namedArgs: {'error': ErrorDisplay.message(e)},
              ),
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

    return Scaffold(
      appBar: _buildAppBar(state),
      body: _buildWatchlistBody(state, theme),
    );
  }

  /// AppBar：搜尋欄 + 排序/比較/新增/更多選單
  PreferredSizeWidget _buildAppBar(WatchlistState state) {
    return AppBar(
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
                _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                  ref.read(watchlistProvider.notifier).setSearchQuery(value);
                });
              },
            )
          : Text('watchlist.title'.tr()),
      actions: [
        IconButton(
          icon: Icon(_isSearching ? Icons.close : Icons.search),
          onPressed: _toggleSearch,
          tooltip: _isSearching ? 'common.close'.tr() : 'common.search'.tr(),
        ),
        _buildSortMenu(state),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () {
            HapticFeedback.selectionClick();
            showAddStockDialog(context: context, ref: ref);
          },
          tooltip: 'watchlist.add'.tr(),
        ),
        _buildMoreMenu(state),
      ],
    );
  }

  /// 排序選單
  Widget _buildSortMenu(WatchlistState state) {
    return PopupMenuButton<WatchlistSort>(
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
                const SizedBox(width: DesignTokens.spacing8),
                Text(sort.label),
              ],
            ),
          );
        }).toList();
      },
    );
  }

  /// 更多選單（行事曆、匯出、分組）
  Widget _buildMoreMenu(WatchlistState state) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: 'scan.more'.tr(),
      onSelected: (value) {
        switch (value) {
          case 'compare':
            HapticFeedback.selectionClick();
            final symbols = state.filteredItems
                .take(4)
                .map((e) => e.symbol)
                .toList();
            context.push(AppRoutes.compare, extra: symbols);
          case 'portfolio':
            HapticFeedback.selectionClick();
            context.push(AppRoutes.portfolio);
          case 'calendar':
            HapticFeedback.selectionClick();
            context.push(AppRoutes.calendar);
          case 'export':
            _exportCsv(true);
          case 'group_none':
            ref.read(watchlistProvider.notifier).setGroup(WatchlistGroup.none);
          case 'group_status':
            ref
                .read(watchlistProvider.notifier)
                .setGroup(WatchlistGroup.status);
          case 'group_trend':
            ref.read(watchlistProvider.notifier).setGroup(WatchlistGroup.trend);
        }
      },
      itemBuilder: (context) => [
        if (state.filteredItems.length >= 2)
          PopupMenuItem(
            value: 'compare',
            child: Row(
              children: [
                const Icon(Icons.compare_arrows, size: 20),
                const SizedBox(width: DesignTokens.spacing12),
                Text('comparison.compare'.tr()),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'portfolio',
          child: Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined, size: 20),
              const SizedBox(width: DesignTokens.spacing12),
              Text('portfolio.title'.tr()),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'calendar',
          child: Row(
            children: [
              const Icon(Icons.calendar_month_outlined, size: 20),
              const SizedBox(width: DesignTokens.spacing12),
              Text('calendar.title'.tr()),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'export',
          child: Row(
            children: [
              const Icon(Icons.file_download_outlined, size: 20),
              const SizedBox(width: DesignTokens.spacing12),
              Text('export.exportWatchlist'.tr()),
            ],
          ),
        ),
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
                const SizedBox(width: DesignTokens.spacing8),
                Text(group.label),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildWatchlistBody(WatchlistState state, ThemeData theme) {
    return ThemedRefreshIndicator(
      onRefresh: _onRefresh,
      child: state.isLoading && state.items.isEmpty
          ? const StockListShimmer(itemCount: 5)
          : state.error != null && state.items.isEmpty
          ? ErrorDisplay.isNetworkError(state.error!)
                ? EmptyStates.networkError(onRetry: _onRefresh)
                : EmptyStates.error(message: state.error!, onRetry: _onRefresh)
          : state.items.isEmpty
          ? EmptyStates.emptyWatchlist(
              onAdd: () => showAddStockDialog(context: context, ref: ref),
            )
          : Column(
              children: [
                // Refresh 失敗時顯示 MaterialBanner
                if (state.error != null)
                  MaterialBanner(
                    content: Text(state.error!),
                    leading: Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.error,
                    ),
                    actions: [
                      TextButton(
                        onPressed: _onRefresh,
                        child: Text('common.retry'.tr()),
                      ),
                      TextButton(
                        onPressed: () =>
                            ref.read(watchlistProvider.notifier).clearError(),
                        child: Text('common.dismiss'.tr()),
                      ),
                    ],
                  ),
                // 股票數量
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
                        const SizedBox(width: DesignTokens.spacing8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DesignTokens.spacing8,
                            vertical: DesignTokens.spacing2,
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
                // 股票列表
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
        list = _buildFlatList(state, showLimitMarkers);
      case WatchlistGroup.status:
        list = _buildGroupedList(
          groupValues: WatchlistStatus.values,
          grouped: state.groupedByStatus,
          getIcon: (s) => s.icon,
          getLabel: (s) => s.label,
          showLimitMarkers: showLimitMarkers,
        );
      case WatchlistGroup.trend:
        list = _buildGroupedList(
          groupValues: WatchlistTrend.values,
          grouped: state.groupedByTrend,
          getIcon: (t) => t.icon,
          getLabel: (t) => t.label,
          showLimitMarkers: showLimitMarkers,
        );
    }

    return AnimatedSwitcher(
      duration: AnimDurations.normal,
      child: KeyedSubtree(key: ValueKey(state.group), child: list),
    );
  }

  Widget _buildFlatList(WatchlistState state, bool showLimitMarkers) {
    final columns = context.responsiveGridColumns;
    final useGrid = columns > 1;

    if (useGrid) {
      return _buildFlatGrid(state.displayedItems, columns, showLimitMarkers);
    }

    final items = state.displayedItems;
    return ListView.builder(
      controller: _scrollController,
      cacheExtent: 500,
      addAutomaticKeepAlives: false,
      itemCount: items.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        // 載入指示器
        if (index == items.length) {
          return _buildLoadingIndicator(state);
        }

        final item = items[index];
        return RepaintBoundary(
          child: WatchlistStockItem(
            item: item,
            index: index,
            showLimitMarkers: showLimitMarkers,
            onView: () => context.push(AppRoutes.stockDetail(item.symbol)),
            onRemove: () => _removeFromWatchlist(item.symbol),
            onLongPress: () => _showStockPreview(item),
          ),
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

    final state = ref.read(watchlistProvider);
    return GridView.builder(
      controller: _scrollController,
      cacheExtent: 500,
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: spacing),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        mainAxisExtent: DesignTokens.stockCardHeight,
      ),
      itemCount: items.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == items.length) {
          return _buildLoadingIndicator(state);
        }
        final item = items[index];
        return RepaintBoundary(
          child: WatchlistStockGridItem(
            item: item,
            index: index,
            showLimitMarkers: showLimitMarkers,
            onView: () => context.push(AppRoutes.stockDetail(item.symbol)),
            onRemove: () => _removeFromWatchlist(item.symbol),
            onLongPress: () => _showStockPreview(item),
          ),
        );
      },
    );
  }

  /// 載入指示器
  Widget _buildLoadingIndicator(WatchlistState state) {
    return Padding(
      padding: const EdgeInsets.all(DesignTokens.spacing16),
      child: Center(
        child: state.isLoadingMore
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildGroupedList<T extends Enum>({
    required List<T> groupValues,
    required Map<T, List<WatchlistItemData>> grouped,
    required String Function(T) getIcon,
    required String Function(T) getLabel,
    required bool showLimitMarkers,
  }) {
    return CustomScrollView(
      slivers: [
        for (final group in groupValues)
          if (grouped[group]!.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: WatchlistGroupHeader(
                icon: getIcon(group),
                title: getLabel(group),
                count: grouped[group]!.length,
              ),
            ),
            SliverList.builder(
              itemCount: grouped[group]!.length,
              itemBuilder: (_, i) {
                final item = grouped[group]![i];
                return WatchlistStockItem(
                  item: item,
                  index: i,
                  showLimitMarkers: showLimitMarkers,
                  onView: () =>
                      context.push(AppRoutes.stockDetail(item.symbol)),
                  onRemove: () => _removeFromWatchlist(item.symbol),
                  onLongPress: () => _showStockPreview(item),
                );
              },
            ),
          ],
      ],
    );
  }
}
