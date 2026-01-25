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
  });

  final double? foreignSharesRatio;
  final double? foreignSharesRatioChange;
  final double? dayTradingRatio;
  final double? concentrationRatio;
}
