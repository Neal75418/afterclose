/// 響應式斷點定義
///
/// 用於統一管理不同設備尺寸的斷點閾值。
/// 參考 Material Design 3 斷點建議：
/// - Compact (手機): < 600dp
/// - Medium (平板): 600-839dp
/// - Expanded (大平板/桌面): >= 840dp
abstract final class Breakpoints {
  /// 手機最大寬度（< 600px 為手機）
  static const double mobile = 600;

  /// 平板最大寬度（600-1024px 為平板）
  static const double tablet = 1024;

  /// 導航欄收合斷點（低於此寬度使用 BottomNav）
  static const double navigationRailBreakpoint = 600;

  /// Modal bottom sheet 最大寬度。
  ///
  /// 寬視窗（桌面）下 modal bottom sheet 預設撐滿全寬、不置中，閱讀體驗差；
  /// 給 `showModalBottomSheet(constraints:)` 限寬後 Flutter 會自動水平置中，
  /// 窄視窗（< 此值）則仍維持滿寬。
  static const double sheetMaxWidth = 640;
}

/// 設備類型枚舉
enum DeviceType {
  /// 手機（< 600px）
  mobile,

  /// 平板（600-1024px）
  tablet,

  /// 桌面（>= 1024px）
  desktop,
}
