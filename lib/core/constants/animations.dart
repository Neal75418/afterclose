import 'package:flutter/widgets.dart';

/// 標準化動畫時長，確保 UI 轉場一致性
///
/// 使用範例：
/// ```dart
/// AnimatedContainer(
///   duration: AnimDurations.press,
///   curve: AnimCurves.enter,
///   // ...
/// )
/// ```
abstract final class AnimDurations {
  /// 極快速：微互動（按壓回饋、漣漪效果）- 100ms
  static const press = Duration(milliseconds: 100);

  /// 標準：大多數動畫（淡入淡出、滑動）- 200ms
  static const standard = Duration(milliseconds: 200);

  /// 極慢：載入動畫 - 1000ms
  static const loading = Duration(milliseconds: 1000);
}

/// 標準動畫曲線，確保動態效果一致性
abstract final class AnimCurves {
  /// 進入效果：元素進場時使用
  static const enter = Curves.easeOut;
}
