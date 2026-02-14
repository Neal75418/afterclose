import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/models.dart';
import 'package:afterclose/domain/services/technical_indicator_service.dart';
import 'package:afterclose/domain/services/analysis/analysis_coordinator_service.dart';

/// 股票技術分析服務
///
/// 此類現在是 AnalysisCoordinatorService 的包裝器，以保持向後兼容性。
/// 新的程式碼應優先使用 AnalysisCoordinatorService 及其相關的子服務：
/// - TrendDetectionService（趨勢檢測）
/// - ReversalDetectionService（反轉檢測）
/// - SupportResistanceService（支撐壓力檢測）
/// - PriceVolumeAnalysisService（價量分析）
class AnalysisService {
  /// 建立分析服務
  ///
  /// [indicatorService] 可選的技術指標服務，用於依賴注入（測試用）
  /// 若未提供則使用預設實例
  AnalysisService({TechnicalIndicatorService? indicatorService})
    : _coordinator = AnalysisCoordinatorService(
        indicatorService: indicatorService,
      );

  final AnalysisCoordinatorService _coordinator;

  /// 分析單一股票並回傳分析結果
  ///
  /// 委託給 [AnalysisCoordinatorService.analyzeStock]
  AnalysisResult? analyzeStock(List<DailyPriceEntry> priceHistory) {
    return _coordinator.analyzeStock(priceHistory);
  }

  /// 建立規則引擎所需的分析上下文
  ///
  /// 委託給 [AnalysisCoordinatorService.buildContext]
  AnalysisContext buildContext(
    AnalysisResult result, {
    List<DailyPriceEntry>? priceHistory,
    MarketDataContext? marketData,
    DateTime? evaluationTime,
  }) {
    return _coordinator.buildContext(
      result,
      priceHistory: priceHistory,
      marketData: marketData,
      evaluationTime: evaluationTime,
    );
  }

  /// 從價格歷史計算技術指標
  ///
  /// 委託給 [AnalysisCoordinatorService.calculateTechnicalIndicators]
  TechnicalIndicators? calculateTechnicalIndicators(
    List<DailyPriceEntry> prices,
  ) {
    return _coordinator.calculateTechnicalIndicators(prices);
  }

  /// 檢查候選條件（分析前的預篩選）
  ///
  /// 委託給 [AnalysisCoordinatorService.isCandidate]
  bool isCandidate(List<DailyPriceEntry> prices) {
    return _coordinator.isCandidate(prices);
  }

  /// 分析價量關係以偵測背離
  ///
  /// 委託給 [AnalysisCoordinatorService.analyzePriceVolume]
  PriceVolumeAnalysis analyzePriceVolume(List<DailyPriceEntry> prices) {
    return _coordinator.analyzePriceVolume(prices);
  }

  // ==================================================
  // 以下方法用於測試,委託給內部子服務
  // 新程式碼應直接使用對應的子服務
  // ==================================================

  /// 偵測趨勢狀態
  ///
  /// 委託給 TrendDetectionService
  /// @deprecated 測試專用,新程式碼應使用 TrendDetectionService
  TrendState detectTrendState(List<DailyPriceEntry> prices) {
    return _coordinator.trendService.detectTrendState(prices);
  }

  /// 找出支撐與壓力位
  ///
  /// 委託給 SupportResistanceService
  /// @deprecated 測試專用,新程式碼應使用 SupportResistanceService
  (double?, double?) findSupportResistance(List<DailyPriceEntry> prices) {
    return _coordinator.srService.findSupportResistance(prices);
  }

  /// 找出 60 日價格區間
  ///
  /// 委託給 SupportResistanceService
  /// @deprecated 測試專用,新程式碼應使用 SupportResistanceService
  (double?, double?) findRange(List<DailyPriceEntry> prices) {
    return _coordinator.srService.findRange(prices);
  }

  /// 偵測反轉狀態
  ///
  /// 委託給 ReversalDetectionService
  /// @deprecated 測試專用,新程式碼應使用 ReversalDetectionService
  ReversalState detectReversalState(
    List<DailyPriceEntry> prices, {
    required TrendState trendState,
    double? rangeTop,
    double? rangeBottom,
    double? support,
  }) {
    return _coordinator.reversalService.detectReversalState(
      prices,
      trendState: trendState,
      rangeTop: rangeTop,
      rangeBottom: rangeBottom,
      support: support,
    );
  }
}
