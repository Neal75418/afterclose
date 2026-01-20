import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:afterclose/presentation/providers/scan_provider.dart';
import 'package:afterclose/presentation/widgets/stock_card.dart';

/// Scan screen - shows all analyzed stocks with filters
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(scanProvider.notifier).loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scanProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('市場掃描'),
        actions: [
          PopupMenuButton<ScanSort>(
            icon: const Icon(Icons.sort),
            tooltip: '排序',
            initialValue: state.sort,
            onSelected: (sort) {
              ref.read(scanProvider.notifier).setSort(sort);
            },
            itemBuilder: (context) {
              return ScanSort.values.map((sort) {
                return PopupMenuItem(
                  value: sort,
                  child: Row(
                    children: [
                      if (state.sort == sort)
                        const Icon(Icons.check, size: 18)
                      else
                        const SizedBox(width: 18),
                      const SizedBox(width: 8),
                      Text(sort.label),
                    ],
                  ),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(scanProvider.notifier).loadData(),
        child: Column(
          children: [
            // Filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: ScanFilter.values.map((filter) {
                  final isSelected = state.filter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(filter.label),
                      selected: isSelected,
                      onSelected: (_) {
                        ref.read(scanProvider.notifier).setFilter(filter);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            // Stock count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    '共 ${state.stocks.length} 檔',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // Stock list
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(state.error!),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () {
                              ref.read(scanProvider.notifier).loadData();
                            },
                            child: const Text('重試'),
                          ),
                        ],
                      ),
                    )
                  : state.stocks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '無符合條件的股票',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: state.stocks.length,
                      itemBuilder: (context, index) {
                        final stock = state.stocks[index];
                        return StockCard(
                          symbol: stock.symbol,
                          stockName: stock.stockName,
                          latestClose: stock.latestClose,
                          priceChange: stock.priceChange,
                          score: stock.score,
                          reasons: stock.reasons
                              .map((r) => r.reasonType)
                              .toList(),
                          trendState: stock.trendState,
                          isInWatchlist: stock.isInWatchlist,
                          onTap: () => context.push('/stock/${stock.symbol}'),
                          onWatchlistTap: () {
                            ref
                                .read(scanProvider.notifier)
                                .toggleWatchlist(stock.symbol);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
