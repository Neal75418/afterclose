import 'package:afterclose/core/constants/exit_params.dart';

/// 失效判定結果
typedef InvalidationResult = ({
  ExitReason reason,

  /// 觸發日相對釘選日的列偏移（closes index）
  int triggerOffset,
});

/// 釘選論點失效規則（純函數，出場層 Phase 2）
///
/// **範圍 = timeStop 單一條件**：hardStop / trendBreak 經 replay gate
/// 81,989 樣本驗證全年全 mode 為負、不上線
/// （docs/plans/2026-07-12-exit-gate-report.md）。語意與 gate 的
/// `simulateExit` timeStop 分支一致：
/// - 滿 [ExitParams.timeStopTradingDays] 個價格列（停牌 null 列計入列數、
///   跳過判定；TWSE 停牌通常缺列 → 倒數自然凍結）
/// - 且從未收高於 referencePrice（> 嚴格；邊界日收高視為論點實現、壓制觸發）
abstract final class ThesisInvalidationRules {
  /// [closesFromPinnedDate]：釘選日（含）起的收盤序列，index 0 = 釘選日。
  /// 回 null = 未失效（含資料不足倒數中）。
  static InvalidationResult? evaluate({
    required double referencePrice,
    required List<double?> closesFromPinnedDate,
  }) {
    var everAboveRef = false;
    for (var d = 1; d < closesFromPinnedDate.length; d++) {
      final c = closesFromPinnedDate[d];
      if (c == null) continue;
      if (c > referencePrice) everAboveRef = true;
      if (everAboveRef) return null; // 論點已實現，timeStop 永不觸發
      if (d >= ExitParams.timeStopTradingDays) {
        return (reason: ExitReason.timeStop, triggerOffset: d);
      }
    }
    return null;
  }
}
