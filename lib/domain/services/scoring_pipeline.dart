// 單檔評分 pipeline 的共用核心。
//
// `scoring_service.scoreStocks`（主執行緒 fallback）與
// `scoring_isolate._evaluateStocksIsolated`（isolate）過去各自複製這段
// 邏輯、靠註解「與另一路徑對齊」人肉同步——歷史上已 drift 過（M8/H-1）。
// 兩條路徑改為共用此檔的純函式：改評分邏輯只改一處。
//
// 本檔對 Flutter SDK 零依賴、無狀態，isolate 可直接使用。

import 'package:afterclose/core/constants/calibrated_scores/calibrated_score_context.dart';
import 'package:afterclose/core/constants/calibrated_scores/horizon.dart';
import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/liquidity_checker.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/models.dart';
import 'package:afterclose/domain/services/rule_engine.dart';

/// 候選股被略過的原因分類（統計計數用）
enum CandidateSkipReason { noData, insufficientData, lowLiquidity }

/// 資格檢查：價格資料存在、歷史長度足夠、流動性合格。
///
/// 回傳 null 表示通過；通過時保證 `prices.last` 的 close/volume 非 null
/// （由 [LiquidityChecker] 的 MISSING_DATA 檢查擔保）。
CandidateSkipReason? classifyCandidate(List<DailyPriceEntry>? prices) {
  if (prices == null || prices.isEmpty) return CandidateSkipReason.noData;
  if (prices.length < RuleParams.swingWindow) {
    return CandidateSkipReason.insufficientData;
  }
  final liquidity = LiquidityChecker.checkCandidateLiquidity(prices.last);
  if (liquidity != null) {
    return liquidity == 'MISSING_DATA'
        ? CandidateSkipReason.noData
        : CandidateSkipReason.lowLiquidity;
  }
  return null;
}

/// 雙 horizon 評分核心：
///
/// 1. mutex 過濾——short / long 各自用 horizon-aware calibrated lookup
///    （H-1 fix：calculateScore 是 pure arithmetic contract、不做 mutex，
///    caller 顯式控制；calibration 因此能在不同 horizon 翻轉 mutex 贏家，
///    fallback 到 hardcoded 維持 calibration 未載入時的等效行為）
/// 2. 兩 horizon 各自 calculateScore
/// 3. 持久化門檻 = observationScoreThreshold（8）：任一 horizon ≥ 8 即保留，
///    掃描頁再分層（≥12 成立訊號 / 8–11 觀察區）。門檻兩 horizon 共用、
///    不做 per-horizon 拆分（設計 §9，YAGNI）
/// 4. UI 顯示用 hardcoded 分數另做一次 mutex（保持「design intent 強度」
///    可讀性）再取 topReasons——與 scoring 路徑的 mutex 互不影響
///
/// 回傳 null 表示兩 horizon 都低於觀察門檻、應過濾。
({int scoreShort, int scoreLong, List<TriggeredReason> topReasons})?
scoreReasonsDualHorizon({
  required RuleEngine ruleEngine,
  required List<TriggeredReason> reasons,
  required CalibratedScoreContext calibratedScores,
}) {
  final mutedShort = ruleEngine.applyMutexGroups(
    reasons,
    (r) => calibratedScores.lookup(Horizon.short, r.type.code) ?? r.score,
  );
  final mutedLong = ruleEngine.applyMutexGroups(
    reasons,
    (r) => calibratedScores.lookup(Horizon.long, r.type.code) ?? r.score,
  );

  final scoreShort = ruleEngine.calculateScore(
    mutedShort,
    horizon: Horizon.short,
    calibratedScores: calibratedScores,
  );
  final scoreLong = ruleEngine.calculateScore(
    mutedLong,
    horizon: Horizon.long,
    calibratedScores: calibratedScores,
  );

  if (scoreShort < RuleParams.observationScoreThreshold &&
      scoreLong < RuleParams.observationScoreThreshold) {
    return null;
  }

  final mutedForUi = ruleEngine.applyMutexGroups(reasons, (r) => r.score);
  final topReasons = ruleEngine.getTopReasons(mutedForUi);

  return (scoreShort: scoreShort, scoreLong: scoreLong, topReasons: topReasons);
}
