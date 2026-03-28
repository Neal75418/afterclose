import 'package:csv/csv.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:afterclose/core/constants/animations.dart';
import 'package:afterclose/core/constants/api_config.dart';
import 'package:afterclose/core/constants/app_routes.dart';
import 'package:afterclose/core/services/share_service.dart';
import 'package:afterclose/core/utils/error_display.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/l10n/app_strings.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/responsive_helper.dart';
import 'package:afterclose/presentation/providers/market_overview_provider.dart';
import 'package:afterclose/presentation/providers/settings_provider.dart';
import 'package:afterclose/presentation/providers/today_provider.dart';
import 'package:afterclose/presentation/providers/watchlist_provider.dart';
import 'package:afterclose/presentation/widgets/empty_state.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/market_dashboard.dart';
import 'package:afterclose/presentation/widgets/section_header.dart';
import 'package:afterclose/presentation/widgets/shimmer_loading.dart';
import 'package:afterclose/presentation/widgets/stock_card.dart';
import 'package:afterclose/presentation/widgets/stock_preview_sheet.dart';
import 'package:afterclose/presentation/widgets/themed_refresh_indicator.dart';
import 'package:afterclose/presentation/widgets/update_progress_banner.dart';

/// 今日畫面 - 顯示每日推薦
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  bool _isExporting = false;

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
    // 使用 selector 分離 loading/error 狀態，避免 updateProgress 變更時重建整個畫面
    final isLoading = ref.watch(todayProvider.select((s) => s.isLoading));
    final error = ref.watch(todayProvider.select((s) => s.error));
    final hasRecommendations = ref.watch(
      todayProvider.select((s) => s.recommendations.isNotEmpty),
    );
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
        child: isLoading
            ? const StockListShimmer(itemCount: 5)
            : error != null && !hasRecommendations
            ? _buildError(error)
            : _buildContent(watchlistSymbols),
      ),
    );
  }

  Widget _buildError(String error) {
    void onRetry() => ref.read(todayProvider.notifier).loadData();
    if (ErrorDisplay.isNetworkError(error)) {
      return EmptyStates.networkError(onRetry: onRetry);
    }
    return EmptyStates.error(message: error, onRetry: onRetry);
  }

  /// 響應式推薦清單：手機使用 SliverList，平板/桌面使用 SliverGrid
  Widget _buildRecommendationsList(
    BuildContext context,
    List<RecommendationWithDetails> recommendations,
    Set<String> watchlistSymbols,
    bool showLimitMarkers,
  ) {
    final columns = context.responsiveGridColumns;
    final useGrid = columns > 1;
    final padding = context.responsiveHorizontalPadding;
    final spacing = context.responsiveCardSpacing;

    if (useGrid) {
      return SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: padding),
        sliver: SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            mainAxisExtent: DesignTokens.stockCardHeight,
          ),
          itemCount: recommendations.length,
          itemBuilder: (context, index) => _buildRecommendationCard(
            context,
            recommendations,
            watchlistSymbols,
            index,
            showLimitMarkers,
          ),
        ),
      );
    }

    return SliverList.builder(
      itemCount: recommendations.length,
      itemBuilder: (context, index) => _buildRecommendationCard(
        context,
        recommendations,
        watchlistSymbols,
        index,
        showLimitMarkers,
      ),
    );
  }

  /// 建立推薦卡片
  Widget _buildRecommendationCard(
    BuildContext context,
    List<RecommendationWithDetails> recommendations,
    Set<String> watchlistSymbols,
    int index,
    bool showLimitMarkers,
  ) {
    final rec = recommendations[index];
    final isInWatchlist = watchlistSymbols.contains(rec.symbol);
    final columns = context.responsiveGridColumns;

    final card = RepaintBoundary(
      key: ValueKey('${rec.symbol}_$isInWatchlist'),
      child: StockCard(
        symbol: rec.symbol,
        stockName: rec.stockName,
        market: rec.market,
        latestClose: rec.latestClose,
        priceChange: rec.priceChange,
        score: rec.score,
        reasons: rec.reasonTypes,
        trendState: rec.trendState,
        recentPrices: rec.recentPrices,
        isInWatchlist: isInWatchlist,
        showLimitMarkers: showLimitMarkers,
        onTap: () {
          HapticFeedback.lightImpact();
          context.push(AppRoutes.stockDetail(rec.symbol));
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
              reasons: rec.reasonTypes,
              isInWatchlist: isInWatchlist,
            ),
            onViewDetails: () =>
                context.push(AppRoutes.stockDetail(rec.symbol)),
            onToggleWatchlist: () =>
                _toggleWatchlist(rec.symbol, isInWatchlist),
          );
        },
        onWatchlistTap: () => _toggleWatchlist(rec.symbol, isInWatchlist),
      ),
    );

    // 前 10/20 筆項目使用交錯進場動畫（Grid 顯示更多）
    final animateCount = columns > 1 ? 20 : 10;
    final animateDelay = columns > 1 ? 30 : 50;

    if (index < animateCount) {
      return card
          .animate()
          .fadeIn(
            delay: Duration(milliseconds: animateDelay * index),
            duration: columns > 1
                ? AnimDurations.normal
                : AnimDurations.moderate,
          )
          .then()
          .custom(
            builder: (context, value, child) {
              if (columns > 1) {
                // Grid：縮放動畫
                return Transform.scale(
                  scale: 0.95 + 0.05 * value,
                  child: child,
                );
              }
              // List：水平滑入
              return Transform.translate(
                offset: Offset(20 * (1 - value), 0),
                child: child,
              );
            },
            duration: columns > 1
                ? AnimDurations.normal
                : AnimDurations.moderate,
            curve: AnimCurves.smooth,
          );
    }
    return card;
  }

  Widget _buildContent(Set<String> watchlistSymbols) {
    final theme = Theme.of(context);
    final showLimitMarkers = ref.watch(
      settingsProvider.select((s) => s.limitAlerts),
    );

    return CustomScrollView(
      slivers: [
        // App Bar（Consumer 隔離 isUpdating 狀態，避免進度更新時重建推薦清單）
        Consumer(
          builder: (context, ref, _) {
            final isUpdating = ref.watch(
              todayProvider.select((s) => s.isUpdating),
            );
            return SliverAppBar(
              pinned: true,
              floating: true,
              expandedHeight: 0, // Standard height
              backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.7),
              surfaceTintColor: Colors.transparent,
              title: Text(
                S.appName,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              actions: [
                if (isUpdating)
                  const Padding(
                    padding: EdgeInsets.all(DesignTokens.spacing12),
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
                _isExporting
                    ? const Padding(
                        padding: EdgeInsets.all(DesignTokens.spacing12),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.ios_share),
                        onPressed: _exportTodayCsv,
                        tooltip: 'export.exportCsv'.tr(),
                      ),
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => context.push(AppRoutes.alerts),
                  tooltip: S.todayPriceAlert,
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'scan.more'.tr(),
                  onSelected: (value) {
                    HapticFeedback.selectionClick();
                    switch (value) {
                      case 'news':
                        context.push(AppRoutes.news);
                      case 'settings':
                        context.push(AppRoutes.settings);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'news',
                      child: Row(
                        children: [
                          const Icon(Icons.newspaper_outlined, size: 20),
                          const SizedBox(width: DesignTokens.spacing12),
                          Text('nav.news'.tr()),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'settings',
                      child: Row(
                        children: [
                          const Icon(Icons.settings_outlined, size: 20),
                          const SizedBox(width: DesignTokens.spacing12),
                          Text(S.settings),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),

        // 更新進度橫幅（Consumer 隔離 updateProgress 頻繁更新）
        Consumer(
          builder: (context, ref, _) {
            final isUpdating = ref.watch(
              todayProvider.select((s) => s.isUpdating),
            );
            final updateProgress = ref.watch(
              todayProvider.select((s) => s.updateProgress),
            );
            if (isUpdating && updateProgress != null) {
              return SliverToBoxAdapter(
                child: UpdateProgressBanner(progress: updateProgress),
              );
            }
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          },
        ),

        // 最後更新時間 + 資料日期（Consumer 隔離日期狀態）
        Consumer(
          builder: (context, ref, _) {
            final lastUpdate = ref.watch(
              todayProvider.select((s) => s.lastUpdate),
            );
            final dataDate = ref.watch(todayProvider.select((s) => s.dataDate));
            if (lastUpdate == null && dataDate == null) {
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            }
            return SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  DesignTokens.spacing16,
                  DesignTokens.spacing16,
                  DesignTokens.spacing16,
                  DesignTokens.spacing8,
                ),
                child: Wrap(
                  spacing: DesignTokens.spacing8,
                  runSpacing: DesignTokens.spacing4,
                  children: [
                    if (lastUpdate != null)
                      Text(
                        S.todayLastUpdate(S.dateFormat(lastUpdate)),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (lastUpdate != null && dataDate != null)
                      Text(
                        '·',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (dataDate != null)
                      Text(
                        S.todayDataDate(_formatDataDate(dataDate)),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),

        // 大盤總覽卡片（獨立 Consumer 隔離 market data rebuild）
        SliverToBoxAdapter(
          child: Consumer(
            builder: (context, ref, _) {
              final marketState = ref.watch(marketOverviewProvider);
              if (!marketState.hasData && !marketState.isLoading) {
                if (marketState.error != null) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spacing16,
                    ),
                    child: Card(
                      child: ListTile(
                        leading: Icon(
                          Icons.error_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        title: Text(marketState.error!),
                        trailing: TextButton(
                          onPressed: () => ref
                              .read(marketOverviewProvider.notifier)
                              .loadData(),
                          child: Text('common.retry'.tr()),
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              }
              return MarketDashboard(state: marketState);
            },
          ),
        ),

        // 部分錯誤橫幅（有推薦資料但重新整理失敗時顯示）
        Consumer(
          builder: (context, ref, _) {
            final error = ref.watch(todayProvider.select((s) => s.error));
            if (error == null) {
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            }
            return SliverToBoxAdapter(
              child: MaterialBanner(
                content: Text(error),
                actions: [
                  TextButton(
                    onPressed: () =>
                        ref.read(todayProvider.notifier).loadData(),
                    child: Text('common.retry'.tr()),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(todayProvider.notifier).clearError(),
                    child: Text('common.dismiss'.tr()),
                  ),
                ],
              ),
            );
          },
        ),

        // Top 10 區塊
        SliverToBoxAdapter(
          child: SectionHeader(
            title: S.todayTop10,
            icon: Icons.trending_up,
            trailing: IconButton(
              icon: Icon(
                Icons.analytics_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              tooltip: 'recPerf.title'.tr(),
              onPressed: () =>
                  context.push(AppRoutes.recommendationPerformance),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ),

        // 推薦清單（Consumer 隔離推薦資料，避免 updateProgress 觸發昂貴的清單重建）
        Consumer(
          builder: (context, ref, _) {
            final recommendations = ref.watch(
              todayProvider.select((s) => s.recommendations),
            );
            if (recommendations.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyStates.noRecommendations(onRefresh: _runUpdate),
              );
            }
            return _buildRecommendationsList(
              context,
              recommendations,
              watchlistSymbols,
              showLimitMarkers,
            );
          },
        ),

        // 底部間距
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Future<void> _exportTodayCsv() async {
    if (_isExporting) return;
    final recommendations = ref.read(todayProvider).recommendations;
    if (recommendations.isEmpty) return;

    setState(() => _isExporting = true);
    try {
      final csv = _recommendationsToCsv(recommendations);
      final date = DateFormat('yyyyMMdd').format(DateTime.now());
      await const ShareService().shareCsv(csv, 'today_$date.csv');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorDisplay.message(e)),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  String _recommendationsToCsv(List<RecommendationWithDetails> recs) {
    final headers = [
      'export.csvSymbol'.tr(),
      'export.csvName'.tr(),
      'export.csvMarket'.tr(),
      'export.csvClose'.tr(),
      'export.csvChange'.tr(),
      'export.csvTrend'.tr(),
      'export.csvScore'.tr(),
    ];

    final rows = recs.map((r) {
      return [
        r.symbol,
        r.stockName ?? '',
        r.market ?? '',
        r.latestClose?.toStringAsFixed(2) ?? '',
        r.priceChange != null
            ? '${r.priceChange! >= 0 ? "+" : ""}${r.priceChange!.toStringAsFixed(2)}%'
            : '',
        r.trendState ?? '',
        r.score.toStringAsFixed(0),
      ];
    }).toList();

    return const CsvEncoder().convert([headers, ...rows]);
  }

  Future<void> _toggleWatchlist(
    String symbol,
    bool currentlyInWatchlist,
  ) async {
    HapticFeedback.lightImpact();
    final notifier = ref.read(watchlistProvider.notifier);

    // 清除現有的 SnackBar，避免堆積（與 watchlist_screen 一致）
    ScaffoldMessenger.of(context).clearSnackBars();

    if (currentlyInWatchlist) {
      final success = await notifier.removeStock(symbol);
      if (!mounted) return;
      if (!success) {
        final watchlistState = ref.read(watchlistProvider);
        _showSnackBar(
          watchlistState.error ?? 'watchlist.removeFailed'.tr(),
          isError: true,
        );
      } else {
        HapticFeedback.mediumImpact();
        final messenger = ScaffoldMessenger.of(context);
        final errorColor = Theme.of(context).colorScheme.error;
        _showSnackBar(
          S.watchlistRemoved(symbol),
          action: SnackBarAction(
            label: S.watchlistUndo,
            onPressed: () {
              notifier.restoreStock(symbol).then((_) {
                // restoreStock 失敗時會設 watchlistProvider.state.error
                final error = ref.read(watchlistProvider).error;
                if (error != null && mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(error),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: errorColor,
                    ),
                  );
                }
              });
            },
          ),
          duration: const Duration(seconds: ApiConfig.longMessageDurationSec),
        );
      }
    } else {
      final success = await notifier.addStock(symbol);
      if (mounted) {
        if (success) HapticFeedback.mediumImpact();
        _showSnackBar(
          success ? S.watchlistAddedToWatchlist(symbol) : S.watchlistAddFailed,
          duration: const Duration(seconds: ApiConfig.shortMessageDurationSec),
          isError: !success,
        );
      }
    }
  }

  /// 在畫面重繪後顯示 SnackBar，避免生命週期問題
  void _showSnackBar(
    String message, {
    SnackBarAction? action,
    Duration duration = const Duration(
      seconds: ApiConfig.shortMessageDurationSec,
    ),
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
          backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
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
        if (result.hasRateLimitError) {
          _showRateLimitDialog();
        }

        final theme = Theme.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.summary),
            behavior: SnackBarBehavior.floating,
            backgroundColor: result.hasWarnings
                ? theme.colorScheme.tertiary
                : null,
            action: result.hasWarnings
                ? SnackBarAction(
                    label: S.detail,
                    textColor: theme.colorScheme.onTertiary,
                    onPressed: () => _showWarningDetails(result.errors),
                  )
                : null,
            showCloseIcon: result.hasWarnings,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        if (e is RateLimitException) {
          _showRateLimitDialog();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.todayUpdateFailed(ErrorDisplay.message(e))),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  String _formatDataDate(DateTime date) {
    final now = DateTime.now();
    final today = DateContext.normalize(now);
    final dataDay = DateContext.normalize(date);

    if (dataDay == today) {
      return S.todayDataToday;
    } else if (dataDay == today.subtract(const Duration(days: 1))) {
      return S.todayDataYesterday;
    } else {
      return '${date.month}/${date.day}';
    }
  }

  void _showWarningDetails(List<String> warnings) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(dialogContext).colorScheme.tertiary,
          size: 48,
        ),
        title: Text(S.todayWarningDetail),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(S.todayWarningItems),
            const SizedBox(height: DesignTokens.spacing8),
            ...warnings.map(
              (w) => Padding(
                padding: const EdgeInsets.only(bottom: DesignTokens.spacing4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '• ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: Text(w, style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(MaterialLocalizations.of(dialogContext).okButtonLabel),
          ),
        ],
      ),
    );
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
