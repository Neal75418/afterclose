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
import 'package:afterclose/domain/services/liquidity_checker.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/models.dart';
import 'package:afterclose/domain/services/rule_engine.dart';

/// 候選股被略過的原因分類（統計計數用）
enum CandidateSkipReason { noData, insufficientData, lowLiquidity, staleBar }

/// 資格檢查：價格資料存在、歷史長度足夠、當日 bar 新鮮、流動性合格。
///
/// 回傳 null 表示通過；通過時保證 `prices.last` 的 close/volume 非 null
/// （由 [LiquidityChecker] 的 MISSING_DATA 檢查擔保）。
///
/// [asOf] 為評分日。給定時會要求 `prices.last` 就是該日的 bar，否則回
/// [CandidateSkipReason.staleBar]。
///
/// 為什麼需要這道檢查：`batch_data_loader` 的價格窗以 `endDate = 評分日`
/// 收斂，所以 DB 缺當日 bar 時 `prices.last` 會**自動退化成前一交易日**，
/// 而本函式原本只驗 null/長度/流動性 —— 於是「昨日 K 棒算出的訊號掛上
/// 今日日期寫進 daily_analysis」可以無聲通過。這條路徑不只在 API 限流時
/// 出現：`price_repository.dart` 的「兩市場皆空」是正常回傳（不拋例外）、
/// NetworkException 也不會翻起 `rateLimitedAbort`，所以上游任何以旗標為
/// 基礎的閘門都擋不住，必須在此處以資料本身為準。
///
/// 實測：2026-07-15~07-24 共 8 個交易日、1,568 列 daily_analysis，「當日
/// 無有效價格 bar」的有 0 列 —— 健康日此檢查是 no-op，只在故障路徑生效。
///
/// [asOf] 省略時不做此檢查（向後相容；isolate 輸入的 date 可為 null）。
CandidateSkipReason? classifyCandidate(
  List<DailyPriceEntry>? prices, {
  DateTime? asOf,
}) {
  if (prices == null || prices.isEmpty) return CandidateSkipReason.noData;
  if (prices.length < RuleParams.swingWindow) {
    return CandidateSkipReason.insufficientData;
  }
  if (asOf != null) {
    // 逐欄比 y/m/d：DateTime 的 == 連時分秒與 isUtc 一起比，
    // 評分日帶了時間就會把整批股票誤殺。與 update_service 既有回滾
    // 比較法同源。
    final last = prices.last.date;
    if (last.year != asOf.year ||
        last.month != asOf.month ||
        last.day != asOf.day) {
      return CandidateSkipReason.staleBar;
    }
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
({
  int scoreShort,
  int scoreLong,
  List<TriggeredReason> topReasons,
  Map<String, double> decayMultipliers,
})?
scoreReasonsDualHorizon({
  required RuleEngine ruleEngine,
  required List<TriggeredReason> reasons,
  required CalibratedScoreContext calibratedScores,
}) {
  // 基本面同組遞減（對原始 reasons 算一次、兩 horizon 與持久化共用；
  // 排序用 hardcoded 設計分數、horizon 無關）
  final decayMultipliers = ruleEngine.computeFundamentalDecayMultipliers(
    reasons,
  );

  final mutedShort = ruleEngine.applyMutexGroups(
    reasons,
    (r) => calibratedScores.lookup(Horizon.short, r.type.code) ?? r.score,
  );
  final mutedLong = ruleEngine.applyMutexGroups(
    reasons,
    (r) => calibratedScores.lookup(Horizon.long, r.type.code) ?? r.score,
  );

  // floorAtZero: false —— 門檻要看「帶正負號的 raw 總分」:引擎的下限
  // clamp 會把純空方股(如只觸發跌破季線 -8)變 0 而被剪掉,掃描與風控
  // 就看不見它們。落庫值另行 floor 回 0,維持下游「分數非負」契約。
  final rawShort = ruleEngine.calculateScore(
    mutedShort,
    horizon: Horizon.short,
    calibratedScores: calibratedScores,
    decayMultipliers: decayMultipliers,
    floorAtZero: false,
  );
  final rawLong = ruleEngine.calculateScore(
    mutedLong,
    horizon: Horizon.long,
    calibratedScores: calibratedScores,
    decayMultipliers: decayMultipliers,
    floorAtZero: false,
  );

  // 門檻取絕對值(2026-07-31):純空方觸發(負總分)的股票也要落庫,
  // 否則「只跌破季線」的弱勢股在掃描器上隱形——空方風控正好在最需要
  // 它的股票上失明,rule_accuracy 觀察區也帶倖存者偏差。
  if (rawShort.abs() < RuleParams.observationScoreThreshold &&
      rawLong.abs() < RuleParams.observationScoreThreshold) {
    return null;
  }
  final scoreShort = rawShort < 0 ? 0 : rawShort;
  final scoreLong = rawLong < 0 ? 0 : rawLong;

  final mutedForUi = ruleEngine.applyMutexGroups(reasons, (r) => r.score);
  final topReasons = ruleEngine.getTopReasons(mutedForUi);

  return (
    scoreShort: scoreShort,
    scoreLong: scoreLong,
    topReasons: topReasons,
    decayMultipliers: decayMultipliers,
  );
}
