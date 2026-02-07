import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/models.dart';

/// 規則評估所需的市場資料物件
class StockData {
  const StockData({
    required this.symbol,
    required this.prices,
    this.institutional,
    this.news,
    this.latestRevenue,
    this.latestValuation,
    this.revenueHistory,
    this.epsHistory,
    this.roeHistory,
    this.dividendHistory,
  });

  final String symbol;
  final List<DailyPriceEntry> prices;
  final List<DailyInstitutionalEntry>? institutional;
  final List<NewsItemEntry>? news;

  /// 最新月營收資料（用於基本面規則）
  final MonthlyRevenueEntry? latestRevenue;

  /// 最新估值資料（PE、PBR、殖利率）
  final StockValuationEntry? latestValuation;

  /// 近期月營收歷史（用於月增率追蹤）
  ///
  /// 需依時間降序排列（最新在前）
  final List<MonthlyRevenueEntry>? revenueHistory;

  /// EPS 歷史（最近 8 季，依時間降序）
  final List<FinancialDataEntry>? epsHistory;

  /// ROE 歷史（最近 8 季，依時間降序，虛擬 FinancialDataEntry）
  final List<FinancialDataEntry>? roeHistory;

  /// 股利歷史（依年度降序，用於 52 週新高/新低除息調整）
  final List<DividendHistoryEntry>? dividendHistory;

  /// 取得最新價格，若無資料則為 null
  DailyPriceEntry? get latestPrice => prices.isEmpty ? null : prices.last;

  /// 取得最新收盤價，若無資料則為 null
  double? get latestClose => latestPrice?.close;

  /// 取得前一日價格，若少於 2 筆則為 null
  DailyPriceEntry? get previousPrice =>
      prices.length < 2 ? null : prices[prices.length - 2];

  /// 取得前一日收盤價，若無資料則為 null
  double? get previousClose => previousPrice?.close;
}

/// 股票分析規則的基礎介面
abstract class StockRule {
  const StockRule();

  /// 規則的唯一識別碼
  String get id;

  /// 規則名稱
  String get name;

  /// 對股票資料評估此規則
  ///
  /// 若規則符合則回傳 [TriggeredReason]，否則回傳 null
  TriggeredReason? evaluate(AnalysisContext context, StockData data);
}
