import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:afterclose/core/constants/app_routes.dart';
import 'package:afterclose/core/extensions/router_extensions.dart';

import 'package:afterclose/presentation/screens/alerts/alerts_screen.dart';
import 'package:afterclose/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:afterclose/presentation/screens/custom_screening/backtest/backtest_screen.dart';
import 'package:afterclose/presentation/screens/custom_screening/custom_screening_screen.dart';
import 'package:afterclose/presentation/screens/industry/industry_overview_screen.dart';
import 'package:afterclose/presentation/screens/news/news_screen.dart';
import 'package:afterclose/presentation/screens/scan/scan_screen.dart';
import 'package:afterclose/presentation/screens/settings/settings_screen.dart';
import 'package:afterclose/presentation/screens/comparison/comparison_screen.dart';
import 'package:afterclose/presentation/screens/calendar/event_calendar_screen.dart';
import 'package:afterclose/presentation/screens/portfolio/position_detail_screen.dart';
import 'package:afterclose/presentation/screens/stock_detail/stock_detail_screen.dart';
import 'package:afterclose/presentation/screens/today/today_screen.dart';
import 'package:afterclose/presentation/screens/watchlist/watchlist_screen.dart';
import 'package:afterclose/presentation/widgets/app_shell.dart';

/// 導航分支 key
final _todayNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'today');
final _scanNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'scan');
final _watchlistNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'watchlist',
);
final _newsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'news');

/// 快取 onboarding 完成狀態，避免重複 async 讀取
bool _onboardingComplete = false;

/// 預載 onboarding 狀態（須在 router 使用前呼叫）
Future<void> initOnboardingStatus() async {
  final prefs = await SharedPreferences.getInstance();
  _onboardingComplete = prefs.getBool(OnboardingScreen.completedKey) ?? false;
}

/// 標記 onboarding 已完成（更新快取 + 持久化）
Future<void> completeOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(OnboardingScreen.completedKey, true);
  _onboardingComplete = true;
}

/// App 路由設定
final router = GoRouter(
  initialLocation: AppRoutes.home,
  redirect: (context, state) {
    if (!_onboardingComplete && state.matchedLocation != AppRoutes.onboarding) {
      return AppRoutes.onboarding;
    }
    if (_onboardingComplete && state.matchedLocation == AppRoutes.onboarding) {
      return AppRoutes.home;
    }
    return null;
  },
  routes: [
    // Onboarding（全螢幕，無底部導航）
    GoRoute(
      path: AppRoutes.onboarding,
      name: 'onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    // 含底部導航的 Shell 路由
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppShell(navigationShell: navigationShell);
      },
      branches: [
        // 今日分頁
        StatefulShellBranch(
          navigatorKey: _todayNavigatorKey,
          routes: [
            GoRoute(
              path: AppRoutes.home,
              name: 'today',
              builder: (context, state) => const TodayScreen(),
            ),
          ],
        ),

        // 掃描分頁
        StatefulShellBranch(
          navigatorKey: _scanNavigatorKey,
          routes: [
            GoRoute(
              path: AppRoutes.scan,
              name: 'scan',
              builder: (context, state) => const ScanScreen(),
            ),
          ],
        ),

        // 自選股分頁
        StatefulShellBranch(
          navigatorKey: _watchlistNavigatorKey,
          routes: [
            GoRoute(
              path: AppRoutes.watchlist,
              name: 'watchlist',
              builder: (context, state) => const WatchlistScreen(),
            ),
          ],
        ),

        // 新聞分頁
        StatefulShellBranch(
          navigatorKey: _newsNavigatorKey,
          routes: [
            GoRoute(
              path: AppRoutes.news,
              name: 'news',
              builder: (context, state) => const NewsScreen(),
            ),
          ],
        ),
      ],
    ),

    // 個股詳情（全螢幕，Shell 外）
    GoRoute(
      path: AppRoutes.stockDetailTemplate,
      name: 'stockDetail',
      builder: (context, state) {
        final symbol = state.pathParameters['symbol'] ?? '';
        return StockDetailScreen(symbol: symbol);
      },
    ),

    // 設定（全螢幕，Shell 外）
    GoRoute(
      path: AppRoutes.settings,
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),

    // 價格警示（全螢幕，Shell 外）
    GoRoute(
      path: AppRoutes.alerts,
      name: 'alerts',
      builder: (context, state) => const AlertsScreen(),
    ),

    // 產業總覽（全螢幕，Shell 外）
    GoRoute(
      path: AppRoutes.industry,
      name: 'industry',
      builder: (context, state) => const IndustryOverviewScreen(),
    ),

    // 自訂篩選（全螢幕，Shell 外）
    GoRoute(
      path: AppRoutes.customScreening,
      name: 'customScreening',
      builder: (context, state) => const CustomScreeningScreen(),
    ),

    // 股票比較（全螢幕，Shell 外）
    GoRoute(
      path: AppRoutes.compare,
      name: 'comparison',
      builder: (context, state) {
        return ComparisonScreen(initialSymbols: state.symbolsExtra);
      },
    ),

    // 回測（全螢幕，Shell 外）
    GoRoute(
      path: AppRoutes.backtest,
      name: 'backtest',
      builder: (context, state) {
        return BacktestScreen(conditions: state.conditionsExtra);
      },
    ),

    // 持股詳情（全螢幕，Shell 外）
    GoRoute(
      path: AppRoutes.positionDetailTemplate,
      name: 'positionDetail',
      builder: (context, state) {
        final symbol = state.pathParameters['symbol'] ?? '';
        return PositionDetailScreen(symbol: symbol);
      },
    ),

    // 行事曆（全螢幕，Shell 外）
    GoRoute(
      path: AppRoutes.calendar,
      name: 'eventCalendar',
      builder: (context, state) => const EventCalendarScreen(),
    ),
  ],
);
