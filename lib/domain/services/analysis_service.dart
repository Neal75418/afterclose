import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/technical_indicator_service.dart';

/// 股票技術分析服務
class AnalysisService {
  const AnalysisService();

  /// 分析單一股票並回傳分析結果
  ///
  /// 需至少 [RuleParams.rangeLookback] 天的價格歷史
  AnalysisResult? analyzeStock(List<DailyPriceEntry> priceHistory) {
    if (priceHistory.length < RuleParams.swingWindow) {
      return null; // 資料不足
    }

    // 將歷史資料分為「過去」（上下文）和「當前」（行動）
    // 以避免前視偏差（當前價格影響支撐/壓力位計算）
    // 若計算區間/壓力時包含「今日」，則「今日」永遠無法突破
    // 因為「今日」會成為新的高點
    final priorHistory = priceHistory.length > 1
        ? priceHistory.sublist(0, priceHistory.length - 1)
        : priceHistory;

    // 使用「過去」歷史計算支撐與壓力
    final (support, resistance) = findSupportResistance(priorHistory);

    // 使用「過去」歷史計算 60 日區間
    final (rangeBottom, rangeTop) = findRange(priorHistory);

    // 使用「過去」歷史判斷趨勢狀態
    final trendState = detectTrendState(priorHistory);

    // 判斷反轉狀態
    // 注意：這裡傳入完整的 priceHistory，因為需要看到「今日」價格
    // 才能與剛計算出的「過去」關卡做比較
    final reversalState = detectReversalState(
      priceHistory,
      trendState: trendState,
      rangeTop: rangeTop,
      rangeBottom: rangeBottom,
      support: support,
    );

    return AnalysisResult(
      trendState: trendState,
      reversalState: reversalState,
      supportLevel: support,
      resistanceLevel: resistance,
      rangeTop: rangeTop,
      rangeBottom: rangeBottom,
    );
  }

  /// KD、RSI 等技術指標計算服務
  static final _indicatorService = TechnicalIndicatorService();

  /// 建立規則引擎所需的分析上下文
  AnalysisContext buildContext(
    AnalysisResult result, {
    List<DailyPriceEntry>? priceHistory,
    MarketDataContext? marketData,
  }) {
    TechnicalIndicators? indicators;

    // 若有提供價格歷史則計算技術指標
    if (priceHistory != null &&
        priceHistory.length >= _minIndicatorDataPoints) {
      indicators = calculateTechnicalIndicators(priceHistory);
    }

    return AnalysisContext(
      trendState: result.trendState,
      reversalState: result.reversalState,
      supportLevel: result.supportLevel,
      resistanceLevel: result.resistanceLevel,
      rangeTop: result.rangeTop,
      rangeBottom: result.rangeBottom,
      indicators: indicators,
      marketData: marketData,
    );
  }

  /// 技術指標所需的最少資料點數
  /// RSI 需要：rsiPeriod + 1 (14 + 1 = 15)
  /// KD 需要：kdPeriodK + kdPeriodD - 1 + 1 (9 + 3 - 1 + 1 = 12)
  /// 取最大值以確保兩者皆可計算
  static final _minIndicatorDataPoints = [
    RuleParams.rsiPeriod + 1,
    RuleParams.kdPeriodK + RuleParams.kdPeriodD,
  ].reduce((a, b) => a > b ? a : b);

  /// 從價格歷史計算技術指標
  ///
  /// 回傳最近一日的 RSI 和 KD 值，
  /// 以及前一日的 KD 用於交叉偵測
  TechnicalIndicators? calculateTechnicalIndicators(
    List<DailyPriceEntry> prices,
  ) {
    if (prices.length < _minIndicatorDataPoints) {
      return null;
    }

    // 擷取 OHLC 資料
    final closes = <double>[];
    final highs = <double>[];
    final lows = <double>[];

    for (final price in prices) {
      if (price.close != null && price.high != null && price.low != null) {
        closes.add(price.close!);
        highs.add(price.high!);
        lows.add(price.low!);
      }
    }

    if (closes.length < RuleParams.rsiPeriod + 2) {
      return null;
    }

    // 計算 RSI
    final rsiValues = _indicatorService.calculateRSI(
      closes,
      period: RuleParams.rsiPeriod,
    );
    final currentRsi = rsiValues.isNotEmpty ? rsiValues.last : null;

    // 計算 KD
    final kd = _indicatorService.calculateKD(
      highs,
      lows,
      closes,
      kPeriod: RuleParams.kdPeriodK,
      dPeriod: RuleParams.kdPeriodD,
    );

    // 取得當日與前一日的 KD 值
    double? currentK, currentD, prevK, prevD;

    if (kd.k.length >= 2 && kd.d.length >= 2) {
      currentK = kd.k.last;
      currentD = kd.d.last;
      prevK = kd.k[kd.k.length - 2];
      prevD = kd.d[kd.d.length - 2];
    } else if (kd.k.isNotEmpty && kd.d.isNotEmpty) {
      currentK = kd.k.last;
      currentD = kd.d.last;
    }

    return TechnicalIndicators(
      rsi: currentRsi,
      kdK: currentK,
      kdD: currentD,
      prevKdK: prevK,
      prevKdD: prevD,
    );
  }

  /// 使用波段高低點聚類法找出支撐與壓力位
  ///
  /// 改良演算法：
  /// 1. 找出所有波段高點與低點
  /// 2. 將鄰近點聚類為區域（彼此差距在 2% 以內）
  /// 3. 依觸及次數加權（觸及越多次 = 關卡越強）
  /// 4. 選出現價下方最相關的支撐及上方最相關的壓力
  ///
  /// 回傳 (支撐, 壓力) 元組
  (double?, double?) findSupportResistance(List<DailyPriceEntry> prices) {
    if (prices.length < RuleParams.swingWindow * 2) {
      return (null, null);
    }

    // 找出所有波段高點與低點及其索引
    final swingHighs = <_SwingPoint>[];
    final swingLows = <_SwingPoint>[];

    // 左右各使用半個波段窗口
    const halfWindow = RuleParams.swingWindow ~/ 2;

    for (var i = halfWindow; i < prices.length - halfWindow; i++) {
      final current = prices[i];
      final high = current.high;
      final low = current.low;

      if (high == null || low == null) continue;

      // 檢查是否為波段高點
      var isSwingHigh = true;
      var isSwingLow = true;

      for (var j = i - halfWindow; j <= i + halfWindow; j++) {
        if (j == i) continue;
        final other = prices[j];

        // 使用嚴格不等式（>），允許相同價格成為波段點
        if (isSwingHigh && other.high != null && other.high! > high) {
          isSwingHigh = false;
        }
        if (isSwingLow && other.low != null && other.low! < low) {
          isSwingLow = false;
        }

        // 若兩條件皆不成立則提前結束（效能優化）
        if (!isSwingHigh && !isSwingLow) break;
      }

      if (isSwingHigh) swingHighs.add(_SwingPoint(price: high, index: i));
      if (isSwingLow) swingLows.add(_SwingPoint(price: low, index: i));
    }

    // 取得當前價格作為參考
    final currentClose = prices.last.close;
    if (currentClose == null) {
      // 若無當前價格則使用簡易方法
      final resistance = swingHighs.isNotEmpty ? swingHighs.last.price : null;
      final support = swingLows.isNotEmpty ? swingLows.last.price : null;
      return (support, resistance);
    }

    // 聚類波段點並找出最顯著的關卡
    final resistanceZones = _clusterSwingPoints(swingHighs, prices.length);
    final supportZones = _clusterSwingPoints(swingLows, prices.length);

    // 找出現價上方最近的壓力（在最大距離內）
    double? resistance;
    var bestResistanceScore = 0.0;
    final maxResistance =
        currentClose * (1 + RuleParams.maxSupportResistanceDistance);
    for (final zone in resistanceZones) {
      // 僅考慮最大距離內的壓力
      if (zone.avgPrice > currentClose && zone.avgPrice <= maxResistance) {
        // 依觸及次數與時近性評分
        final score = zone.touches * (1 + zone.recencyWeight);
        if (score > bestResistanceScore) {
          bestResistanceScore = score;
          resistance = zone.avgPrice;
        }
      }
    }

    // 找出現價下方最近的支撐（在最大距離內）
    // 這對 BREAKDOWN 和 S2W 訊號至關重要
    double? support;
    var bestSupportScore = 0.0;
    final minSupport =
        currentClose * (1 - RuleParams.maxSupportResistanceDistance);
    for (final zone in supportZones) {
      // 僅考慮最大距離內的支撐
      if (zone.avgPrice < currentClose && zone.avgPrice >= minSupport) {
        // 依觸及次數與時近性評分
        final score = zone.touches * (1 + zone.recencyWeight);
        if (score > bestSupportScore) {
          bestSupportScore = score;
          support = zone.avgPrice;
        }
      }
    }

    // 僅在最大距離內才回退至最近的波段點
    // 不回退至過遠的關卡，因其不具操作參考價值
    if (resistance == null && swingHighs.isNotEmpty) {
      final lastHigh = swingHighs.last.price;
      if (lastHigh > currentClose && lastHigh <= maxResistance) {
        resistance = lastHigh;
      }
    }
    if (support == null && swingLows.isNotEmpty) {
      final lastLow = swingLows.last.price;
      if (lastLow < currentClose && lastLow >= minSupport) {
        support = lastLow;
      }
    }

    return (support, resistance);
  }

  /// 將波段點聚類為價格區域
  ///
  /// 將差距在 [_clusterThreshold]（2%）以內的點分為一組
  List<_PriceZone> _clusterSwingPoints(
    List<_SwingPoint> points,
    int totalDataPoints,
  ) {
    if (points.isEmpty) return [];

    // 依價格排序
    final sorted = List<_SwingPoint>.from(points)
      ..sort((a, b) => a.price.compareTo(b.price));

    final zones = <_PriceZone>[];
    var currentZonePoints = <_SwingPoint>[sorted.first];

    for (var i = 1; i < sorted.length; i++) {
      final point = sorted[i];
      final zoneAvg =
          currentZonePoints.map((p) => p.price).reduce((a, b) => a + b) /
          currentZonePoints.length;

      // 檢查點是否在區域平均的 2% 以內
      // 防止除以零（雖然價格不應為 0）
      final isWithinThreshold = zoneAvg > 0
          ? (point.price - zoneAvg).abs() / zoneAvg <= _clusterThreshold
          : true; // 若 zoneAvg 為 0，將所有零價格點歸為一組
      if (isWithinThreshold) {
        currentZonePoints.add(point);
      } else {
        // 儲存當前區域並開始新區域
        zones.add(_createZone(currentZonePoints, totalDataPoints));
        currentZonePoints = [point];
      }
    }

    // 別忘了最後一個區域
    if (currentZonePoints.isNotEmpty) {
      zones.add(_createZone(currentZonePoints, totalDataPoints));
    }

    return zones;
  }

  /// 從波段點列表建立價格區域
  ///
  /// 前置條件：[points] 不可為空
  _PriceZone _createZone(List<_SwingPoint> points, int totalDataPoints) {
    assert(points.isNotEmpty, '_createZone called with empty points list');

    final prices = points.map((p) => p.price);
    final avgPrice = prices.reduce((a, b) => a + b) / points.length;
    final maxIndex = points.map((p) => p.index).reduce((a, b) => a > b ? a : b);
    // 時近性權重：越近期 = 權重越高（0.0 到 1.0）
    final recencyWeight = totalDataPoints > 0
        ? maxIndex / totalDataPoints
        : 0.5;

    return _PriceZone(
      avgPrice: avgPrice,
      touches: points.length,
      recencyWeight: recencyWeight,
    );
  }

  /// 波段點聚類閾值（2%）
  static const _clusterThreshold = 0.02;

  /// 找出 60 日價格區間
  ///
  /// 回傳 (區間底部, 區間頂部) 元組
  (double?, double?) findRange(List<DailyPriceEntry> prices) {
    final rangePrices = prices.reversed.take(RuleParams.rangeLookback).toList();

    if (rangePrices.isEmpty) return (null, null);

    double? rangeHigh;
    double? rangeLow;

    for (final price in rangePrices) {
      final high = price.high;
      final low = price.low;

      if (high != null && (rangeHigh == null || high > rangeHigh)) {
        rangeHigh = high;
      }
      if (low != null && (rangeLow == null || low < rangeLow)) {
        rangeLow = low;
      }
    }

    return (rangeLow, rangeHigh);
  }

  /// 偵測整體趨勢狀態
  TrendState detectTrendState(List<DailyPriceEntry> prices) {
    if (prices.length < RuleParams.swingWindow) {
      return TrendState.range;
    }

    // 取得近期價格進行趨勢分析
    final recentPrices = prices.reversed.take(RuleParams.swingWindow).toList();

    // 使用收盤價計算簡易趨勢
    final closes = recentPrices
        .map((p) => p.close)
        .whereType<double>()
        .toList();

    if (closes.length < 5) return TrendState.range;

    // 線性迴歸斜率
    // 注意：closes 是由 reversed.take() 得來，順序為新到舊，
    // 因此需取負值才是時間正向的斜率
    final slope = -_calculateSlope(closes);

    // 依平均價格標準化斜率（防止除以零）
    final avgPrice = closes.reduce((a, b) => a + b) / closes.length;
    if (avgPrice <= 0) return TrendState.range;

    final normalizedSlope = (slope / avgPrice) * 100;

    // 趨勢偵測閾值（已調低以產生更多訊號）
    const upThreshold = 0.08; // 每日 0.08% = 20 天約 1.6%
    const downThreshold = -0.08;

    if (normalizedSlope > upThreshold) {
      return TrendState.up;
    } else if (normalizedSlope < downThreshold) {
      return TrendState.down;
    } else {
      return TrendState.range;
    }
  }

  /// 根據趨勢和價格行為偵測反轉狀態
  ReversalState detectReversalState(
    List<DailyPriceEntry> prices, {
    required TrendState trendState,
    double? rangeTop,
    double? rangeBottom,
    double? support,
  }) {
    if (prices.length < 2) return ReversalState.none;

    final today = prices.last;
    final todayClose = today.close;
    if (todayClose == null) return ReversalState.none;

    // 檢查弱轉強 (W2S)
    if (trendState == TrendState.down || trendState == TrendState.range) {
      // 突破區間頂部
      if (rangeTop != null) {
        final breakoutLevel = rangeTop * (1 + RuleParams.breakoutBuffer);
        if (todayClose > breakoutLevel) {
          return ReversalState.weakToStrong;
        }
      }

      // 形成更高的低點
      if (_hasHigherLow(prices)) {
        return ReversalState.weakToStrong;
      }
    }

    // 檢查強轉弱 (S2W)
    // 使用 breakdownBuffer（較寬鬆）以便更容易觸發
    if (trendState == TrendState.up || trendState == TrendState.range) {
      // 跌破支撐
      if (support != null) {
        final breakdownLevel = support * (1 - RuleParams.breakdownBuffer);
        if (todayClose < breakdownLevel) {
          return ReversalState.strongToWeak;
        }
      }

      // 跌破區間底部
      if (rangeBottom != null) {
        final breakdownLevel = rangeBottom * (1 - RuleParams.breakdownBuffer);
        if (todayClose < breakdownLevel) {
          return ReversalState.strongToWeak;
        }
      }

      // 形成更低的高點
      if (_hasLowerHigh(prices)) {
        return ReversalState.strongToWeak;
      }
    }

    return ReversalState.none;
  }

  /// 檢查候選條件（分析前的預篩選）
  ///
  /// 符合任一條件即回傳 true：
  /// - 漲跌幅 >= 5%
  /// - 成交量 >= 20 日均量 * 2
  /// - 接近 60 日高/低點
  bool isCandidate(List<DailyPriceEntry> prices) {
    if (prices.length < RuleParams.volMa + 1) return false;

    final today = prices.last;
    final yesterday = prices[prices.length - 2];

    // 檢查價格異動
    final todayClose = today.close;
    final yesterdayClose = yesterday.close;

    if (todayClose != null && yesterdayClose != null && yesterdayClose > 0) {
      final pctChange =
          ((todayClose - yesterdayClose) / yesterdayClose).abs() * 100;
      if (pctChange >= RuleParams.priceSpikePercent) {
        return true;
      }
    }

    // 檢查成交量爆量
    final todayVolume = today.volume;
    if (todayVolume != null && todayVolume > 0) {
      final volumeHistory = prices.reversed
          .skip(1)
          .take(RuleParams.volMa)
          .map((p) => p.volume ?? 0)
          .toList();

      if (volumeHistory.isNotEmpty) {
        final volMa20 =
            volumeHistory.reduce((a, b) => a + b) / volumeHistory.length;
        if (volMa20 > 0 &&
            todayVolume >= volMa20 * RuleParams.volumeSpikeMult) {
          return true;
        }
      }
    }

    // 檢查是否接近 60 日高/低點
    if (todayClose != null) {
      final (rangeLow, rangeHigh) = findRange(prices);

      if (rangeHigh != null && rangeHigh > 0) {
        // 在 60 日高點的 2% 以內
        if (todayClose >= rangeHigh * 0.98) {
          return true;
        }
      }

      if (rangeLow != null && rangeLow > 0) {
        // 在 60 日低點的 2% 以內
        if (todayClose <= rangeLow * 1.02) {
          return true;
        }
      }
    }

    return false;
  }

  // ==========================================
  // 私有輔助方法
  // ==========================================

  /// 計算線性迴歸斜率
  double _calculateSlope(List<double> values) {
    final n = values.length;
    if (n < 2) return 0;

    double sumX = 0;
    double sumY = 0;
    double sumXY = 0;
    double sumX2 = 0;

    for (var i = 0; i < n; i++) {
      sumX += i;
      sumY += values[i];
      sumXY += i * values[i];
      sumX2 += i * i;
    }

    final denominator = n * sumX2 - sumX * sumX;
    // 使用 epsilon 比較以確保浮點數安全
    const epsilon = 1e-10;
    if (denominator.abs() < epsilon) return 0;

    return (n * sumXY - sumX * sumY) / denominator;
  }

  /// 檢查是否形成更高的低點（反轉訊號）
  bool _hasHigherLow(List<DailyPriceEntry> prices) {
    if (prices.length < RuleParams.swingWindow * 2) return false;

    // 找出近期波段低點
    final recentPrices = prices.reversed.take(RuleParams.swingWindow).toList();
    final prevPrices = prices.reversed
        .skip(RuleParams.swingWindow)
        .take(RuleParams.swingWindow)
        .toList();

    final recentLow = _findMinLow(recentPrices);
    final prevLow = _findMinLow(prevPrices);

    if (recentLow == null || prevLow == null) return false;

    // MA20 過濾：需站上 MA20 才確認上漲反轉
    final ma20 = _calculateMA(prices, 20);
    final currentClose = prices.last.close;

    if (ma20 != null && currentClose != null) {
      // 需站上 MA20 以確認強勢
      if (currentClose < ma20) return false;
    }

    // 近期低點應高於前期低點
    // 緩衝區從 1% 提高至 3% 以過濾弱訊號
    return recentLow > prevLow * 1.03;
  }

  /// 檢查是否形成更低的高點（趨勢反轉訊號）
  bool _hasLowerHigh(List<DailyPriceEntry> prices) {
    if (prices.length < RuleParams.swingWindow * 2) return false;

    // MA20 過濾：需跌破 MA20 才確認下跌反轉
    final ma20 = _calculateMA(prices, 20);
    final currentClose = prices.last.close;

    if (ma20 != null && currentClose != null) {
      // 需跌破 MA20 以確認弱勢
      if (currentClose > ma20) return false;
    }

    // 找出近期波段高點
    final recentPrices = prices.reversed.take(RuleParams.swingWindow).toList();
    final prevPrices = prices.reversed
        .skip(RuleParams.swingWindow)
        .take(RuleParams.swingWindow)
        .toList();

    final recentHigh = _findMaxHigh(recentPrices);
    final prevHigh = _findMaxHigh(prevPrices);

    if (recentHigh == null || prevHigh == null) return false;

    // 近期高點應低於前期高點
    // 緩衝區從 1% 提高至 3% 以過濾弱訊號
    return recentHigh < prevHigh * 0.97;
  }

  /// 計算簡單移動平均
  double? _calculateMA(List<DailyPriceEntry> prices, int period) {
    if (prices.length < period) return null;

    double sum = 0;
    int count = 0;

    // 取最後 N 筆價格
    for (var i = prices.length - 1; i >= prices.length - period; i--) {
      final close = prices[i].close;
      if (close != null) {
        sum += close;
        count++;
      }
    }

    if (count < period) return null; // 有效資料不足
    return sum / count;
  }

  /// 找出價格列表中的最低價
  double? _findMinLow(List<DailyPriceEntry> prices) {
    double? minLow;
    for (final price in prices) {
      final low = price.low;
      if (low != null && (minLow == null || low < minLow)) {
        minLow = low;
      }
    }
    return minLow;
  }

  /// 找出價格列表中的最高價
  double? _findMaxHigh(List<DailyPriceEntry> prices) {
    double? maxHigh;
    for (final price in prices) {
      final high = price.high;
      if (high != null && (maxHigh == null || high > maxHigh)) {
        maxHigh = high;
      }
    }
    return maxHigh;
  }

  /// 分析價量關係以偵測背離
  ///
  /// 回傳包含背離狀態和上下文的 [PriceVolumeAnalysis]
  PriceVolumeAnalysis analyzePriceVolume(List<DailyPriceEntry> prices) {
    if (prices.length < RuleParams.priceVolumeLookbackDays + 1) {
      return const PriceVolumeAnalysis(state: PriceVolumeState.neutral);
    }

    // 取得近期價格（排除今日作為比較基準）
    const lookback = RuleParams.priceVolumeLookbackDays;
    final recentPrices = prices.reversed.take(lookback + 1).toList();

    // 計算回看期間的價格變化
    final todayClose = recentPrices.first.close;
    final startClose = recentPrices.last.close;
    if (todayClose == null || startClose == null || startClose <= 0) {
      return const PriceVolumeAnalysis(state: PriceVolumeState.neutral);
    }

    final priceChangePercent = ((todayClose - startClose) / startClose) * 100;

    // 計算成交量變化（近期與前期的平均比較）
    final recentVolumes = recentPrices
        .take(lookback)
        .map((p) => p.volume ?? 0.0)
        .where((v) => v > 0)
        .toList();

    if (recentVolumes.length < lookback ~/ 2) {
      return const PriceVolumeAnalysis(state: PriceVolumeState.neutral);
    }

    final avgRecentVolume =
        recentVolumes.reduce((a, b) => a + b) / recentVolumes.length;

    // 取得前期成交量作為比較
    final prevPrices = prices.reversed
        .skip(lookback)
        .take(lookback)
        .map((p) => p.volume ?? 0.0)
        .where((v) => v > 0)
        .toList();

    if (prevPrices.isEmpty) {
      return const PriceVolumeAnalysis(state: PriceVolumeState.neutral);
    }

    final avgPrevVolume =
        prevPrices.reduce((a, b) => a + b) / prevPrices.length;
    if (avgPrevVolume <= 0) {
      return const PriceVolumeAnalysis(state: PriceVolumeState.neutral);
    }

    final volumeChangePercent =
        ((avgRecentVolume - avgPrevVolume) / avgPrevVolume) * 100;

    // 計算價格在 60 日區間中的位置（用於高低點偵測）
    final (rangeLow, rangeHigh) = findRange(prices);
    double? pricePosition;
    if (rangeLow != null && rangeHigh != null && rangeHigh > rangeLow) {
      pricePosition = (todayClose - rangeLow) / (rangeHigh - rangeLow);
    }

    // 判斷背離狀態
    const priceThreshold = RuleParams.priceVolumePriceThreshold;
    const volumeThreshold = RuleParams.priceVolumeVolumeThreshold;

    PriceVolumeState state = PriceVolumeState.neutral;

    // 價漲量縮 = 多頭背離（警訊）
    if (priceChangePercent >= priceThreshold &&
        volumeChangePercent <= -volumeThreshold) {
      state = PriceVolumeState.bullishDivergence;
    }
    // 價跌量增 = 空頭背離（恐慌）
    else if (priceChangePercent <= -priceThreshold &&
        volumeChangePercent >= volumeThreshold) {
      state = PriceVolumeState.bearishDivergence;
    }
    // 高檔爆量 = 可能出貨
    else if (pricePosition != null &&
        pricePosition >= RuleParams.highPositionThreshold &&
        volumeChangePercent >= volumeThreshold * 1.5) {
      state = PriceVolumeState.highVolumeAtHigh;
    }
    // 低檔縮量 = 可能吸籌
    else if (pricePosition != null &&
        pricePosition <= RuleParams.lowPositionThreshold &&
        volumeChangePercent <= -volumeThreshold) {
      state = PriceVolumeState.lowVolumeAtLow;
    }
    // 健康：價漲量增
    else if (priceChangePercent >= priceThreshold &&
        volumeChangePercent >= volumeThreshold) {
      state = PriceVolumeState.healthyUptrend;
    }

    return PriceVolumeAnalysis(
      state: state,
      priceChangePercent: priceChangePercent,
      volumeChangePercent: volumeChangePercent,
      pricePosition: pricePosition,
    );
  }
}

/// 價量關係狀態
enum PriceVolumeState {
  /// 中性 - 無顯著背離
  neutral,

  /// 價漲量縮 - 上漲無力警訊
  bullishDivergence,

  /// 價跌量增 - 恐慌殺盤
  bearishDivergence,

  /// 高檔爆量 - 可能出貨
  highVolumeAtHigh,

  /// 低檔縮量 - 可能吸籌
  lowVolumeAtLow,

  /// 健康上漲 - 價漲量增
  healthyUptrend,
}

/// 價量分析結果
class PriceVolumeAnalysis {
  const PriceVolumeAnalysis({
    required this.state,
    this.priceChangePercent,
    this.volumeChangePercent,
    this.pricePosition,
  });

  final PriceVolumeState state;
  final double? priceChangePercent;
  final double? volumeChangePercent;
  final double? pricePosition;

  bool get hasDivergence =>
      state == PriceVolumeState.bullishDivergence ||
      state == PriceVolumeState.bearishDivergence;
}

/// 股票分析結果
class AnalysisResult {
  const AnalysisResult({
    required this.trendState,
    required this.reversalState,
    this.supportLevel,
    this.resistanceLevel,
    this.rangeTop,
    this.rangeBottom,
  });

  final TrendState trendState;
  final ReversalState reversalState;
  final double? supportLevel;
  final double? resistanceLevel;
  final double? rangeTop;
  final double? rangeBottom;

  /// 檢查是否為潛在的反轉候選
  bool get isReversalCandidate => reversalState != ReversalState.none;
}

// ==================================================
// 私有輔助類別
// ==================================================

/// 帶有價格與位置索引的波段點
class _SwingPoint {
  const _SwingPoint({required this.price, required this.index});

  final double price;
  final int index;
}

/// 代表聚類波段點的價格區域
class _PriceZone {
  const _PriceZone({
    required this.avgPrice,
    required this.touches,
    required this.recencyWeight,
  });

  /// 此區域所有點的平均價格
  final double avgPrice;

  /// 觸及此區域的波段點數量
  final int touches;

  /// 依觸及時間的時近性權重（0.0 到 1.0）
  final double recencyWeight;
}
// ==========================================
// 分析上下文與資料類別
// ==========================================

/// 傳遞給所有規則的評估上下文
class AnalysisContext {
  const AnalysisContext({
    required this.trendState,
    this.reversalState = ReversalState.none,
    this.supportLevel,
    this.resistanceLevel,
    this.rangeTop,
    this.rangeBottom,
    this.marketData,
    this.indicators,
  });

  final TrendState trendState;
  final ReversalState reversalState;
  final double? supportLevel;
  final double? resistanceLevel;
  final double? rangeTop;
  final double? rangeBottom;
  final MarketDataContext? marketData;
  final TechnicalIndicators? indicators;
}

/// 第四階段訊號所需的額外市場資料
class MarketDataContext {
  const MarketDataContext({
    this.foreignSharesRatio,
    this.foreignSharesRatioChange,
    this.dayTradingRatio,
    this.concentrationRatio,
  });

  final double? foreignSharesRatio;
  final double? foreignSharesRatioChange;
  final double? dayTradingRatio;
  final double? concentrationRatio;
}

/// 特定規則觸發的原因
class TriggeredReason {
  const TriggeredReason({
    required this.type,
    required this.score,
    required this.description,
    this.evidence,
  });

  final ReasonType type;
  final int score;
  final String description;
  final Map<String, dynamic>? evidence;

  /// 取得證據的 JSON map
  Map<String, dynamic>? get evidenceJson => evidence;
}

/// 規則評估用的技術指標
class TechnicalIndicators {
  const TechnicalIndicators({
    this.rsi,
    this.kdK,
    this.kdD,
    this.prevKdK,
    this.prevKdD,
    this.ma5,
    this.ma20,
    this.ma60,
  });

  final double? rsi;
  final double? kdK;
  final double? kdD;
  final double? prevKdK;
  final double? prevKdD;
  final double? ma5;
  final double? ma20;
  final double? ma60;
}
