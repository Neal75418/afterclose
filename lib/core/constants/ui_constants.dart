/// UI 層共用常數
///
/// 集中管理動畫時間、捲動閾值等 UI 相關數值，
/// 避免散落在各 Widget 中的 magic numbers。
abstract final class UiConstants {
  /// Grid 卡片交錯動畫延遲（每張卡片間隔毫秒）
  static const int gridAnimationDelayMs = 30;

  /// List 卡片交錯動畫延遲（每張卡片間隔毫秒）
  static const int listAnimationDelayMs = 50;

  /// Grid 卡片動畫時長（毫秒）
  static const int gridAnimationDurationMs = 300;

  /// List 卡片動畫時長（毫秒）
  static const int listAnimationDurationMs = 400;

  /// 無限捲動觸發距離（像素）
  static const double infiniteScrollThresholdPx = 300.0;

  /// 卡片寬度低於此值時切換為緊湊佈局（像素）
  static const double compactCardBreakpoint = 320.0;

  /// 卡片寬度達此值時才顯示迷你走勢圖（像素）
  ///
  /// 走勢圖佔 78px (70+8)，需要比 compact 門檻更多空間，
  /// 避免 320-400px 邊界寬度的水平溢出。
  static const double sparklineMinWidth = 400.0;

  /// 自訂篩選捲動載入觸發距離（像素）
  static const double scrollLoadMoreThreshold = 200.0;

  /// 大盤 Dashboard 情緒配對列 `VerticalDivider` 的固定高度（像素）
  ///
  /// 該分隔線所在 Row 無法用 `IntrinsicHeight` 撐開高度（見
  /// `MarketDashboard._buildParallelView` 的內部註解），必須給明確值，否則
  /// 在 unbounded 高度環境下會塌陷為 0 而不可見。取值需大於等於
  /// `SentimentGaugeSection` 各狀態下的實測渲染高度，否則分隔線會明顯短於
  /// 卡片本身：子指標收摺、無趨勢 sparkline 172、趨勢 sparkline 顯示 210、
  /// 子指標展開 197、兩者同時 256——260 留有餘裕。
  static const double sentimentDividerHeight = 260.0;
}
