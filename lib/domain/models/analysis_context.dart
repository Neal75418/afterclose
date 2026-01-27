import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/domain/models/technical_indicators.dart';

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
    // Killer Features 資料
    this.warningData,
    this.insiderData,
  });

  final double? foreignSharesRatio;
  final double? foreignSharesRatioChange;
  final double? dayTradingRatio;
  final double? concentrationRatio;

  // Killer Features 資料
  final WarningDataContext? warningData;
  final InsiderDataContext? insiderData;
}

/// 注意/處置股票資料
class WarningDataContext {
  const WarningDataContext({
    this.isAttention = false,
    this.isDisposal = false,
    this.warningType,
    this.reasonDescription,
    this.disposalMeasures,
    this.disposalEndDate,
  });

  /// 是否為注意股票
  final bool isAttention;

  /// 是否為處置股票
  final bool isDisposal;

  /// 警示類型（ATTENTION / DISPOSAL）
  final String? warningType;

  /// 警示原因描述
  final String? reasonDescription;

  /// 處置措施
  final String? disposalMeasures;

  /// 處置結束日期
  final DateTime? disposalEndDate;
}

/// 董監持股資料
class InsiderDataContext {
  const InsiderDataContext({
    this.insiderRatio,
    this.pledgeRatio,
    this.hasSellingStreak = false,
    this.sellingStreakMonths = 0,
    this.hasSignificantBuying = false,
    this.buyingChange,
  });

  /// 董監持股比例（%）
  final double? insiderRatio;

  /// 質押比例（%）
  final double? pledgeRatio;

  /// 是否連續減持
  final bool hasSellingStreak;

  /// 連續減持月數
  final int sellingStreakMonths;

  /// 是否有顯著增持
  final bool hasSignificantBuying;

  /// 增持變化幅度（%）
  final double? buyingChange;
}
