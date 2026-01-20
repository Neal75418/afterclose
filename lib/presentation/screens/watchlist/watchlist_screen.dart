import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:afterclose/presentation/providers/providers.dart';

/// Watchlist screen - shows user's selected stocks
class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({super.key});

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen> {
  List<WatchlistItemData> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final db = ref.read(databaseProvider);
      final today = DateTime.now();
      final normalizedToday = DateTime.utc(today.year, today.month, today.day);

      final watchlist = await db.getWatchlist();
      final items = <WatchlistItemData>[];

      for (final item in watchlist) {
        final stock = await db.getStock(item.symbol);
        final latestPrice = await db.getLatestPrice(item.symbol);
        final analysis = await db.getAnalysis(item.symbol, normalizedToday);
        final reasons = await db.getReasons(item.symbol, normalizedToday);

        // Calculate price change
        double? priceChange;
        if (latestPrice?.close != null) {
          final history = await db.getPriceHistory(
            item.symbol,
            startDate: normalizedToday.subtract(const Duration(days: 5)),
            endDate: normalizedToday,
          );
          if (history.length >= 2) {
            final prevClose = history[history.length - 2].close;
            if (prevClose != null && prevClose > 0) {
              priceChange =
                  ((latestPrice!.close! - prevClose) / prevClose) * 100;
            }
          }
        }

        items.add(
          WatchlistItemData(
            symbol: item.symbol,
            stockName: stock?.name,
            latestClose: latestPrice?.close,
            priceChange: priceChange,
            trendState: analysis?.trendState,
            score: analysis?.score,
            hasSignal: reasons.isNotEmpty,
            addedAt: item.createdAt,
          ),
        );
      }

      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _removeFromWatchlist(String symbol) async {
    final db = ref.read(databaseProvider);
    await db.removeFromWatchlist(symbol);

    setState(() {
      _items.removeWhere((item) => item.symbol == symbol);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已從自選移除 $symbol'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: '復原',
            onPressed: () async {
              await db.addToWatchlist(symbol);
              _loadData();
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('自選股票'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddDialog,
            tooltip: '新增股票',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
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
                    Text(_error!),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _loadData, child: const Text('重試')),
                  ],
                ),
              )
            : _items.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.star_outline,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '尚無自選股票',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '點擊右上角 + 新增股票',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return _buildWatchlistTile(item);
                },
              ),
      ),
    );
  }

  Widget _buildWatchlistTile(WatchlistItemData item) {
    final theme = Theme.of(context);
    final isPositive = (item.priceChange ?? 0) >= 0;
    final priceColor = isPositive ? Colors.red.shade700 : Colors.green.shade700;

    return Dismissible(
      key: Key(item.symbol),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _removeFromWatchlist(item.symbol),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: item.hasSignal
                ? Colors.amber.withValues(alpha: 0.2)
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(item.statusIcon, style: const TextStyle(fontSize: 20)),
          ),
        ),
        title: Row(
          children: [
            Text(
              item.symbol,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (item.score != null && item.score! > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${item.score!.toInt()}分',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: item.stockName != null ? Text(item.stockName!) : null,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (item.latestClose != null)
              Text(
                item.latestClose!.toStringAsFixed(2),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            if (item.priceChange != null)
              Text(
                '${isPositive ? '+' : ''}${item.priceChange!.toStringAsFixed(2)}%',
                style: TextStyle(color: priceColor, fontSize: 12),
              ),
          ],
        ),
        onTap: () => context.push('/stock/${item.symbol}'),
      ),
    );
  }

  void _showAddDialog() {
    final controller = TextEditingController();
    // Capture the messenger before showing dialog
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('新增自選'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: '股票代號',
              hintText: '例如: 2330',
            ),
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final symbol = controller.text.trim().toUpperCase();
                if (symbol.isEmpty) return;

                Navigator.pop(dialogContext);

                final db = ref.read(databaseProvider);

                // Check if stock exists
                final stock = await db.getStock(symbol);
                if (stock == null) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('找不到股票 $symbol'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                  return;
                }

                await db.addToWatchlist(symbol);
                _loadData();

                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('已加入 $symbol'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('新增'),
            ),
          ],
        );
      },
    );
  }
}

/// Data class for watchlist item
class WatchlistItemData {
  const WatchlistItemData({
    required this.symbol,
    this.stockName,
    this.latestClose,
    this.priceChange,
    this.trendState,
    this.score,
    this.hasSignal = false,
    this.addedAt,
  });

  final String symbol;
  final String? stockName;
  final double? latestClose;
  final double? priceChange;
  final String? trendState;
  final double? score;
  final bool hasSignal;
  final DateTime? addedAt;

  String get statusIcon {
    if (hasSignal) return '🔥';
    if (priceChange != null && priceChange!.abs() >= 3) return '👀';
    return '😴';
  }
}
