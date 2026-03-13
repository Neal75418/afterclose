import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/technical_indicator_service.dart';

/// Context data needed for alert evaluation
class AlertEvaluationContext {
  const AlertEvaluationContext({
    required this.currentPrices,
    required this.priceChanges,
    required this.volumeDataMap,
    required this.priceHistoryMap,
    required this.indicatorDataMap,
    required this.warningSymbols,
    required this.disposalSymbols,
  });

  final Map<String, double> currentPrices;
  final Map<String, double> priceChanges;
  final Map<String, List<DailyPriceEntry>> volumeDataMap;
  final Map<String, List<DailyPriceEntry>> priceHistoryMap;
  final Map<String, List<DailyPriceEntry>> indicatorDataMap;
  final Set<String> warningSymbols;
  final Set<String> disposalSymbols;
}

/// Domain service for evaluating price alert conditions
///
/// Extracted from UserDaoMixin to fix layer violation - technical indicator
/// calculations belong in the domain layer, not in the data access layer.
class AlertEvaluationService {
  AlertEvaluationService({TechnicalIndicatorService? indicatorService})
    : _indicatorService = indicatorService ?? TechnicalIndicatorService();

  final TechnicalIndicatorService _indicatorService;

  /// Evaluate all active alerts against current market data
  ///
  /// Returns list of alerts that should be triggered.
  List<PriceAlertEntry> evaluateAlerts(
    List<PriceAlertEntry> activeAlerts,
    AlertEvaluationContext context,
  ) {
    final triggered = <PriceAlertEntry>[];

    for (final alert in activeAlerts) {
      final currentPrice = context.currentPrices[alert.symbol];
      if (currentPrice == null) continue;

      final priceChange = context.priceChanges[alert.symbol];
      bool shouldTrigger = false;

      switch (alert.alertType) {
        case 'ABOVE':
          shouldTrigger = currentPrice >= alert.targetValue;
        case 'BELOW':
          shouldTrigger = currentPrice <= alert.targetValue;
        case 'CHANGE_PCT':
          if (priceChange != null) {
            shouldTrigger = priceChange.abs() >= alert.targetValue;
          }
        case 'VOLUME_SPIKE':
          final volumeData = context.volumeDataMap[alert.symbol];
          if (volumeData != null && volumeData.isNotEmpty) {
            shouldTrigger = _checkVolumeSpike(
              volumeData,
              currentPrice,
              priceChange,
            );
          }
        case 'VOLUME_ABOVE':
          final volumeData = context.volumeDataMap[alert.symbol];
          if (volumeData != null && volumeData.isNotEmpty) {
            shouldTrigger = _checkVolumeAbove(
              volumeData.last,
              alert.targetValue,
            );
          }
        case 'WEEK_52_HIGH':
          final priceHistory = context.priceHistoryMap[alert.symbol];
          if (priceHistory != null && priceHistory.isNotEmpty) {
            shouldTrigger = _checkWeek52High(priceHistory, currentPrice);
          }
        case 'WEEK_52_LOW':
          final priceHistory = context.priceHistoryMap[alert.symbol];
          if (priceHistory != null && priceHistory.isNotEmpty) {
            shouldTrigger = _checkWeek52Low(priceHistory, currentPrice);
          }
        case 'RSI_OVERBOUGHT':
          final indicatorData = context.indicatorDataMap[alert.symbol];
          if (indicatorData != null && indicatorData.isNotEmpty) {
            shouldTrigger = _checkRsiOverbought(
              indicatorData,
              alert.targetValue,
            );
          }
        case 'RSI_OVERSOLD':
          final indicatorData = context.indicatorDataMap[alert.symbol];
          if (indicatorData != null && indicatorData.isNotEmpty) {
            shouldTrigger = _checkRsiOversold(indicatorData, alert.targetValue);
          }
        case 'KD_GOLDEN_CROSS':
          final indicatorData = context.indicatorDataMap[alert.symbol];
          if (indicatorData != null && indicatorData.isNotEmpty) {
            shouldTrigger = _checkKdGoldenCross(indicatorData);
          }
        case 'KD_DEATH_CROSS':
          final indicatorData = context.indicatorDataMap[alert.symbol];
          if (indicatorData != null && indicatorData.isNotEmpty) {
            shouldTrigger = _checkKdDeathCross(indicatorData);
          }
        case 'CROSS_ABOVE_MA':
          final indicatorData = context.indicatorDataMap[alert.symbol];
          if (indicatorData != null && indicatorData.isNotEmpty) {
            shouldTrigger = _checkCrossAboveMa(
              indicatorData,
              alert.targetValue.toInt(),
            );
          }
        case 'CROSS_BELOW_MA':
          final indicatorData = context.indicatorDataMap[alert.symbol];
          if (indicatorData != null && indicatorData.isNotEmpty) {
            shouldTrigger = _checkCrossBelowMa(
              indicatorData,
              alert.targetValue.toInt(),
            );
          }
        case 'TRADING_WARNING':
          shouldTrigger = context.warningSymbols.contains(alert.symbol);
        case 'TRADING_DISPOSAL':
          shouldTrigger = context.disposalSymbols.contains(alert.symbol);
      }

      if (shouldTrigger) {
        triggered.add(alert);
      }
    }

    return triggered;
  }

  // ==================================================
  // 警示檢查輔助方法 - 成交量警示
  // ==================================================

  /// 計算平均成交量（排除最新一天，計算前 20 個交易日）
  double? _calculateAverageVolume(List<DailyPriceEntry> prices) {
    if (prices.length < 2) return null; // 至少需要 2 筆資料（1 筆歷史 + 1 筆最新）

    // 排除最新一天，只計算歷史資料
    final historicalPrices = prices.sublist(0, prices.length - 1);

    final volumes = historicalPrices
        .map((p) => p.volume)
        .where((v) => v != null && v > 0)
        .map((v) => v!)
        .toList();

    if (volumes.isEmpty) return null;

    // 取最近 20 個交易日（排除今天後的）
    final recent = volumes.length > AlertParams.volumeSmaWindow
        ? volumes.sublist(volumes.length - AlertParams.volumeSmaWindow)
        : volumes;
    return recent.reduce((a, b) => a + b) / recent.length;
  }

  /// 檢查成交量爆量（成交量 >= 4x 均量 且價格變動 >= 1.5%）
  bool _checkVolumeSpike(
    List<DailyPriceEntry> prices,
    double currentPrice,
    double? priceChange,
  ) {
    if (prices.isEmpty) return false;

    final avgVolume = _calculateAverageVolume(prices);
    if (avgVolume == null) return false;

    final latestVolume = prices.last.volume;
    if (latestVolume == null || latestVolume <= 0) return false;

    // 條件 1: 成交量 >= 4x 均量
    final volumeSpike = latestVolume >= avgVolume * 4;

    // 條件 2: 價格變動 >= 1.5%
    final significantPriceChange =
        priceChange != null && priceChange.abs() >= 1.5;

    return volumeSpike && significantPriceChange;
  }

  /// 檢查成交量高於目標值
  bool _checkVolumeAbove(DailyPriceEntry price, double targetVolume) {
    final volume = price.volume;
    if (volume == null || volume <= 0) return false;
    return volume >= targetVolume;
  }

  // ==================================================
  // 警示檢查輔助方法 - 52 週警示
  // ==================================================

  /// 檢查是否創 52 週新高
  bool _checkWeek52High(List<DailyPriceEntry> prices, double currentPrice) {
    if (prices.isEmpty) return false;

    // 找出過去 52 週的最高價
    double? maxHigh;
    for (final price in prices) {
      if (price.high != null) {
        if (maxHigh == null || price.high! > maxHigh) {
          maxHigh = price.high;
        }
      }
    }

    if (maxHigh == null) return false;

    // 當前價格 >= 52 週最高價
    return currentPrice >= maxHigh;
  }

  /// 檢查是否創 52 週新低
  bool _checkWeek52Low(List<DailyPriceEntry> prices, double currentPrice) {
    if (prices.isEmpty) return false;

    // 找出過去 52 週的最低價
    double? minLow;
    for (final price in prices) {
      if (price.low != null) {
        if (minLow == null || price.low! < minLow) {
          minLow = price.low;
        }
      }
    }

    if (minLow == null) return false;

    // 當前價格 <= 52 週最低價
    return currentPrice <= minLow;
  }

  // ==================================================
  // 警示檢查輔助方法 - RSI/KD 指標警示
  // ==================================================

  /// 檢查 RSI 超買（RSI >= 目標值，如 70）
  bool _checkRsiOverbought(List<DailyPriceEntry> prices, double targetRsi) {
    if (prices.length < AlertParams.rsiMinDataPoints) return false;

    final closePrices = prices.map((p) => p.close).whereType<double>().toList();
    if (closePrices.length < AlertParams.rsiMinDataPoints) return false;

    // 使用 TechnicalIndicatorService 計算 RSI
    final rsiValues = _indicatorService.calculateRSI(closePrices, period: 14);

    final latestRsi = rsiValues.last;
    if (latestRsi == null) return false;

    return latestRsi >= targetRsi;
  }

  /// 檢查 RSI 超賣（RSI <= 目標值，如 30）
  bool _checkRsiOversold(List<DailyPriceEntry> prices, double targetRsi) {
    if (prices.length < AlertParams.rsiMinDataPoints) return false;

    final closePrices = prices.map((p) => p.close).whereType<double>().toList();
    if (closePrices.length < AlertParams.rsiMinDataPoints) return false;

    final rsiValues = _indicatorService.calculateRSI(closePrices, period: 14);

    final latestRsi = rsiValues.last;
    if (latestRsi == null) return false;

    return latestRsi <= targetRsi;
  }

  /// 檢查 KD 黃金交叉（K 上穿 D）
  ///
  /// 檢查最近 2 天內是否發生過黃金交叉。
  /// 簡化版本：只檢查交叉本身，不要求在低檔區。
  bool _checkKdGoldenCross(List<DailyPriceEntry> prices) {
    if (prices.length < AlertParams.kdMinDataPoints) return false;

    final highs = prices.map((p) => p.high).whereType<double>().toList();
    final lows = prices.map((p) => p.low).whereType<double>().toList();
    final closes = prices.map((p) => p.close).whereType<double>().toList();

    if (highs.length < 11 || lows.length < 11 || closes.length < 11) {
      return false;
    }

    final kd = _indicatorService.calculateKD(
      highs,
      lows,
      closes,
      kPeriod: 9,
      dPeriod: 3,
    );

    if (kd.k.length < 2 || kd.d.length < 2) return false;

    // 檢查最近 2 天內是否發生過黃金交叉
    final startIndex = kd.k.length >= 3 ? kd.k.length - 3 : 0;
    for (int i = startIndex; i < kd.k.length - 1; i++) {
      final prevK = kd.k[i];
      final prevD = kd.d[i];
      final nextK = kd.k[i + 1];
      final nextD = kd.d[i + 1];

      if (prevK != null && prevD != null && nextK != null && nextD != null) {
        // K 上穿 D（前一天 K < D，今天 K >= D）
        if (prevK < prevD && nextK >= nextD) {
          return true;
        }
      }
    }

    return false;
  }

  /// 檢查 KD 死亡交叉（K 下穿 D）
  ///
  /// 檢查最近 2 天內是否發生過死亡交叉。
  /// 簡化版本：只檢查交叉本身，不要求在高檔區。
  bool _checkKdDeathCross(List<DailyPriceEntry> prices) {
    if (prices.length < AlertParams.kdMinDataPoints) return false;

    final highs = prices.map((p) => p.high).whereType<double>().toList();
    final lows = prices.map((p) => p.low).whereType<double>().toList();
    final closes = prices.map((p) => p.close).whereType<double>().toList();

    if (highs.length < 11 || lows.length < 11 || closes.length < 11) {
      return false;
    }

    final kd = _indicatorService.calculateKD(
      highs,
      lows,
      closes,
      kPeriod: 9,
      dPeriod: 3,
    );

    if (kd.k.length < 2 || kd.d.length < 2) return false;

    // 檢查最近 2 天內是否發生過死亡交叉
    final startIndex = kd.k.length >= 3 ? kd.k.length - 3 : 0;
    for (int i = startIndex; i < kd.k.length - 1; i++) {
      final prevK = kd.k[i];
      final prevD = kd.d[i];
      final nextK = kd.k[i + 1];
      final nextD = kd.d[i + 1];

      if (prevK != null && prevD != null && nextK != null && nextD != null) {
        // K 下穿 D（前一天 K > D，今天 K <= D）
        if (prevK > prevD && nextK <= nextD) {
          return true;
        }
      }
    }

    return false;
  }

  // ==================================================
  // 警示檢查輔助方法 - 均線交叉警示
  // ==================================================

  /// 檢查股價突破均線（價格由下往上穿越均線）
  ///
  /// 檢查最近 2 天內是否發生過突破。
  bool _checkCrossAboveMa(List<DailyPriceEntry> prices, int maDays) {
    if (prices.length < maDays + 2) return false;

    final closes = prices.map((p) => p.close).whereType<double>().toList();
    if (closes.length < maDays + 2) return false;

    final maValues = _indicatorService.calculateSMA(closes, maDays);

    if (maValues.length < 2) return false;

    // 檢查最近 2 天內是否發生過突破
    final startIndex = maValues.length >= 3 ? maValues.length - 3 : 0;
    for (int i = startIndex; i < maValues.length - 1; i++) {
      final prevClose = closes[i];
      final prevMa = maValues[i];
      final nextClose = closes[i + 1];
      final nextMa = maValues[i + 1];

      if (prevMa != null && nextMa != null) {
        // 價格由下往上穿越均線（前一天 close < MA，今天 close >= MA）
        if (prevClose < prevMa && nextClose >= nextMa) {
          return true;
        }
      }
    }

    return false;
  }

  /// 檢查股價跌破均線（價格由上往下穿越均線）
  ///
  /// 檢查最近 2 天內是否發生過跌破。
  bool _checkCrossBelowMa(List<DailyPriceEntry> prices, int maDays) {
    if (prices.length < maDays + 2) return false;

    final closes = prices.map((p) => p.close).whereType<double>().toList();
    if (closes.length < maDays + 2) return false;

    final maValues = _indicatorService.calculateSMA(closes, maDays);

    if (maValues.length < 2) return false;

    // 檢查最近 2 天內是否發生過跌破
    final startIndex = maValues.length >= 3 ? maValues.length - 3 : 0;
    for (int i = startIndex; i < maValues.length - 1; i++) {
      final prevClose = closes[i];
      final prevMa = maValues[i];
      final nextClose = closes[i + 1];
      final nextMa = maValues[i + 1];

      if (prevMa != null && nextMa != null) {
        // 價格由上往下穿越均線（前一天 close > MA，今天 close <= MA）
        if (prevClose > prevMa && nextClose <= nextMa) {
          return true;
        }
      }
    }

    return false;
  }
}
