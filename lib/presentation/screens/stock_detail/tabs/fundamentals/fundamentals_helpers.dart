import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/design_tokens.dart';

/// 基本面區塊共用的輔助 Widget。

/// 建立成長率標章，以顏色區分漲跌。
///
/// 正成長使用 [AppTheme.upColor]，負成長使用 [AppTheme.downColor]。
/// 絕對值 >= 10% 時加上底色與粗體。
Widget buildGrowthBadge(BuildContext context, double? growth) {
  final theme = Theme.of(context);

  if (growth == null) {
    return Text(
      '-',
      textAlign: TextAlign.end,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.outline,
      ),
    );
  }

  final isPositive = growth >= 0;
  final color = isPositive ? AppTheme.upColor : AppTheme.downColor;
  final prefix = isPositive ? '+' : '';
  final isSignificant = growth.abs() >= 10;

  return Align(
    alignment: Alignment.centerRight,
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spacing6,
        vertical: DesignTokens.spacing2,
      ),
      decoration: BoxDecoration(
        color: isSignificant
            ? color.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(DesignTokens.radiusXs),
      ),
      child: Text(
        '$prefix${growth.toStringAsFixed(1)}%',
        style: TextStyle(
          fontSize: DesignTokens.fontSizeSm,
          fontWeight: isSignificant ? FontWeight.bold : FontWeight.w500,
          color: color,
        ),
      ),
    ),
  );
}

/// 建立載入中佔位元件，置中顯示圓形進度指示器。
Widget buildLoadingState(BuildContext context) {
  final theme = Theme.of(context);

  return Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
    ),
    child: const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}

/// 建立空狀態佔位元件，顯示 [message]。
Widget buildEmptyState(BuildContext context, String message) {
  final theme = Theme.of(context);

  return Container(
    padding: const EdgeInsets.symmetric(
      vertical: DesignTokens.spacing32,
      horizontal: DesignTokens.spacing24,
    ),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
    ),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: DesignTokens.iconSizeXl,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: DesignTokens.spacing8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    ),
  );
}

/// 回傳資料表的交替列背景色。
///
/// Index 0 使用主色容器色調高亮；偶數索引使用 [surface]；奇數索引透明。
Color? getRowColor(BuildContext context, int index) {
  final theme = Theme.of(context);

  if (index == 0) {
    return theme.colorScheme.primaryContainer.withValues(alpha: 0.3);
  }
  if (index.isEven) {
    return theme.colorScheme.surface;
  }
  return Colors.transparent;
}

// ==================================================
// 表格結構輔助
// ==================================================

/// 建立資料表的樣式化標題列。
Widget buildTableHeader(BuildContext context, List<Widget> columns) {
  final theme = Theme.of(context);
  return Container(
    padding: const EdgeInsets.symmetric(
      vertical: DesignTokens.spacing8,
      horizontal: DesignTokens.spacing4,
    ),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
    ),
    child: Row(children: columns),
  );
}

/// 建立單一標題欄位，使用一致的樣式。
Widget buildHeaderCell(
  BuildContext context,
  String label, {
  int flex = 2,
  TextAlign? textAlign,
}) {
  final theme = Theme.of(context);
  return Expanded(
    flex: flex,
    child: Text(
      label,
      textAlign: textAlign,
      style: theme.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.outline,
      ),
    ),
  );
}

/// 建立資料列容器，使用交替列背景色。
Widget buildTableDataRow(
  BuildContext context,
  int index,
  List<Widget> columns,
) {
  return Container(
    padding: const EdgeInsets.symmetric(
      vertical: DesignTokens.spacing8,
      horizontal: DesignTokens.spacing4,
    ),
    decoration: BoxDecoration(
      color: getRowColor(context, index),
      borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
    ),
    child: Row(children: columns),
  );
}
