import 'package:afterclose/data/database/app_database.dart';

/// Candlestick pattern types
enum CandlePatternType {
  /// 十字線 - indecision, potential reversal
  doji('DOJI', '十字線'),

  /// 多頭吞噬 - bullish reversal
  bullishEngulfing('BULLISH_ENGULFING', '多頭吞噬'),

  /// 空頭吞噬 - bearish reversal
  bearishEngulfing('BEARISH_ENGULFING', '空頭吞噬'),

  /// 錘子線 - bullish reversal at bottom
  hammer('HAMMER', '錘子線'),

  /// 吊人線 - bearish reversal at top
  hangingMan('HANGING_MAN', '吊人線'),

  /// 向上跳空缺口 - bullish continuation/breakout
  gapUp('GAP_UP', '跳空上漲'),

  /// 向下跳空缺口 - bearish continuation/breakdown
  gapDown('GAP_DOWN', '跳空下跌'),

  /// 三白兵 - strong bullish trend
  threeWhiteSoldiers('THREE_WHITE_SOLDIERS', '三白兵'),

  /// 三黑鴉 - strong bearish trend
  threeBlackCrows('THREE_BLACK_CROWS', '三黑鴉'),

  /// 晨星 - bullish reversal
  morningStar('MORNING_STAR', '晨星'),

  /// 暮星 - bearish reversal
  eveningStar('EVENING_STAR', '暮星');

  const CandlePatternType(this.code, this.label);

  final String code;
  final String label;
}

/// Result of pattern detection
class PatternResult {
  const PatternResult({
    required this.type,
    required this.confidence,
    this.description,
  });

  final CandlePatternType type;

  /// Confidence level 0.0-1.0
  final double confidence;

  /// Optional description with specifics
  final String? description;
}

/// Service for detecting candlestick patterns
class PatternService {
  /// Minimum body ratio for a "real" candle (not doji)
  static const double _minBodyRatio = 0.1;

  /// Minimum shadow ratio for hammer/hanging man
  static const double _minShadowRatio = 2.0;

  /// Minimum gap percentage for gap detection
  static const double _minGapPercent = 0.01; // 1%

  /// Detect all patterns in the most recent candles
  /// [prices] should be ordered oldest to newest
  List<PatternResult> detectPatterns(List<DailyPriceEntry> prices) {
    if (prices.isEmpty) return [];

    final results = <PatternResult>[];

    // Single candle patterns
    final today = prices.last;
    final dojiResult = _checkDoji(today);
    if (dojiResult != null) results.add(dojiResult);

    final hammerResult = _checkHammerOrHangingMan(today, prices);
    if (hammerResult != null) results.add(hammerResult);

    // Two candle patterns (need at least 2)
    if (prices.length >= 2) {
      final yesterday = prices[prices.length - 2];

      final gapResult = _checkGap(today, yesterday);
      if (gapResult != null) results.add(gapResult);

      final engulfingResult = _checkEngulfing(today, yesterday, prices);
      if (engulfingResult != null) results.add(engulfingResult);
    }

    // Three candle patterns (need at least 3)
    if (prices.length >= 3) {
      final day1 = prices[prices.length - 3];
      final day2 = prices[prices.length - 2];
      final day3 = prices.last;

      final starResult = _checkStar(day1, day2, day3);
      if (starResult != null) results.add(starResult);

      final soldiersResult = _checkThreeSoldiersOrCrows(day1, day2, day3);
      if (soldiersResult != null) results.add(soldiersResult);
    }

    return results;
  }

  /// Check for Doji pattern (small body relative to range)
  PatternResult? _checkDoji(DailyPriceEntry candle) {
    final open = candle.open;
    final close = candle.close;
    final high = candle.high;
    final low = candle.low;

    if (open == null || close == null || high == null || low == null) {
      return null;
    }

    final range = high - low;
    if (range <= 0) return null;

    final body = (close - open).abs();
    final bodyRatio = body / range;

    if (bodyRatio < _minBodyRatio) {
      // Determine doji type based on shadows
      final upperShadow = high - (open > close ? open : close);
      final lowerShadow = (open < close ? open : close) - low;

      String description;
      double confidence;

      // Gravestone Doji: long upper shadow, minimal lower shadow (bearish at top)
      // Lower shadow should be < 20% of upper shadow for true gravestone
      if (upperShadow > range * 0.6 && lowerShadow < upperShadow * 0.2) {
        description = '墓碑十字（高檔警訊）';
        confidence = 0.85;
      }
      // Dragonfly Doji: long lower shadow, minimal upper shadow (bullish at bottom)
      // Upper shadow should be < 20% of lower shadow for true dragonfly
      else if (lowerShadow > range * 0.6 && upperShadow < lowerShadow * 0.2) {
        description = '蜻蜓十字（低檔訊號）';
        confidence = 0.85;
      }
      // Long-legged Doji: both shadows are significant
      else if (upperShadow > range * 0.3 && lowerShadow > range * 0.3) {
        description = '長腳十字（多空拉鋸）';
        confidence = 0.75;
      }
      // Standard Doji
      else {
        description = '標準十字';
        confidence = 0.7;
      }

      return PatternResult(
        type: CandlePatternType.doji,
        confidence: confidence,
        description: description,
      );
    }

    return null;
  }

  /// Check for Hammer or Hanging Man pattern
  PatternResult? _checkHammerOrHangingMan(
    DailyPriceEntry candle,
    List<DailyPriceEntry> history,
  ) {
    final open = candle.open;
    final close = candle.close;
    final high = candle.high;
    final low = candle.low;

    if (open == null || close == null || high == null || low == null) {
      return null;
    }

    final range = high - low;
    if (range <= 0) return null;

    final body = (close - open).abs();
    final realBodyTop = open > close ? open : close;
    final realBodyBottom = open < close ? open : close;
    final upperShadow = high - realBodyTop;
    final lowerShadow = realBodyBottom - low;

    // Hammer/Hanging Man: small body, long lower shadow, small upper shadow
    if (body > 0 &&
        lowerShadow >= body * _minShadowRatio &&
        upperShadow < body * 0.5) {
      // Determine if hammer (at bottom) or hanging man (at top)
      // by checking recent trend
      final isDowntrend = _isRecentDowntrend(history);
      final isUptrend = _isRecentUptrend(history);

      if (isDowntrend) {
        return const PatternResult(
          type: CandlePatternType.hammer,
          confidence: 0.75,
          description: '錘子線：下跌趨勢中的反轉訊號',
        );
      } else if (isUptrend) {
        return const PatternResult(
          type: CandlePatternType.hangingMan,
          confidence: 0.7,
          description: '吊人線：上漲趨勢中的警示訊號',
        );
      }
    }

    return null;
  }

  /// Check for Gap (up or down)
  PatternResult? _checkGap(DailyPriceEntry today, DailyPriceEntry yesterday) {
    final todayLow = today.low;
    final todayHigh = today.high;
    final yesterdayHigh = yesterday.high;
    final yesterdayLow = yesterday.low;
    final yesterdayClose = yesterday.close;

    if (todayLow == null ||
        todayHigh == null ||
        yesterdayHigh == null ||
        yesterdayLow == null ||
        yesterdayClose == null) {
      return null;
    }

    // Gap Up: today's low > yesterday's high
    if (todayLow > yesterdayHigh) {
      final gapSize = todayLow - yesterdayHigh;
      final gapPercent = gapSize / yesterdayClose;

      if (gapPercent >= _minGapPercent) {
        return PatternResult(
          type: CandlePatternType.gapUp,
          confidence: gapPercent >= 0.03 ? 0.9 : 0.7,
          description: '跳空上漲 ${(gapPercent * 100).toStringAsFixed(1)}%',
        );
      }
    }

    // Gap Down: today's high < yesterday's low
    if (todayHigh < yesterdayLow) {
      final gapSize = yesterdayLow - todayHigh;
      final gapPercent = gapSize / yesterdayClose;

      if (gapPercent >= _minGapPercent) {
        return PatternResult(
          type: CandlePatternType.gapDown,
          confidence: gapPercent >= 0.03 ? 0.9 : 0.7,
          description: '跳空下跌 ${(gapPercent * 100).toStringAsFixed(1)}%',
        );
      }
    }

    return null;
  }

  /// Check for Engulfing pattern
  /// Now accepts history for trend context
  PatternResult? _checkEngulfing(
    DailyPriceEntry today,
    DailyPriceEntry yesterday, [
    List<DailyPriceEntry>? history,
  ]) {
    final todayOpen = today.open;
    final todayClose = today.close;
    final yesterdayOpen = yesterday.open;
    final yesterdayClose = yesterday.close;

    if (todayOpen == null ||
        todayClose == null ||
        yesterdayOpen == null ||
        yesterdayClose == null) {
      return null;
    }

    final todayBullish = todayClose > todayOpen;
    final yesterdayBullish = yesterdayClose > yesterdayOpen;

    // Bullish Engulfing: yesterday bearish, today bullish, today engulfs yesterday
    if (!yesterdayBullish && todayBullish) {
      if (todayOpen <= yesterdayClose && todayClose >= yesterdayOpen) {
        // Higher confidence if in downtrend (classic reversal setup)
        final inDowntrend = history != null && _isRecentDowntrend(history);
        return PatternResult(
          type: CandlePatternType.bullishEngulfing,
          confidence: inDowntrend ? 0.9 : 0.75,
          description: inDowntrend ? '多頭吞噬：底部反轉訊號' : '多頭吞噬：偏多訊號',
        );
      }
    }

    // Bearish Engulfing: yesterday bullish, today bearish, today engulfs yesterday
    if (yesterdayBullish && !todayBullish) {
      if (todayOpen >= yesterdayClose && todayClose <= yesterdayOpen) {
        // Higher confidence if in uptrend (classic reversal setup)
        final inUptrend = history != null && _isRecentUptrend(history);
        return PatternResult(
          type: CandlePatternType.bearishEngulfing,
          confidence: inUptrend ? 0.9 : 0.75,
          description: inUptrend ? '空頭吞噬：頭部反轉訊號' : '空頭吞噬：偏空訊號',
        );
      }
    }

    return null;
  }

  /// Check for Morning Star or Evening Star pattern
  PatternResult? _checkStar(
    DailyPriceEntry day1,
    DailyPriceEntry day2,
    DailyPriceEntry day3,
  ) {
    final day1Open = day1.open;
    final day1Close = day1.close;
    final day2Open = day2.open;
    final day2Close = day2.close;
    final day2High = day2.high;
    final day2Low = day2.low;
    final day3Open = day3.open;
    final day3Close = day3.close;

    if (day1Open == null ||
        day1Close == null ||
        day2Open == null ||
        day2Close == null ||
        day2High == null ||
        day2Low == null ||
        day3Open == null ||
        day3Close == null) {
      return null;
    }

    final day2Body = (day2Close - day2Open).abs();
    final day2Range = day2High - day2Low;

    // Day2 should be a small body (star)
    final isDay2Star = day2Range > 0 && day2Body / day2Range < 0.3;
    if (!isDay2Star) return null;

    final day1Bearish = day1Close < day1Open;
    final day3Bullish = day3Close > day3Open;

    // Morning Star: day1 bearish, day2 star, day3 bullish
    if (day1Bearish && day3Bullish && day3Close > (day1Open + day1Close) / 2) {
      return const PatternResult(
        type: CandlePatternType.morningStar,
        confidence: 0.85,
        description: '晨星：底部反轉形態',
      );
    }

    final day1Bullish = day1Close > day1Open;
    final day3Bearish = day3Close < day3Open;

    // Evening Star: day1 bullish, day2 star, day3 bearish
    if (day1Bullish && day3Bearish && day3Close < (day1Open + day1Close) / 2) {
      return const PatternResult(
        type: CandlePatternType.eveningStar,
        confidence: 0.85,
        description: '暮星：頭部反轉形態',
      );
    }

    return null;
  }

  /// Minimum body ratio for significant candles in multi-candle patterns
  static const double _minSignificantBodyRatio = 0.3;

  /// Check for Three White Soldiers or Three Black Crows
  PatternResult? _checkThreeSoldiersOrCrows(
    DailyPriceEntry day1,
    DailyPriceEntry day2,
    DailyPriceEntry day3,
  ) {
    final day1Open = day1.open;
    final day1Close = day1.close;
    final day1High = day1.high;
    final day1Low = day1.low;
    final day2Open = day2.open;
    final day2Close = day2.close;
    final day2High = day2.high;
    final day2Low = day2.low;
    final day3Open = day3.open;
    final day3Close = day3.close;
    final day3High = day3.high;
    final day3Low = day3.low;

    if (day1Open == null ||
        day1Close == null ||
        day1High == null ||
        day1Low == null ||
        day2Open == null ||
        day2Close == null ||
        day2High == null ||
        day2Low == null ||
        day3Open == null ||
        day3Close == null ||
        day3High == null ||
        day3Low == null) {
      return null;
    }

    // Calculate body ratios to ensure significant candles
    final day1Range = day1High - day1Low;
    final day2Range = day2High - day2Low;
    final day3Range = day3High - day3Low;
    if (day1Range <= 0 || day2Range <= 0 || day3Range <= 0) return null;

    final day1Body = (day1Close - day1Open).abs();
    final day2Body = (day2Close - day2Open).abs();
    final day3Body = (day3Close - day3Open).abs();

    final day1Bullish = day1Close > day1Open;
    final day2Bullish = day2Close > day2Open;
    final day3Bullish = day3Close > day3Open;

    // Three White Soldiers requirements:
    // 1. All three candles are bullish
    // 2. Each closes higher than the previous
    // 3. Each opens within or near the previous candle's body
    // 4. Bodies should be significant (not doji-like)
    if (day1Bullish &&
        day2Bullish &&
        day3Bullish &&
        day2Close > day1Close &&
        day3Close > day2Close &&
        day1Body / day1Range >= _minSignificantBodyRatio &&
        day2Body / day2Range >= _minSignificantBodyRatio &&
        day3Body / day3Range >= _minSignificantBodyRatio) {
      // Check opens are within or near previous body (allow some tolerance)
      final day2OpensInDay1Body =
          day2Open >= day1Open && day2Open <= day1Close * 1.01;
      final day3OpensInDay2Body =
          day3Open >= day2Open && day3Open <= day2Close * 1.01;

      if (day2OpensInDay1Body && day3OpensInDay2Body) {
        return const PatternResult(
          type: CandlePatternType.threeWhiteSoldiers,
          confidence: 0.85,
          description: '三白兵：強勢上漲形態',
        );
      }
      // Relaxed version: just require progressive closes
      return const PatternResult(
        type: CandlePatternType.threeWhiteSoldiers,
        confidence: 0.7,
        description: '三白兵：連續上漲',
      );
    }

    final day1Bearish = day1Close < day1Open;
    final day2Bearish = day2Close < day2Open;
    final day3Bearish = day3Close < day3Open;

    // Three Black Crows requirements (mirror of Three White Soldiers)
    if (day1Bearish &&
        day2Bearish &&
        day3Bearish &&
        day2Close < day1Close &&
        day3Close < day2Close &&
        day1Body / day1Range >= _minSignificantBodyRatio &&
        day2Body / day2Range >= _minSignificantBodyRatio &&
        day3Body / day3Range >= _minSignificantBodyRatio) {
      // Check opens are within or near previous body
      final day2OpensInDay1Body =
          day2Open <= day1Open && day2Open >= day1Close * 0.99;
      final day3OpensInDay2Body =
          day3Open <= day2Open && day3Open >= day2Close * 0.99;

      if (day2OpensInDay1Body && day3OpensInDay2Body) {
        return const PatternResult(
          type: CandlePatternType.threeBlackCrows,
          confidence: 0.85,
          description: '三黑鴉：強勢下跌形態',
        );
      }
      // Relaxed version
      return const PatternResult(
        type: CandlePatternType.threeBlackCrows,
        confidence: 0.7,
        description: '三黑鴉：連續下跌',
      );
    }

    return null;
  }

  /// Helper: Check if recent trend is down (last 5 days)
  bool _isRecentDowntrend(List<DailyPriceEntry> history) {
    if (history.length < 5) return false;

    final recent = history.skip(history.length - 5).toList();
    final firstClose = recent.first.close;
    final lastClose = recent.last.close;

    // Guard against null and division by zero
    if (firstClose == null || lastClose == null || firstClose <= 0) {
      return false;
    }

    // Down at least 3%
    return (firstClose - lastClose) / firstClose >= 0.03;
  }

  /// Helper: Check if recent trend is up (last 5 days)
  bool _isRecentUptrend(List<DailyPriceEntry> history) {
    if (history.length < 5) return false;

    final recent = history.skip(history.length - 5).toList();
    final firstClose = recent.first.close;
    final lastClose = recent.last.close;

    // Guard against null and division by zero
    if (firstClose == null || lastClose == null || firstClose <= 0) {
      return false;
    }

    // Up at least 3%
    return (lastClose - firstClose) / firstClose >= 0.03;
  }
}
