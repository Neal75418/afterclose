import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:afterclose/core/theme/breakpoints.dart';
import 'package:afterclose/core/theme/design_tokens.dart';

/// BuildContext 響應式擴展
///
/// 提供便捷的方法來判斷設備類型和獲取響應式值。
///
/// 使用範例：
/// ```dart
/// // 判斷設備類型
/// if (context.isMobile) { ... }
/// if (context.isTablet) { ... }
/// if (context.isDesktop) { ... }
///
/// // 根據設備類型返回不同值
/// final padding = context.responsive(
///   mobile: 16.0,
///   tablet: 24.0,
///   desktop: 32.0,
/// );
///
/// // 判斷佈局類型
/// if (context.layoutType == LayoutType.dualPane) { ... }
/// ```
extension ResponsiveHelper on BuildContext {
  /// 螢幕寬度
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// 螢幕高度
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// 螢幕方向
  Orientation get orientation => MediaQuery.orientationOf(this);

  /// 是否為橫向
  bool get isLandscape => orientation == Orientation.landscape;

  /// 是否為直向
  bool get isPortrait => orientation == Orientation.portrait;

  /// 設備類型
  DeviceType get deviceType {
    final width = screenWidth;
    if (width < Breakpoints.mobile) return DeviceType.mobile;
    if (width < Breakpoints.tablet) return DeviceType.tablet;
    return DeviceType.desktop;
  }

  /// 是否為手機
  bool get isMobile => deviceType == DeviceType.mobile;

  /// 是否為平板
  bool get isTablet => deviceType == DeviceType.tablet;

  /// 是否為桌面
  bool get isDesktop => deviceType == DeviceType.desktop;

  /// 是否為平板或更大
  bool get isTabletOrLarger => screenWidth >= Breakpoints.mobile;

  /// 是否為桌面或更大
  bool get isDesktopOrLarger => screenWidth >= Breakpoints.desktop;

  /// 佈局類型
  LayoutType get layoutType {
    final width = screenWidth;
    if (width >= Breakpoints.triplePaneMinWidth) return LayoutType.triplePane;
    if (width >= Breakpoints.dualPaneMinWidth) return LayoutType.dualPane;
    return LayoutType.singlePane;
  }

  /// 是否應顯示 NavigationRail（側邊導航）
  bool get shouldShowNavigationRail =>
      screenWidth >= Breakpoints.navigationRailBreakpoint;

  /// 是否應顯示雙欄佈局
  bool get shouldShowDualPane => screenWidth >= Breakpoints.dualPaneMinWidth;

  /// 是否應顯示三欄佈局
  bool get shouldShowTriplePane =>
      screenWidth >= Breakpoints.triplePaneMinWidth;

  /// 根據設備類型返回對應值
  ///
  /// [mobile] 手機時的值（必填）
  /// [tablet] 平板時的值（可選，預設使用 mobile）
  /// [desktop] 桌面時的值（可選，預設使用 tablet 或 mobile）
  T responsive<T>({required T mobile, T? tablet, T? desktop}) {
    return switch (deviceType) {
      DeviceType.desktop => desktop ?? tablet ?? mobile,
      DeviceType.tablet => tablet ?? mobile,
      DeviceType.mobile => mobile,
    };
  }

  /// 根據佈局類型返回對應值
  T responsiveLayout<T>({required T singlePane, T? dualPane, T? triplePane}) {
    return switch (layoutType) {
      LayoutType.triplePane => triplePane ?? dualPane ?? singlePane,
      LayoutType.dualPane => dualPane ?? singlePane,
      LayoutType.singlePane => singlePane,
    };
  }

  /// 響應式邊距
  EdgeInsets get responsivePadding {
    return responsive(
      mobile: const EdgeInsets.all(16),
      tablet: const EdgeInsets.all(24),
      desktop: const EdgeInsets.all(32),
    );
  }

  /// 響應式水平邊距
  double get responsiveHorizontalPadding {
    return responsive(mobile: 16.0, tablet: 24.0, desktop: 32.0);
  }

  /// 響應式卡片間距
  double get responsiveCardSpacing {
    return responsive(mobile: 8.0, tablet: 12.0, desktop: 16.0);
  }

  /// 響應式 GridView 列數
  ///
  /// 基於最小卡片寬度計算，確保卡片不會過窄。
  /// 計算公式：(可用寬度 + 間距) / (最小卡片寬度 + 間距)
  int get responsiveGridColumns {
    final padding = responsiveHorizontalPadding;
    final spacing = responsiveCardSpacing;
    final availableWidth = screenWidth - (padding * 2);
    const minCardWidth = DesignTokens.stockCardMinWidth;

    // 計算可容納的欄數
    // 公式：(可用寬度 + 間距) / (最小卡片寬度 + 間距)
    final maxColumns = ((availableWidth + spacing) / (minCardWidth + spacing))
        .floor();

    // 限制在 1-4 欄之間
    return math.max(1, math.min(maxColumns, 4));
  }

  /// 響應式列表項目寬度（用於 GridView）
  double get responsiveListItemWidth {
    final columns = responsiveGridColumns;
    final totalPadding = responsiveHorizontalPadding * 2;
    final totalSpacing = responsiveCardSpacing * (columns - 1);
    return (screenWidth - totalPadding - totalSpacing) / columns;
  }
}

/// 響應式 Widget Builder
///
/// 根據螢幕尺寸自動重建 Widget。
///
/// 使用範例：
/// ```dart
/// ResponsiveBuilder(
///   mobile: (context) => MobileLayout(),
///   tablet: (context) => TabletLayout(),
///   desktop: (context) => DesktopLayout(),
/// )
/// ```
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  /// 手機佈局（必填）
  final Widget Function(BuildContext context) mobile;

  /// 平板佈局（可選）
  final Widget Function(BuildContext context)? tablet;

  /// 桌面佈局（可選）
  final Widget Function(BuildContext context)? desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (width >= Breakpoints.desktop && desktop != null) {
          return desktop!(context);
        }
        if (width >= Breakpoints.mobile && tablet != null) {
          return tablet!(context);
        }
        return mobile(context);
      },
    );
  }
}

/// 響應式佈局 Widget
///
/// 根據佈局類型（單欄/雙欄/三欄）自動選擇佈局。
class ResponsiveLayoutBuilder extends StatelessWidget {
  const ResponsiveLayoutBuilder({
    super.key,
    required this.singlePane,
    this.dualPane,
    this.triplePane,
  });

  /// 單欄佈局（必填）
  final Widget Function(BuildContext context) singlePane;

  /// 雙欄佈局（可選）
  final Widget Function(BuildContext context)? dualPane;

  /// 三欄佈局（可選）
  final Widget Function(BuildContext context)? triplePane;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (width >= Breakpoints.triplePaneMinWidth && triplePane != null) {
          return triplePane!(context);
        }
        if (width >= Breakpoints.dualPaneMinWidth && dualPane != null) {
          return dualPane!(context);
        }
        return singlePane(context);
      },
    );
  }
}
