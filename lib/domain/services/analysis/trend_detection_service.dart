import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/technical_indicator_service.dart';

/// 趨勢檢測服務
///
/// 負責判斷股票的趨勢狀態（上升、下降、盤整）
/// 以及檢測弱轉強、強轉弱等反轉條件
class TrendDetectionService {
  /// 偵測趨勢狀態
  ///
  /// 使用線性迴歸計算最近 [RuleParams.swingWindow] 天的價格斜率
  /// 根據斜率判斷為上升趨勢、下降趨勢或盤整
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

  /// 檢查弱轉強條件（W2S）
  ///
  /// 滿足以下任一條件即為弱轉強：
  /// - 突破區間頂部（需在下跌或盤整趨勢中）
  /// - 形成更高的低點且站上 MA20（需在下跌或盤整趨勢中）
  bool checkWeakToStrong(
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
  bool checkStrongToWeak(
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

  // ==========================================
  // 私有輔助方法
  // ==========================================

  /// 檢查是否形成更高的低點（反轉訊號）
  ///
  /// 條件：
  /// 1. 近期低點高於前期低點 5%
  /// 2. 收盤站上 MA20
  /// 3. 近期成交量高於前期平均（量能確認）
  bool _hasHigherLow(List<DailyPriceEntry> prices, {double? ma20}) {
    if (prices.length < 40) return false;

    // 分為近期 (0-19) 與前期 (20-39)
    final recentPrices = prices.skip(prices.length - 20).toList();
    final priorPrices = prices.skip(prices.length - 40).take(20).toList();

    final recentLow = recentPrices
        .map((p) => p.low ?? double.infinity)
        .reduce((a, b) => a < b ? a : b);

    final priorLow = priorPrices
        .map((p) => p.low ?? double.infinity)
        .reduce((a, b) => a < b ? a : b);

    if (!recentLow.isFinite || !priorLow.isFinite || priorLow == 0) {
      return false;
    }

    // 條件 1：近期低點高於前期低點（使用 higherLowBuffer）
    if (recentLow <= priorLow * RuleParams.higherLowBuffer) {
      return false;
    }

    // 條件 2：收盤站上 MA20
    final todayClose = prices.last.close;
    if (todayClose == null) return false;

    final ma = ma20 ?? TechnicalIndicatorService.latestSMA(prices, 20);
    if (ma == null || todayClose < ma) {
      return false;
    }

    // 條件 3：量能確認
    return _hasVolumeConfirmation(recentPrices, priorPrices);
  }

  /// 檢查是否形成更低的高點（反轉訊號）
  ///
  /// 條件：
  /// 1. 近期高點低於前期高點 5%
  /// 2. 近期成交量高於前期平均（量能確認）
  bool _hasLowerHigh(List<DailyPriceEntry> prices) {
    if (prices.length < 40) return false;

    // 分為近期 (0-19) 與前期 (20-39)
    final recentPrices = prices.skip(prices.length - 20).toList();
    final priorPrices = prices.skip(prices.length - 40).take(20).toList();

    final recentHigh = recentPrices
        .map((p) => p.high ?? double.negativeInfinity)
        .reduce((a, b) => a > b ? a : b);

    final priorHigh = priorPrices
        .map((p) => p.high ?? double.negativeInfinity)
        .reduce((a, b) => a > b ? a : b);

    if (!recentHigh.isFinite || !priorHigh.isFinite || priorHigh == 0) {
      return false;
    }

    // 條件 1：近期高點低於前期高點（使用 lowerHighBuffer）
    if (recentHigh >= priorHigh * RuleParams.lowerHighBuffer) {
      return false;
    }

    // 條件 2：量能確認
    return _hasVolumeConfirmation(recentPrices, priorPrices);
  }

  /// 檢查量能確認
  ///
  /// 近期平均成交量需高於前期平均成交量的 [RuleParams.reversalVolumeConfirm] 倍
  bool _hasVolumeConfirmation(
    List<DailyPriceEntry> recentPrices,
    List<DailyPriceEntry> priorPrices,
  ) {
    final recentVol =
        recentPrices.map((p) => p.volume ?? 0).reduce((a, b) => a + b) /
        recentPrices.length;

    final priorVol =
        priorPrices.map((p) => p.volume ?? 0).reduce((a, b) => a + b) /
        priorPrices.length;

    if (priorVol <= 0) return false;

    return recentVol >= priorVol * RuleParams.reversalVolumeConfirm;
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

  /// 從列表尾端取得 [count] 個元素（反序：最新在前），
  /// 可選跳過尾端 [skip] 個元素。
  /// 比 `list.reversed.skip(s).take(n).toList()` 高效，
  /// 避免對整個列表建立惰性迭代器。
  static List<T> _lastN<T>(List<T> list, int count, {int skip = 0}) {
    final end = (list.length - skip).clamp(0, list.length);
    final start = (end - count).clamp(0, end);
    return list.sublist(start, end).reversed.toList();
  }
}
