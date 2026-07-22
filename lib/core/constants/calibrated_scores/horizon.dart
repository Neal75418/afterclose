/// 評分時間範圍（Stage 5a runtime loader）
///
/// AfterClose 支援雙 horizon 評分：
/// - [short] 短線（5 個交易日），適合盤中波段
/// - [long] 長線（60 個交易日），適合季度趨勢
///
/// 每個 horizon 對應一個 calibrated rule scores JSON asset，
/// 由 `tool/recalibrate.dart` 產生（2026-07-13 起 production JSON 已有
/// 校準值；多數 rule 被 cut 為 0 → lookup 視為 null → fallback 至
/// `RuleScores` hardcoded 值）。
///
/// **設計原則**：固定 2 個 value，不保留 `default` 或 `unknown`。
/// Dual-horizon scoring 的語意就是每檔股票必須同時計算兩個 horizon
/// 的分數，不會存在「模糊的 horizon」選擇。
enum Horizon {
  short(tradingDays: 5, assetPath: 'assets/rule_scores_calibrated_short.json'),
  long(tradingDays: 60, assetPath: 'assets/rule_scores_calibrated_long.json');

  const Horizon({required this.tradingDays, required this.assetPath});

  /// 交易日數（不含非交易日）。也是查詢
  /// [CalibrationThresholds.successThresholds] 的 key — `Horizon.short.tradingDays=5`
  /// 對應 5D threshold，long 對應 60D threshold。
  final int tradingDays;

  /// JSON asset 路徑，供 `rootBundle.loadString` 讀取
  final String assetPath;
}
