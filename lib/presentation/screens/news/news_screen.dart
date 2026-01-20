import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:afterclose/presentation/providers/news_provider.dart';
import 'package:afterclose/presentation/widgets/empty_state.dart';
import 'package:afterclose/presentation/widgets/shimmer_loading.dart';

/// News screen - shows recent market news
class NewsScreen extends ConsumerStatefulWidget {
  const NewsScreen({super.key});

  @override
  ConsumerState<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends ConsumerState<NewsScreen> {
  @override
  void initState() {
    super.initState();
    // Load data on first build
    Future.microtask(() {
      ref.read(newsProvider.notifier).loadData();
    });
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(newsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('市場新聞'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(newsProvider.notifier).loadData(),
            tooltip: '重新整理',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(newsProvider.notifier).loadData(),
        child: state.isLoading
            ? const StockListShimmer(itemCount: 8)
            : state.error != null
            // Wrap in scrollable so RefreshIndicator works on error state
            ? SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: EmptyStates.error(
                    message: state.error!,
                    onRetry: () => ref.read(newsProvider.notifier).loadData(),
                  ),
                ),
              )
            : state.news.isEmpty
            // Wrap in scrollable so RefreshIndicator works on empty state
            ? SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: EmptyStates.noNews(),
                ),
              )
            : ListView.separated(
                itemCount: state.news.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = state.news[index];
                  final relatedStocks = state.newsStockMap[item.id] ?? [];

                  return ListTile(
                    title: Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
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
                          ],
                        ),
                        if (relatedStocks.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            children: relatedStocks.take(3).map((symbol) {
                              return ActionChip(
                                label: Text(symbol),
                                labelStyle: theme.textTheme.labelSmall,
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  context.push('/stock/$symbol');
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                    trailing: const Icon(Icons.open_in_new, size: 16),
                    onTap: () => _openUrl(item.url),
                  );
                },
              ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} 分鐘前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} 小時前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} 天前';
    } else {
      return '${dt.month}/${dt.day}';
    }
  }
}
