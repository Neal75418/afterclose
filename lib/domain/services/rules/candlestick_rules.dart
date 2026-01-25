import 'dart:math';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/price_calculator.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/analysis_service.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';

// ==========================================
// K 線型態規則
// ==========================================

/// 判斷 K 棒是否為錘子/吊人形態
///
/// 錘子線與吊人線形狀相同：
/// - 下影線 >= 實體 * 2
/// - 上影線 <= 實體 * 0.5
/// - 實體 >= 振幅 * 5%
bool isHammerShape(DailyPriceEntry candle) {
  if (candle.open == null ||
      candle.close == null ||
      candle.high == null ||
      candle.low == null) {
    return false;
  }

  final open = candle.open!;
  final close = candle.close!;
  final high = candle.high!;
  final low = candle.low!;

  final body = (close - open).abs();
  final lowerShadow = min(open, close) - low;
  final upperShadow = high - max(open, close);

  final range = high - low;
  if (range == 0) return false;
  if (body < range * 0.05) return false;

  return lowerShadow >= body * 2 && upperShadow <= body * 0.5;
}

/// 規則：十字線型態（市場猶豫不決）
class DojiRule extends StockRule {
  const DojiRule();

  @override
  String get id => 'pattern_doji';

  @override
  String get name => '十字線';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    if (data.prices.isEmpty) return null;
    final today = data.prices.last;

    if (_isDoji(today)) {
      // 過濾條件：RSI 必須在極端區域（>70 或 <30）
      final rsi = context.indicators?.rsi;
      if (rsi != null && rsi > 30 && rsi < 70) return null;

      return TriggeredReason(
        type: ReasonType.patternDoji,
        score: RuleScores.patternDoji,
        description: '出現十字線變盤訊號',
        evidence: {
          'open': today.open,
          'close': today.close,
          'high': today.high,
          'low': today.low,
        },
      );
    }
    return null;
  }

  bool _isDoji(DailyPriceEntry candle) {
    if (candle.open == null ||
        candle.close == null ||
        candle.high == null ||
        candle.low == null) {
      return false;
    }
    final range = candle.high! - candle.low!;
    if (range == 0) return true; // 無波動為十字線

    final body = (candle.close! - candle.open!).abs();
    // 實體小於總振幅的 10%
    return body <= range * 0.1;
  }
}

/// 規則：多頭吞噬型態
class BullishEngulfingRule extends StockRule {
  const BullishEngulfingRule();

  @override
  String get id => 'pattern_bullish_engulfing';

  @override
  String get name => '多頭吞噬';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    if (data.prices.length < 2) return null;

    // 僅在下跌趨勢或區間底部有效
    if (context.trendState == TrendState.up) return null;

    final today = data.prices.last;
    final yesterday = data.prices[data.prices.length - 2];

    if (_isBullishEngulfing(today, yesterday)) {
      return TriggeredReason(
        type: ReasonType.patternBullishEngulfing,
        score: RuleScores.patternEngulfing,
        description: '多頭吞噬型態 (一紅吃一黑)',
        evidence: {
          'today_open': today.open,
          'today_close': today.close,
          'prev_open': yesterday.open,
          'prev_close': yesterday.close,
        },
      );
    }
    return null;
  }

  bool _isBullishEngulfing(DailyPriceEntry today, DailyPriceEntry prev) {
    if (today.open == null ||
        today.close == null ||
        prev.open == null ||
        prev.close == null) {
      return false;
    }

    // 前一日：空方 K 線（收盤 < 開盤）
    final prevOpen = prev.open!;
    final prevClose = prev.close!;
    if (prevClose >= prevOpen) return false;

    // 今日：多方 K 線（收盤 > 開盤）
    final currOpen = today.open!;
    final currClose = today.close!;
    if (currClose <= currOpen) return false;

    // 吞噬邏輯：
    // 今日開盤 <= 前日收盤 且 今日收盤 >= 前日開盤
    return currOpen <= prevClose && currClose >= prevOpen;
  }
}

/// 規則：空頭吞噬型態
class BearishEngulfingRule extends StockRule {
  const BearishEngulfingRule();

  @override
  String get id => 'pattern_bearish_engulfing';

  @override
  String get name => '空頭吞噬';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    if (data.prices.length < 2) return null;

    // 僅在上漲趨勢或區間頂部有效
    if (context.trendState == TrendState.down) return null;

    final today = data.prices.last;
    final yesterday = data.prices[data.prices.length - 2];

    if (_isBearishEngulfing(today, yesterday)) {
      // 過濾條件：成交量須 > 5 日平均量
      if (!PriceCalculator.isVolumeAboveAverage(data.prices, days: 5)) {
        return null;
      }

      return TriggeredReason(
        type: ReasonType.patternBearishEngulfing,
        score: RuleScores.patternEngulfing,
        description: '空頭吞噬型態 (一黑吃一紅)',
        evidence: {
          'today_open': today.open,
          'today_close': today.close,
          'prev_open': yesterday.open,
          'prev_close': yesterday.close,
        },
      );
    }
    return null;
  }

  bool _isBearishEngulfing(DailyPriceEntry today, DailyPriceEntry prev) {
    if (today.open == null ||
        today.close == null ||
        prev.open == null ||
        prev.close == null) {
      return false;
    }

    // 前一日：多方 K 線
    if (prev.close! <= prev.open!) return false;

    // 今日：空方 K 線
    if (today.close! >= today.open!) return false;

    // 吞噬邏輯：
    // 今日開盤 >= 前日收盤 且 今日收盤 <= 前日開盤
    return today.open! >= prev.close! && today.close! <= prev.open!;
  }
}

/// 規則：錘子線（多方反轉訊號）
class HammerRule extends StockRule {
  const HammerRule();

  @override
  String get id => 'pattern_hammer';

  @override
  String get name => '錘子線';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    if (data.prices.isEmpty) return null;
    // 必須處於下跌趨勢
    if (context.trendState == TrendState.up) return null;

    final today = data.prices.last;
    if (isHammerShape(today)) {
      return TriggeredReason(
        type: ReasonType.patternHammer,
        score: RuleScores.patternHammer,
        description: '低檔錘子線 (下影線長)',
        evidence: {
          'open': today.open,
          'close': today.close,
          'high': today.high,
          'low': today.low,
        },
      );
    }
    return null;
  }
}

/// 規則：吊人線（空方反轉訊號）
class HangingManRule extends StockRule {
  const HangingManRule();

  @override
  String get id => 'pattern_hanging_man';

  @override
  String get name => '吊人線';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    if (data.prices.isEmpty) return null;
    // 必須處於上漲趨勢
    if (context.trendState == TrendState.down) return null;

    final today = data.prices.last;
    // 吊人線與錘子線形狀相同，但出現在頂部
    if (isHammerShape(today)) {
      return TriggeredReason(
        type: ReasonType.patternHangingMan,
        score: RuleScores.patternHammer,
        description: '高檔吊人線 (需確認)',
        evidence: {
          'open': today.open,
          'close': today.close,
          'high': today.high,
          'low': today.low,
        },
      );
    }
    return null;
  }
}

/// 規則：向上跳空缺口（多方訊號）
class GapUpRule extends StockRule {
  const GapUpRule();

  @override
  String get id => 'pattern_gap_up';

  @override
  String get name => '跳空上漲';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    if (data.prices.length < 2) return null;

    final today = data.prices.last;
    final prev = data.prices[data.prices.length - 2];

    if (today.low == null || prev.high == null) return null;

    final gapSize = today.low! - prev.high!;
    final threshold = prev.close! * 0.005;

    if (gapSize > 0 && gapSize >= threshold) {
      return TriggeredReason(
        type: ReasonType.patternGapUp,
        score: RuleScores.patternGap,
        description: '向上跳空缺口',
        evidence: {
          'today_low': today.low,
          'prev_high': prev.high,
          'gap': gapSize,
        },
      );
    }
    return null;
  }
}

/// 規則：向下跳空缺口（空方訊號）
class GapDownRule extends StockRule {
  const GapDownRule();

  @override
  String get id => 'pattern_gap_down';

  @override
  String get name => '跳空下跌';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    if (data.prices.length < 2) return null;

    final today = data.prices.last;
    final prev = data.prices[data.prices.length - 2];

    if (today.high == null || prev.low == null) return null;

    final gapSize = prev.low! - today.high!;
    final threshold = prev.close! * 0.005;

    if (gapSize > 0 && gapSize >= threshold) {
      return TriggeredReason(
        type: ReasonType.patternGapDown,
        score: RuleScores.patternGap,
        description: '向下跳空缺口',
        evidence: {
          'today_high': today.high,
          'prev_low': prev.low,
          'gap': gapSize,
        },
      );
    }
    return null;
  }
}

/// 規則：晨星型態（多方反轉訊號）
class MorningStarRule extends StockRule {
  const MorningStarRule();

  @override
  String get id => 'pattern_morning_star';

  @override
  String get name => '晨星';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    if (data.prices.length < 3) return null;
    if (context.trendState == TrendState.up) return null;

    final c3 = data.prices.last;
    final c2 = data.prices[data.prices.length - 2];
    final c1 = data.prices[data.prices.length - 3];

    if (_isMorningStar(c1, c2, c3)) {
      return TriggeredReason(
        type: ReasonType.patternMorningStar,
        score: RuleScores.patternStar,
        description: '晨星型態 (底部反轉)',
        evidence: {
          'c1_close': c1.close,
          'c2_close': c2.close,
          'c3_close': c3.close,
        },
      );
    }
    return null;
  }

  bool _isMorningStar(
    DailyPriceEntry c1,
    DailyPriceEntry c2,
    DailyPriceEntry c3,
  ) {
    if (c1.close == null ||
        c1.open == null ||
        c2.close == null ||
        c2.open == null ||
        c3.close == null ||
        c3.open == null) {
      return false;
    }

    // 1. 第一根 K 線：長黑 K
    final c1Body = c1.close! - c1.open!;
    if (c1Body >= 0) return false;

    // 2. 第二根 K 線：小實體（星線），理想情況向下跳空
    final c2Body = (c2.close! - c2.open!).abs();

    if (c2Body > c1Body.abs() * 0.5) return false;

    // 跳空檢查：第二根實體低於第一根
    if (max(c2.open!, c2.close!) > c1.close!) return false;

    // 3. 第三根 K 線：長紅 K，收盤進入第一根實體
    final c3Body = c3.close! - c3.open!;
    if (c3Body <= 0) return false;

    final c1Mid = (c1.open! + c1.close!) / 2;
    // 收盤高於第一根 K 線中點
    if (c3.close! < c1Mid) return false;

    return true;
  }
}

/// 規則：暮星型態（空方反轉訊號）
class EveningStarRule extends StockRule {
  const EveningStarRule();

  @override
  String get id => 'pattern_evening_star';

  @override
  String get name => '暮星';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    if (data.prices.length < 3) return null;
    if (context.trendState == TrendState.down) return null;

    final c3 = data.prices.last;
    final c2 = data.prices[data.prices.length - 2];
    final c1 = data.prices[data.prices.length - 3];

    if (_isEveningStar(c1, c2, c3)) {
      return TriggeredReason(
        type: ReasonType.patternEveningStar,
        score: RuleScores.patternStar,
        description: '暮星型態 (頭部反轉)',
        evidence: {
          'c1_close': c1.close,
          'c2_close': c2.close,
          'c3_close': c3.close,
        },
      );
    }
    return null;
  }

  bool _isEveningStar(
    DailyPriceEntry c1,
    DailyPriceEntry c2,
    DailyPriceEntry c3,
  ) {
    if (c1.close == null ||
        c1.open == null ||
        c2.close == null ||
        c2.open == null ||
        c3.close == null ||
        c3.open == null) {
      return false;
    }

    // 1. 第一根 K 線：長紅 K
    final c1Body = c1.close! - c1.open!;
    if (c1Body <= 0) return false;

    // 2. 第二根 K 線：小實體，理想情況向上跳空
    final c2Body = (c2.close! - c2.open!).abs();
    if (c2Body > c1Body * 0.5) return false;

    // 跳空檢查：第二根實體高於第一根
    if (min(c2.open!, c2.close!) < c1.close!) return false;

    // 3. 第三根 K 線：長黑 K，收盤進入第一根實體
    final c3Body = c3.close! - c3.open!;
    if (c3Body >= 0) return false;

    final c1Mid = (c1.open! + c1.close!) / 2;
    // 收盤低於第一根 K 線中點
    if (c3.close! > c1Mid) return false;

    return true;
  }
}

/// 規則：紅三兵型態（強勢多方訊號）
class ThreeWhiteSoldiersRule extends StockRule {
  const ThreeWhiteSoldiersRule();

  @override
  String get id => 'pattern_three_white_soldiers';

  @override
  String get name => '紅三兵';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    if (data.prices.length < 3) return null;

    final c3 = data.prices.last;
    final c2 = data.prices[data.prices.length - 2];
    final c1 = data.prices[data.prices.length - 3];

    if (context.trendState == TrendState.up) return null;

    if (_isThreeWhiteSoldiers(c1, c2, c3)) {
      return TriggeredReason(
        type: ReasonType.patternThreeWhiteSoldiers,
        score: RuleScores.patternThreeSoldiers,
        description: '紅三兵型態 (強勢上攻)',
        evidence: {
          'c1_close': c1.close,
          'c2_close': c2.close,
          'c3_close': c3.close,
        },
      );
    }
    return null;
  }

  bool _isThreeWhiteSoldiers(
    DailyPriceEntry c1,
    DailyPriceEntry c2,
    DailyPriceEntry c3,
  ) {
    if (c1.close == null ||
        c1.open == null ||
        c2.close == null ||
        c2.open == null ||
        c3.close == null ||
        c3.open == null) {
      return false;
    }

    // 三根 K 線皆為紅 K
    if (c1.close! <= c1.open!) return false;
    if (c2.close! <= c2.open!) return false;
    if (c3.close! <= c3.open!) return false;

    // 連續創高收盤
    if (c2.close! <= c1.close!) return false;
    if (c3.close! <= c2.close!) return false;

    return true;
  }
}

/// 規則：三黑鴉型態（強勢空方訊號）
class ThreeBlackCrowsRule extends StockRule {
  const ThreeBlackCrowsRule();

  @override
  String get id => 'pattern_three_black_crows';

  @override
  String get name => '三黑鴉';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    if (data.prices.length < 3) return null;
    if (context.trendState == TrendState.down) return null;

    final c3 = data.prices.last;
    final c2 = data.prices[data.prices.length - 2];
    final c1 = data.prices[data.prices.length - 3];

    if (_isThreeBlackCrows(c1, c2, c3)) {
      // 過濾條件：每根 K 線須為強勢實體（從開盤跌幅 > 1.5%）
      bool isStrong(DailyPriceEntry p) =>
          p.open != null &&
          p.open! > 0 &&
          ((p.close! - p.open!) / p.open! < -0.015);

      if (!isStrong(c1) || !isStrong(c2) || !isStrong(c3)) return null;

      return TriggeredReason(
        type: ReasonType.patternThreeBlackCrows,
        score: RuleScores.patternThreeSoldiers,
        description: '三黑鴉型態 (連續下跌)',
        evidence: {
          'c1_close': c1.close,
          'c2_close': c2.close,
          'c3_close': c3.close,
        },
      );
    }
    return null;
  }

  bool _isThreeBlackCrows(
    DailyPriceEntry c1,
    DailyPriceEntry c2,
    DailyPriceEntry c3,
  ) {
    if (c1.close == null ||
        c1.open == null ||
        c2.close == null ||
        c2.open == null ||
        c3.close == null ||
        c3.open == null) {
      return false;
    }

    // 三根 K 線皆為黑 K
    if (c1.close! >= c1.open!) return false;
    if (c2.close! >= c2.open!) return false;
    if (c3.close! >= c3.open!) return false;

    // 連續創低收盤
    if (c2.close! >= c1.close!) return false;
    if (c3.close! >= c2.close!) return false;

    return true;
  }
}
