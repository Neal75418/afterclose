import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:afterclose/presentation/providers/settings_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import 'package:afterclose/core/constants/app_routes.dart';
import 'package:afterclose/core/constants/filter_metadata.dart';
import 'package:afterclose/presentation/widgets/common/drag_handle.dart';
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/core/utils/responsive_helper.dart';
import 'package:afterclose/presentation/providers/scan_provider.dart';
import 'package:afterclose/presentation/widgets/empty_state.dart';
import 'package:afterclose/presentation/widgets/shimmer_loading.dart';
import 'package:afterclose/presentation/widgets/stock_card.dart';
import 'package:afterclose/presentation/widgets/stock_preview_sheet.dart';
import 'package:afterclose/presentation/widgets/themed_refresh_indicator.dart';

/// 掃描畫面 - 顯示所有已分析股票與篩選功能
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

  /// 當使用者捲動接近底部時觸發載入更多
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(scanProvider.notifier).loadMore();
    }
  }

  /// 建立含有篩選條件元資料的空狀態 Widget
  Widget _buildEmptyState(ScanFilter filter, WidgetRef ref) {
    // 對於「全部」篩選，使用簡單的空狀態
    if (filter == ScanFilter.all) {
      return EmptyStates.noFilterResults(
        onClearFilter: null, // 已顯示全部時無需清除
      );
    }

    // 取得篩選條件元資料
    final metadata = filter.metadata;

    // 翻譯資料需求標籤
    final dataReqLabels = metadata.dataRequirements
        .map((req) => req.labelKey.tr())
        .toList();

    return EmptyStates.noFilterResultsWithMeta(
      filterName: filter.labelKey.tr(),
      conditionDescription: metadata.conditionKey.tr(),
      dataRequirements: dataReqLabels,
      thresholdInfo: metadata.thresholdInfo,
      totalScanned: ref.watch(scanProvider).totalAnalyzedCount,
      dataDate: ref.watch(scanProvider).dataDate,
      onClearFilter: () {
        ref.read(scanProvider.notifier).setFilter(ScanFilter.all);
      },
    );
  }

  /// 顯示分組篩選條件的底部選單
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
                // 拖曳把手
                const DragHandle(),
                // 標題
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'scan.moreFilters'.tr(),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                // 篩選群組
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      MediaQuery.of(context).padding.bottom + 40,
                    ),
                    children: ScanFilterGroup.values
                        .where((group) => group != ScanFilterGroup.all)
                        .map((group) {
                          final filters = group.filters;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 群組標題
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
                              // 篩選標籤
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: filters.map((filter) {
                                  final isSelected = currentFilter == filter;
                                  return FilterChip(
                                    label: Text(filter.labelKey.tr()),
                                    selected: isSelected,
                                    onSelected: (_) {
                                      HapticFeedback.selectionClick();
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

    return Scaffold(
      appBar: _buildAppBar(context, state),
      body: ThemedRefreshIndicator(
        onRefresh: () => ref.read(scanProvider.notifier).loadData(),
        child: Column(
          children: [
            _buildFilterChips(context, state),
            _buildStockCount(context, state),
            _buildStockList(context, state),
          ],
        ),
      ),
    );
  }

  /// AppBar：標題 + 自訂篩選 + 排序選單
  PreferredSizeWidget _buildAppBar(BuildContext context, ScanState state) {
    return AppBar(
      title: Text('scan.title'.tr()),
      actions: [
        IconButton(
          icon: const Icon(Icons.tune),
          tooltip: 'customScreening.title'.tr(),
          onPressed: () => context.push(AppRoutes.customScreening),
        ),
        PopupMenuButton<ScanSort>(
          icon: const Icon(Icons.sort),
          tooltip: 'scan.sort'.tr(),
          initialValue: state.sort,
          onSelected: (sort) {
            HapticFeedback.selectionClick();
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
    );
  }

  /// 篩選標籤列：全部 / 目前篩選 / 產業 / 更多篩選
  Widget _buildFilterChips(BuildContext context, ScanState state) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // 「全部」標籤
          FilterChip(
            label: Text(ScanFilter.all.labelKey.tr()),
            labelStyle: TextStyle(
              color: state.filter == ScanFilter.all
                  ? theme.colorScheme.onSecondaryContainer
                  : theme.colorScheme.onSurface,
            ),
            selected: state.filter == ScanFilter.all,
            onSelected: (_) {
              HapticFeedback.selectionClick();
              ref.read(scanProvider.notifier).setFilter(ScanFilter.all);
            },
          ),
          const SizedBox(width: 8),
          // 目前選中的篩選條件（若非「全部」）
          if (state.filter != ScanFilter.all)
            FilterChip(
              label: Text(state.filter.labelKey.tr()),
              selected: true,
              onSelected: (_) {
                HapticFeedback.selectionClick();
                ref.read(scanProvider.notifier).setFilter(ScanFilter.all);
              },
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () {
                HapticFeedback.selectionClick();
                ref.read(scanProvider.notifier).setFilter(ScanFilter.all);
              },
            ),
          if (state.filter != ScanFilter.all) const SizedBox(width: 8),
          // 產業篩選
          if (state.industries.isNotEmpty)
            _IndustryFilterChip(
              industries: state.industries,
              selected: state.industryFilter,
              onSelected: (industry) {
                ref.read(scanProvider.notifier).setIndustryFilter(industry);
              },
            ),
          if (state.industries.isNotEmpty) const SizedBox(width: 8),
          // 「更多篩選」按鈕
          ActionChip(
            avatar: const Icon(Icons.filter_list, size: 18),
            label: Text('scan.moreFilters'.tr()),
            onPressed: () => _showFilterBottomSheet(context, ref, state.filter),
          ),
        ],
      ),
    );
  }

  /// 股票數量列（分頁時顯示已載入/總數）
  Widget _buildStockCount(BuildContext context, ScanState state) {
    final theme = Theme.of(context);

    return Semantics(
      liveRegion: true,
      child: Padding(
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
                      namedArgs: {'count': state.stocks.length.toString()},
                    ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 股票清單：載入中 / 錯誤 / 空狀態 / 列表或網格
  Widget _buildStockList(BuildContext context, ScanState state) {
    if (state.isLoading) {
      return const Expanded(child: StockListShimmer(itemCount: 8));
    }
    if (state.error != null) {
      return Expanded(
        child: EmptyStates.error(
          message: state.error!,
          onRetry: () => ref.read(scanProvider.notifier).loadData(),
        ),
      );
    }
    if (state.stocks.isEmpty) {
      return Expanded(child: _buildEmptyState(state.filter, ref));
    }

    // 響應式佈局：平板/桌面使用 GridView
    final columns = context.responsiveGridColumns;
    final useGrid = columns > 1;

    if (useGrid) {
      return Expanded(child: _buildStockGrid(context, state, columns));
    }

    return Expanded(child: _buildStockListView(context, state));
  }

  /// 手機佈局：ListView
  Widget _buildStockListView(BuildContext context, ScanState state) {
    final showLimitMarkers = ref.watch(
      settingsProvider.select((s) => s.limitAlerts),
    );
    return ListView.builder(
      controller: _scrollController,
      cacheExtent: 500,
      addAutomaticKeepAlives: false,
      itemCount: state.stocks.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        // 在底部顯示載入指示器
        if (index == state.stocks.length) {
          return _buildLoadingIndicator(state);
        }
        return _buildStockCard(
          context,
          state.stocks[index],
          index,
          showLimitMarkers,
        );
      },
    );
  }

  /// 平板/桌面佈局：GridView
  Widget _buildStockGrid(BuildContext context, ScanState state, int columns) {
    final showLimitMarkers = ref.watch(
      settingsProvider.select((s) => s.limitAlerts),
    );
    final padding = context.responsiveHorizontalPadding;
    final spacing = context.responsiveCardSpacing;

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
      itemCount: state.stocks.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        // 在底部顯示載入指示器
        if (index == state.stocks.length) {
          return _buildLoadingIndicator(state);
        }
        return _buildStockCardForGrid(
          context,
          state.stocks[index],
          index,
          showLimitMarkers,
        );
      },
    );
  }

  /// 載入指示器
  Widget _buildLoadingIndicator(ScanState state) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: state.isLoadingMore
            ? const CircularProgressIndicator()
            : const SizedBox.shrink(),
      ),
    );
  }

  /// 單張股票卡片：Slidable 手勢 + 動畫
  Widget _buildStockCard(
    BuildContext context,
    ScanStockItem stock,
    int index,
    bool showLimitMarkers,
  ) {
    final card = RepaintBoundary(
      child: Slidable(
        key: ValueKey(stock.symbol),
        // 向左滑動 → 檢視詳情
        startActionPane: ActionPane(
          motion: const BehindMotion(),
          extentRatio: 0.25,
          children: [
            SlidableAction(
              onPressed: (_) {
                HapticFeedback.lightImpact();
                context.push(AppRoutes.stockDetail(stock.symbol));
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
        // 向右滑動 → 切換自選
        endActionPane: ActionPane(
          motion: const BehindMotion(),
          extentRatio: 0.25,
          children: [
            SlidableAction(
              onPressed: (_) {
                HapticFeedback.lightImpact();
                ref.read(scanProvider.notifier).toggleWatchlist(stock.symbol);
              },
              backgroundColor: stock.isInWatchlist
                  ? Colors.red.shade400
                  : Colors.amber,
              foregroundColor: Colors.white,
              icon: stock.isInWatchlist ? Icons.star_outline : Icons.star,
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
          market: stock.market,
          latestClose: stock.latestClose,
          priceChange: stock.priceChange,
          score: stock.score,
          reasons: stock.reasonTypes,
          trendState: stock.trendState,
          isInWatchlist: stock.isInWatchlist,
          recentPrices: stock.recentPrices,
          showLimitMarkers: showLimitMarkers,
          onTap: () => context.push(AppRoutes.stockDetail(stock.symbol)),
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
                reasons: stock.reasonTypes,
                isInWatchlist: stock.isInWatchlist,
              ),
              onViewDetails: () =>
                  context.push(AppRoutes.stockDetail(stock.symbol)),
              onToggleWatchlist: () {
                ref.read(scanProvider.notifier).toggleWatchlist(stock.symbol);
              },
            );
          },
          onWatchlistTap: () {
            HapticFeedback.lightImpact();
            ref.read(scanProvider.notifier).toggleWatchlist(stock.symbol);
          },
        ),
      ),
    );

    // 前 10 筆項目使用交錯進場動畫
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

  /// Grid 佈局用的股票卡片（無 Slidable，改用 PopupMenu）
  Widget _buildStockCardForGrid(
    BuildContext context,
    ScanStockItem stock,
    int index,
    bool showLimitMarkers,
  ) {
    final card = RepaintBoundary(
      child: StockCard(
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
        onTap: () => context.push(AppRoutes.stockDetail(stock.symbol)),
        onLongPress: () => _showStockContextMenu(context, stock),
        onWatchlistTap: () {
          HapticFeedback.lightImpact();
          ref.read(scanProvider.notifier).toggleWatchlist(stock.symbol);
        },
      ),
    );

    // 前 20 筆項目使用交錯進場動畫（Grid 顯示更多）
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

  /// 顯示股票操作選單（用於 Grid 佈局）
  void _showStockContextMenu(BuildContext context, ScanStockItem stock) {
    showStockPreviewSheet(
      context: context,
      data: StockPreviewData(
        symbol: stock.symbol,
        stockName: stock.stockName,
        latestClose: stock.latestClose,
        priceChange: stock.priceChange,
        score: stock.score,
        trendState: stock.trendState,
        reasons: stock.reasonTypes,
        isInWatchlist: stock.isInWatchlist,
      ),
      onViewDetails: () => context.push(AppRoutes.stockDetail(stock.symbol)),
      onToggleWatchlist: () {
        ref.read(scanProvider.notifier).toggleWatchlist(stock.symbol);
      },
    );
  }
}

/// 產業篩選 Chip — 點擊展開下拉選單
class _IndustryFilterChip extends StatelessWidget {
  const _IndustryFilterChip({
    required this.industries,
    required this.selected,
    required this.onSelected,
  });

  final List<String> industries;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSelection = selected != null;

    return FilterChip(
      avatar: hasSelection
          ? null
          : const Icon(Icons.factory_outlined, size: 16),
      label: Text(hasSelection ? selected! : 'scan.industry'.tr()),
      selected: hasSelection,
      onSelected: (_) => _showIndustryPicker(context, theme),
      deleteIcon: hasSelection ? const Icon(Icons.close, size: 16) : null,
      onDeleted: hasSelection ? () => onSelected(null) : null,
    );
  }

  void _showIndustryPicker(BuildContext context, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // 拖曳把手
                const DragHandle(),
                // 標題
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        'scan.selectIndustry'.tr(),
                        style: theme.textTheme.titleLarge,
                      ),
                      const Spacer(),
                      if (selected != null)
                        TextButton(
                          onPressed: () {
                            onSelected(null);
                            Navigator.pop(context);
                          },
                          child: Text('scan.clearIndustry'.tr()),
                        ),
                    ],
                  ),
                ),
                // 產業列表
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: industries.length,
                    itemBuilder: (context, index) {
                      final industry = industries[index];
                      final isSelected = industry == selected;
                      return ListTile(
                        title: Text(industry),
                        trailing: isSelected
                            ? Icon(
                                Icons.check,
                                color: theme.colorScheme.primary,
                              )
                            : null,
                        selected: isSelected,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onSelected(isSelected ? null : industry);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
