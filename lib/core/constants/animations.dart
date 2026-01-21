import 'package:flutter/widgets.dart';

/// Standardized animation durations for consistent UI transitions.
///
/// Usage:
/// ```dart
/// AnimatedContainer(
///   duration: AnimDurations.fast,
///   curve: AnimCurves.standard,
///   // ...
/// )
/// ```
abstract final class AnimDurations {
  /// Ultra-fast for micro-interactions (press feedback, ripples)
  /// 100ms
  static const press = Duration(milliseconds: 100);

  /// Fast for quick state changes (toggles, highlights)
  /// 150ms
  static const fast = Duration(milliseconds: 150);

  /// Standard duration for most animations (fades, slides)
  /// 200ms
  static const standard = Duration(milliseconds: 200);

  /// Medium for more deliberate animations (page transitions)
  /// 300ms
  static const medium = Duration(milliseconds: 300);

  /// Slow for emphasis or complex animations
  /// 400ms
  static const slow = Duration(milliseconds: 400);

  /// Extra slow for loading animations
  /// 1000ms
  static const loading = Duration(milliseconds: 1000);

  /// Stagger delay for list item animations
  /// 50ms
  static const staggerDelay = Duration(milliseconds: 50);
}

/// Standard animation curves for consistent motion.
abstract final class AnimCurves {
  /// Standard easing for most animations
  static const standard = Curves.easeInOut;

  /// For entering elements
  static const enter = Curves.easeOut;

  /// For exiting elements
  static const exit = Curves.easeIn;

  /// For bouncy, playful animations
  static const bounce = Curves.elasticOut;

  /// For smooth deceleration
  static const decelerate = Curves.decelerate;
}
