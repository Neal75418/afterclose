import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/models.dart';
import 'package:afterclose/domain/services/ohlcv_data.dart';
import 'package:afterclose/domain/services/technical_indicator_service.dart';

/// 股票技術分析服務
class AnalysisService {
  /// 建立分析服務
  ///
  /// [indicatorService] 可選的技術指標服務，用於依賴注入（測試用）
  /// 若未提供則使用預設實例
  AnalysisService({TechnicalIndicatorService? indicatorService})
    : _indicatorService = indicatorService ?? TechnicalIndicatorService();

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

  /// KD、RSI 等技術指標計算服務（支援依賴注入）
  final TechnicalIndicatorService _indicatorService;

  /// 建立規則引擎所需的分析上下文
  AnalysisContext buildContext(
    AnalysisResult result, {
    List<DailyPriceEntry>? priceHistory,
    MarketDataContext? marketData,
    DateTime? evaluationTime,
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
      evaluationTime: evaluationTime,
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
    final (:closes, :highs, :lows, volumes: _) = prices.extractOhlcv();

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

    // 找出所有波段高點與低點
    final (:highs, :lows) = _detectSwingPoints(prices);

    // 取得當前價格作為參考
    final currentClose = prices.last.close;
    if (currentClose == null) {
      final resistance = highs.isNotEmpty ? highs.last.price : null;
      final support = lows.isNotEmpty ? lows.last.price : null;
      return (support, resistance);
    }

    // 聚類波段點並找出最顯著的關卡
    final resistanceZones = _clusterSwingPoints(highs, prices.length);
    final supportZones = _clusterSwingPoints(lows, prices.length);

    // ATR-based 動態距離：高波動股用更寬的搜尋半徑
    final atrDistance = _calculateATRDistance(prices, currentClose);
    final maxDistance = atrDistance ?? RuleParams.maxSupportResistanceDistance;

    final maxResistance = currentClose * (1 + maxDistance);
    final minSupport = currentClose * (1 - maxDistance);

    // 找出最佳壓力與支撐
    var resistance = _scoreBestZone(
      resistanceZones,
      currentClose,
      above: true,
      boundPrice: maxResistance,
    );
    var support = _scoreBestZone(
      supportZones,
      currentClose,
      above: false,
      boundPrice: minSupport,
    );

    // 僅在最大距離內才回退至最近的波段點
    if (resistance == null && highs.isNotEmpty) {
      final lastHigh = highs.last.price;
      if (lastHigh > currentClose && lastHigh <= maxResistance) {
        resistance = lastHigh;
      }
    }
    if (support == null && lows.isNotEmpty) {
      final lastLow = lows.last.price;
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

  /// 偵測價格序列中的波段高低點
  ({List<_SwingPoint> highs, List<_SwingPoint> lows}) _detectSwingPoints(
    List<DailyPriceEntry> prices,
  ) {
    final swingHighs = <_SwingPoint>[];
    final swingLows = <_SwingPoint>[];

    const halfWindow = RuleParams.swingWindow ~/ 2;

    for (var i = halfWindow; i < prices.length - halfWindow; i++) {
      final current = prices[i];
      final high = current.high;
      final low = current.low;

      if (high == null || low == null) continue;

      var isSwingHigh = true;
      var isSwingLow = true;

      for (var j = i - halfWindow; j <= i + halfWindow; j++) {
        if (j == i) continue;
        final other = prices[j];

        if (isSwingHigh && other.high != null && other.high! > high) {
          isSwingHigh = false;
        }
        if (isSwingLow && other.low != null && other.low! < low) {
          isSwingLow = false;
        }

        if (!isSwingHigh && !isSwingLow) break;
      }

      if (isSwingHigh) swingHighs.add(_SwingPoint(price: high, index: i));
      if (isSwingLow) swingLows.add(_SwingPoint(price: low, index: i));
    }

    return (highs: swingHighs, lows: swingLows);
  }

  /// 從區域列表中找出最佳評分的關卡價位
  ///
  /// [above] 為 true 時搜尋壓力（現價上方），false 時搜尋支撐（現價下方）。
  /// 使用觸及次數、時近性、距離衰減三因子綜合評分。
  double? _scoreBestZone(
    List<_PriceZone> zones,
    double currentClose, {
    required bool above,
    required double boundPrice,
  }) {
    double? bestPrice;
    var bestScore = 0.0;

    for (final zone in zones) {
      final inRange = above
          ? (zone.avgPrice > currentClose && zone.avgPrice <= boundPrice)
          : (zone.avgPrice < currentClose && zone.avgPrice >= boundPrice);

      if (inRange) {
        final distance = (zone.avgPrice - currentClose).abs();
        final distanceFactor =
            1.0 /
            (1.0 + (distance / currentClose) * RuleParams.distanceDecayFactor);
        final score = zone.touches * (1 + zone.recencyWeight) * distanceFactor;
        if (score > bestScore) {
          bestScore = score;
          bestPrice = zone.avgPrice;
        }
      }
    }

    return bestPrice;
  }

  /// 波段點聚類閾值
  static const _clusterThreshold = RuleParams.clusterThreshold;

  /// 找出 60 日價格區間
  ///
  /// 回傳 (區間底部, 區間頂部) 元組
  (double?, double?) findRange(List<DailyPriceEntry> prices) {
    final rangePrices = _lastN(prices, RuleParams.rangeLookback);

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
    final recentPrices = _lastN(prices, RuleParams.swingWindow);

    // 使用收盤價計算簡易趨勢
    final closes = recentPrices
        .map((p) => p.close)
        .whereType<double>()
        .toList();

    if (closes.length < RuleParams.minTrendDataPoints) return TrendState.range;

    // 線性迴歸斜率
    // 注意：closes 是由 reversed.take() 得來，順序為新到舊，
    // 因此需取負值才是時間正向的斜率
    final slope = -_calculateSlope(closes);

    // 依平均價格標準化斜率（防止除以零）
    final avgPrice = closes.reduce((a, b) => a + b) / closes.length;
    if (avgPrice <= 0) return TrendState.range;

    final normalizedSlope = (slope / avgPrice) * 100;

    // 趨勢偵測閾值
    if (normalizedSlope > RuleParams.trendUpThreshold) {
      return TrendState.up;
    } else if (normalizedSlope < RuleParams.trendDownThreshold) {
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

    final todayClose = prices.last.close;
    if (todayClose == null) return ReversalState.none;

    // 預先計算 MA20，供 _hasHigherLow 使用（避免在 helper 中重複計算）
    final ma20 = TechnicalIndicatorService.latestSMA(prices, 20);

    if (_checkWeakToStrong(
      prices,
      todayClose,
      trendState: trendState,
      rangeTop: rangeTop,
      ma20: ma20,
    )) {
      return ReversalState.weakToStrong;
    }

    if (_checkStrongToWeak(
      prices,
      todayClose,
      trendState: trendState,
      support: support,
      rangeBottom: rangeBottom,
    )) {
      return ReversalState.strongToWeak;
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
      final volumeHistory = _lastN(
        prices,
        RuleParams.volMa,
        skip: 1,
      ).map((p) => p.volume ?? 0).toList();

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
        // 在 60 日高點附近
        if (todayClose >= rangeHigh * RuleParams.nearRangeHighBuffer) {
          return true;
        }
      }

      if (rangeLow != null && rangeLow > 0) {
        // 在 60 日低點附近
        if (todayClose <= rangeLow * RuleParams.nearRangeLowBuffer) {
          return true;
        }
      }
    }

    return false;
  }

  // ==========================================
  // 私有輔助方法
  // ==========================================

  /// 從列表尾端取得 [count] 個元素（反序：最新在前），
  /// 可選跳過尾端 [skip] 個元素。
  /// 比 `list.reversed.skip(s).take(n).toList()` 高效，
  /// 避免對整個列表建立惰性迭代器。
  static List<T> _lastN<T>(List<T> list, int count, {int skip = 0}) {
    final end = (list.length - skip).clamp(0, list.length);
    final start = (end - count).clamp(0, end);
    return list.sublist(start, end).reversed.toList();
  }

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

  /// 檢查弱轉強條件（W2S）
  ///
  /// 滿足以下任一條件即為弱轉強：
  /// - 突破區間頂部（需在下跌或盤整趨勢中）
  /// - 形成更高的低點且站上 MA20（需在下跌或盤整趨勢中）
  bool _checkWeakToStrong(
    List<DailyPriceEntry> prices,
    double todayClose, {
    required TrendState trendState,
    double? rangeTop,
    double? ma20,
  }) {
    if (trendState != TrendState.down && trendState != TrendState.range) {
      return false;
    }

    // 突破區間頂部
    if (rangeTop != null) {
      final breakoutLevel = rangeTop * (1 + RuleParams.breakoutBuffer);
      if (todayClose > breakoutLevel) {
        return true;
      }
    }

    // 形成更高的低點
    return _hasHigherLow(prices, ma20: ma20);
  }

  /// 檢查強轉弱條件（S2W）
  ///
  /// 滿足以下任一條件即為強轉弱：
  /// - 跌破支撐位（任何趨勢皆檢查）
  /// - 跌破區間底部（任何趨勢皆檢查）
  /// - 形成更低的高點（僅在上升或盤整趨勢中檢查）
  bool _checkStrongToWeak(
    List<DailyPriceEntry> prices,
    double todayClose, {
    required TrendState trendState,
    double? support,
    double? rangeBottom,
  }) {
    // 跌破支撐
    if (support != null) {
      final breakdownLevel = support * (1 - RuleParams.breakdownBuffer);
      if (todayClose < breakdownLevel) {
        AppLogger.debug(
          'S2W',
          '跌破支撐: close=$todayClose < support=$support * 0.97 = $breakdownLevel',
        );
        return true;
      }
    }

    // 跌破區間底部
    if (rangeBottom != null) {
      final breakdownLevel = rangeBottom * (1 - RuleParams.breakdownBuffer);
      if (todayClose < breakdownLevel) {
        AppLogger.debug(
          'S2W',
          '跌破區間底部: close=$todayClose < rangeBottom=$rangeBottom * 0.97 = $breakdownLevel',
        );
        return true;
      }
    }

    // 形成更低的高點（只在上升或盤整趨勢中檢查）
    if (trendState == TrendState.up || trendState == TrendState.range) {
      return _hasLowerHigh(prices);
    }

    return false;
  }

  /// 檢查是否形成更高的低點（反轉訊號）
  ///
  /// 條件：
  /// 1. 近期低點高於前期低點 5%
  /// 2. 收盤站上 MA20
  /// 3. 近期成交量高於前期平均（量能確認）
  bool _hasHigherLow(List<DailyPriceEntry> prices, {double? ma20}) {
    if (prices.length < RuleParams.swingWindow * 2) return false;

    // 找出近期波段低點
    final recentPrices = _lastN(prices, RuleParams.swingWindow);
    final prevPrices = _lastN(
      prices,
      RuleParams.swingWindow,
      skip: RuleParams.swingWindow,
    );

    final recentLow = _findMinLow(recentPrices);
    final prevLow = _findMinLow(prevPrices);

    if (recentLow == null || prevLow == null) return false;

    // MA20 過濾：需站上 MA20 才確認上漲反轉
    // 使用呼叫端傳入的 MA20（避免重複計算），若未提供則自行計算
    final effectiveMa20 =
        ma20 ?? TechnicalIndicatorService.latestSMA(prices, 20);
    final currentClose = prices.last.close;

    if (effectiveMa20 != null && currentClose != null) {
      // 需站上 MA20 以確認強勢
      if (currentClose < effectiveMa20) {
        AppLogger.debug(
          'Analysis',
          '弱轉強未觸發：股價 $currentClose 低於 MA20 $effectiveMa20',
        );
        return false;
      }
    }

    // 成交量確認：近期成交量需高於前期平均
    if (!_hasVolumeConfirmation(recentPrices, prevPrices)) {
      AppLogger.debug('Analysis', '弱轉強未觸發：近期成交量低於前期均量');
      return false;
    }

    // 近期低點應高於前期低點（含緩衝區過濾弱訊號）
    return recentLow > prevLow * RuleParams.higherLowBuffer;
  }

  /// 檢查是否形成更低的高點（趨勢反轉訊號）
  ///
  /// 簡化偵測：移除 MA20 和成交量過濾，頭部形成往往是「量縮價跌」，
  /// 只檢查是否形成更低高點即可。
  bool _hasLowerHigh(List<DailyPriceEntry> prices) {
    if (prices.length < RuleParams.swingWindow * 2) return false;

    // 找出近期波段高點
    final recentPrices = _lastN(prices, RuleParams.swingWindow);
    final prevPrices = _lastN(
      prices,
      RuleParams.swingWindow,
      skip: RuleParams.swingWindow,
    );

    final recentHigh = _findMaxHigh(recentPrices);
    final prevHigh = _findMaxHigh(prevPrices);

    if (recentHigh == null || prevHigh == null) return false;

    // 近期高點應低於前期高點（含緩衝區過濾弱訊號）
    final isLowerHigh = recentHigh < prevHigh * RuleParams.lowerHighBuffer;

    if (isLowerHigh) {
      AppLogger.debug(
        'LowerHigh',
        '偵測到更低高點: 近期高=${recentHigh.toStringAsFixed(2)}, '
            '前期高=${prevHigh.toStringAsFixed(2)}, '
            '比值=${(recentHigh / prevHigh * 100).toStringAsFixed(1)}%',
      );
    }

    return isLowerHigh;
  }

  /// 檢查成交量確認（反轉訊號需有量能配合）
  ///
  /// 近期平均成交量需達前期平均的 1.5 倍以上（用於弱轉強）
  bool _hasVolumeConfirmation(
    List<DailyPriceEntry> recentPrices,
    List<DailyPriceEntry> prevPrices,
  ) {
    // 計算近期平均成交量
    final recentVolumes = recentPrices
        .map((p) => p.volume ?? 0.0)
        .where((v) => v > 0)
        .toList();

    if (recentVolumes.isEmpty) return false;

    final avgRecentVolume =
        recentVolumes.reduce((a, b) => a + b) / recentVolumes.length;

    // 計算前期平均成交量
    final prevVolumes = prevPrices
        .map((p) => p.volume ?? 0.0)
        .where((v) => v > 0)
        .toList();

    if (prevVolumes.isEmpty) return true; // 無前期資料則放行

    final avgPrevVolume =
        prevVolumes.reduce((a, b) => a + b) / prevVolumes.length;

    if (avgPrevVolume <= 0) return true;

    // 近期成交量需達前期的 1.5 倍（弱轉強需有量能）
    return avgRecentVolume >= avgPrevVolume * RuleParams.reversalVolumeConfirm;
  }

  /// 計算 ATR-based 支撐壓力搜尋距離
  ///
  /// ATR（Average True Range）反映股票近期波動程度。
  /// 使用 ATR×3/currentClose 作為動態距離，
  /// 但下限為固定 8%（[RuleParams.maxSupportResistanceDistance]）。
  double? _calculateATRDistance(
    List<DailyPriceEntry> prices,
    double currentClose,
  ) {
    const period = RuleParams.atrPeriod;
    if (prices.length < period + 1) return null;

    double atrSum = 0;
    int count = 0;

    for (var i = prices.length - period; i < prices.length; i++) {
      final high = prices[i].high;
      final low = prices[i].low;
      final prevClose = prices[i - 1].close;

      if (high == null || low == null || prevClose == null) continue;

      // True Range = max(H-L, |H-prevC|, |L-prevC|)
      final hl = high - low;
      final hpc = (high - prevClose).abs();
      final lpc = (low - prevClose).abs();
      final tr = [hl, hpc, lpc].reduce((a, b) => a > b ? a : b);

      atrSum += tr;
      count++;
    }

    if (count < period ~/ 2) return null;

    final atr = atrSum / count;
    final atrDistance = (atr * RuleParams.atrDistanceMultiplier) / currentClose;

    // 下限為固定 8%，確保低波動股仍有合理搜尋範圍
    if (atrDistance < RuleParams.maxSupportResistanceDistance) {
      return RuleParams.maxSupportResistanceDistance;
    }
    // 上限 20%，避免過度搜尋
    return atrDistance > RuleParams.maxAtrDistance
        ? RuleParams.maxAtrDistance
        : atrDistance;
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
  /// 計算成交量變化百分比
  ///
  /// 比較近期和前期的平均成交量，回傳變化百分比。
  /// 資料不足時回傳 null。
  double? _calculateVolumeChange(
    List<DailyPriceEntry> allPrices,
    List<DailyPriceEntry> recentPrices,
    int lookback,
  ) {
    final recentVolumes = recentPrices
        .take(lookback)
        .map((p) => p.volume ?? 0.0)
        .where((v) => v > 0)
        .toList();

    if (recentVolumes.length < lookback ~/ 2) return null;

    final avgRecentVolume =
        recentVolumes.reduce((a, b) => a + b) / recentVolumes.length;

    final prevVolumes = _lastN(
      allPrices,
      lookback,
      skip: lookback,
    ).map((p) => p.volume ?? 0.0).where((v) => v > 0).toList();

    if (prevVolumes.isEmpty) return null;

    final avgPrevVolume =
        prevVolumes.reduce((a, b) => a + b) / prevVolumes.length;
    if (avgPrevVolume <= 0) return null;

    return ((avgRecentVolume - avgPrevVolume) / avgPrevVolume) * 100;
  }

  /// 依據價量變化與價格位置判斷背離狀態
  PriceVolumeState _classifyPriceVolumeState({
    required double priceChangePercent,
    required double volumeChangePercent,
    double? pricePosition,
  }) {
    const priceThreshold = RuleParams.priceVolumePriceThreshold;
    const volumeThreshold = RuleParams.priceVolumeVolumeThreshold;

    // 價漲量縮 = 多頭背離（警訊）
    if (priceChangePercent >= priceThreshold &&
        volumeChangePercent <= -volumeThreshold) {
      return PriceVolumeState.bullishDivergence;
    }
    // 價跌量增 = 空頭背離（恐慌）
    if (priceChangePercent <= -priceThreshold &&
        volumeChangePercent >= volumeThreshold) {
      return PriceVolumeState.bearishDivergence;
    }
    // 高檔爆量 = 可能出貨
    if (pricePosition != null &&
        pricePosition >= RuleParams.highPositionThreshold &&
        volumeChangePercent >=
            volumeThreshold * RuleParams.highVolumeMultiplier) {
      return PriceVolumeState.highVolumeAtHigh;
    }
    // 低檔縮量 = 可能吸籌
    if (pricePosition != null &&
        pricePosition <= RuleParams.lowPositionThreshold &&
        volumeChangePercent <= -volumeThreshold) {
      return PriceVolumeState.lowVolumeAtLow;
    }
    // 健康：價漲量增
    if (priceChangePercent >= priceThreshold &&
        volumeChangePercent >= volumeThreshold) {
      return PriceVolumeState.healthyUptrend;
    }

    return PriceVolumeState.neutral;
  }

  PriceVolumeAnalysis analyzePriceVolume(List<DailyPriceEntry> prices) {
    if (prices.length < RuleParams.priceVolumeLookbackDays + 1) {
      return const PriceVolumeAnalysis(state: PriceVolumeState.neutral);
    }

    const lookback = RuleParams.priceVolumeLookbackDays;
    final recentPrices = _lastN(prices, lookback + 1);

    // 計算價格變化
    final todayClose = recentPrices.first.close;
    final startClose = recentPrices.last.close;
    if (todayClose == null || startClose == null || startClose <= 0) {
      return const PriceVolumeAnalysis(state: PriceVolumeState.neutral);
    }

    final priceChangePercent = ((todayClose - startClose) / startClose) * 100;

    // 計算成交量變化
    final volumeChange = _calculateVolumeChange(prices, recentPrices, lookback);
    if (volumeChange == null) {
      return const PriceVolumeAnalysis(state: PriceVolumeState.neutral);
    }

    // 計算價格在 60 日區間中的位置
    final (rangeLow, rangeHigh) = findRange(prices);
    double? pricePosition;
    if (rangeLow != null && rangeHigh != null && rangeHigh > rangeLow) {
      pricePosition = (todayClose - rangeLow) / (rangeHigh - rangeLow);
    }

    // 判斷背離狀態
    final state = _classifyPriceVolumeState(
      priceChangePercent: priceChangePercent,
      volumeChangePercent: volumeChange,
      pricePosition: pricePosition,
    );

    return PriceVolumeAnalysis(
      state: state,
      priceChangePercent: priceChangePercent,
      volumeChangePercent: volumeChange,
      pricePosition: pricePosition,
    );
  }
}

// ==================================================
// 私有輔助類別（僅在此服務內部使用）
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
