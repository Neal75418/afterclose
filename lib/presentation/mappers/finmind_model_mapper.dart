import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';

/// DB model → FinMind API model 轉換。
///
/// `AnalysisSummaryService` 使用 FinMind model 作為輸入，
/// 但比較頁與詳情頁的資料來源是 DB model。此 mapper 消除兩處重複轉換。
abstract final class FinMindModelMapper {
  /// 將 [MonthlyRevenueEntry] list 轉換為 [FinMindRevenue] list。
  static List<FinMindRevenue> toFinMindRevenues(
    List<MonthlyRevenueEntry> entries,
  ) {
    return entries
        .map(
          (r) => FinMindRevenue(
            stockId: r.symbol,
            date: DateContext.formatYmd(r.date),
            revenueYear: r.revenueYear,
            revenueMonth: r.revenueMonth,
            revenue: r.revenue,
            momGrowth: r.momGrowth,
            yoyGrowth: r.yoyGrowth,
          ),
        )
        .toList();
  }

  /// 將 [StockValuationEntry] 轉換為 [FinMindPER]，null 安全。
  static FinMindPER? toFinMindPER(StockValuationEntry? valuation) {
    if (valuation == null) return null;
    return FinMindPER(
      stockId: valuation.symbol,
      date: DateContext.formatYmd(valuation.date),
      per: valuation.per ?? 0,
      pbr: valuation.pbr ?? 0,
      dividendYield: valuation.dividendYield ?? 0,
    );
  }
}
