import 'package:easy_localization/easy_localization.dart';

import 'package:afterclose/domain/models/stock_summary.dart';

/// 將 domain 層的 [SummaryData] 翻譯為 UI 可直接顯示的 [StockSummary]
///
/// 這是 presentation 層的職責：呼叫 `.tr()` 將 localization key 轉為翻譯後字串。
class SummaryLocalizer {
  const SummaryLocalizer();

  StockSummary localize(SummaryData data) {
    return StockSummary(
      overallAssessment: data.overallParts.map(_resolve).join(''),
      keySignals: data.keySignals.map(_resolve).toList(),
      riskFactors: data.riskFactors.map(_resolve).toList(),
      supportingData: data.supportingData.map(_resolve).toList(),
      sentiment: data.sentiment,
      confidence: data.confidence,
      hasConflict: data.hasConflict,
      confluenceCount: data.confluenceCount,
    );
  }

  /// 遞迴解析 [LocalizableString]：先翻譯巢狀參數，再翻譯自身
  String _resolve(LocalizableString ls) {
    final args = Map<String, String>.from(ls.namedArgs);

    // 遞迴翻譯巢狀參數
    for (final entry in ls.nestedArgs.entries) {
      args[entry.key] = _resolve(entry.value);
    }

    if (args.isEmpty) return ls.key.tr();
    return ls.key.tr(namedArgs: args);
  }
}
