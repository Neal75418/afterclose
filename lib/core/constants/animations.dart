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

  /// 標準：快速動畫（淡入淡出、警示標記）- 200ms
  static const standard = Duration(milliseconds: 200);

  /// 一般：大多數轉場動畫（區塊標題、卡片進場）- 300ms
  static const normal = Duration(milliseconds: 300);

  /// 緩和：較慢的列表與詳情動畫 - 400ms
  static const moderate = Duration(milliseconds: 400);

  /// 極慢：載入動畫 - 1000ms
  static const loading = Duration(milliseconds: 1000);

  /// 呼吸效果：空狀態脈動等循環動畫 - 2000ms
  static const breathe = Duration(milliseconds: 2000);
}

/// 標準動畫曲線，確保動態效果一致性
abstract final class AnimCurves {
  /// 進入效果：元素進場時使用
  static const enter = Curves.easeOut;

  /// 呼吸效果：循環脈動動畫
  static const breathe = Curves.easeInOut;

  /// 彈性進入：帶有輕微回彈的進場效果
  static const bounce = Curves.easeOutBack;

  /// 流暢減速：列表與卡片的漸進停止
  static const smooth = Curves.easeOutQuart;

  /// 柔和減速：進度條等穩定動畫
  static const decelerate = Curves.easeOutCubic;
}
