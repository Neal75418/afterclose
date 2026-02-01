import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:afterclose/core/extensions/trend_state_extension.dart';
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/presentation/providers/stock_detail_provider.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/alerts_tab.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/chip_tab.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/fundamentals_tab.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/insider_tab.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical_tab.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/ai_summary_card.dart';
import 'package:afterclose/presentation/widgets/reason_tags.dart';
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

    // Dynamic gradient based on price change
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
        child: state.isLoading
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
                  // App bar (Glassmorphism)
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
                          context.push('/compare', extra: [widget.symbol]);
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

                  // Stock header
                  SliverToBoxAdapter(child: _buildHeader(state, theme)),

                  // AI 智慧分析摘要
                  SliverToBoxAdapter(
                    child: AiSummaryCard(symbol: widget.symbol),
                  ),

                  // Tab bar (Glassmorphism)
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

  String _buildHeaderSemanticLabel(StockDetailState state) {
    final parts = <String>[];
    final name = state.stock?.name;
    if (name != null) parts.add(name);
    parts.add(widget.symbol);
    final close = state.latestPrice?.close;
    if (close != null) parts.add('收盤價 ${close.toStringAsFixed(2)} 元');
    final change = state.priceChange;
    if (change != null) {
      parts.add('漲跌幅 ${change >= 0 ? "+" : ""}${change.toStringAsFixed(2)}%');
    }
    final trend = state.analysis?.trendState;
    if (trend != null) parts.add('趨勢 ${trend.trendKey}');
    return parts.join(', ');
  }

  Widget _buildHeader(StockDetailState state, ThemeData theme) {
    final priceChange = state.priceChange;
    final isPositive = (priceChange ?? 0) >= 0;
    final priceColor = AppTheme.getPriceColor(priceChange);

    return Semantics(
      label: _buildHeaderSemanticLabel(state),
      container: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        // No background color to let gradient show through
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stock name and price
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              state.stock?.name ?? widget.symbol,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (state.stock?.market == 'TPEx') ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'stockDetail.otcBadge'.tr(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                          if (state.stock?.industry != null &&
                              state.stock!.industry!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.tertiaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  state.stock!.industry!,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color:
                                        theme.colorScheme.onTertiaryContainer,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Reason tags
                      if (state.reasons.isNotEmpty)
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: state.reasons.take(3).map((reason) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                ReasonTags.translateReasonCode(
                                  reason.reasonType,
                                ),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      state.latestPrice?.close?.toStringAsFixed(2) ?? '-',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight
                            .w800, // Matching heavy weight from StockCard
                        fontFamily: 'RobotoMono',
                        fontSize: 32,
                        letterSpacing: -1,
                      ),
                    ),
                    if (priceChange != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isPositive
                                ? [
                                    AppTheme.upColor.withValues(alpha: 0.2),
                                    AppTheme.upColor.withValues(alpha: 0.1),
                                  ]
                                : [
                                    AppTheme.downColor.withValues(alpha: 0.2),
                                    AppTheme.downColor.withValues(alpha: 0.1),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: priceColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPositive ? Icons.north : Icons.south,
                              size: 14,
                              color: priceColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${isPositive ? '+' : ''}${priceChange.toStringAsFixed(2)}%',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: priceColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Show synchronized data date
                    if (state.dataDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (state.hasDataMismatch)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(
                                  Icons.sync_problem,
                                  size: 12,
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            Text(
                              _formatDataDate(state.dataDate!),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: state.hasDataMismatch
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Trend and key levels row
            Row(
              children: [
                _buildInfoChip(
                  theme: theme,
                  label:
                      'trend.${state.analysis?.trendState.trendKey ?? 'sideways'}'
                          .tr(),
                  icon:
                      state.analysis?.trendState.trendIconData ??
                      Icons.trending_flat,
                  color:
                      state.analysis?.trendState.trendColor ??
                      AppTheme.neutralColor,
                ),
                const SizedBox(width: 8),
                if (state.analysis?.supportLevel case final supportLevel?)
                  _buildLevelChip(
                    theme: theme,
                    label: 'stockDetail.support'.tr(),
                    value: supportLevel,
                    color: AppTheme.downColor,
                  ),
                const SizedBox(width: 8),
                if (state.analysis?.resistanceLevel case final resistanceLevel?)
                  _buildLevelChip(
                    theme: theme,
                    label: 'stockDetail.resistance'.tr(),
                    value: resistanceLevel,
                    color: AppTheme.upColor,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required ThemeData theme,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelChip({
    required ThemeData theme,
    required String label,
    required double value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$label ${value.toStringAsFixed(1)}',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Format synchronized data date for display
  String _formatDataDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dataDay = DateTime(date.year, date.month, date.day);

    if (dataDay == today) {
      return 'stockDetail.dataToday'.tr();
    } else if (dataDay == today.subtract(const Duration(days: 1))) {
      return 'stockDetail.dataYesterday'.tr();
    } else {
      return '${date.month}/${date.day} ${'stockDetail.dataLabel'.tr()}';
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
