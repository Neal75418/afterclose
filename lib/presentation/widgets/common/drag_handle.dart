import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/design_tokens.dart';

/// Bottom sheet 頂部的拖曳指示條
///
/// 統一所有 bottom sheet 的 drag handle 樣式。
/// [margin] 可自訂外距，預設為 `EdgeInsets.only(top: 12)`。
class DragHandle extends StatelessWidget {
  const DragHandle({
    super.key,
    this.margin = const EdgeInsets.only(top: DesignTokens.spacing12),
  });

  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Container(
        margin: margin,
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          // WCAG 1.4.11 裝飾豁免：拖曳把手是慣例位置的冗餘 affordance
          //（sheet 可由手勢下滑／scrim 點擊關閉），不傳達相鄰內容沒有的
          // 資訊，刻意維持低對比（實測 1.75~2.10:1）以不搶內容視覺
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
