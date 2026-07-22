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
  static const portfolio = '/portfolio';
  static const compare = '/compare';
  static const calendar = '/calendar';
  static const shortSellRanking = '/short-sell-ranking';
  static const industryEps = '/industry-eps';

  // 參數化路由
  static String stockDetail(String symbol) => '/stock/$symbol';

  /// 詳情頁「上/下一檔」換股時傳入 route extra 的標記：套無轉場動畫
  /// （巡檢連續換股不該每次播整頁滑入；正常從清單點進維持預設轉場）。
  /// 判定集中在 [isStockDetailSwap]。
  static const stockDetailSwapExtra = 'stockDetailSwap';

  /// route extra 是否為換股標記（詳情頁 pageBuilder 與導航列共用的契約）
  static bool isStockDetailSwap(Object? extra) => extra == stockDetailSwapExtra;
  static String positionDetail(String symbol) => '/portfolio/$symbol';

  // GoRouter path 模板（僅用於 router.dart 路由定義）
  static const stockDetailTemplate = '/stock/:symbol';
  static const positionDetailTemplate = '/portfolio/:symbol';
}
