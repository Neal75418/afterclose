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
    if (prevClose >= prevOpen) return false; // Must be bearish candle

    // Today: Bullish (Close > Open)
    final currOpen = today.open!;
    final currClose = today.close!;
    if (currClose <= currOpen) return false; // Must be bullish candle

    // Engulfing logic:
    // Today Open <= Previous Close (gap down or same) AND Today Close >= Previous Open (gap up or same)
    // Strictly engulfing body
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
