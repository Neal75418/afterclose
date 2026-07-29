import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/constants/scoring_mode.dart';
import 'package:afterclose/data/database/app_database.dart';

/// 負證據歸零的每日影響摘要(2026-07-29 三態 lookup 配套觀測)。
///
/// 「交付前先問:如果它沒生效,我怎麼知道?」——三個數讓歸零機制的
/// 生效與量級每天可從 log 驗證:
/// - [zeroedRows]/[zeroedStocks]:今日被歸零的 reason 列數/涉及檔數
///   (0 = 機制沒生效或今日無觸發)
/// - [droppedStocks]:因歸零跌出「訊號層」(任一 mode 任一 horizon
///   mode-sum ≥ [RuleParams.minScoreThreshold])的檔數——對照離線重放
///   的預期量級(2026-07-29 重放:日均 ~29 檔)
class ZeroingImpact {
  const ZeroingImpact({
    required this.zeroedRows,
    required this.zeroedStocks,
    required this.droppedStocks,
    required this.addedStocks,
  });

  final int zeroedRows;
  final int zeroedStocks;
  final int droppedStocks;

  /// 因歸零「新進」訊號層的檔數。方向 gate 下歸零只移除正分貢獻,
  /// 此值結構上應恆為 0——非零代表歸零集混入了負分規則(sign gate
  /// 失效),是活的 invariant 警報。
  final int addedStocks;
}

/// code → mode 的靜態對照(從 [ReasonType.scoringMode] 展開,排除 neutral)
final Map<String, ScoringMode> _codeToMode = {
  for (final rt in ReasonType.values)
    if (rt.scoringMode != ScoringMode.neutral) rt.code: rt.scoringMode,
};

/// 純函式:由當日 daily_reason rows 重算「若無歸零」的 mode 分數,
/// 量測歸零的實際影響。
///
/// 判定口徑與 mode tab 的訊號層一致:任一 mode 的 short **或** long
/// mode-sum ≥ [RuleParams.minScoreThreshold](neutral 規則不計入,與
/// `getModeStockScores` + `isSignalTier` 同語意)。would-be 版本把
/// 「歸零集內且 short 已為 0」的列補回 hardcoded 分數;long 不受歸零
/// 影響、兩版相同。
///
/// **量測侷限(數字是下界)**:would-be 補回不乘 decay multipliers
/// (營收 decay 組同組疊加時輕微高估 dropped),且無法還原 mutex
/// 反事實(被歸零規則在 mutex 擠掉的列不在 rows 中)。對照離線重放
/// 量級時要有此認知。
ZeroingImpact computeZeroingImpact({
  required List<DailyReasonEntry> rows,
  required Set<String> zeroedRules,
  required Map<String, int> hardcodedScores,
}) {
  final threshold = RuleParams.minScoreThreshold.toDouble();

  // symbol → mode → [actualShort, wouldShort, long]
  final sums = <String, Map<ScoringMode, List<double>>>{};
  var zeroedRows = 0;
  final zeroedStocks = <String>{};

  for (final r in rows) {
    final isZeroed =
        zeroedRules.contains(r.reasonType) && r.ruleScoreShort == 0;
    if (isZeroed) {
      zeroedRows++;
      zeroedStocks.add(r.symbol);
    }
    final mode = _codeToMode[r.reasonType];
    if (mode == null) continue; // neutral 不進 mode 分數
    final s = sums
        .putIfAbsent(r.symbol, () => {})
        .putIfAbsent(mode, () => [0, 0, 0]);
    s[0] += r.ruleScoreShort;
    s[1] += isZeroed
        ? (hardcodedScores[r.reasonType] ?? 0).toDouble()
        : r.ruleScoreShort;
    s[2] += r.ruleScoreLong;
  }

  var dropped = 0;
  var added = 0;
  for (final modes in sums.values) {
    bool tier(int shortIdx) =>
        modes.values.any((s) => s[shortIdx] >= threshold || s[2] >= threshold);
    if (tier(1) && !tier(0)) dropped++;
    if (tier(0) && !tier(1)) added++;
  }

  return ZeroingImpact(
    zeroedRows: zeroedRows,
    zeroedStocks: zeroedStocks.length,
    droppedStocks: dropped,
    addedStocks: added,
  );
}
