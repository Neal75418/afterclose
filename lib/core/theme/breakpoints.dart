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

  /// 全頁內容欄最大寬度（桌面）。
  ///
  /// 手機優先的頁面（行事曆等）直接鋪滿桌面視窗時，格線被拉到極寬、
  /// 資訊密度崩壞；以 `Center + ConstrainedBox(maxWidth: 此值)` 收斂。
  /// 1000 介於 M3 expanded pane（840）與雙欄佈局之間：7 欄月曆格
  /// 每格仍有 ~140dp、清單行寬也不至於一行拉太長。
  static const double contentMaxWidth = 1000;

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
