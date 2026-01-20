import 'package:go_router/go_router.dart';

import 'package:afterclose/main.dart';

/// App routes configuration
/// Will be expanded in Phase 2 with actual screens
final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'today',
      builder: (context, state) => const PlaceholderHomePage(),
    ),
    // Phase 2: Add these routes
    // GoRoute(path: '/scan', name: 'scan', builder: ...),
    // GoRoute(path: '/watchlist', name: 'watchlist', builder: ...),
    // GoRoute(path: '/news', name: 'news', builder: ...),
    // GoRoute(path: '/stock/:symbol', name: 'stockDetail', builder: ...),
  ],
);
