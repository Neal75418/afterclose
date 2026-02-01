/// 可翻譯的字串：包含 localization key 與具名參數
///
/// Domain 層產出此結構，由 presentation 層負責呼叫 `.tr()` 翻譯。
class LocalizableString {
  const LocalizableString(
    this.key, [
    this.namedArgs = const {},
    this.nestedArgs = const {},
  ]);

  final String key;
  final Map<String, String> namedArgs;

  /// 巢狀可翻譯參數：localizer 先遞迴翻譯，再注入 namedArgs
  final Map<String, LocalizableString> nestedArgs;
}

/// Domain 層產出的結構化摘要資料（尚未翻譯）
///
/// 由 [SummaryLocalizer] 轉換為 [StockSummary] 供 UI 顯示。
class SummaryData {
  const SummaryData({
    required this.overallParts,
    this.keySignals = const [],
    this.riskFactors = const [],
    this.supportingData = const [],
    required this.sentiment,
    this.confidence = AnalysisConfidence.medium,
    this.hasConflict = false,
    this.confluenceCount = 0,
  });

  /// 總體評估的片段（依序串接）
  final List<LocalizableString> overallParts;

  /// 關鍵訊號
  final List<LocalizableString> keySignals;

  /// 風險因子
  final List<LocalizableString> riskFactors;

  /// 輔助數據
  final List<LocalizableString> supportingData;

  /// 整體情緒判斷
  final SummarySentiment sentiment;

  /// 分析信心度
  final AnalysisConfidence confidence;

  /// 是否存在多空矛盾訊號
  final bool hasConflict;

  /// 匯流模式命中數量
  final int confluenceCount;
}

/// AI 智慧分析摘要的結構化輸出（已翻譯，供 UI 直接使用）
class StockSummary {
  const StockSummary({
    required this.overallAssessment,
    this.keySignals = const [],
    this.riskFactors = const [],
    this.supportingData = const [],
    required this.sentiment,
    this.confidence = AnalysisConfidence.medium,
    this.hasConflict = false,
    this.confluenceCount = 0,
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

  /// 分析信心度
  final AnalysisConfidence confidence;

  /// 是否存在多空矛盾訊號
  final bool hasConflict;

  /// 匯流模式命中數量
  final int confluenceCount;

  bool get hasRisks => riskFactors.isNotEmpty;
  bool get hasSignals => keySignals.isNotEmpty;
  bool get hasSupportingData => supportingData.isNotEmpty;
}

/// 摘要整體情緒
enum SummarySentiment { bullish, neutral, bearish }

/// 分析信心度
enum AnalysisConfidence { high, medium, low }
