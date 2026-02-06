import 'dart:ui';

/// 設計系統核心常數
///
/// 統一管理應用程式中的間距、圓角、透明度等設計參數，
/// 確保 UI 風格一致性，避免魔術數字。
abstract final class DesignTokens {
  // ============================================================
  // 間距系統 (8dp Grid)
  // ============================================================

  /// 2dp - 微間距（行內元素間距）
  static const double spacing2 = 2.0;

  /// 4dp - 極小間距（標籤內文字間距）
  static const double spacing4 = 4.0;

  /// 6dp - 小間距（緊湊元素間距）
  static const double spacing6 = 6.0;

  /// 8dp - 基礎間距
  static const double spacing8 = 8.0;

  /// 12dp - 中等間距
  static const double spacing12 = 12.0;

  /// 14dp - 卡片內間距
  static const double spacing14 = 14.0;

  /// 16dp - 標準間距（Section 間距）
  static const double spacing16 = 16.0;

  /// 24dp - 大間距（區塊間距）
  static const double spacing24 = 24.0;

  /// 32dp - 超大間距
  static const double spacing32 = 32.0;

  // ============================================================
  // 圓角系統
  // ============================================================

  /// 4dp - 極小圓角（標籤、徽章）
  static const double radiusXs = 4.0;

  /// 6dp - 小圓角（緊湊標籤）
  static const double radiusSm = 6.0;

  /// 8dp - 中等圓角（Chip、小卡片）
  static const double radiusMd = 8.0;

  /// 12dp - 大圓角（按鈕、輸入框）
  static const double radiusLg = 12.0;

  /// 16dp - 超大圓角（卡片）
  static const double radiusXl = 16.0;

  /// 20dp - 特大圓角（Dialog）
  static const double radiusXxl = 20.0;

  // ============================================================
  // 透明度系統
  // ============================================================

  /// 10% 透明度 - 淺色主題背景
  static const double opacity10 = 0.10;

  /// 15% 透明度 - 淺色主題懸停
  static const double opacity15 = 0.15;

  /// 20% 透明度 - 中等透明
  static const double opacity20 = 0.20;

  /// 25% 透明度 - 深色主題背景
  static const double opacity25 = 0.25;

  /// 40% 透明度 - 邊框、分隔線
  static const double opacity40 = 0.40;

  // ============================================================
  // StockCard 專用常數
  // ============================================================

  /// 股票卡片高度（Grid 佈局用）
  /// 計算：margin(12) + padding(28) + content(~114) = 154
  static const double stockCardHeight = 154.0;

  /// 股票卡片最小寬度（用於計算 Grid 欄數）
  static const double stockCardMinWidth = 340.0;

  /// 股票卡片水平外邊距
  static const double stockCardMarginH = 16.0;

  /// 股票卡片垂直外邊距
  static const double stockCardMarginV = 6.0;

  /// 股票卡片內邊距
  static const double stockCardPadding = 14.0;

  // ============================================================
  // 文字大小
  // ============================================================

  /// 10sp - 極小文字（輔助標記）
  static const double fontSizeXs = 10.0;

  /// 12sp - 小文字（標籤）
  static const double fontSizeSm = 12.0;

  /// 14sp - 中等文字（內文）
  static const double fontSizeMd = 14.0;

  /// 16sp - 大文字（副標題）
  static const double fontSizeLg = 16.0;

  /// 18sp - 超大文字（價格顯示）
  static const double fontSizeXl = 18.0;

  // ============================================================
  // 圖示大小
  // ============================================================

  /// 14dp - 小圖示
  static const double iconSizeSm = 14.0;

  /// 18dp - 中等圖示
  static const double iconSizeMd = 18.0;

  /// 24dp - 標準圖示
  static const double iconSizeLg = 24.0;

  /// 26dp - 大圖示（自選按鈕）
  static const double iconSizeXl = 26.0;

  // ============================================================
  // 進度條/視覺化元素
  // ============================================================

  /// 12dp - 進度條/量表高度
  static const double barHeight = 12.0;

  // ============================================================
  // Bottom Sheet 尺寸
  // ============================================================

  /// Bottom Sheet 初始高度比例
  static const double sheetInitialSize = 0.5;

  /// Bottom Sheet 最小高度比例
  static const double sheetMinSize = 0.3;

  /// Bottom Sheet 最大高度比例
  static const double sheetMaxSize = 0.9;

  // ============================================================
  // 動畫時長
  // ============================================================

  /// 快速動畫 (200ms)
  static const Duration animDurationFast = Duration(milliseconds: 200);

  /// 標準動畫 (300ms)
  static const Duration animDurationNormal = Duration(milliseconds: 300);

  /// 動畫交錯延遲 (30ms/item)
  static const int animStaggerDelayMs = 30;

  /// 列表動畫最大項目數
  static const int maxAnimatedItems = 10;

  // ============================================================
  // 圖表色盤
  // ============================================================

  /// 通用圖表色盤（8 色循環使用）
  ///
  /// 用於比較圖表、配置圓餅圖等需要多色區分的場景。
  static const chartPalette = [
    Color(0xFF2196F3), // Blue
    Color(0xFFFF9800), // Orange
    Color(0xFF9C27B0), // Purple
    Color(0xFF4CAF50), // Green
    Color(0xFFF44336), // Red
    Color(0xFF00BCD4), // Cyan
    Color(0xFFFFEB3B), // Yellow
    Color(0xFF795548), // Brown
  ];
}
