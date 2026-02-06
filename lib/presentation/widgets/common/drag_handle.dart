import 'package:flutter/material.dart';

/// Bottom sheet 頂部的拖曳指示條
///
/// 統一所有 bottom sheet 的 drag handle 樣式。
/// [margin] 可自訂外距，預設為 `EdgeInsets.only(top: 12)`。
class DragHandle extends StatelessWidget {
  const DragHandle({super.key, this.margin = const EdgeInsets.only(top: 12)});

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
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
