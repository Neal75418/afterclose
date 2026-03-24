// Integration test: 底部導航列與路由切換驗證
//
// 驗證 GoRouter + StatefulShellRoute 的導航行為：
// 4 個分頁正確渲染並可切換。
//
// 注意：不使用真實 AppShell（依賴 EasyLocalization），
// 而是使用等效的測試 Shell 來驗證導航邏輯。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:afterclose/core/theme/app_theme.dart';

void main() {
  group('App Navigation Integration', () {
    late GoRouter testRouter;

    setUp(() {
      testRouter = GoRouter(
        initialLocation: '/',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) {
              // 等效 AppShell 的測試版本
              return Scaffold(
                body: navigationShell,
                bottomNavigationBar: NavigationBar(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: (index) {
                    navigationShell.goBranch(
                      index,
                      initialLocation: index == navigationShell.currentIndex,
                    );
                  },
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.today_outlined),
                      selectedIcon: Icon(Icons.today),
                      label: 'Today',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.search_outlined),
                      selectedIcon: Icon(Icons.search),
                      label: 'Scan',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.star_outline),
                      selectedIcon: Icon(Icons.star),
                      label: 'Watchlist',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.newspaper_outlined),
                      selectedIcon: Icon(Icons.newspaper),
                      label: 'News',
                    ),
                  ],
                ),
              );
            },
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (_, _) =>
                        const Center(child: Text('Today Content')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/scan',
                    builder: (_, _) =>
                        const Center(child: Text('Scan Content')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/watchlist',
                    builder: (_, _) =>
                        const Center(child: Text('Watchlist Content')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/news',
                    builder: (_, _) =>
                        const Center(child: Text('News Content')),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
    });

    Widget buildApp() {
      return MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: testRouter,
      );
    }

    testWidgets('renders 4 bottom navigation destinations', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);

      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.destinations.length, 4);
    });

    testWidgets('initial tab shows Today content', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Today Content'), findsOneWidget);
      expect(find.text('Scan Content'), findsNothing);
      expect(find.text('Watchlist Content'), findsNothing);
      expect(find.text('News Content'), findsNothing);
    });

    testWidgets('tapping Scan tab switches to Scan content', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scan'));
      await tester.pumpAndSettle();

      expect(find.text('Scan Content'), findsOneWidget);
      expect(find.text('Today Content'), findsNothing);
    });

    testWidgets('tapping Watchlist tab switches to Watchlist content', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Watchlist'));
      await tester.pumpAndSettle();

      expect(find.text('Watchlist Content'), findsOneWidget);
    });

    testWidgets('tapping News tab switches to News content', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('News'));
      await tester.pumpAndSettle();

      expect(find.text('News Content'), findsOneWidget);
    });

    testWidgets('preserves tab state when switching (IndexedStack)', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // 確認初始在 Today
      expect(find.text('Today Content'), findsOneWidget);

      // 切到 Scan
      await tester.tap(find.text('Scan'));
      await tester.pumpAndSettle();
      expect(find.text('Scan Content'), findsOneWidget);

      // 切回 Today — IndexedStack 應保留先前的 widget state
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();
      expect(find.text('Today Content'), findsOneWidget);
    });

    testWidgets('NavigationBar selectedIndex updates on tap', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // 初始 selectedIndex = 0
      var navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 0);

      // 切到 Watchlist (index 2)
      await tester.tap(find.text('Watchlist'));
      await tester.pumpAndSettle();

      navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 2);
    });
  });
}
