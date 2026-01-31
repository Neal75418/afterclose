import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/providers/providers.dart';
import 'package:afterclose/presentation/providers/watchlist_provider.dart';

/// Bottom sheet for searching and selecting stocks to compare.
class StockPickerSheet extends ConsumerStatefulWidget {
  const StockPickerSheet({super.key, required this.existingSymbols});

  final List<String> existingSymbols;

  @override
  ConsumerState<StockPickerSheet> createState() => _StockPickerSheetState();
}

class _StockPickerSheetState extends ConsumerState<StockPickerSheet> {
  final _searchController = TextEditingController();
  List<StockMasterEntry> _searchResults = [];
  Timer? _debounce;
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    final db = ref.read(databaseProvider);
    final results = await db.searchStocks(query);
    if (mounted) {
      setState(() {
        _searchResults = results
            .where((s) => !widget.existingSymbols.contains(s.symbol))
            .take(20)
            .toList();
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final watchlistState = ref.watch(watchlistProvider);
    final watchlistSymbols = watchlistState.items
        .where((item) => !widget.existingSymbols.contains(item.symbol))
        .take(10)
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Search field
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'comparison.searchHint'.tr(),
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: _onSearchChanged,
              ),
            ),

            // Content
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _searchController.text.isNotEmpty
                  ? _buildSearchResults(theme)
                  : _buildWatchlistShortcuts(theme, watchlistSymbols),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchResults(ThemeData theme) {
    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          'comparison.noData'.tr(),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final stock = _searchResults[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              stock.symbol.substring(0, stock.symbol.length.clamp(0, 2)),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          title: Text(stock.symbol),
          subtitle: Text(stock.name),
          trailing: Text(stock.market, style: theme.textTheme.labelSmall),
          onTap: () => Navigator.of(context).pop(stock.symbol),
        );
      },
    );
  }

  Widget _buildWatchlistShortcuts(
    ThemeData theme,
    List<WatchlistItemData> items,
  ) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'comparison.searchHint'.tr(),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'comparison.fromWatchlist'.tr(),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    item.symbol.substring(0, item.symbol.length.clamp(0, 2)),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                title: Text(item.symbol),
                subtitle: Text(item.stockName ?? ''),
                onTap: () => Navigator.of(context).pop(item.symbol),
              );
            },
          ),
        ),
      ],
    );
  }
}
