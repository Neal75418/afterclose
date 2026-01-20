import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:afterclose/presentation/screens/news/news_screen.dart';
import 'package:afterclose/presentation/screens/scan/scan_screen.dart';
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

/// App routes configuration
final router = GoRouter(
  initialLocation: '/',
  routes: [
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
  ],
);
