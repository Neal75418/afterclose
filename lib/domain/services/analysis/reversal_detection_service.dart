import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/technical_indicator_service.dart';
import 'package:afterclose/domain/services/analysis/trend_detection_service.dart';

/// 反轉檢測服務
///
/// 負責判斷股票的反轉狀態（弱轉強、強轉弱）
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
}
