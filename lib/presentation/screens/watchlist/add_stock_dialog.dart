import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/presentation/providers/providers.dart';
import 'package:afterclose/presentation/providers/watchlist_provider.dart';

/// 顯示新增自選股對話框
///
/// 支援代號或中文名稱搜尋，輸入 2 字元後顯示候選清單。
/// 選中候選項後直接加入自選清單。
void showAddStockDialog({
  required BuildContext context,
  required WidgetRef ref,
}) {
  final messenger = ScaffoldMessenger.of(context);
  final parentContext = context;

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return _AddStockDialogContent(
        ref: ref,
        dialogContext: dialogContext,
        messenger: messenger,
        parentContext: parentContext,
      );
    },
  );
}

class _AddStockDialogContent extends StatefulWidget {
  const _AddStockDialogContent({
    required this.ref,
    required this.dialogContext,
    required this.messenger,
    required this.parentContext,
  });

  final WidgetRef ref;
  final BuildContext dialogContext;
  final ScaffoldMessengerState messenger;
  final BuildContext parentContext;

  @override
  State<_AddStockDialogContent> createState() => _AddStockDialogContentState();
}

class _AddStockDialogContentState extends State<_AddStockDialogContent> {
  final _controller = TextEditingController();
  List<StockMasterEntry> _searchResults = [];
  bool _isSearching = false;
  bool _isAdding = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);
    final db = widget.ref.read(databaseProvider);
    final results = await db.searchStocks(query);
    if (mounted) {
      setState(() {
        _searchResults = results.take(8).toList();
        _isSearching = false;
      });
    }
  }

  Future<void> _addStock(String symbol) async {
    setState(() => _isAdding = true);

    final notifier = widget.ref.read(watchlistProvider.notifier);
    final success = await notifier.addStock(symbol);

    if (!widget.dialogContext.mounted) return;
    Navigator.pop(widget.dialogContext);

    if (widget.parentContext.mounted) {
      widget.messenger.clearSnackBars();
      if (success) {
        widget.messenger.showSnackBar(
          SnackBar(
            content: Text('watchlist.added'.tr(namedArgs: {'symbol': symbol})),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        widget.messenger.showSnackBar(
          SnackBar(
            content: Text(
              'watchlist.notFound'.tr(namedArgs: {'symbol': symbol}),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(widget.parentContext).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text('watchlist.addDialog'.tr()),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'watchlist.symbolLabel'.tr(),
                hintText: 'watchlist.searchHint'.tr(),
                prefixIcon: const Icon(Icons.search),
              ),
              autofocus: true,
              enabled: !_isAdding,
              onChanged: _onSearchChanged,
            ),
            if (_isSearching)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            if (_searchResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final stock = _searchResults[index];
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          stock.market == 'TPEx' ? '櫃' : '市',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      title: Text(
                        '${stock.symbol} ${stock.name}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: stock.industry != null
                          ? Text(
                              stock.industry!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            )
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          DesignTokens.radiusMd,
                        ),
                      ),
                      onTap: _isAdding ? null : () => _addStock(stock.symbol),
                    );
                  },
                ),
              ),
            ],
            if (!_isSearching &&
                _searchResults.isEmpty &&
                _controller.text.length >= 2)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'watchlist.noMatching'.tr(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isAdding
              ? null
              : () => Navigator.pop(widget.dialogContext),
          child: Text('common.cancel'.tr()),
        ),
      ],
    );
  }
}
