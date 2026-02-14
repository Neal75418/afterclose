import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/models.dart';
import 'package:afterclose/domain/services/ohlcv_data.dart';
import 'package:afterclose/domain/services/technical_indicator_service.dart';
import 'package:afterclose/domain/services/analysis/trend_detection_service.dart';
import 'package:afterclose/domain/services/analysis/reversal_detection_service.dart';
import 'package:afterclose/domain/services/analysis/support_resistance_service.dart';
import 'package:afterclose/domain/services/analysis/price_volume_analysis_service.dart';

/// 分析協調服務
///
/// 整合所有分析服務，提供統一的股票分析入口
/// 協調趨勢檢測、反轉檢測、支撐壓力計算、價量分析等功能
class AnalysisCoordinatorService {
  AnalysisCoordinatorService({
    TrendDetectionService? trendService,
    ReversalDetectionService? reversalService,
    SupportResistanceService? srService,
    PriceVolumeAnalysisService? pvService,
    TechnicalIndicatorService? indicatorService,
  }) : trendService = trendService ?? TrendDetectionService(),
       reversalService = reversalService ?? ReversalDetectionService(),
       srService = srService ?? SupportResistanceService(),
       pvService = pvService ?? PriceVolumeAnalysisService(),
       indicatorService = indicatorService ?? TechnicalIndicatorService();

  /// 趨勢檢測服務
  final TrendDetectionService trendService;

  /// 反轉檢測服務
  final ReversalDetectionService reversalService;

  /// 支撐壓力檢測服務
  final SupportResistanceService srService;

  /// 價量分析服務
  final PriceVolumeAnalysisService pvService;

  /// 技術指標服務
  final TechnicalIndicatorService indicatorService;

  /// 分析單一股票並回傳分析結果
  ///
  /// 需至少 [RuleParams.rangeLookback] 天的價格歷史
  ///
  /// 為了避免前視偏差，支撐/壓力/區間使用「過去」價格計算，
  /// 反轉狀態則使用完整價格（包含今日）與過去關卡做比較
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
    final (support, resistance) = srService.findSupportResistance(priorHistory);

    // 使用「過去」歷史計算 60 日區間
    final (rangeBottom, rangeTop) = srService.findRange(priorHistory);

    // 使用「過去」歷史判斷趨勢狀態
    final trendState = trendService.detectTrendState(priorHistory);

    // 判斷反轉狀態
    // 注意：這裡傳入完整的 priceHistory，因為需要看到「今日」價格
    // 才能與剛計算出的「過去」關卡做比較
    final reversalState = reversalService.detectReversalState(
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

  /// 建立規則引擎所需的分析上下文
  ///
  /// 整合分析結果和技術指標，供規則引擎使用
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

  /// 檢查候選條件（分析前的預篩選）
  ///
  /// 委託給 ReversalDetectionService
  bool isCandidate(List<DailyPriceEntry> prices) {
    final (rangeLow, rangeHigh) = srService.findRange(prices);
    return reversalService.isCandidate(
      prices,
      rangeHigh: rangeHigh,
      rangeLow: rangeLow,
    );
  }

  /// 分析價量關係
  ///
  /// 委託給 PriceVolumeAnalysisService
  PriceVolumeAnalysis analyzePriceVolume(List<DailyPriceEntry> prices) {
    return pvService.analyzePriceVolume(prices);
  }

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
    final rsiValues = indicatorService.calculateRSI(
      closes,
      period: RuleParams.rsiPeriod,
    );
    final currentRsi = rsiValues.isNotEmpty ? rsiValues.last : null;

    // 計算 KD
    final kd = indicatorService.calculateKD(
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

  /// 技術指標所需的最少資料點數
  /// RSI 需要：rsiPeriod + 1 (14 + 1 = 15)
  /// KD 需要：kdPeriodK + kdPeriodD - 1 + 1 (9 + 3 - 1 + 1 = 12)
  /// 取最大值以確保兩者皆可計算
  static final _minIndicatorDataPoints = [
    RuleParams.rsiPeriod + 1,
    RuleParams.kdPeriodK + RuleParams.kdPeriodD,
  ].reduce((a, b) => a > b ? a : b);
}
