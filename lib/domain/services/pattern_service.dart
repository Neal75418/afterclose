import 'package:afterclose/data/database/app_database.dart';

/// K 線型態類型
enum CandlePatternType {
  /// 十字線 - 猶豫不決，可能反轉
  doji('DOJI', '十字線'),

  /// 多頭吞噬 - 看漲反轉訊號
  bullishEngulfing('BULLISH_ENGULFING', '多頭吞噬'),

  /// 空頭吞噬 - 看跌反轉訊號
  bearishEngulfing('BEARISH_ENGULFING', '空頭吞噬'),

  /// 錘子線 - 底部看漲反轉
  hammer('HAMMER', '錘子線'),

  /// 吊人線 - 頭部看跌反轉
  hangingMan('HANGING_MAN', '吊人線'),

  /// 向上跳空缺口 - 看漲突破
  gapUp('GAP_UP', '跳空上漲'),

  /// 向下跳空缺口 - 看跌破位
  gapDown('GAP_DOWN', '跳空下跌'),

  /// 三白兵 - 強勢多頭趨勢
  threeWhiteSoldiers('THREE_WHITE_SOLDIERS', '三白兵'),

  /// 三黑鴉 - 強勢空頭趨勢
  threeBlackCrows('THREE_BLACK_CROWS', '三黑鴉'),

  /// 晨星 - 看漲反轉
  morningStar('MORNING_STAR', '晨星'),

  /// 暮星 - 看跌反轉
  eveningStar('EVENING_STAR', '暮星');

  const CandlePatternType(this.code, this.label);

  final String code;
  final String label;
}

/// 型態偵測結果
class PatternResult {
  const PatternResult({
    required this.type,
    required this.confidence,
    this.description,
  });

  final CandlePatternType type;

  /// 信心水準 0.0-1.0
  final double confidence;

  /// 詳細說明
  final String? description;
}

/// K 線型態偵測服務
class PatternService {
  /// 實體 K 棒的最小比例（排除十字線）
  static const double _minBodyRatio = 0.1;

  /// 錘子線/吊人線的最小影線比例
  static const double _minShadowRatio = 2.0;

  /// 跳空缺口的最小百分比（1%）
  static const double _minGapPercent = 0.01;

  /// 偵測最近 K 棒的所有型態
  ///
  /// [prices] 需依時間排序（舊到新）
  List<PatternResult> detectPatterns(List<DailyPriceEntry> prices) {
    if (prices.isEmpty) return [];

    final results = <PatternResult>[];

    // 單根 K 棒型態
    final today = prices.last;
    final dojiResult = _checkDoji(today);
    if (dojiResult != null) results.add(dojiResult);

    final hammerResult = _checkHammerOrHangingMan(today, prices);
    if (hammerResult != null) results.add(hammerResult);

    // 雙根 K 棒型態（需至少 2 根）
    if (prices.length >= 2) {
      final yesterday = prices[prices.length - 2];

      final gapResult = _checkGap(today, yesterday);
      if (gapResult != null) results.add(gapResult);

      final engulfingResult = _checkEngulfing(today, yesterday, prices);
      if (engulfingResult != null) results.add(engulfingResult);
    }

    // 三根 K 棒型態（需至少 3 根）
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

  /// 檢查十字線型態（實體相對於振幅很小）
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
      // 根據影線判斷十字線類型
      final upperShadow = high - (open > close ? open : close);
      final lowerShadow = (open < close ? open : close) - low;

      String description;
      double confidence;

      // 墓碑十字：長上影線、極短下影線（高檔看跌）
      // 下影線應小於上影線的 20%
      if (upperShadow > range * 0.6 && lowerShadow < upperShadow * 0.2) {
        description = '墓碑十字（高檔警訊）';
        confidence = 0.85;
      }
      // 蜻蜓十字：長下影線、極短上影線（低檔看漲）
      // 上影線應小於下影線的 20%
      else if (lowerShadow > range * 0.6 && upperShadow < lowerShadow * 0.2) {
        description = '蜻蜓十字（低檔訊號）';
        confidence = 0.85;
      }
      // 長腳十字：上下影線都很長
      else if (upperShadow > range * 0.3 && lowerShadow > range * 0.3) {
        description = '長腳十字（多空拉鋸）';
        confidence = 0.75;
      }
      // 標準十字
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

  /// 檢查錘子線或吊人線型態
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

    // 錘子線/吊人線：小實體、長下影線、短上影線
    if (body > 0 &&
        lowerShadow >= body * _minShadowRatio &&
        upperShadow < body * 0.5) {
      // 根據近期趨勢判斷是錘子線（底部）或吊人線（頭部）
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

  /// 檢查跳空缺口（上漲或下跌）
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

    // 向上跳空：今日最低價 > 昨日最高價
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

    // 向下跳空：今日最高價 < 昨日最低價
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

  /// 檢查吞噬型態
  ///
  /// 可傳入歷史資料以判斷趨勢方向
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

    // 多頭吞噬：昨日陰線、今日陽線、今日吞噬昨日
    if (!yesterdayBullish && todayBullish) {
      if (todayOpen <= yesterdayClose && todayClose >= yesterdayOpen) {
        // 若處於下跌趨勢中，信心度較高（經典反轉型態）
        final inDowntrend = history != null && _isRecentDowntrend(history);
        return PatternResult(
          type: CandlePatternType.bullishEngulfing,
          confidence: inDowntrend ? 0.9 : 0.75,
          description: inDowntrend ? '多頭吞噬：底部反轉訊號' : '多頭吞噬：偏多訊號',
        );
      }
    }

    // 空頭吞噬：昨日陽線、今日陰線、今日吞噬昨日
    if (yesterdayBullish && !todayBullish) {
      if (todayOpen >= yesterdayClose && todayClose <= yesterdayOpen) {
        // 若處於上漲趨勢中，信心度較高（經典反轉型態）
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

  /// 檢查晨星或暮星型態
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

    // 第二天應為小實體（星）
    final isDay2Star = day2Range > 0 && day2Body / day2Range < 0.3;
    if (!isDay2Star) return null;

    final day1Bearish = day1Close < day1Open;
    final day3Bullish = day3Close > day3Open;

    // 晨星：第一天陰線、第二天星、第三天陽線
    if (day1Bearish && day3Bullish && day3Close > (day1Open + day1Close) / 2) {
      return const PatternResult(
        type: CandlePatternType.morningStar,
        confidence: 0.85,
        description: '晨星：底部反轉形態',
      );
    }

    final day1Bullish = day1Close > day1Open;
    final day3Bearish = day3Close < day3Open;

    // 暮星：第一天陽線、第二天星、第三天陰線
    if (day1Bullish && day3Bearish && day3Close < (day1Open + day1Close) / 2) {
      return const PatternResult(
        type: CandlePatternType.eveningStar,
        confidence: 0.85,
        description: '暮星：頭部反轉形態',
      );
    }

    return null;
  }

  /// 多根 K 棒型態中有效實體的最小比例
  static const double _minSignificantBodyRatio = 0.3;

  /// 檢查紅三兵或三黑鴉型態
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

    // 計算實體比以確保有效 K 線
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

    // 紅三兵條件：
    // 1. 三根皆為陽線
    // 2. 每根收盤價高於前一根
    // 3. 每根開盤價在前一根實體內或接近
    // 4. 實體需夠大（非十字線）
    if (day1Bullish &&
        day2Bullish &&
        day3Bullish &&
        day2Close > day1Close &&
        day3Close > day2Close &&
        day1Body / day1Range >= _minSignificantBodyRatio &&
        day2Body / day2Range >= _minSignificantBodyRatio &&
        day3Body / day3Range >= _minSignificantBodyRatio) {
      // 檢查開盤價是否在前一根實體內（允許些許誤差）
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
      // 寬鬆版本：只要求連續收高
      return const PatternResult(
        type: CandlePatternType.threeWhiteSoldiers,
        confidence: 0.7,
        description: '三白兵：連續上漲',
      );
    }

    final day1Bearish = day1Close < day1Open;
    final day2Bearish = day2Close < day2Open;
    final day3Bearish = day3Close < day3Open;

    // 三黑鴉條件（紅三兵的相反）
    if (day1Bearish &&
        day2Bearish &&
        day3Bearish &&
        day2Close < day1Close &&
        day3Close < day2Close &&
        day1Body / day1Range >= _minSignificantBodyRatio &&
        day2Body / day2Range >= _minSignificantBodyRatio &&
        day3Body / day3Range >= _minSignificantBodyRatio) {
      // 檢查開盤價是否在前一根實體內
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
      // 寬鬆版本
      return const PatternResult(
        type: CandlePatternType.threeBlackCrows,
        confidence: 0.7,
        description: '三黑鴉：連續下跌',
      );
    }

    return null;
  }

  /// 輔助方法：檢查近期是否為下跌趨勢（最近 5 日）
  bool _isRecentDowntrend(List<DailyPriceEntry> history) {
    if (history.length < 5) return false;

    final recent = history.skip(history.length - 5).toList();
    final firstClose = recent.first.close;
    final lastClose = recent.last.close;

    // 防止 null 和除以零
    if (firstClose == null || lastClose == null || firstClose <= 0) {
      return false;
    }

    // 至少下跌 3%
    return (firstClose - lastClose) / firstClose >= 0.03;
  }

  /// 輔助方法：檢查近期是否為上漲趨勢（最近 5 日）
  bool _isRecentUptrend(List<DailyPriceEntry> history) {
    if (history.length < 5) return false;

    final recent = history.skip(history.length - 5).toList();
    final firstClose = recent.first.close;
    final lastClose = recent.last.close;

    // 防止 null 和除以零
    if (firstClose == null || lastClose == null || firstClose <= 0) {
      return false;
    }

    // 至少上漲 3%
    return (lastClose - firstClose) / firstClose >= 0.03;
  }
}
