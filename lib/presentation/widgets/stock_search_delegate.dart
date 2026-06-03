import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/providers/providers.dart';

/// 全域股票搜尋 — Flutter `SearchDelegate` 標準入口。
///
/// 用法：
/// ```dart
/// final symbol = await showSearch<String?>(
///   context: context,
///   delegate: StockSearchDelegate(ref),
/// );
/// if (symbol != null && context.mounted) {
///   context.push(AppRoutes.stockDetail(symbol));
/// }
/// ```
///
/// 重用既有 `StockRepository.searchStocks()`，無新增 query / cache 邏輯。
/// 在使用者選擇股票時 close 帶回 symbol，導航由 caller 處理。
class StockSearchDelegate extends SearchDelegate<String?> {
  StockSearchDelegate(this.ref)
    : super(
        searchFieldLabel: 'stockSearch.hint'.tr(),
        textInputAction: TextInputAction.search,
      );

  /// 取得 [stockRepositoryProvider]。
  ///
  /// 必須是 `WidgetRef`（不是 `Ref`）—— SearchDelegate 在 widget tree 之外
  /// 建立，無法用 `ref.read` 取得 ConsumerWidget 的 ref。caller 由
  /// ConsumerStatefulWidget 的 `ref` 傳入。
  final WidgetRef ref;

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) => _buildResultsList(context);

  @override
  Widget buildResults(BuildContext context) => _buildResultsList(context);

  Widget _buildResultsList(BuildContext context) {
    return _DebouncedResults(
      query: query,
      ref: ref,
      onSelect: (symbol) => close(context, symbol),
    );
  }
}

/// 內部 debounced 結果列表 —— 300ms 對齊 `add_stock_dialog` 既有慣例，
/// 避免每個 keystroke 都打 DB（`stockMaster` LIKE scan 無 index）。
class _DebouncedResults extends StatefulWidget {
  const _DebouncedResults({
    required this.query,
    required this.ref,
    required this.onSelect,
  });

  final String query;
  final WidgetRef ref;
  final ValueChanged<String> onSelect;

  @override
  State<_DebouncedResults> createState() => _DebouncedResultsState();
}

class _DebouncedResultsState extends State<_DebouncedResults> {
  static const _debounce = Duration(milliseconds: 300);

  Timer? _debounceTimer;
  String _effectiveQuery = '';

  @override
  void initState() {
    super.initState();
    _effectiveQuery = widget.query.trim();
  }

  @override
  void didUpdateWidget(covariant _DebouncedResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.query.trim();
    if (next == _effectiveQuery) return;
    _debounceTimer?.cancel();
    if (next.isEmpty) {
      setState(() => _effectiveQuery = '');
      return;
    }
    _debounceTimer = Timer(_debounce, () {
      if (!mounted) return;
      setState(() => _effectiveQuery = next);
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_effectiveQuery.isEmpty) {
      return _EmptyHint(message: 'stockSearch.emptyHint'.tr());
    }

    final repo = widget.ref.read(stockRepositoryProvider);
    return FutureBuilder<List<StockMasterEntry>>(
      future: repo.searchStocks(_effectiveQuery),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _EmptyHint(message: 'stockSearch.error'.tr());
        }
        final results = (snapshot.data ?? []).take(20).toList();
        if (results.isEmpty) {
          return _EmptyHint(
            message: 'stockSearch.noMatch'.tr(
              namedArgs: {'query': _effectiveQuery},
            ),
          );
        }
        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final stock = results[index];
            return ListTile(
              leading: const Icon(Icons.show_chart),
              title: Text(
                '${stock.symbol}  ${stock.name}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                [
                  stock.market,
                  if (stock.industry != null && stock.industry!.isNotEmpty)
                    stock.industry,
                ].join(' · '),
              ),
              onTap: () => widget.onSelect(stock.symbol),
            );
          },
        );
      },
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spacing24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
