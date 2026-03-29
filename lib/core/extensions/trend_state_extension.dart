import 'package:flutter/material.dart';

import 'package:afterclose/core/constants/rule_enums.dart';
import 'package:afterclose/core/theme/app_theme.dart';

/// 趨勢狀態擴展
///
/// 統一處理 'UP' / 'DOWN' / 'SIDEWAYS' 等趨勢狀態的對應邏輯，
/// 避免在多處重複相同的 switch 語句。
///
/// 使用範例:
/// ```dart
/// final trend = 'UP';
/// print(trend.trendEmoji);       // 📈
/// print(trend.trendIconData);    // Icons.trending_up_rounded
/// print(trend.trendColor);       // AppTheme.upColor
/// print(trend.trendKey);         // 'up'
/// ```
extension TrendStateExtension on String? {
  /// 趨勢表情符號
  ///
  /// - UP: 📈
  /// - DOWN: 📉
  /// - 其他: ➡️
  String get trendEmoji {
    return switch (this) {
      TrendState.upCode => '📈',
      TrendState.downCode => '📉',
      _ => '➡️',
    };
  }

  /// 趨勢 Material 圖示
  ///
  /// - UP: trending_up_rounded
  /// - DOWN: trending_down_rounded
  /// - 其他: trending_flat_rounded
  IconData get trendIconData {
    return switch (this) {
      TrendState.upCode => Icons.trending_up_rounded,
      TrendState.downCode => Icons.trending_down_rounded,
      _ => Icons.trending_flat_rounded,
    };
  }

  /// 趨勢顏色
  ///
  /// - UP: AppTheme.upColor (紅色)
  /// - DOWN: AppTheme.downColor (綠色)
  /// - 其他: AppTheme.neutralColor (灰色)
  Color get trendColor {
    return switch (this) {
      TrendState.upCode => AppTheme.upColor,
      TrendState.downCode => AppTheme.downColor,
      _ => AppTheme.neutralColor,
    };
  }

  /// 趨勢 i18n 鍵值
  ///
  /// 用於翻譯查詢，如 'trend.$trendKey'.tr()
  ///
  /// - UP: 'up'
  /// - DOWN: 'down'
  /// - 其他: 'sideways'
  String get trendKey {
    return switch (this) {
      TrendState.upCode => 'up',
      TrendState.downCode => 'down',
      _ => 'sideways',
    };
  }
}
