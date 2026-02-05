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

  /// 桌面最小寬度（>= 1024px 為桌面）
  static const double desktop = 1024;

  /// 大桌面寬度（>= 1440px 為大桌面）
  static const double largeDesktop = 1440;

  /// 導航欄收合斷點（低於此寬度使用 BottomNav）
  static const double navigationRailBreakpoint = 600;

  /// 雙欄佈局最小寬度
  static const double dualPaneMinWidth = 720;

  /// 三欄佈局最小寬度
  static const double triplePaneMinWidth = 1200;
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

/// 佈局類型枚舉
enum LayoutType {
  /// 單欄佈局（手機）
  singlePane,

  /// 雙欄佈局（平板橫向、小桌面）
  dualPane,

  /// 三欄佈局（大桌面）
  triplePane,
}
