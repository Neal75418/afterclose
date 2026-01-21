import 'package:flutter/material.dart';

/// Modern theme system for AfterClose app
///
/// Design philosophy:
/// - Dark mode first with vibrant accents
/// - Financial data focus with clear visual hierarchy
/// - Taiwan stock market convention: red for up, green for down
class AppTheme {
  AppTheme._();

  // ==========================================
  // Color Palette
  // ==========================================

  /// Primary brand color - Modern violet
  static const primaryColor = Color(0xFF6C63FF);

  /// Secondary accent - Cyan for highlights
  static const secondaryColor = Color(0xFF00D9FF);

  /// Tertiary accent - Warm coral
  static const tertiaryColor = Color(0xFFFF6B9D);

  // Stock price colors (Taiwan convention)
  /// Up/Gain - Red (漲)
  static const upColor = Color(0xFFFF4757);

  /// Down/Loss - Green (跌)
  static const downColor = Color(0xFF2ED573);

  /// Neutral/Unchanged - Grey (平盤)
  static const neutralColor = Color(0xFF747D8C);

  /// Error color - Distinct from upColor for semantic clarity
  /// Uses a deeper red-orange to differentiate from stock price increases
  static const errorColor = Color(0xFFE74C3C);

  // Surface colors for dark theme
  static const _surfaceDark = Color(0xFF1E1E2E);
  static const _backgroundDark = Color(0xFF121218);
  static const _cardDark = Color(0xFF252536);

  // Surface colors for light theme
  static const _surfaceLight = Color(0xFFF8F9FA);
  static const _backgroundLight = Color(0xFFFFFFFF);
  static const _cardLight = Color(0xFFFFFFFF);

  // ==========================================
  // Dark Theme
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
        onSurface: Colors.white,
        onSurfaceVariant: const Color(0xFFB0B0C0),
        error: const Color(0xFFFF6B6B),
        outline: const Color(0xFF3A3A4A),
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
          color: Colors.white,
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
        backgroundColor: _surfaceDark.withValues(alpha: 0.95),
        indicatorColor: primaryColor.withValues(alpha: 0.2),
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
        backgroundColor: _cardDark,
        labelStyle: const TextStyle(fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2A2A3A),
        thickness: 1,
        space: 1,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _cardDark,
        contentTextStyle: const TextStyle(color: Colors.white),
        actionTextColor: secondaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: _surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  // ==========================================
  // Light Theme
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
  // Helper Methods
  // ==========================================

  /// Get color for price change
  static Color getPriceColor(double? change) {
    if (change == null) return neutralColor;
    if (change > 0) return upColor;
    if (change < 0) return downColor;
    return neutralColor;
  }

  /// Get color for score badge
  static Color getScoreColor(double score) {
    if (score >= 50) return upColor;
    if (score >= 35) return Colors.orange;
    if (score >= 20) return Colors.amber;
    return neutralColor;
  }

  /// Get gradient for backgrounds
  static LinearGradient get darkGradient => const LinearGradient(
    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get lightGradient => const LinearGradient(
    colors: [Color(0xFFF8F9FA), Color(0xFFEEF2F7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Card decoration with subtle border
  static BoxDecoration cardDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? _cardDark : _cardLight,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isDark ? const Color(0xFF3A3A4A) : const Color(0xFFE8E8F0),
        width: 1,
      ),
    );
  }
}

/// Extension for easy access to theme colors
extension ThemeExtension on BuildContext {
  /// Get price color based on change percentage
  Color priceColor(double? change) => AppTheme.getPriceColor(change);

  /// Get score badge color
  Color scoreColor(double score) => AppTheme.getScoreColor(score);

  /// Check if current theme is dark
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
