/// 季報法定申報窗口(2026-08-06 季報總覽)。
///
/// 期限依證期局規定(一般公司):Q1=5/15、Q2=8/14、Q3=11/14、年報
/// (含 Q4)=3/31。窗口起點取季結束後申報潮實際開始的月初——與月營收
/// 入口的 1~14 日窗口同一設計語言:窗口內顯示「公布中」入口(進度逐日
/// 長),窗口外入口隱藏。
///
/// 注意金控/保險等業別的法定期限與一般公司略有差異(如年報後延),
/// 此處取一般公司期限當入口 gate——入口收起只影響「顯示」,資料同步
/// 不受窗口限制(端點平時回最後完整季,遲交者下次同步自然補上)。
abstract final class QuarterlyFilingCalendar {
  /// [now] 落在申報窗口內時,回傳該窗口對應的申報季;窗口外回 null。
  ///
  /// - 1/1~3/31 → 去年 Q4(年報)
  /// - 4/1~5/15 → 當年 Q1
  /// - 7/1~8/14 → 當年 Q2
  /// - 10/1~11/14 → 當年 Q3
  static ({int year, int quarter})? expectedFilingQuarter(DateTime now) {
    final m = now.month;
    final d = now.day;
    if (m <= 3) return (year: now.year - 1, quarter: 4);
    if (m == 4 || (m == 5 && d <= 15)) return (year: now.year, quarter: 1);
    if (m == 7 || (m == 8 && d <= 14)) return (year: now.year, quarter: 2);
    if (m == 10 || (m == 11 && d <= 14)) return (year: now.year, quarter: 3);
    return null;
  }
}
