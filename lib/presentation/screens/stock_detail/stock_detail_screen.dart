import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:afterclose/core/constants/app_routes.dart';
import 'package:afterclose/core/services/share_service.dart';
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/core/utils/error_display.dart';
import 'package:afterclose/core/utils/widget_capture.dart';
import 'package:afterclose/presentation/providers/stock_detail_provider.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/alerts_tab.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/chip_tab.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/fundamentals_tab.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/insider_tab.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical_tab.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/ai_summary_card.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/stock_detail_header.dart';
import 'package:afterclose/presentation/services/export_service.dart';
import 'package:afterclose/presentation/widgets/empty_state.dart';
import 'package:afterclose/presentation/widgets/frosted_bar.dart';
import 'package:afterclose/presentation/widgets/share_options_sheet.dart';
import 'package:afterclose/presentation/widgets/shareable/shareable_analysis_card.dart';
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
  bool _isExporting = false;

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
                      _isExporting
                          ? const SizedBox(
                              width: 48,
                              height: 48,
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.share_outlined),
                              onPressed: () =>
                                  _showShareOptions(ref.read(provider)),
                              tooltip: 'export.title'.tr(),
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

  Future<void> _showShareOptions(StockDetailState state) async {
    final format = await ShareOptionsSheet.show(context);
    if (format == null || !mounted || _isExporting) return;

    const shareService = ShareService();
    const exportService = ExportService();

    setState(() => _isExporting = true);
    try {
      switch (format) {
        case ShareFormat.png:
          final imageBytes = await _captureAnalysisCard(state);
          if (imageBytes != null) {
            await shareService.shareImage(
              imageBytes,
              '${widget.symbol}_analysis.png',
            );
          }
        case ShareFormat.pdf:
          final pdfBytes = await exportService.analysisDataToPdf(
            widget.symbol,
            state,
          );
          await shareService.sharePdf(
            pdfBytes,
            '${widget.symbol}_analysis.pdf',
          );
        case ShareFormat.csv:
          final csv = exportService.analysisDataToCsv(widget.symbol, state);
          await shareService.shareCsv(csv, '${widget.symbol}_analysis.csv');
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
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<Uint8List?> _captureAnalysisCard(StockDetailState state) async {
    final key = GlobalKey();
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        left: -1000,
        top: -1000,
        child: RepaintBoundary(
          key: key,
          child: Material(child: ShareableAnalysisCard(state: state)),
        ),
      ),
    );
    overlay.insert(entry);
    try {
      await WidgetsBinding.instance.endOfFrame;
      return await const WidgetCapture().captureFromKey(key);
    } finally {
      entry.remove();
    }
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
