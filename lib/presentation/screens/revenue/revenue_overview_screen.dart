import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:afterclose/core/constants/app_routes.dart';
import 'package:afterclose/core/constants/market_codes.dart';
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/semantic_colors.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/core/utils/localized_number_format.dart';
import 'package:afterclose/data/database/dao/revenue_dao.dart';
import 'package:afterclose/presentation/providers/revenue_overview_provider.dart';
import 'package:afterclose/presentation/providers/watchlist_provider.dart';
import 'package:afterclose/presentation/widgets/empty_state.dart';
import 'package:afterclose/presentation/widgets/shimmer_loading.dart';
import 'package:afterclose/presentation/widgets/themed_refresh_indicator.dart';

/// 月營收總覽——資料中最新月份的**完整**已申報清單。
///
/// 設計要求(2026-08-05,四輪討論定稿):清單累積、完整、不被策展裁剪
/// ——排序與過濾都是使用者主動操作,預設顯示全量。公布期(每月上旬)
/// 清單逐日增長,頂部進度標明樣本範圍;月中後即為上月完整總表。
class RevenueOverviewScreen extends ConsumerStatefulWidget {
  const RevenueOverviewScreen({super.key});

  @override
  ConsumerState<RevenueOverviewScreen> createState() =>
      _RevenueOverviewScreenState();
}

class _RevenueOverviewScreenState extends ConsumerState<RevenueOverviewScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(revenueOverviewProvider.notifier).loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(revenueOverviewProvider);
    final watchlistSymbols = ref.watch(
      watchlistProvider.select((s) => s.items.map((i) => i.symbol).toSet()),
    );
    final theme = Theme.of(context);
    final overview = state.overview;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('revenueOverview.title'.tr()),
            if (overview != null)
              Text(
                'revenueOverview.monthLabel'.tr(
                  namedArgs: {
                    'year': '${overview.year}',
                    'month': '${overview.month}',
                  },
                ),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
      body: state.isLoading && overview == null
          ? const GenericListShimmer(itemCount: 10)
          : overview == null
          ? EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'revenueOverview.empty'.tr(),
            )
          : _buildList(state, overview, watchlistSymbols),
    );
  }

  Widget _buildList(
    RevenueOverviewState state,
    RevenueOverview overview,
    Set<String> watchlistSymbols,
  ) {
    final theme = Theme.of(context);
    final rows = state.visibleRows(watchlistSymbols);

    return ThemedRefreshIndicator(
      onRefresh: () => ref.read(revenueOverviewProvider.notifier).loadData(),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildProgressHeader(overview)),
          SliverToBoxAdapter(child: _buildControls(state)),
          if (rows.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.filter_alt_off_outlined,
                title: 'revenueOverview.noMatch'.tr(),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(bottom: DesignTokens.spacing24),
              sliver: SliverList.builder(
                itemCount: rows.length,
                itemBuilder: (context, index) =>
                    _buildRow(theme, rows[index], watchlistSymbols),
              ),
            ),
        ],
      ),
    );
  }

  /// 公布期進度:樣本範圍自明(「已公布 N 家中」——早申報樣本偏樂觀,
  /// 8/10 截止前的沉默本身就是資訊)
  Widget _buildProgressHeader(RevenueOverview overview) {
    final theme = Theme.of(context);
    final twseFiled = overview.filedByMarket[MarketCode.twse] ?? 0;
    final twseTotal = overview.activeByMarket[MarketCode.twse] ?? 0;
    final tpexFiled = overview.filedByMarket[MarketCode.tpex] ?? 0;
    final tpexTotal = overview.activeByMarket[MarketCode.tpex] ?? 0;
    final total = twseTotal + tpexTotal;
    final filed = twseFiled + tpexFiled;
    // 覆蓋率 >= 95% 視為完整月,不再顯示「公布中」進度
    final inProgress = total > 0 && filed / total < 0.95;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DesignTokens.spacing16,
        DesignTokens.spacing12,
        DesignTokens.spacing16,
        0,
      ),
      child: Text(
        inProgress
            ? 'revenueOverview.progressFiling'.tr(
                namedArgs: {
                  'twseFiled': '$twseFiled',
                  'twseTotal': '$twseTotal',
                  'tpexFiled': '$tpexFiled',
                  'tpexTotal': '$tpexTotal',
                },
              )
            : 'revenueOverview.progressComplete'.tr(
                namedArgs: {'count': '$filed'},
              ),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildControls(RevenueOverviewState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spacing16,
        vertical: DesignTokens.spacing8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: DesignTokens.spacing8,
            children: [
              for (final f in RevenueFilter.values)
                FilterChip(
                  label: Text('revenueOverview.filter.${f.name}'.tr()),
                  selected: state.filter == f,
                  onSelected: (_) =>
                      ref.read(revenueOverviewProvider.notifier).setFilter(f),
                ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacing8),
          SegmentedButton<RevenueSortBy>(
            segments: [
              for (final s in RevenueSortBy.values)
                ButtonSegment(
                  value: s,
                  label: Text('revenueOverview.sort.${s.name}'.tr()),
                ),
            ],
            selected: {state.sortBy},
            onSelectionChanged: (selection) => ref
                .read(revenueOverviewProvider.notifier)
                .setSortBy(selection.first),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(
    ThemeData theme,
    RevenueOverviewRow row,
    Set<String> watchlistSymbols,
  ) {
    final isWatched = watchlistSymbols.contains(row.symbol);
    // 營收單位千元 → 轉元再交給 compact(億/萬)
    final revenueLabel = LocalizedNumberFormat.compact(row.revenue * 1000);

    return InkWell(
      onTap: () => context.push(AppRoutes.stockDetail(row.symbol)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spacing16,
          vertical: DesignTokens.spacing8,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${row.symbol} ${row.name}',
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: isWatched
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (isWatched) ...[
                        const SizedBox(width: DesignTokens.spacing4),
                        Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                      if (row.isNewHigh) ...[
                        const SizedBox(width: DesignTokens.spacing4),
                        _newHighBadge(theme),
                      ],
                    ],
                  ),
                  Text(
                    revenueLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            _growthCell(
              theme,
              label: 'revenueOverview.momShort'.tr(),
              value: row.momGrowth,
            ),
            const SizedBox(width: DesignTokens.spacing12),
            _growthCell(
              theme,
              label: 'revenueOverview.yoyShort'.tr(),
              value: row.yoyGrowth,
            ),
          ],
        ),
      ),
    );
  }

  Widget _newHighBadge(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: AppTheme.upColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
      ),
      child: Text(
        'revenueOverview.newHigh'.tr(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: PriceColors.onTintOf(AppTheme.upColor, theme.brightness),
          fontSize: DesignTokens.fontSizeXs,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _growthCell(
    ThemeData theme, {
    required String label,
    required double? value,
  }) {
    final color = value == null
        ? theme.colorScheme.onSurfaceVariant
        : AppTheme.getPriceColor(value, theme.brightness);
    return SizedBox(
      width: 76,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: DesignTokens.fontSizeXs,
            ),
          ),
          Text(
            value == null
                ? '--'
                : '${value > 0 ? '+' : ''}${value.toStringAsFixed(1)}%',
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
