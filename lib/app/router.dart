import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:afterclose/presentation/screens/alerts/alerts_screen.dart';
import 'package:afterclose/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:afterclose/domain/models/screening_condition.dart';
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

/// Navigation branch keys
final _todayNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'today');
final _scanNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'scan');
final _watchlistNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'watchlist',
);
final _newsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'news');

/// Cached onboarding completion status to avoid repeated async reads
bool _onboardingComplete = false;

/// Pre-load onboarding status (call before router is used)
Future<void> initOnboardingStatus() async {
  final prefs = await SharedPreferences.getInstance();
  _onboardingComplete = prefs.getBool(OnboardingScreen.completedKey) ?? false;
}

/// Mark onboarding as completed (updates cached state + persistence)
Future<void> completeOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(OnboardingScreen.completedKey, true);
  _onboardingComplete = true;
}

/// App routes configuration
final router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    if (!_onboardingComplete && state.matchedLocation != '/onboarding') {
      return '/onboarding';
    }
    if (_onboardingComplete && state.matchedLocation == '/onboarding') {
      return '/';
    }
    return null;
  },
  routes: [
    // Onboarding (full screen, no bottom nav)
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    // Shell route with bottom navigation
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppShell(navigationShell: navigationShell);
      },
      branches: [
        // Today branch
        StatefulShellBranch(
          navigatorKey: _todayNavigatorKey,
          routes: [
            GoRoute(
              path: '/',
              name: 'today',
              builder: (context, state) => const TodayScreen(),
            ),
          ],
        ),

        // Scan branch
        StatefulShellBranch(
          navigatorKey: _scanNavigatorKey,
          routes: [
            GoRoute(
              path: '/scan',
              name: 'scan',
              builder: (context, state) => const ScanScreen(),
            ),
          ],
        ),

        // Watchlist branch
        StatefulShellBranch(
          navigatorKey: _watchlistNavigatorKey,
          routes: [
            GoRoute(
              path: '/watchlist',
              name: 'watchlist',
              builder: (context, state) => const WatchlistScreen(),
            ),
          ],
        ),

        // News branch
        StatefulShellBranch(
          navigatorKey: _newsNavigatorKey,
          routes: [
            GoRoute(
              path: '/news',
              name: 'news',
              builder: (context, state) => const NewsScreen(),
            ),
          ],
        ),
      ],
    ),

    // Stock detail (full screen, outside shell)
    GoRoute(
      path: '/stock/:symbol',
      name: 'stockDetail',
      builder: (context, state) {
        final symbol = state.pathParameters['symbol']!;
        return StockDetailScreen(symbol: symbol);
      },
    ),

    // Settings (full screen, outside shell)
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),

    // Alerts (full screen, outside shell)
    GoRoute(
      path: '/alerts',
      name: 'alerts',
      builder: (context, state) => const AlertsScreen(),
    ),

    // Industry overview (full screen, outside shell)
    GoRoute(
      path: '/industry',
      name: 'industry',
      builder: (context, state) => const IndustryOverviewScreen(),
    ),

    // Custom screening (full screen, outside shell)
    GoRoute(
      path: '/scan/custom',
      name: 'customScreening',
      builder: (context, state) => const CustomScreeningScreen(),
    ),

    // Stock comparison (full screen, outside shell)
    GoRoute(
      path: '/compare',
      name: 'comparison',
      builder: (context, state) {
        final symbols = state.extra as List<String>? ?? const [];
        return ComparisonScreen(initialSymbols: symbols);
      },
    ),

    // Backtest (full screen, outside shell)
    GoRoute(
      path: '/scan/custom/backtest',
      name: 'backtest',
      builder: (context, state) {
        final conditions = state.extra as List<ScreeningCondition>? ?? const [];
        return BacktestScreen(conditions: conditions);
      },
    ),

    // Portfolio position detail (full screen, outside shell)
    GoRoute(
      path: '/portfolio/:symbol',
      name: 'positionDetail',
      builder: (context, state) {
        final symbol = state.pathParameters['symbol']!;
        return PositionDetailScreen(symbol: symbol);
      },
    ),

    // Event calendar (full screen, outside shell)
    GoRoute(
      path: '/calendar',
      name: 'eventCalendar',
      builder: (context, state) => const EventCalendarScreen(),
    ),
  ],
);
