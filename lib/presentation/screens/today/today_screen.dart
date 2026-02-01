import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/presentation/providers/settings_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:afterclose/core/l10n/app_strings.dart';
import 'package:afterclose/presentation/providers/today_provider.dart';
import 'package:afterclose/presentation/providers/watchlist_provider.dart';
import 'package:afterclose/presentation/widgets/empty_state.dart';
import 'package:afterclose/presentation/widgets/section_header.dart';
import 'package:afterclose/presentation/widgets/shimmer_loading.dart';
import 'package:afterclose/presentation/widgets/stock_card.dart';
import 'package:afterclose/presentation/widgets/stock_preview_sheet.dart';
import 'package:afterclose/presentation/widgets/themed_refresh_indicator.dart';
import 'package:afterclose/presentation/providers/market_overview_provider.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/market_dashboard.dart';
import 'package:afterclose/presentation/widgets/update_progress_banner.dart';

/// 今日畫面 - 顯示每日推薦
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  @override
  void initState() {
    super.initState();
    // 首次建置時載入資料
    Future.microtask(() {
      ref.read(todayProvider.notifier).loadData();
      ref.read(watchlistProvider.notifier).loadData();
      ref.read(marketOverviewProvider.notifier).loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(todayProvider);
    // 使用 selector 只監聽 watchlist 的 symbols，避免不必要的重建
    final watchlistSymbols = ref.watch(
      watchlistProvider.select((s) => s.items.map((i) => i.symbol).toSet()),
    );

    return Scaffold(
      body: ThemedRefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.read(todayProvider.notifier).loadData(),
            ref.read(marketOverviewProvider.notifier).loadData(),
          ]);
        },
        child: state.isLoading
            ? const StockListShimmer(itemCount: 5)
            : state.error != null
            ? _buildError(state.error!)
            : _buildContent(state, watchlistSymbols),
      ),
    );
  }

  Widget _buildError(String error) {
    return EmptyStates.error(
      message: error,
      onRetry: () => ref.read(todayProvider.notifier).loadData(),
    );
  }

  Widget _buildContent(TodayState state, Set<String> watchlistSymbols) {
    final theme = Theme.of(context);
    final marketState = ref.watch(marketOverviewProvider);

    return CustomScrollView(
      slivers: [
        // Glassmorphism App Bar
        SliverAppBar(
          pinned: true,
          floating: true,
          expandedHeight: 0, // Standard height
          backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.7),
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.transparent),
            ),
          ),
          title: const Text(
            S.appName,
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
          ),
          actions: [
            if (state.isUpdating)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _runUpdate,
                tooltip: S.todayUpdateData,
              ),
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => context.push('/alerts'),
              tooltip: S.todayPriceAlert,
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push('/settings'),
              tooltip: S.settings,
            ),
          ],
        ),

        // 更新進度橫幅
        if (state.isUpdating && state.updateProgress != null)
          SliverToBoxAdapter(
            child: UpdateProgressBanner(progress: state.updateProgress!),
          ),

        // 最後更新時間 + 資料日期
        if (state.lastUpdate != null || state.dataDate != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text.rich(
                TextSpan(
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  children: [
                    if (state.lastUpdate != null)
                      TextSpan(
                        text: S.todayLastUpdate(
                          S.dateFormat(state.lastUpdate!),
                        ),
                      ),
                    if (state.lastUpdate != null && state.dataDate != null)
                      const TextSpan(text: '  ·  '),
                    if (state.dataDate != null)
                      TextSpan(
                        text: S.todayDataDate(_formatDataDate(state.dataDate!)),
                      ),
                  ],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

        // 大盤總覽卡片
        if (marketState.hasData || marketState.isLoading)
          SliverToBoxAdapter(child: MarketDashboard(state: marketState)),

        // Top 10 區塊
        const SliverToBoxAdapter(
          child: SectionHeader(title: S.todayTop10, icon: Icons.trending_up),
        ),

        // 推薦清單
        if (state.recommendations.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyStates.noRecommendations(onRefresh: _runUpdate),
          )
        else
          SliverList.builder(
            itemCount: state.recommendations.length,
            itemBuilder: (context, index) {
              final rec = state.recommendations[index];
              // 使用 RepaintBoundary 提升捲動效能
              final isInWatchlist = watchlistSymbols.contains(rec.symbol);
              final card = RepaintBoundary(
                // Key 包含自選狀態，以便狀態變更時強制重建
                key: ValueKey('${rec.symbol}_$isInWatchlist'),
                child: StockCard(
                  symbol: rec.symbol,
                  stockName: rec.stockName,
                  market: rec.market,
                  latestClose: rec.latestClose,
                  priceChange: rec.priceChange,
                  score: rec.score,
                  reasons: rec.reasons.map((r) => r.reasonType).toList(),
                  trendState: rec.trendState,
                  recentPrices: rec.recentPrices,
                  isInWatchlist: isInWatchlist,
                  showLimitMarkers: ref.watch(settingsProvider).limitAlerts,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/stock/${rec.symbol}');
                  },
                  onLongPress: () {
                    showStockPreviewSheet(
                      context: context,
                      data: StockPreviewData(
                        symbol: rec.symbol,
                        stockName: rec.stockName,
                        latestClose: rec.latestClose,
                        priceChange: rec.priceChange,
                        score: rec.score,
                        trendState: rec.trendState,
                        reasons: rec.reasons.map((r) => r.reasonType).toList(),
                        isInWatchlist: isInWatchlist,
                      ),
                      onViewDetails: () => context.push('/stock/${rec.symbol}'),
                      onToggleWatchlist: () =>
                          _toggleWatchlist(rec.symbol, isInWatchlist),
                    );
                  },
                  onWatchlistTap: () =>
                      _toggleWatchlist(rec.symbol, isInWatchlist),
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

        // 底部間距
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Future<void> _toggleWatchlist(
    String symbol,
    bool currentlyInWatchlist,
  ) async {
    HapticFeedback.lightImpact();
    final notifier = ref.read(watchlistProvider.notifier);

    // 隱藏目前的 SnackBar（比 clearSnackBars 更溫和）
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (currentlyInWatchlist) {
      await notifier.removeStock(symbol);
      if (mounted) {
        _showSnackBar(
          S.watchlistRemoved(symbol),
          action: SnackBarAction(
            label: S.watchlistUndo,
            onPressed: () => notifier.restoreStock(symbol),
          ),
          duration: const Duration(seconds: 3),
        );
      }
    } else {
      final success = await notifier.addStock(symbol);
      if (mounted) {
        _showSnackBar(
          success ? S.watchlistAddedToWatchlist(symbol) : S.watchlistAddFailed,
          duration: const Duration(seconds: 2),
          isError: !success,
        );
      }
    }
  }

  /// 在畫面重繪後顯示 SnackBar，避免生命週期問題
  void _showSnackBar(
    String message, {
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 2),
    bool isError = false,
  }) {
    // 使用畫面回呼確保 SnackBar 在重建後顯示
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: duration,
          action: action,
          backgroundColor: isError ? Colors.red : null,
          showCloseIcon: action != null, // 有動作按鈕時顯示關閉圖示
          dismissDirection: DismissDirection.horizontal,
        ),
      );
    });
  }

  Future<void> _runUpdate() async {
    try {
      final result = await ref.read(todayProvider.notifier).runUpdate();

      if (mounted) {
        // Check for rate limit errors
        final hasRateLimitError = result.errors.any(
          (e) =>
              e.contains('流量') ||
              e.contains('limit') ||
              e.contains('quota') ||
              e.contains('429'),
        );

        if (hasRateLimitError) {
          _showRateLimitDialog();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.summary),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Check if exception is rate limit related
        final errorStr = e.toString();
        final isRateLimit =
            errorStr.contains('流量') ||
            errorStr.contains('limit') ||
            errorStr.contains('quota') ||
            errorStr.contains('429');

        if (isRateLimit) {
          _showRateLimitDialog();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.todayUpdateFailed(errorStr)),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDataDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dataDay = DateTime(date.year, date.month, date.day);

    if (dataDay == today) {
      return S.todayDataToday;
    } else if (dataDay == today.subtract(const Duration(days: 1))) {
      return S.todayDataYesterday;
    } else {
      return '${date.month}/${date.day}';
    }
  }

  void _showRateLimitDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: Colors.orange,
          size: 48,
        ),
        title: Text('settings.rateLimitTitle'.tr()),
        content: Text('settings.rateLimitMessage'.tr()),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('settings.rateLimitOk'.tr()),
          ),
        ],
      ),
    );
  }
}
