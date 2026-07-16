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
  /// 卡片本身。
  ///
  /// 趨勢 sparkline 已移除（見 `SentimentGaugeSection.sentimentHistory` 註解），
  /// 實測（`sentiment_gauge_section_test.dart` 渲染高度測試）：子指標收摺
  /// 172、子指標展開（5 項全部命中，最高狀態）218——222 留有餘裕。原值 260
  /// 是移除前「子指標展開+趨勢 sparkline」同時發生的最高狀態（256）預留的，
  /// sparkline 移除後未同步下修，導致情緒卡片下方出現殘留空白。
  static const double sentimentDividerHeight = 222.0;
}
