import 'package:flutter/material.dart';

/// AfterClose 應用程式主題系統
///
/// 設計理念：
/// - 深色模式優先，搭配鮮豔強調色
/// - 專注於金融數據，清晰的視覺層次
/// - 台灣股市慣例：紅色代表漲，綠色代表跌
class AppTheme {
  AppTheme._();

  // ==========================================
  // 色彩調色盤（Material Design 標準）
  // ==========================================

  /// 主品牌色 - Material Blue
  static const primaryColor = Color(0xFF2196F3);

  /// 次要強調色 - Material Teal
  static const secondaryColor = Color(0xFF03DAC6);

  /// 第三強調色 - Material Deep Orange
  static const tertiaryColor = Color(0xFFFF5722);

  // 股價顏色（台灣慣例）
  /// 上漲 - 紅色
  static const upColor = Color(0xFFFF4757);

  /// 下跌 - 綠色
  static const downColor = Color(0xFF2ED573);

  /// 平盤 - 灰色
  static const neutralColor = Color(0xFF747D8C);

  /// 錯誤色 - 使用較深的紅橘色，與上漲顏色區分
  static const errorColor = Color(0xFFE74C3C);

  // 法人類別顏色
  /// 外資 - 藍色
  static const foreignColor = Color(0xFF3498DB);

  /// 投信 - 紫色
  static const investmentTrustColor = Color(0xFF9B59B6);

  /// 自營商 - 橘色
  static const dealerColor = Color(0xFFE67E22);

  // 深色主題表面顏色 (Midnight Slate)
  static const _surfaceDark = Color(0xFF1E293B); // Slate 800
  static const _backgroundDark = Color(0xFF0F172A); // Slate 900
  static const _cardDark = Color(0xFF1E293B); // Slate 800
  static const _cardDarkSurface = Color(0xFF334155); // Slate 700

  // 淺色主題表面顏色
  static const _surfaceLight = Color(0xFFF8F9FA);
  static const _backgroundLight = Color(0xFFFFFFFF);
  static const _cardLight = Color(0xFFFFFFFF);

  // ==========================================
  // 深色主題
  // ==========================================

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      // ignore: prefer_const_constructors - ColorScheme.dark is a factory constructor
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: tertiaryColor,
        surface: _surfaceDark,
        onSurface: const Color(0xFFF1F5F9), // Slate 100
        onSurfaceVariant: const Color(0xFF94A3B8), // Slate 400
        error: const Color(0xFFFF6B6B),
        outline: const Color(0xFF475569), // Slate 600
      ),
      scaffoldBackgroundColor: _backgroundDark,

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFFF1F5F9),
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        elevation: 0,
        color: _cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // ListTile
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: _cardDark,
      ),

      // Bottom Navigation
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent, // Handled by AppShell for blur
        indicatorColor: primaryColor.withValues(alpha: 0.2),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 70,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFFF1F5F9));
          }
          return const IconThemeData(color: Color(0xFF94A3B8));
        }),
      ),

      // Buttons
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF475569)),
          ),
        ),
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _cardDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: _cardDarkSurface,
        labelStyle: const TextStyle(fontSize: 12, color: Color(0xFFF1F5F9)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide.none,
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: Color(0xFF334155),
        thickness: 1,
        space: 1,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _cardDarkSurface,
        contentTextStyle: const TextStyle(color: Color(0xFFF1F5F9)),
        actionTextColor: secondaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: _surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 10,
      ),
    );
  }

  // ==========================================
  // 淺色主題
  // ==========================================

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      // ignore: prefer_const_constructors - ColorScheme.light is a factory constructor
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: tertiaryColor,
        surface: _surfaceLight,
        onSurface: const Color(0xFF1A1A2E),
        onSurfaceVariant: const Color(0xFF666680),
        error: const Color(0xFFE53935),
        outline: const Color(0xFFE0E0E8),
      ),
      scaffoldBackgroundColor: _backgroundLight,

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1A1A2E),
        ),
        iconTheme: IconThemeData(color: Color(0xFF1A1A2E)),
      ),

      // Cards
      cardTheme: CardThemeData(
        elevation: 0,
        color: _cardLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE8E8F0), width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // ListTile
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: _cardLight,
      ),

      // Bottom Navigation
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _backgroundLight.withValues(alpha: 0.95),
        indicatorColor: primaryColor.withValues(alpha: 0.15),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 70,
      ),

      // Buttons
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: _surfaceLight,
        selectedColor: primaryColor.withValues(alpha: 0.15),
        labelStyle: const TextStyle(
          fontSize: 12,
          color: Color(0xFF1A1A2E), // Ensure visible text in light mode
        ),
        secondaryLabelStyle: const TextStyle(
          fontSize: 12,
          color: Color(0xFF1A1A2E),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFE0E0E8)),
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE8E8F0),
        thickness: 1,
        space: 1,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1A1A2E),
        contentTextStyle: const TextStyle(color: Colors.white),
        actionTextColor: primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: _backgroundLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  // ==========================================
  // 輔助方法
  // ==========================================

  /// 根據漲跌幅取得對應顏色
  static Color getPriceColor(double? change) {
    if (change == null) return neutralColor;
    if (change > 0) return upColor;
    if (change < 0) return downColor;
    return neutralColor;
  }

  /// 根據評分取得對應顏色
  static Color getScoreColor(double score) {
    if (score >= 50) return upColor;
    if (score >= 35) return Colors.orange;
    if (score >= 20) return Colors.amber;
    return neutralColor;
  }

  /// 取得背景漸層
  static LinearGradient get darkGradient => const LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get lightGradient => const LinearGradient(
    colors: [Color(0xFFF8F9FA), Color(0xFFEEF2F7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 高分股票的頂級金屬漸層
  static LinearGradient get premiumGradient => LinearGradient(
    colors: [
      const Color(0xFF1E293B),
      const Color(0xFF334155).withValues(alpha: 0.5),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 卡片裝飾（含細微邊框）
  static BoxDecoration cardDecoration(
    BuildContext context, {
    bool isPremium = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 如果是高分卡片且在深色模式，使用特殊樣式
    if (isPremium && isDark) {
      return BoxDecoration(
        gradient: premiumGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF475569).withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.05),
            blurRadius: 16,
            spreadRadius: -4,
          ),
        ],
      );
    }

    return BoxDecoration(
      color: isDark ? _cardDark : _cardLight,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isDark ? const Color(0xFF334155) : const Color(0xFFE8E8F0),
        width: 1,
      ),
    );
  }
}

/// 便捷存取主題顏色的擴充方法
extension ThemeExtension on BuildContext {
  /// 根據漲跌幅取得價格顏色
  Color priceColor(double? change) => AppTheme.getPriceColor(change);

  /// 取得評分徽章顏色
  Color scoreColor(double score) => AppTheme.getScoreColor(score);

  /// 檢查目前是否為深色主題
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
