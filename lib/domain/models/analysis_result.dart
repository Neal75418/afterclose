import 'package:afterclose/core/constants/rule_params.dart';

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
