import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import 'package:afterclose/core/constants/filter_metadata.dart';
import 'package:afterclose/core/theme/app_theme.dart';
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
            // 篩選標籤 - 顯示快速篩選與「更多」按鈕
            Padding(
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
                        // 再次點擊清除篩選
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
                  // 「更多篩選」按鈕
                  ActionChip(
                    avatar: const Icon(Icons.filter_list, size: 18),
                    label: Text('scan.moreFilters'.tr()),
                    onPressed: () =>
                        _showFilterBottomSheet(context, ref, state.filter),
                  ),
                ],
              ),
            ),

            // 股票數量（分頁時顯示已載入/總數）
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

            // 股票清單
            Expanded(
              child: state.isLoading
                  ? const StockListShimmer(itemCount: 8)
                  : state.error != null
                  ? EmptyStates.error(
                      message: state.error!,
                      onRetry: () => ref.read(scanProvider.notifier).loadData(),
                    )
                  : state.stocks.isEmpty
                  ? _buildEmptyState(state.filter, ref)
                  : ListView.builder(
                      controller: _scrollController,
                      // 效能優化設定
                      cacheExtent: 500, // 預渲染更多項目以獲得更流暢的捲動
                      addAutomaticKeepAlives: false, // 減少記憶體使用
                      // 載入更多時項目數 +1 用於顯示載入指示器
                      itemCount: state.stocks.length + (state.hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        // 在底部顯示載入指示器
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
                        // RepaintBoundary 隔離每張卡片以提升捲動效能
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
                            // 向右滑動 → 切換自選
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
                              market: stock.market,
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

                        // 前 10 筆項目使用交錯進場動畫
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
