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
bool wasStrongOverPeriod(StockData data, double ma20Now, {int days = 20}) {
  if (data.prices.length < days + 1) return false;
  final past = data.prices[data.prices.length - 1 - days];
  final pastClose = past.close;
  if (pastClose == null || pastClose <= 0) return false;
  return ma20Now > pastClose * 1.05;
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
  return (todayClose - prevClose) / prevClose <= -0.095;
}

/// 過去 N 日內至少 1 根紅 K（過濾瀑布跌、cascading decline）
///
/// 連跌 5 天才碰 MA20 不是「健康回檔」、是 panicky decline、return false
/// 阻止 fire。
bool hasRecentBullishCandle(StockData data, {int days = 5}) {
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
    if (data.prices.length < 21) return null;
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
    if (!wasStrongOverPeriod(data, ma20, days: 20)) return null;

    // ---- Step 4: 拉回到 MA20 附近 (-1.5% ~ +3%) ----
    final distanceToMa20 = (todayClose - ma20) / ma20;
    if (distanceToMa20 < -0.015 || distanceToMa20 > 0.03) return null;

    // ---- Step 5: 今日收黑 ----
    if (todayClose >= yesterdayClose) return null;

    // ---- Step 6: 量縮 (< volumeMA20 * 0.85) ----
    if (todayVolume >= volumeMA20 * 0.85) return null;

    // ---- Step 7: 非跌停 ----
    if (isLimitDownDay(data)) return null;

    // ---- Step 8: 過去 5 日非瀑布跌（至少 1 根紅 K）----
    if (!hasRecentBullishCandle(data, days: 5)) return null;

    // ---- 全部過 → fire ----
    final past20Close = data.prices[data.prices.length - 1 - 20].close ?? 0;
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
    if (data.prices.length < 21) return null;
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
    if (!wasStrongOverPeriod(data, ma20, days: 20)) return null;

    // ---- Step 3: 錘子形狀 ----
    if (!isHammerShape(today)) return null;

    // ---- Step 4: body 非零（排除 doji-like）----
    if ((close - open).abs() == 0) return null;

    // ---- Step 5: 下影線觸及支撐 (MA20 或 MA60) ----
    final touchMa20 = (low - ma20).abs() / ma20 <= 0.015;
    final touchMa60 = (low - ma60).abs() / ma60 <= 0.015;
    if (!touchMa20 && !touchMa60) return null;
    final support = touchMa20 ? 'MA20' : 'MA60';
    final supportLevel = touchMa20 ? ma20 : ma60;

    // ---- Step 6: 收盤站穩支撐 (close >= supportLevel * 0.985) ----
    if (close < supportLevel * 0.985) return null;

    // ---- Step 7: close 在 MA20 附近（≤ MA20 * 1.03）— 與 HangingMan 互斥位置 ----
    if (close > ma20 * 1.03) return null;

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
        ? (yesterdayClose - open) / yesterdayClose > 0.01
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

    // ---- Step 4: 前日 KD 在高檔（prevKdK >= 80）----
    if (prevKdK < 80) return null;

    // ---- Step 5: 今日 K 回落到 [50, 75] 區間（inclusive 兩端）----
    if (kdK < 50 || kdK > 75) return null;

    // ---- Step 6: 未死叉（kdK > kdD）----
    if (kdK <= kdD) return null;

    // ---- Step 7: 收盤未破 MA20 過深（>= ma20 * 0.99）----
    if (todayClose < ma20 * 0.99) return null;

    // ---- Step 8: K 值漸降非崩跌（單日 K 跌幅 <= 20）----
    final kdKDailyDrop = prevKdK - kdK;
    if (kdKDailyDrop > 20) return null;

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
