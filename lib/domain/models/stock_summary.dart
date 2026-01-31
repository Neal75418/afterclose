/// AI 智慧分析摘要的結構化輸出
class StockSummary {
  const StockSummary({
    required this.overallAssessment,
    this.keySignals = const [],
    this.riskFactors = const [],
    this.supportingData = const [],
    required this.sentiment,
  });

  /// 總體評估（趨勢 + 反轉 + 分數判斷）
  final String overallAssessment;

  /// 關鍵訊號（正面，依分數排序，前 3-5 條）
  final List<String> keySignals;

  /// 風險因子（負面訊號 + 警示）
  final List<String> riskFactors;

  /// 輔助數據（法人流向、基本面指標）
  final List<String> supportingData;

  /// 整體情緒判斷
  final SummarySentiment sentiment;

  bool get hasRisks => riskFactors.isNotEmpty;
  bool get hasSignals => keySignals.isNotEmpty;
  bool get hasSupportingData => supportingData.isNotEmpty;
}

/// 摘要整體情緒
enum SummarySentiment { bullish, neutral, bearish }
