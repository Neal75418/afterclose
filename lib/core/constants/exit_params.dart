import 'package:afterclose/core/constants/rule_params.dart';

/// 出場/論點失效參數（評分改進 #3）
///
/// 起始值為 spec §2 設計值（docs/plans/2026-07-11-exit-thesis-invalidation-design.md）；
/// **最終值由 tool/exit_validate.dart 的 replay gate 定案**——沒 edge 的
/// 條件不進 app。
abstract final class ExitParams {
  /// 硬停損：收盤 < referencePrice × (1 - 此值)
  static const double hardStopPct = 0.08;

  /// 時間停損：釘選後滿此交易日數且從未收高於 referencePrice
  static const int timeStopTradingDays = 40;

  /// trendBreak 的均線窗
  static const int ma60Window = 60;

  /// gate 的持有對照窗（交易日）
  static const int holdHorizonTradingDays = 60;

  /// gate 報告 (mode × 年) cell 的最低樣本數，低於此標灰不計入結論
  static const int minCellSample = 30;

  /// mode 訊號日樣本門檻：該 mode 規則分數加總 ≥ 此值（訊號 tier proxy）
  static const int modeSignalScoreThreshold = RuleParams.minScoreThreshold;
}

/// 失效原因。**宣告順序即同日 tie-break 優先序**（spec §2）：
/// 同一天多條件為真時取 index 最小者。
enum ExitReason { hardStop, trendBreak, timeStop }
