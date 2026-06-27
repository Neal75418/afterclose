// 第 9 階段：強股回檔進場 (Mode C v2)
//
// 2026-06-19 workflow wf_6676643c-0e9 設計、3 條 buy-signal rule 識別「**之前
// 強、現在剛開始拉回**」的進場時機。score 正分（跟 Mode A/B 一致）— 打破舊
// 「Mode C 全負分 warning」invariant，因為新 Mode C 是「觀察機會 tab」而非
// 「警示 tab」。
//
// **CALIBRATION_PENDING**：閾值是直覺值、缺台股 backtest。pre-launch 上線
// 後靠 telemetry 30 天累積樣本後校準。
//
// 設計原則：
// - 每條 rule 用 MA stack（ma5 > ma20 > ma60）自驗多頭排列，不依賴
//   `context.trendState`（避免耦合）
// - 過去強勢確認用 `_wasStrongOverPeriod`（20 日累積漲幅 ≥ 5%）
// - 跌停日（pct ≤ -9.5%）一律 short-circuit return null（避免恐慌下殺誤判）

import 'package:afterclose/core/constants/reason_type.dart';
import 'package:afterclose/core/constants/rule_params_pullback.dart';
import 'package:afterclose/core/constants/rule_scores.dart';
import 'package:afterclose/domain/models/analysis_context.dart';
import 'package:afterclose/domain/models/triggered_reason.dart';
import 'package:afterclose/domain/services/rules/candlestick_rules.dart'
    show isHammerShape;
import 'package:afterclose/domain/services/rules/stock_rules.dart';

// ============================================
// Shared helpers — pullback rules 共用
// ============================================

/// 過去 N 日累積漲幅 ≥ 5%（強勢 baseline）
///
/// 用 N 日前的 close 跟今日的 ma20 比較：ma20 > pastClose * 1.05 代表中期
/// 趨勢確實向上（不是 flat 累積）。
bool wasStrongOverPeriod(
  StockData data,
  double ma20Now, {
  int days = PullbackParams.strongLookbackDays,
}) {
  if (data.prices.length < days + 1) return false;
  final past = data.prices[data.prices.length - 1 - days];
  final pastClose = past.close;
  if (pastClose == null || pastClose <= 0) return false;
  return ma20Now > pastClose * PullbackParams.wasStrongMinRatio;
}

/// 跌停日 guard（台股 ±10%、留 0.5% 安全 margin）
///
/// 跌停代表恐慌賣壓或突發利空、不是 sweet spot 進場、無論 K 線 / 量能怎麼樣
/// 都該 return null。
bool isLimitDownDay(StockData data) {
  if (data.prices.length < 2) return false;
  final today = data.prices.last;
  final prev = data.prices[data.prices.length - 2];
  final todayClose = today.close;
  final prevClose = prev.close;
  if (todayClose == null || prevClose == null || prevClose <= 0) return false;
  return (todayClose - prevClose) / prevClose <= PullbackParams.limitDownRatio;
}

/// 過去 N 日內至少 1 根紅 K（過濾瀑布跌、cascading decline）
///
/// 連跌 5 天才碰 MA20 不是「健康回檔」、是 panicky decline、return false
/// 阻止 fire。
bool hasRecentBullishCandle(
  StockData data, {
  int days = PullbackParams.recentBullishCandleDays,
}) {
  if (data.prices.length < days + 1) return false;
  final start = data.prices.length - days - 1;
  for (var i = start; i < data.prices.length - 1; i++) {
    final p = data.prices[i];
    final close = p.close;
    final open = p.open;
    if (close != null && open != null && close > open) return true;
  }
  return false;
}

// ============================================
// Rule A: PULLBACK_TO_MA20 — 強勢回檔至 MA20 (量縮)
// ============================================

/// 強股拉回 MA20 動態支撐位 + 量能縮減 + 多頭排列維持
///
/// 最常見的「健康回檔」訊號、score +15（給 user「**進場時機**」alert）。
class HealthyPullbackToMa20Rule extends StockRule {
  const HealthyPullbackToMa20Rule();

  @override
  String get id => 'pullback_to_ma20';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    // ---- Step 1: history / indicators 必備 ----
    if (data.prices.length < PullbackParams.minHistoryDays) return null;
    final ind = context.indicators;
    if (ind == null) return null;
    final ma5 = ind.ma5;
    final ma20 = ind.ma20;
    final ma60 = ind.ma60;
    final volumeMA20 = ind.volumeMA20;
    if (ma5 == null || ma20 == null || ma60 == null || volumeMA20 == null) {
      return null;
    }

    final today = data.prices.last;
    final yesterday = data.prices[data.prices.length - 2];
    final todayClose = today.close;
    final todayVolume = today.volume;
    final yesterdayClose = yesterday.close;
    if (todayClose == null ||
        todayVolume == null ||
        todayVolume <= 0 ||
        yesterdayClose == null) {
      return null;
    }

    // ---- Step 2: 多頭排列 + 站上 MA60 ----
    if (!(ma5 > ma20 && ma20 > ma60)) return null;
    if (todayClose <= ma60) return null;

    // ---- Step 3: 過去 20 日強勢 ----
    if (!wasStrongOverPeriod(data, ma20)) return null;

    // ---- Step 4: 拉回到 MA20 附近 (-1.5% ~ +3%) ----
    final distanceToMa20 = (todayClose - ma20) / ma20;
    if (distanceToMa20 < PullbackParams.ma20PullbackBandLow ||
        distanceToMa20 > PullbackParams.ma20PullbackBandHigh) {
      return null;
    }

    // ---- Step 5: 今日收黑 ----
    if (todayClose >= yesterdayClose) return null;

    // ---- Step 6: 量縮 (< volumeMA20 * 0.85) ----
    if (todayVolume >= volumeMA20 * PullbackParams.volumeShrinkRatio) {
      return null;
    }

    // ---- Step 7: 非跌停 ----
    if (isLimitDownDay(data)) return null;

    // ---- Step 8: 過去 5 日非瀑布跌（至少 1 根紅 K）----
    if (!hasRecentBullishCandle(data)) return null;

    // ---- 全部過 → fire ----
    final past20Close =
        data
            .prices[data.prices.length - 1 - PullbackParams.strongLookbackDays]
            .close ??
        0;
    final past20dGain = past20Close > 0 ? (ma20 / past20Close - 1) * 100 : 0.0;

    return TriggeredReason(
      type: ReasonType.pullbackToMa20,
      score: RuleScores.pullbackToMa20,
      description: '強勢回檔至 MA20 (量縮)',
      evidence: {
        'close': todayClose,
        'ma5': ma5,
        'ma20': ma20,
        'ma60': ma60,
        'distanceToMa20Pct': distanceToMa20 * 100,
        'volume': todayVolume,
        'volumeMA20': volumeMA20,
        'volumeRatio': todayVolume / volumeMA20,
        'past20dGain': past20dGain,
      },
    );
  }
}

// ============================================
// Rule A2: PULLBACK_TO_MA10 — 強勢淺回檔至 MA10 (量縮)
// ============================================

/// 強股拉回 MA10（淺回檔）+ 量縮 + 多頭排列維持 + close 仍在 MA20 上方
///
/// **2026-06-20 B2 加**：MA20 深回檔對強股太稀有（強股遠在 MA20 上方）、Mode C
/// 常空白。MA10 是「buy the dip」經典淺回檔帶、日常頻率高。score +12（淺＝最低
/// tier）。
///
/// **與 [HealthyPullbackToMa20Rule] 互斥**：要求 close > ma20（價還沒跌到深支撐），
/// MA20 rule 要 close 在 ma20 附近 → 同一檔不會雙 fire（趨勢市 ma10 與 ma20 分離）。
///
/// **CALIBRATION_PENDING**：閾值直覺值、缺 backtest。
class HealthyPullbackToMa10Rule extends StockRule {
  const HealthyPullbackToMa10Rule();

  @override
  String get id => 'pullback_to_ma10';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    // ---- Step 1: history / indicators 必備 ----
    if (data.prices.length < PullbackParams.minHistoryDays) return null;
    final ind = context.indicators;
    if (ind == null) return null;
    final ma10 = ind.ma10;
    final ma20 = ind.ma20;
    final ma60 = ind.ma60;
    final volumeMA20 = ind.volumeMA20;
    if (ma10 == null || ma20 == null || ma60 == null || volumeMA20 == null) {
      return null;
    }

    final today = data.prices.last;
    final yesterday = data.prices[data.prices.length - 2];
    final todayClose = today.close;
    final todayVolume = today.volume;
    final yesterdayClose = yesterday.close;
    if (todayClose == null ||
        todayVolume == null ||
        todayVolume <= 0 ||
        yesterdayClose == null) {
      return null;
    }

    // ---- Step 2: 中期多頭排列（不要求 ma5>ma10、因 ma5 正回落）----
    if (!(ma10 > ma20 && ma20 > ma60)) return null;

    // ---- Step 3: 淺回檔分界 — close 仍在 MA20 上方（與 MA20 深回檔互斥）----
    if (todayClose <= ma20) return null;

    // ---- Step 4: 過去 20 日強勢（錨在 ma10）----
    if (!wasStrongOverPeriod(data, ma10)) return null;

    // ---- Step 5: 拉回到 MA10 附近 (-1.5% ~ +2.5%) ----
    final distanceToMa10 = (todayClose - ma10) / ma10;
    if (distanceToMa10 < PullbackParams.ma10PullbackBandLow ||
        distanceToMa10 > PullbackParams.ma10PullbackBandHigh) {
      return null;
    }

    // ---- Step 6: 今日收黑 ----
    if (todayClose >= yesterdayClose) return null;

    // ---- Step 7: 量縮 (< volumeMA20 * 0.85) ----
    if (todayVolume >= volumeMA20 * PullbackParams.volumeShrinkRatio) {
      return null;
    }

    // ---- Step 8: 非跌停 ----
    if (isLimitDownDay(data)) return null;

    // ---- Step 9: 過去 5 日非瀑布跌 ----
    if (!hasRecentBullishCandle(data)) return null;

    final past20Close =
        data
            .prices[data.prices.length - 1 - PullbackParams.strongLookbackDays]
            .close ??
        0;
    final past20dGain = past20Close > 0 ? (ma10 / past20Close - 1) * 100 : 0.0;

    return TriggeredReason(
      type: ReasonType.pullbackToMa10,
      score: RuleScores.pullbackToMa10,
      description: '強勢回檔至 MA10 (淺回檔)',
      evidence: {
        'close': todayClose,
        'ma10': ma10,
        'ma20': ma20,
        'ma60': ma60,
        'distanceToMa10Pct': distanceToMa10 * 100,
        'volume': todayVolume,
        'volumeMA20': volumeMA20,
        'volumeRatio': todayVolume / volumeMA20,
        'past20dGain': past20dGain,
      },
    );
  }
}

// ============================================
// Rule B: HAMMER_AT_SUPPORT — 強股拉回支撐 + 錘子止跌
// ============================================

/// 強股拉回 MA20 / MA60 支撐位 + 出現錘子線 K 線型態 + 收盤站穩支撐
///
/// 比單純 pullback 多了「**止跌確認**」、score +18（最強主訊號）。
class HammerAtSupportRule extends StockRule {
  const HammerAtSupportRule();

  @override
  String get id => 'hammer_at_support';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    // ---- Step 1: history / indicators 必備 ----
    if (data.prices.length < PullbackParams.minHistoryDays) return null;
    final ind = context.indicators;
    if (ind == null) return null;
    final ma20 = ind.ma20;
    final ma60 = ind.ma60;
    if (ma20 == null || ma60 == null) return null;

    final today = data.prices.last;
    final open = today.open;
    final close = today.close;
    final high = today.high;
    final low = today.low;
    if (open == null || close == null || high == null || low == null) {
      return null;
    }

    // ---- Step 2: 多頭排列（簡化版：ma20 > ma60）+ 過去強勢 ----
    if (ma20 <= ma60) return null;
    if (!wasStrongOverPeriod(data, ma20)) return null;

    // ---- Step 3: 錘子形狀 ----
    if (!isHammerShape(today)) return null;

    // ---- Step 4: body 非零（排除 doji-like）----
    if ((close - open).abs() == 0) return null;

    // ---- Step 5: 下影線觸及支撐 (MA20 或 MA60) ----
    //
    // **2026-06-20 早期體檢修正（CALIBRATION_PENDING）**：原 ±1.5% 太緊 — 強股的
    // low 通常在 MA20 上方（實測中位數 +11.1%、只 7.8% 落 ±1.5%）、理論母體 ~0。
    // 放寬到 ±4%（對齊 strong-stock low p10≈-3.5%）讓「拉回測支撐」的強股進得來。
    final touchMa20 =
        (low - ma20).abs() / ma20 <= PullbackParams.hammerSupportTouchBand;
    final touchMa60 =
        (low - ma60).abs() / ma60 <= PullbackParams.hammerSupportTouchBand;
    if (!touchMa20 && !touchMa60) return null;
    final support = touchMa20 ? 'MA20' : 'MA60';
    final supportLevel = touchMa20 ? ma20 : ma60;

    // ---- Step 6: 收盤站穩支撐 (close >= supportLevel * 0.985) ----
    if (close < supportLevel * PullbackParams.hammerCloseHoldRatio) return null;

    // ---- Step 7: close 在 MA20 附近（≤ MA20 * 1.06）— 與 HangingMan 互斥位置 ----
    //
    // **2026-06-20 早期體檢修正**：原 ≤ MA20*1.03 配合 ±4% touch 放寬同步放寬到
    // 1.06，避免「low 觸支撐但 close 已彈回」的強股回檔被擋。仍保留上界讓真正高
    // 檔（HangingMan 區）交給 HangingManRule 處理。
    if (close > ma20 * PullbackParams.hammerCloseMaxMa20Ratio) return null;

    // ---- Step 8: 非跌停 ----
    if (isLimitDownDay(data)) return null;

    // ---- Fire ----
    final volumeMA20 = ind.volumeMA20;
    final todayVolume = today.volume;
    final volumeRatio =
        (volumeMA20 != null && todayVolume != null && volumeMA20 > 0)
        ? todayVolume / volumeMA20
        : null;
    final yesterdayClose = data.prices.length >= 2
        ? data.prices[data.prices.length - 2].close
        : null;
    final gapDown = (yesterdayClose != null && yesterdayClose > 0)
        ? (yesterdayClose - open) / yesterdayClose >
              PullbackParams.hammerGapDownRatio
        : false;

    return TriggeredReason(
      type: ReasonType.hammerAtSupport,
      score: RuleScores.hammerAtSupport,
      description: '$support 支撐位錘子線 (強股止跌)',
      evidence: {
        'open': open,
        'close': close,
        'high': high,
        'low': low,
        'ma20': ma20,
        'ma60': ma60,
        'support': support,
        'supportLevel': supportLevel,
        'distanceLowToSupportPct': (low - supportLevel) / supportLevel * 100,
        if (volumeRatio != null) 'volumeRatio': volumeRatio,
        'gapDown': gapDown,
      },
    );
  }
}

// ============================================
// Rule C: KD_HIGH_PULLBACK — KD 高檔回落未死叉
// ============================================

/// KD 從 80+ 回落到 [50, 75] 區間但 K > D（未死叉）+ 多頭排列維持
///
/// 技術指標 proxy、相對較弱訊號、score +12。
class KdHighLevelPullbackRule extends StockRule {
  const KdHighLevelPullbackRule();

  @override
  String get id => 'kd_high_pullback';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    // ---- Step 1: indicators 必備 ----
    final ind = context.indicators;
    if (ind == null) return null;
    final kdK = ind.kdK;
    final kdD = ind.kdD;
    final prevKdK = ind.prevKdK;
    final ma20 = ind.ma20;
    final ma60 = ind.ma60;
    if (kdK == null ||
        kdD == null ||
        prevKdK == null ||
        ma20 == null ||
        ma60 == null) {
      return null;
    }

    // ---- Step 2: today.close 必備 ----
    if (data.prices.isEmpty) return null;
    final todayClose = data.prices.last.close;
    if (todayClose == null) return null;

    // ---- Step 3: 多頭排列 ----
    if (ma20 <= ma60) return null;

    // ---- Step 4: 前日 KD 在高檔（prevKdK >= 78）----
    //
    // **2026-06-20 早期體檢修正（CALIBRATION_PENDING）**：原 >= 80 太緊、80 邊緣
    // 回落進不來。放寬到 78 容納剛從超買區滑落的 case。
    if (prevKdK < PullbackParams.kdHighPrevMin) return null;

    // ---- Step 5: 今日 K 回落到 [60, 80) 區間 ----
    //
    // **2026-06-20 早期體檢修正**：原 [50, 75] 含數學矛盾 — KD 平滑因子寫死 1/3
    // （technical_indicator_service kSmoothFactor），prevKdK≥78 時單日 K 下限 =
    // 78×2/3 = 52，[50,52) 物理上一天到不了；上緣 75 又把真實「高檔剛回落」帶
    // (75-80) 排除掉。改 [60, 80)：60 是 1/3 平滑可達的合理下緣、80 開區間排除
    // 「還在超買沒回落」。實測 prevKdK≥80 母體原 0 fire、改後預估 10-30 檔可進。
    if (kdK < PullbackParams.kdPullbackBandLow ||
        kdK >= PullbackParams.kdPullbackBandHigh) {
      return null;
    }

    // ---- Step 6: 未死叉（kdK > kdD）----
    //
    // 語意核心保留。窗口上移到 [60,80) 後 K 仍在 D 上方機率大增、不再像舊窗口
    // [50,75] 那樣「掉進區間的都已死叉」自相殘殺。
    if (kdK <= kdD) return null;

    // ---- Step 7: 收盤未破 MA20 過深（>= ma20 * 0.99）----
    if (todayClose < ma20 * PullbackParams.kdCloseMinMa20Ratio) return null;

    // ---- Step 8: K 值漸降非崩跌（單日 K 跌幅 <= 30）----
    //
    // **2026-06-20 早期體檢修正**：原 <= 20 跟 [60,80) 窗口衝突（prevKdK 高時
    // drop 自然 > 20）、是窗口變窄元兇。放寬到 30 保留 panic 防護但不殺窗口。
    final kdKDailyDrop = prevKdK - kdK;
    if (kdKDailyDrop > PullbackParams.kdMaxDailyDrop) return null;

    // ---- Step 9: 非跌停 ----
    if (isLimitDownDay(data)) return null;

    return TriggeredReason(
      type: ReasonType.kdHighPullback,
      score: RuleScores.kdHighPullback,
      description: 'KD 高檔回落未死叉 (動能稍歇)',
      evidence: {
        'kdK': kdK,
        'kdD': kdD,
        'prevKdK': prevKdK,
        'kdKDailyDrop': kdKDailyDrop,
        'close': todayClose,
        'ma20': ma20,
        'ma60': ma60,
        if (ind.rsi != null) 'rsi': ind.rsi!,
      },
    );
  }
}
