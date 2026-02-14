/// 集中定義所有路由路徑，避免硬編碼字串散佈各處。
abstract final class AppRoutes {
  // Tab 頁面
  static const home = '/';
  static const scan = '/scan';
  static const watchlist = '/watchlist';
  static const news = '/news';

  // 全螢幕路由
  static const onboarding = '/onboarding';
  static const settings = '/settings';
  static const alerts = '/alerts';
  static const industry = '/industry';
  static const customScreening = '/scan/custom';
  static const backtest = '/scan/custom/backtest';
  static const compare = '/compare';
  static const calendar = '/calendar';

  // 參數化路由
  static String stockDetail(String symbol) => '/stock/$symbol';
  static String positionDetail(String symbol) => '/portfolio/$symbol';

  // GoRouter path 模板（僅用於 router.dart 路由定義）
  static const stockDetailTemplate = '/stock/:symbol';
  static const positionDetailTemplate = '/portfolio/:symbol';
}
