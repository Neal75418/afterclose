import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/technical_indicator_service.dart';
import 'package:afterclose/domain/services/analysis/trend_detection_service.dart';

/// 反轉檢測服務
///
/// 負責判斷股票的反轉狀態（弱轉強、強轉弱）
/// 以及檢查候選條件（分析前的預篩選）
class ReversalDetectionService {
  ReversalDetectionService({TrendDetectionService? trendService})
    : _trendService = trendService ?? TrendDetectionService();

  final TrendDetectionService _trendService;

  /// 根據趨勢和價格行為偵測反轉狀態
  ///
  /// 依序檢查：
  /// 1. 弱轉強（W2S）條件
  /// 2. 強轉弱（S2W）條件
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

    // 預先計算 MA20，供 checkWeakToStrong 使用（避免重複計算）
    final ma20 = TechnicalIndicatorService.latestSMA(prices, 20);

    if (_trendService.checkWeakToStrong(
      prices,
      todayClose,
      trendState: trendState,
      rangeTop: rangeTop,
      ma20: ma20,
    )) {
      return ReversalState.weakToStrong;
    }

    if (_trendService.checkStrongToWeak(
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
  ///
  /// 此函式需要 [findRange] 方法的支援,應由外部傳入 rangeHigh 和 rangeLow
  bool isCandidate(
    List<DailyPriceEntry> prices, {
    required double? rangeHigh,
    required double? rangeLow,
  }) {
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
  static List<T> _lastN<T>(List<T> list, int count, {int skip = 0}) {
    final end = (list.length - skip).clamp(0, list.length);
    final start = (end - count).clamp(0, end);
    return list.sublist(start, end).reversed.toList();
  }
}
