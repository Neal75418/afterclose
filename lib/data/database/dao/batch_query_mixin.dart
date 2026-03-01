part of '../app_database.dart';

/// 批次查詢通用工具類
///
/// 提供可重用的分組方法，避免重複代碼。
class _BatchQueryHelper {
  /// 依 symbol 分組輔助方法
  ///
  /// 將查詢結果列表依 symbol 分組成 Map。
  ///
  /// [items] - 要分組的項目列表
  /// [getSymbol] - 從項目中提取 symbol 的函數
  ///
  /// 返回 Map<String, List<E>>，其中 key 是 symbol，value 是該 symbol 的所有項目
  ///
  /// 使用範例：
  /// ```dart
  /// final results = await query.get();
  /// final grouped = _BatchQueryHelper.groupBySymbol(results, (e) => e.symbol);
  /// ```
  static Map<String, List<E>> groupBySymbol<E>(
    List<E> items,
    String Function(E) getSymbol,
  ) {
    final grouped = <String, List<E>>{};
    for (final item in items) {
      grouped.putIfAbsent(getSymbol(item), () => []).add(item);
    }
    return grouped;
  }
}
