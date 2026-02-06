import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/data/database/app_database.dart';

/// 水平 Chip 列：顯示已選股票並提供移除按鈕
class ComparisonHeader extends StatelessWidget {
  const ComparisonHeader({
    super.key,
    required this.symbols,
    required this.stocksMap,
    required this.canAddMore,
    required this.onRemove,
    required this.onAdd,
  });

  final List<String> symbols;
  final Map<String, StockMasterEntry> stocksMap;
  final bool canAddMore;
  final void Function(String symbol) onRemove;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (var i = 0; i < symbols.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _StockChip(
                symbol: symbols[i],
                name: stocksMap[symbols[i]]?.name ?? '',
                color: DesignTokens
                    .chartPalette[i % DesignTokens.chartPalette.length],
                onRemove: () => onRemove(symbols[i]),
              ),
            ),
          if (canAddMore)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: Text('comparison.addStock'.tr()),
                onPressed: onAdd,
              ),
            ),
        ],
      ),
    );
  }
}

class _StockChip extends StatelessWidget {
  const _StockChip({
    required this.symbol,
    required this.name,
    required this.color,
    required this.onRemove,
  });

  final String symbol;
  final String name;
  final Color color;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = name.length > 4 ? name.substring(0, 4) : name;

    return Chip(
      avatar: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      label: Text('$symbol $displayName', style: theme.textTheme.labelMedium),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: onRemove,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}
