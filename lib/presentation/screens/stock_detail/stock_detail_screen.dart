import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/presentation/providers/stock_detail_provider.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/alerts_tab.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/chip_tab.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/fundamentals_tab.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical_tab.dart';
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
    _tabController = TabController(length: 4, vsync: this);
    Future.microtask(() {
      ref.read(stockDetailProvider(widget.symbol).notifier).loadData();
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

    return Scaffold(
      body: state.isLoading
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
                // App bar
                SliverAppBar(
                  pinned: true,
                  floating: true,
                  title: Text(widget.symbol),
                  actions: [
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

                // Tab bar (pinned)
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
                  AlertsTab(symbol: widget.symbol),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(StockDetailState state, ThemeData theme) {
    final priceChange = state.priceChange;
    final isPositive = (priceChange ?? 0) >= 0;
    final priceColor = AppTheme.getPriceColor(priceChange);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
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
                    Text(
                      state.stock?.name ?? widget.symbol,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
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
                              _translateReasonCode(reason.reasonType),
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
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
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
                label: 'trend.${_getTrendKey(state.analysis?.trendState)}'.tr(),
                icon: _getTrendIcon(state.analysis?.trendState),
                color: _getTrendColor(state.analysis?.trendState),
              ),
              const SizedBox(width: 8),
              if (state.analysis?.supportLevel != null)
                _buildLevelChip(
                  theme: theme,
                  label: 'stockDetail.support'.tr(),
                  value: state.analysis!.supportLevel!,
                  color: AppTheme.downColor,
                ),
              const SizedBox(width: 8),
              if (state.analysis?.resistanceLevel != null)
                _buildLevelChip(
                  theme: theme,
                  label: 'stockDetail.resistance'.tr(),
                  value: state.analysis!.resistanceLevel!,
                  color: AppTheme.upColor,
                ),
            ],
          ),
        ],
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

  String _getTrendKey(String? trend) {
    return switch (trend) {
      'UP' => 'up',
      'DOWN' => 'down',
      _ => 'sideways',
    };
  }

  IconData _getTrendIcon(String? trend) {
    return switch (trend) {
      'UP' => Icons.trending_up,
      'DOWN' => Icons.trending_down,
      _ => Icons.trending_flat,
    };
  }

  Color _getTrendColor(String? trend) {
    return switch (trend) {
      'UP' => AppTheme.upColor,
      'DOWN' => AppTheme.downColor,
      _ => Colors.grey,
    };
  }

  String _translateReasonCode(String code) {
    final key = switch (code) {
      // Core signals
      'REVERSAL_W2S' => 'reasons.reversalW2S',
      'REVERSAL_S2W' => 'reasons.reversalS2W',
      'TECH_BREAKOUT' => 'reasons.breakout',
      'TECH_BREAKDOWN' => 'reasons.breakdown',
      'VOLUME_SPIKE' => 'reasons.volumeSpike',
      'PRICE_SPIKE' => 'reasons.priceSpike',
      'INSTITUTIONAL_SHIFT' => 'reasons.institutional',
      'NEWS_RELATED' => 'reasons.news',
      // KD signals
      'KD_GOLDEN_CROSS' => 'reasons.kdGoldenCross',
      'KD_DEATH_CROSS' => 'reasons.kdDeathCross',
      // Institutional streaks
      'INSTITUTIONAL_BUY_STREAK' => 'reasons.institutionalBuyStreak',
      'INSTITUTIONAL_SELL_STREAK' => 'reasons.institutionalSellStreak',
      // Candlestick patterns
      'PATTERN_DOJI' => 'reasons.patternDoji',
      'PATTERN_BULLISH_ENGULFING' => 'reasons.patternBullishEngulfing',
      'PATTERN_BEARISH_ENGULFING' => 'reasons.patternBearishEngulfing',
      'PATTERN_HAMMER' => 'reasons.patternHammer',
      'PATTERN_HANGING_MAN' => 'reasons.patternHangingMan',
      'PATTERN_MORNING_STAR' => 'reasons.patternMorningStar',
      'PATTERN_EVENING_STAR' => 'reasons.patternEveningStar',
      'PATTERN_THREE_WHITE_SOLDIERS' => 'reasons.patternThreeWhiteSoldiers',
      'PATTERN_THREE_BLACK_CROWS' => 'reasons.patternThreeBlackCrows',
      'PATTERN_GAP_UP' => 'reasons.patternGapUp',
      'PATTERN_GAP_DOWN' => 'reasons.patternGapDown',
      // Phase 3: 52-week and MA signals
      'WEEK_52_HIGH' => 'reasons.week52High',
      'WEEK_52_LOW' => 'reasons.week52Low',
      'MA_ALIGNMENT_BULLISH' => 'reasons.maAlignmentBullish',
      'MA_ALIGNMENT_BEARISH' => 'reasons.maAlignmentBearish',
      'RSI_EXTREME_OVERBOUGHT' => 'reasons.rsiExtremeOverbought',
      'RSI_EXTREME_OVERSOLD' => 'reasons.rsiExtremeOversold',
      // Phase 4: Extended market data signals
      'FOREIGN_SHAREHOLDING_INCREASING' => 'reasons.foreignShareholdingIncreasing',
      'FOREIGN_SHAREHOLDING_DECREASING' => 'reasons.foreignShareholdingDecreasing',
      'DAY_TRADING_HIGH' => 'reasons.dayTradingHigh',
      'DAY_TRADING_EXTREME' => 'reasons.dayTradingExtreme',
      'CONCENTRATION_HIGH' => 'reasons.concentrationHigh',
      // Phase 5: Price-volume divergence
      'PRICE_VOLUME_BULLISH_DIVERGENCE' => 'reasons.priceVolumeBullishDivergence',
      'PRICE_VOLUME_BEARISH_DIVERGENCE' => 'reasons.priceVolumeBearishDivergence',
      'HIGH_VOLUME_BREAKOUT' => 'reasons.highVolumeBreakout',
      'LOW_VOLUME_ACCUMULATION' => 'reasons.lowVolumeAccumulation',
      // Phase 6: Fundamental signals
      'REVENUE_YOY_SURGE' => 'reasons.revenueYoySurge',
      'REVENUE_YOY_DECLINE' => 'reasons.revenueYoyDecline',
      'REVENUE_MOM_GROWTH' => 'reasons.revenueMomGrowth',
      'HIGH_DIVIDEND_YIELD' => 'reasons.highDividendYield',
      'PE_UNDERVALUED' => 'reasons.peUndervalued',
      'PE_OVERVALUED' => 'reasons.peOvervalued',
      'PBR_UNDERVALUED' => 'reasons.pbrUndervalued',
      _ => code,
    };
    return key.tr();
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
    return Container(
      color: theme.colorScheme.surface,
      child: TabBar(
        controller: tabController,
        labelColor: theme.colorScheme.primary,
        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        indicatorColor: theme.colorScheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 14,
        ),
        tabs: [
          Tab(text: 'stockDetail.tabTechnical'.tr()),
          Tab(text: 'stockDetail.tabChip'.tr()),
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
