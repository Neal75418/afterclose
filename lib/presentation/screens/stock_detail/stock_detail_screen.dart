import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:afterclose/core/constants/app_routes.dart';
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/presentation/providers/stock_detail_provider.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/alerts_tab.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/chip_tab.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/fundamentals_tab.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/insider_tab.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical_tab.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/ai_summary_card.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/stock_detail_header.dart';
import 'package:afterclose/presentation/widgets/share_options_sheet.dart';
import 'package:afterclose/presentation/widgets/shareable/shareable_analysis_card.dart';
import 'package:afterclose/core/utils/widget_capture.dart';
import 'package:afterclose/core/services/share_service.dart';
import 'package:afterclose/presentation/services/export_service.dart';
import 'package:afterclose/presentation/widgets/empty_state.dart';
import 'package:afterclose/presentation/widgets/shimmer_loading.dart';

/// Stock detail screen - shows comprehensive stock information with tabs
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
    final state = ref.watch(stockDetailProvider(widget.symbol));
    final theme = Theme.of(context);

    // 依漲跌幅動態漸層
    final priceChange = state.priceChange ?? 0;
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
        child: state.loading.isLoading
            ? const SafeArea(child: StockDetailShimmer())
            : state.error != null
            ? SafeArea(
                child: EmptyStates.error(
                  message: state.error!,
                  onRetry: () {
                    ref
                        .read(stockDetailProvider(widget.symbol).notifier)
                        .loadData();
                  },
                ),
              )
            : NestedScrollView(
                headerSliverBuilder: (context, innerBoxScrolled) => [
                  // App Bar（毛玻璃效果）
                  SliverAppBar(
                    pinned: true,
                    floating: true,
                    backgroundColor: theme.colorScheme.surface.withValues(
                      alpha: 0.7,
                    ),
                    flexibleSpace: ClipRect(
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                    title: Text(widget.symbol),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.share_outlined),
                        onPressed: () => _showShareOptions(state),
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
                          state.isInWatchlist ? Icons.star : Icons.star_border,
                          color: state.isInWatchlist ? Colors.amber : null,
                        ),
                        onPressed: () {
                          ref
                              .read(stockDetailProvider(widget.symbol).notifier)
                              .toggleWatchlist();
                        },
                        tooltip: state.isInWatchlist
                            ? 'stock.removeFromWatchlist'.tr()
                            : 'stock.addToWatchlist'.tr(),
                      ),
                    ],
                  ),

                  // 股票標題
                  SliverToBoxAdapter(
                    child: StockDetailHeader(
                      state: state,
                      symbol: widget.symbol,
                    ),
                  ),

                  // AI 智慧分析摘要
                  SliverToBoxAdapter(
                    child: AiSummaryCard(symbol: widget.symbol),
                  ),

                  // Tab Bar（毛玻璃效果）
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
                    FundamentalsTab(symbol: widget.symbol),
                    InsiderTab(symbol: widget.symbol),
                    AlertsTab(symbol: widget.symbol),
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _showShareOptions(StockDetailState state) async {
    final format = await ShareOptionsSheet.show(context);
    if (format == null || !mounted) return;

    const shareService = ShareService();
    const exportService = ExportService();

    try {
      if (format == ShareFormat.png) {
        // 在 Overlay 中渲染分享卡片再截圖
        final imageBytes = await _captureAnalysisCard(state);
        if (imageBytes != null) {
          await shareService.shareImage(
            imageBytes,
            '${widget.symbol}_analysis.png',
          );
        }
      } else {
        final csv = exportService.analysisDataToCsv(widget.symbol, state);
        await shareService.shareCsv(csv, '${widget.symbol}_analysis.csv');
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

/// Tab bar delegate for pinned header
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
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: theme.colorScheme.surface.withValues(alpha: 0.7),
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
              fontSize: 14,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.normal,
              fontSize: 14,
            ),
            tabs: [
              Tab(text: 'stockDetail.tabTechnical'.tr()),
              Tab(text: 'stockDetail.tabChip'.tr()),
              Tab(text: 'stockDetail.tabFundamentals'.tr()),
              Tab(text: 'stockDetail.tabInsider'.tr()),
              Tab(text: 'stockDetail.tabAlerts'.tr()),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) {
    return tabController != oldDelegate.tabController ||
        theme != oldDelegate.theme;
  }
}
