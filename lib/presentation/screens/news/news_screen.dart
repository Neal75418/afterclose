import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:afterclose/core/constants/app_routes.dart';
import 'package:afterclose/core/l10n/app_strings.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/providers/news_provider.dart';
import 'package:afterclose/presentation/widgets/empty_state.dart';
import 'package:afterclose/presentation/widgets/shimmer_loading.dart';
import 'package:afterclose/presentation/widgets/common/drag_handle.dart';
import 'package:afterclose/presentation/widgets/themed_refresh_indicator.dart';
import 'package:afterclose/core/theme/design_tokens.dart';

/// News screen - shows recent market news with filtering and grouping
class NewsScreen extends ConsumerStatefulWidget {
  const NewsScreen({super.key});

  @override
  ConsumerState<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends ConsumerState<NewsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(newsProvider.notifier).loadData();
    });
  }

  Future<void> _refresh() async {
    await ref.read(newsProvider.notifier).loadData();
    // Haptic feedback on refresh complete
    HapticFeedback.mediumImpact();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !{'http', 'https'}.contains(uri.scheme)) return;
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('無法開啟連結')));
      }
    }
  }

  void _showNewsPreview(NewsItemEntry item, List<String> relatedStocks) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Drag handle
            const DragHandle(margin: EdgeInsets.symmetric(vertical: 8)),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Source and time
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(
                              DesignTokens.radiusXs,
                            ),
                          ),
                          child: Text(
                            item.source,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatFullTime(item.publishedAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Title
                    Text(
                      item.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // Related stocks
                    if (relatedStocks.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        S.newsRelatedStocks,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: relatedStocks.map((symbol) {
                          return ActionChip(
                            label: Text(symbol),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Navigator.pop(context);
                              context.push(AppRoutes.stockDetail(symbol));
                            },
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // Open in browser button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _openUrl(item.url);
                        },
                        icon: const Icon(Icons.open_in_new),
                        label: const Text(S.newsOpenInBrowser),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(newsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(S.newsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: S.refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          // Source filter chips
          if (!state.isLoading && state.allNews.isNotEmpty)
            _SourceFilterChips(
              selectedSource: state.selectedSource,
              sourceCounts: state.sourceCounts,
              onSelected: (source) {
                ref.read(newsProvider.notifier).setSourceFilter(source);
              },
            ),
          // News list
          Expanded(
            child: ThemedRefreshIndicator(
              onRefresh: _refresh,
              child: state.isLoading
                  ? const NewsListShimmer(itemCount: 8)
                  : state.error != null
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: EmptyStates.error(
                          message: state.error!,
                          onRetry: _refresh,
                        ),
                      ),
                    )
                  : state.filteredNews.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: EmptyStates.noNews(),
                      ),
                    )
                  : _GroupedNewsList(
                      news: state.filteredNews,
                      newsStockMap: state.newsStockMap,
                      onTap: _showNewsPreview,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFullTime(DateTime dt) {
    return '${dt.year}/${dt.month}/${dt.day} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ==================================================
// Source Filter Chips
// ==================================================

class _SourceFilterChips extends StatelessWidget {
  const _SourceFilterChips({
    required this.selectedSource,
    required this.sourceCounts,
    required this.onSelected,
  });

  final NewsSource selectedSource;
  final Map<NewsSource, int> sourceCounts;
  final ValueChanged<NewsSource> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: NewsSource.values.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final source = NewsSource.values[index];
          final count = sourceCounts[source] ?? 0;
          final isSelected = source == selectedSource;

          // Skip sources with 0 news (except "all")
          if (count == 0 && source != NewsSource.all) {
            return const SizedBox.shrink();
          }

          return FilterChip(
            selected: isSelected,
            label: Text(
              source == NewsSource.all
                  ? '${source.label} ($count)'
                  : '${source.label} ($count)',
            ),
            labelStyle: theme.textTheme.labelMedium?.copyWith(
              color: isSelected
                  ? theme.colorScheme.onSecondaryContainer
                  : theme.colorScheme.onSurface,
            ),
            onSelected: (_) {
              HapticFeedback.selectionClick();
              onSelected(source);
            },
          );
        },
      ),
    );
  }
}

// ==================================================
// Grouped News List
// ==================================================

class _GroupedNewsList extends StatelessWidget {
  const _GroupedNewsList({
    required this.news,
    required this.newsStockMap,
    required this.onTap,
  });

  final List<NewsItemEntry> news;
  final Map<String, List<String>> newsStockMap;
  final void Function(NewsItemEntry, List<String>) onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // Group news by date
    final todayNews = <NewsItemEntry>[];
    final yesterdayNews = <NewsItemEntry>[];
    final earlierNews = <NewsItemEntry>[];

    for (final item in news) {
      final itemDate = DateTime(
        item.publishedAt.year,
        item.publishedAt.month,
        item.publishedAt.day,
      );

      if (itemDate == today) {
        todayNews.add(item);
      } else if (itemDate == yesterday) {
        yesterdayNews.add(item);
      } else {
        earlierNews.add(item);
      }
    }

    return ListView(
      children: [
        if (todayNews.isNotEmpty) ...[
          _SectionHeader(title: S.newsToday, count: todayNews.length),
          ...todayNews.map(
            (item) => _NewsListItem(
              item: item,
              relatedStocks: newsStockMap[item.id] ?? [],
              onTap: onTap,
            ),
          ),
        ],
        if (yesterdayNews.isNotEmpty) ...[
          _SectionHeader(title: S.newsYesterday, count: yesterdayNews.length),
          ...yesterdayNews.map(
            (item) => _NewsListItem(
              item: item,
              relatedStocks: newsStockMap[item.id] ?? [],
              onTap: onTap,
            ),
          ),
        ],
        if (earlierNews.isNotEmpty) ...[
          _SectionHeader(title: S.newsEarlier, count: earlierNews.length),
          ...earlierNews.map(
            (item) => _NewsListItem(
              item: item,
              relatedStocks: newsStockMap[item.id] ?? [],
              onTap: onTap,
            ),
          ),
        ],
      ],
    );
  }
}

// ==================================================
// Section Header
// ==================================================

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceContainerLow,
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================================================
// News List Item
// ==================================================

class _NewsListItem extends StatelessWidget {
  const _NewsListItem({
    required this.item,
    required this.relatedStocks,
    required this.onTap,
  });

  final NewsItemEntry item;
  final List<String> relatedStocks;
  final void Function(NewsItemEntry, List<String>) onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const maxVisibleStocks = 3;
    final hasMoreStocks = relatedStocks.length > maxVisibleStocks;

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap(item, relatedStocks);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            // Source and time
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(DesignTokens.radiusXs),
                  ),
                  child: Text(
                    item.source,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatTime(item.publishedAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            // Related stocks
            if (relatedStocks.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  ...relatedStocks.take(maxVisibleStocks).map((symbol) {
                    return _StockChip(
                      symbol: symbol,
                      onTap: () => context.push(AppRoutes.stockDetail(symbol)),
                    );
                  }),
                  if (hasMoreStocks)
                    _StockChip(
                      symbol: '+${relatedStocks.length - maxVisibleStocks}',
                      isOverflow: true,
                      onTap: () => onTap(item, relatedStocks),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 60) {
      return S.newsMinutesAgo(diff.inMinutes);
    } else if (diff.inHours < 24) {
      return S.newsHoursAgo(diff.inHours);
    } else if (diff.inDays < 7) {
      return S.newsDaysAgo(diff.inDays);
    } else {
      return '${dt.month}/${dt.day}';
    }
  }
}

// ==================================================
// Stock Chip
// ==================================================

class _StockChip extends StatelessWidget {
  const _StockChip({
    required this.symbol,
    required this.onTap,
    this.isOverflow = false,
  });

  final String symbol;
  final VoidCallback onTap;
  final bool isOverflow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isOverflow
              ? theme.colorScheme.tertiaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        ),
        child: Text(
          symbol,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isOverflow
                ? theme.colorScheme.onTertiaryContainer
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: isOverflow ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
