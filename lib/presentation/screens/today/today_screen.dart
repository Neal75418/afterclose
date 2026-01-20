import 'package:flutter/material.dart';
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

/// Today screen - shows daily recommendations and watchlist status
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  @override
  void initState() {
    super.initState();
    // Load data on first build
    Future.microtask(() {
      ref.read(todayProvider.notifier).loadData();
      ref.read(watchlistProvider.notifier).loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(todayProvider);
    // Watch watchlistProvider in build() to ensure dependency is always registered
    final watchlistState = ref.watch(watchlistProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(S.appName),
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
      body: ThemedRefreshIndicator(
        onRefresh: () => ref.read(todayProvider.notifier).loadData(),
        child: state.isLoading
            ? const StockListShimmer(itemCount: 5)
            : state.error != null
            ? _buildError(state.error!)
            : _buildContent(state, watchlistState),
      ),
    );
  }

  Widget _buildError(String error) {
    return EmptyStates.error(
      message: error,
      onRetry: () => ref.read(todayProvider.notifier).loadData(),
    );
  }

  Widget _buildContent(TodayState state, WatchlistState watchlistState) {
    final theme = Theme.of(context);
    final watchlistSymbols = watchlistState.items.map((i) => i.symbol).toSet();

    return CustomScrollView(
      slivers: [
        // Update progress banner
        if (state.isUpdating && state.updateProgress != null)
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              color: theme.colorScheme.primaryContainer,
              child: Column(
                children: [
                  Text(
                    state.updateProgress!.message,
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: state.updateProgress!.progress,
                  ),
                ],
              ),
            ),
          ),

        // Last update time
        if (state.lastUpdate != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                S.todayLastUpdate(S.dateFormat(state.lastUpdate!)),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),

        // Top 10 section
        const SliverToBoxAdapter(
          child: SectionHeader(title: S.todayTop10, icon: Icons.trending_up),
        ),

        // Recommendations
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
              // RepaintBoundary for better scroll performance
              final isInWatchlist = watchlistSymbols.contains(rec.symbol);
              final card = RepaintBoundary(
                // Key includes watchlist status to force rebuild when it changes
                key: ValueKey('${rec.symbol}_$isInWatchlist'),
                child: StockCard(
                  symbol: rec.symbol,
                  stockName: rec.stockName,
                  latestClose: rec.latestClose,
                  priceChange: rec.priceChange,
                  score: rec.score,
                  reasons: rec.reasons.map((r) => r.reasonType).toList(),
                  trendState: rec.trendState,
                  recentPrices: rec.recentPrices,
                  isInWatchlist: isInWatchlist,
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

              // Staggered entry animation for first 10 items
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

        // Watchlist section
        if (state.watchlistStatus.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 8),
              child: SectionHeader(
                title: S.todayWatchlistStatus,
                icon: Icons.star,
              ),
            ),
          ),

          SliverList.builder(
            itemCount: state.watchlistStatus.length,
            itemBuilder: (context, index) {
              final entry = state.watchlistStatus.entries.elementAt(index);
              final status = entry.value;
              return ListTile(
                leading: Text(
                  status.statusIcon,
                  style: const TextStyle(fontSize: 24),
                ),
                title: Row(
                  children: [
                    Text(
                      status.symbol,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    if (status.stockName != null)
                      Expanded(
                        child: Text(
                          status.stockName!,
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
                subtitle: status.hasSignal
                    ? Text(
                        S.signalType(status.signalType),
                        style: TextStyle(color: theme.colorScheme.primary),
                      )
                    : null,
                trailing: status.priceChange != null
                    ? Text(
                        '${status.priceChange! >= 0 ? '+' : ''}${status.priceChange!.toStringAsFixed(2)}%',
                        style: TextStyle(
                          color: status.priceChange! >= 0
                              ? Colors.red.shade700
                              : Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/stock/${status.symbol}');
                },
              );
            },
          ),
        ],

        // Bottom padding
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

    // Hide current SnackBar if any (gentler than clearSnackBars)
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (currentlyInWatchlist) {
      await notifier.removeStock(symbol);
      if (mounted) {
        _showSnackBar(
          '已從自選移除 $symbol',
          action: SnackBarAction(
            label: '復原',
            onPressed: () => notifier.restoreStock(symbol),
          ),
          duration: const Duration(seconds: 3),
        );
      }
    } else {
      final success = await notifier.addStock(symbol);
      if (mounted) {
        _showSnackBar(
          success ? '已加入自選 $symbol' : '加入自選失敗',
          duration: const Duration(seconds: 2),
          isError: !success,
        );
      }
    }
  }

  /// Show SnackBar after frame to avoid lifecycle issues
  void _showSnackBar(
    String message, {
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 2),
    bool isError = false,
  }) {
    // Use post frame callback to ensure SnackBar is shown after rebuild
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: duration,
          action: action,
          backgroundColor: isError ? Colors.red : null,
          showCloseIcon:
              action != null, // Show close icon for SnackBars with actions
          dismissDirection: DismissDirection.horizontal,
        ),
      );
    });
  }

  Future<void> _runUpdate() async {
    try {
      final result = await ref.read(todayProvider.notifier).runUpdate();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.summary),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.todayUpdateFailed(e.toString())),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
