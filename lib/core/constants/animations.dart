import 'package:flutter/widgets.dart';

/// 標準化動畫時長，確保 UI 轉場一致性
///
/// 使用範例：
/// ```dart
/// AnimatedContainer(
///   duration: AnimDurations.fast,
///   curve: AnimCurves.standard,
///   // ...
/// )
/// ```
abstract final class AnimDurations {
  /// 極快速：微互動（按壓回饋、漣漪效果）- 100ms
  static const press = Duration(milliseconds: 100);

  /// 快速：快速狀態切換（開關、高亮）- 150ms
  static const fast = Duration(milliseconds: 150);

  /// 標準：大多數動畫（淡入淡出、滑動）- 200ms
  static const standard = Duration(milliseconds: 200);

  /// 中等：較從容的動畫（頁面轉場）- 300ms
  static const medium = Duration(milliseconds: 300);

  /// 緩慢：強調或複雜動畫 - 400ms
  static const slow = Duration(milliseconds: 400);

  /// 極慢：載入動畫 - 1000ms
  static const loading = Duration(milliseconds: 1000);

  /// 列表項目錯開延遲 - 50ms
  static const staggerDelay = Duration(milliseconds: 50);
}

/// 標準動畫曲線，確保動態效果一致性
abstract final class AnimCurves {
  /// 標準緩動：適用於大多數動畫
  static const standard = Curves.easeInOut;

  /// 進入效果：元素進場時使用
  static const enter = Curves.easeOut;

  /// 離開效果：元素離場時使用
  static const exit = Curves.easeIn;

  /// 彈跳效果：活潑的動畫
  static const bounce = Curves.elasticOut;

  /// 平滑減速
  static const decelerate = Curves.decelerate;
}
