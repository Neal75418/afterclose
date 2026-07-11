// tool/exit_validate.dart
//
// CLI tool — print 為預期輸出，關閉 avoid_print lint。
// ignore_for_file: avoid_print
//
// 出場條件 replay gate（評分改進 #3 Phase 1）。
//
// 驗證三個出場/失效條件（hardStop / trendBreak / timeStop）在歷史資料上
// 「觸發出場 vs 持有滿 60 交易日」是否有 edge，產出按 mode × 年切分的
// gate 報告供人工決定哪些條件上線。**沒 edge 的條件不進 app。**
//
// 設計：docs/plans/2026-07-11-exit-thesis-invalidation-design.md §2-§3
// 計畫：docs/plans/2026-07-11-exit-validate-gate-plan.md
//
// ## 關鍵原則
//
// - 進場模擬 = 訊號日**次一交易日收盤**（T+1）——盤後 app 買不到訊號日
//   收盤（與 calibration look-ahead 修正同一原則）。
// - 觸發判斷基準 = 訊號日收盤（T0 referencePrice）。兩者不可互換。
// - 出場後以 0% 報酬計（不含資金再部署效益）→ gate 系統性低估出場紀律
//   的實務價值；「沒 edge」= 單筆訊號品質無差異，不等於「紀律沒用」。

import 'package:afterclose/core/constants/exit_params.dart';

// ============================================================================
// 純函數出場模擬（importable by tests）
// ============================================================================

/// 單一樣本的出場模擬結果
typedef ExitSimResult = ({
  double exitReturnPct, // 出場版總報酬（%），出場後 0
  double holdReturnPct, // 持有滿 horizon 總報酬（%）
  int holdingDays, // 出場版實際持有交易日數（未觸發 = horizon）
  ExitReason? reason, // null = 全程未觸發
  double exitMddPct, // 出場版最大回檔（%，負值）
  double holdMddPct, // 持有版最大回檔
});

/// 對單一樣本（訊號日 [t0Index]）模擬「條件出場 vs 持有」。
///
/// [closes]：該股收盤序列（升序、可含 null＝停牌日）。
/// [enabled]：本次模擬啟用的條件集（單條變體用）。
///
/// 回 null 的情況（caller 應計入 survivorship counter、不得靜默丟棄）：
/// - referencePrice（T0 收盤）為 null
/// - T+1 進場價不存在 / null / ≤ 0
/// - T+1 + horizon 超出序列（60 日窗不完整——下市/資料尾端）
ExitSimResult? simulateExit({
  required List<double?> closes,
  required int t0Index,
  required Set<ExitReason> enabled,
}) {
  final ref = closes[t0Index];
  final entryIndex = t0Index + 1;
  final endIndex = entryIndex + ExitParams.holdHorizonTradingDays;
  if (ref == null || ref <= 0 || endIndex >= closes.length) return null;
  final entry = closes[entryIndex];
  if (entry == null || entry <= 0) return null;

  // 該日往前（含該日）60 根非 null 收盤的平均；不足 60 根回 null（不判定）
  double? ma60At(int d) {
    var sum = 0.0;
    var n = 0;
    for (var k = d; k >= 0 && n < ExitParams.ma60Window; k--) {
      final c = closes[k];
      if (c != null) {
        sum += c;
        n++;
      }
    }
    return n < ExitParams.ma60Window ? null : sum / n;
  }

  var everAboveRef = false;
  ExitReason? reason;
  var exitIndex = endIndex; // 未觸發 = 持有到 horizon 末
  for (var d = entryIndex; d <= endIndex; d++) {
    final c = closes[d];
    if (c == null) continue; // 停牌日跳過（timeStop 以 index 差計數）
    if (c > ref) everAboveRef = true;

    // 同日 tie-break：照 ExitReason 宣告序（hardStop > trendBreak > timeStop）
    ExitReason? hit;
    if (enabled.contains(ExitReason.hardStop) &&
        c < ref * (1 - ExitParams.hardStopPct)) {
      hit = ExitReason.hardStop;
    } else if (enabled.contains(ExitReason.trendBreak)) {
      final ma = ma60At(d);
      if (ma != null && c < ma) hit = ExitReason.trendBreak;
    }
    if (hit == null &&
        enabled.contains(ExitReason.timeStop) &&
        d - t0Index >= ExitParams.timeStopTradingDays &&
        !everAboveRef) {
      hit = ExitReason.timeStop;
    }
    if (hit != null) {
      reason = hit;
      exitIndex = d;
      break;
    }
  }

  double retPct(int d) => (closes[d]! / entry - 1) * 100;

  // 出場日/窗末若為 null（停牌），往前找最近非 null 收盤當結算價
  int settleIndex(int from) {
    var d = from;
    while (d > entryIndex && closes[d] == null) {
      d--;
    }
    return d;
  }

  var exitMdd = 0.0;
  var holdMdd = 0.0;
  for (var d = entryIndex; d <= endIndex; d++) {
    if (closes[d] == null) continue;
    final r = retPct(d);
    if (d <= exitIndex && r < exitMdd) exitMdd = r;
    if (r < holdMdd) holdMdd = r;
  }

  return (
    exitReturnPct: retPct(settleIndex(exitIndex)),
    holdReturnPct: retPct(settleIndex(endIndex)),
    holdingDays: reason == null
        ? ExitParams.holdHorizonTradingDays
        : exitIndex - entryIndex,
    reason: reason,
    exitMddPct: exitMdd,
    holdMddPct: holdMdd,
  );
}
