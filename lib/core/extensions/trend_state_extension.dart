import 'package:flutter/material.dart';

import 'package:afterclose/core/constants/rule_enums.dart';
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/semantic_colors.dart';

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
/// print(trend.trendColorFor(Brightness.dark)); // AppTheme.upColor
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

  /// 趨勢顏色（依主題解析）
  ///
  /// - UP: 上漲紅
  /// - DOWN: 下跌綠 —— 淺色主題自動改用較深的 `PriceColors.downOnLight`
  /// - 其他: 平盤灰 —— 淺色主題自動改用較深的 `PriceColors.flatOnLight`
  ///
  /// 曾是不帶參數的 `trendColor` getter，恆回傳深色主題的色值：淺色主題下
  /// 的下跌綢 `#2ED573` 對白底僅 1.93:1、平盤 `#A1A1A1` 僅 2.58:1，
  /// 兩者皆低於圖形物件 3.0:1 門檻（此 getter 的兩個消費端都是圖示）。
  Color trendColorFor(Brightness brightness) {
    return switch (this) {
      TrendState.upCode => AppTheme.upColor,
      TrendState.downCode => PriceColors.downFor(brightness),
      _ => PriceColors.flatFor(brightness),
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
