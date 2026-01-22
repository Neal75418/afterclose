import 'dart:math';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/analysis_service.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';

// ==========================================
// Candlestick Pattern Rules
// ==========================================

/// Rule: Doji Pattern (Indecision)
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
    if (range == 0) return true; // Flat line is a doji

    final body = (candle.close! - candle.open!).abs();
    // Body is less than 10% of total range
    return body <= range * 0.1;
  }
}

/// Rule: Bullish Engulfing
class BullishEngulfingRule extends StockRule {
  const BullishEngulfingRule();

  @override
  String get id => 'pattern_bullish_engulfing';

  @override
  String get name => '多頭吞噬';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    if (data.prices.length < 2) return null;

    // Only valid in downtrend or range bottom
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

    // Previous day: Bearish (Close < Open)
    final prevOpen = prev.open!;
    final prevClose = prev.close!;
    if (prevClose >= prevOpen) return false;

    // Today: Bullish (Close > Open)
    final currOpen = today.open!;
    final currClose = today.close!;
    if (currClose <= currOpen) return false;

    // Engulfing logic:
    // Today Open <= Previous Close AND Today Close >= Previous Open
    return currOpen <= prevClose && currClose >= prevOpen;
  }
}

/// Rule: Bearish Engulfing
class BearishEngulfingRule extends StockRule {
  const BearishEngulfingRule();

  @override
  String get id => 'pattern_bearish_engulfing';

  @override
  String get name => '空頭吞噬';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    if (data.prices.length < 2) return null;

    // Only valid in uptrend or range top
    if (context.trendState == TrendState.down) return null;

    final today = data.prices.last;
    final yesterday = data.prices[data.prices.length - 2];

    if (_isBearishEngulfing(today, yesterday)) {
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

    // Previous day: Bullish
    if (prev.close! <= prev.open!) return false;

    // Today: Bearish
    if (today.close! >= today.open!) return false;

    // Engulfing logic:
    // Today Open >= Previous Close AND Today Close <= Previous Open
    return today.open! >= prev.close! && today.close! <= prev.open!;
  }
}

/// Rule: Hammer (Bullish Reversal)
class HammerRule extends StockRule {
  const HammerRule();

  @override
  String get id => 'pattern_hammer';

  @override
  String get name => '錘子線';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    if (data.prices.isEmpty) return null;
    // Must be in downtrend
    if (context.trendState == TrendState.up) return null;

    final today = data.prices.last;
    if (_isHammer(today)) {
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

  bool _isHammer(DailyPriceEntry candle) {
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
}

/// Rule: Hanging Man (Bearish Reversal)
class HangingManRule extends StockRule {
  const HangingManRule();

  @override
  String get id => 'pattern_hanging_man';

  @override
  String get name => '吊人線';

  @override
  TriggeredReason? evaluate(AnalysisContext context, StockData data) {
    if (data.prices.isEmpty) return null;
    // Must be in uptrend
    if (context.trendState == TrendState.down) return null;

    final today = data.prices.last;
    // Hanging man is same shape as Hammer but at top
    if (_isHammer(today)) {
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

  bool _isHammer(DailyPriceEntry candle) {
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
}

/// Rule: Gap Up (Bullish)
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

/// Rule: Gap Down (Bearish)
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

/// Rule: Morning Star (Bullish Reversal)
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

    // 1. First candle: Long Bearish
    final c1Body = c1.close! - c1.open!;
    if (c1Body >= 0) return false;

    // 2. Second candle: Small body (Star), Gap down ideally
    final c2Body = (c2.close! - c2.open!).abs();

    if (c2Body > c1Body.abs() * 0.5) return false;

    // Gap down check: c2 body below c1 body
    if (max(c2.open!, c2.close!) > c1.close!) return false;

    // 3. Third candle: Long Bullish, closes into c1 body
    final c3Body = c3.close! - c3.open!;
    if (c3Body <= 0) return false;

    final c1Mid = (c1.open! + c1.close!) / 2;
    // Close above midpoint of first candle
    if (c3.close! < c1Mid) return false;

    return true;
  }
}

/// Rule: Evening Star (Bearish Reversal)
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

    // 1. First candle: Long Bullish
    final c1Body = c1.close! - c1.open!;
    if (c1Body <= 0) return false;

    // 2. Second candle: Small body, Gap up ideally
    final c2Body = (c2.close! - c2.open!).abs();
    if (c2Body > c1Body * 0.5) return false;

    // Gap up check: c2 body above c1 body
    if (min(c2.open!, c2.close!) < c1.close!) return false;

    // 3. Third candle: Long Bearish, closes into c1 body
    final c3Body = c3.close! - c3.open!;
    if (c3Body >= 0) return false;

    final c1Mid = (c1.open! + c1.close!) / 2;
    // Close below midpoint of first candle
    if (c3.close! > c1Mid) return false;

    return true;
  }
}

/// Rule: Three White Soldiers (Strong Bullish)
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

    // All 3 candles bullish
    if (c1.close! <= c1.open!) return false;
    if (c2.close! <= c2.open!) return false;
    if (c3.close! <= c3.open!) return false;

    // Consecutive higher closes
    if (c2.close! <= c1.close!) return false;
    if (c3.close! <= c2.close!) return false;

    return true;
  }
}

/// Rule: Three Black Crows (Strong Bearish)
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

    // All 3 candles bearish
    if (c1.close! >= c1.open!) return false;
    if (c2.close! >= c2.open!) return false;
    if (c3.close! >= c3.open!) return false;

    // Consecutive lower closes
    if (c2.close! >= c1.close!) return false;
    if (c3.close! >= c2.close!) return false;

    return true;
  }
}
