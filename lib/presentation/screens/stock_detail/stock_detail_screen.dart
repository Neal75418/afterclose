import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:afterclose/core/constants/app_routes.dart';
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/core/utils/error_display.dart';
import 'package:afterclose/presentation/providers/pinned_thesis_provider.dart';
import 'package:afterclose/presentation/providers/stock_browsing_context_provider.dart';
import 'package:afterclose/presentation/providers/stock_detail_provider.dart';
import 'package:afterclose/presentation/widgets/stock_nav_bar.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/alerts_tab.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/chip_tab.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/fundamentals_tab.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/insider_tab.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical_tab.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/ai_summary_card.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/stock_detail_header.dart';
import 'package:afterclose/presentation/widgets/empty_state.dart';
import 'package:afterclose/presentation/widgets/frosted_bar.dart';
import 'package:afterclose/presentation/widgets/shimmer_loading.dart';

/// 個股詳情畫面 - 以分頁顯示完整股票資訊
class StockDetailScreen extends ConsumerStatefulWidget {
  const StockDetailScreen({super.key, required this.symbol});

  final String symbol;

  @override
  ConsumerState<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends ConsumerState<StockDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    Future.microtask(() {
      final notifier = ref.read(stockDetailProvider(widget.symbol).notifier);
      notifier.loadData();
      notifier.loadFundamentals();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 只 watch scaffold 需要的欄位，避免 loading flag 變動觸發全頁 rebuild
    final provider = stockDetailProvider(widget.symbol);
    final isLoading = ref.watch(provider.select((s) => s.loading.isLoading));
    final error = ref.watch(provider.select((s) => s.error));
    final stockName = ref.watch(provider.select((s) => s.stockName));
    final isInWatchlist = ref.watch(provider.select((s) => s.isInWatchlist));
    final priceChangeRaw = ref.watch(provider.select((s) => s.priceChange));
    final theme = Theme.of(context);

    // 依漲跌幅動態漸層
    final priceChange = priceChangeRaw ?? 0;
    final isPositive = priceChange > 0;
    final isNegative = priceChange < 0;

    final bgGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        if (isPositive)
          AppTheme.upColor.withValues(alpha: 0.15)
        else if (isNegative)
          AppTheme.downColor.withValues(alpha: 0.15)
        else
          theme.colorScheme.surface,
        theme.colorScheme.surface,
        theme.colorScheme.surface,
      ],
      stops: const [0.0, 0.3, 1.0],
    );

    return Scaffold(
      // 巡檢導航列：從清單（自選/今日/掃描…）進入時提供上一檔/下一檔，
      // pushReplacement 換股 → 返回鍵仍回到來源清單。搜尋/深連結進入
      // （不在瀏覽脈絡中）時 neighbors 為 null、整列不顯示。
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final neighbors = browsingNeighbors(
            ref.watch(stockBrowsingContextProvider),
            widget.symbol,
          );
          if (neighbors == null) return const SizedBox.shrink();
          return StockNavBar(
            prev: neighbors.prev,
            next: neighbors.next,
            position: neighbors.position,
            total: neighbors.total,
            onNavigate: (target) =>
                context.pushReplacement(AppRoutes.stockDetail(target)),
          );
        },
      ),
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: isLoading
            ? const SafeArea(child: StockDetailShimmer())
            : error != null
            ? SafeArea(
                child: ErrorDisplay.isNetworkError(error)
                    ? EmptyStates.networkError(
                        onRetry: () => ref
                            .read(stockDetailProvider(widget.symbol).notifier)
                            .loadData(),
                      )
                    : EmptyStates.error(
                        message: error,
                        onRetry: () => ref
                            .read(stockDetailProvider(widget.symbol).notifier)
                            .loadData(),
                      ),
              )
            : NestedScrollView(
                headerSliverBuilder: (context, innerBoxScrolled) => [
                  // App Bar（毛玻璃：blur 下方內容，半透質感又不會疊影穿透）
                  SliverAppBar(
                    pinned: true,
                    floating: true,
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    flexibleSpace: const FrostedBackground(),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.symbol,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (stockName != null)
                          Text(
                            stockName,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    actions: [
                      // 釘選論點（出場層 Phase 2）：mode 由 dominant 規則推斷
                      Consumer(
                        builder: (context, ref, _) {
                          final pinned = ref.watch(
                            pinnedThesisProvider.select(
                              (s) => s.value?.isPinned(widget.symbol) ?? false,
                            ),
                          );
                          return IconButton(
                            tooltip: 'thesis.pinTooltip'.tr(),
                            icon: Icon(
                              pinned ? Icons.push_pin : Icons.push_pin_outlined,
                            ),
                            onPressed: () async {
                              final notifier = ref.read(
                                pinnedThesisProvider.notifier,
                              );
                              final active = ref
                                  .read(pinnedThesisProvider)
                                  .value
                                  ?.active
                                  .where((t) => t.symbol == widget.symbol)
                                  .toList();
                              try {
                                if (active != null && active.isNotEmpty) {
                                  await notifier.cancel(active.first.id);
                                } else {
                                  await notifier.pin(widget.symbol);
                                }
                              } on StateError catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.message)),
                                );
                              }
                            },
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.compare_arrows),
                        onPressed: () {
                          context.push(
                            AppRoutes.compare,
                            extra: [widget.symbol],
                          );
                        },
                        tooltip: 'comparison.compare'.tr(),
                      ),
                      IconButton(
                        icon: Icon(
                          isInWatchlist ? Icons.star : Icons.star_border,
                          color: isInWatchlist ? Colors.amber : null,
                        ),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await ref
                                .read(
                                  stockDetailProvider(widget.symbol).notifier,
                                )
                                .toggleWatchlist();
                          } catch (e) {
                            if (!mounted) return;
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  e is StateError ? e.message : '$e',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        tooltip: isInWatchlist
                            ? 'stock.removeFromWatchlist'.tr()
                            : 'stock.addToWatchlist'.tr(),
                      ),
                    ],
                  ),

                  // 股票標題
                  SliverToBoxAdapter(
                    child: Consumer(
                      builder: (context, ref, _) {
                        final headerData = ref.watch(
                          provider.select((s) => StockHeaderData.fromState(s)),
                        );
                        return StockDetailHeader(
                          data: headerData,
                          symbol: widget.symbol,
                        );
                      },
                    ),
                  ),

                  // AI 智慧分析摘要
                  SliverToBoxAdapter(
                    child: AiSummaryCard(symbol: widget.symbol),
                  ),

                  // Tab Bar（毛玻璃，與 App Bar 一致）
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabBarDelegate(
                      tabController: _tabController,
                      theme: theme,
                    ),
                  ),
                ],
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    TechnicalTab(symbol: widget.symbol),
                    ChipTab(symbol: widget.symbol),
                    InsiderTab(symbol: widget.symbol),
                    FundamentalsTab(symbol: widget.symbol),
                    AlertsTab(symbol: widget.symbol),
                  ],
                ),
              ),
      ),
    );
  }
}

/// 固定式 Tab bar 的 SliverPersistentHeaderDelegate
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  const _TabBarDelegate({required this.tabController, required this.theme});

  final TabController tabController;
  final ThemeData theme;

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return FrostedBackground(
      child: TabBar(
        controller: tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: theme.colorScheme.primary,
        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        indicatorColor: theme.colorScheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: DesignTokens.fontSizeMd,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: DesignTokens.fontSizeMd,
        ),
        tabs: [
          Tab(text: 'stockDetail.tabTechnical'.tr()),
          Tab(text: 'stockDetail.tabChip'.tr()),
          Tab(text: 'stockDetail.tabInsider'.tr()),
          Tab(text: 'stockDetail.tabFundamentals'.tr()),
          Tab(text: 'stockDetail.tabAlerts'.tr()),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) {
    return tabController != oldDelegate.tabController ||
        theme != oldDelegate.theme;
  }
}
