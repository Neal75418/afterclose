import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/analysis_context.dart';

/// 外資持股資料
class ShareholdingData {
  const ShareholdingData({
    this.foreignSharesRatio,
    this.foreignSharesRatioChange,
    this.concentrationRatio,
  });

  factory ShareholdingData.fromMap(Map<String, dynamic> map) =>
      ShareholdingData(
        foreignSharesRatio: map['foreignSharesRatio'] as double?,
        foreignSharesRatioChange: map['foreignSharesRatioChange'] as double?,
        concentrationRatio: map['concentrationRatio'] as double?,
      );

  final double? foreignSharesRatio;
  final double? foreignSharesRatioChange;
  final double? concentrationRatio;

  Map<String, double?> toMap() => {
    'foreignSharesRatio': foreignSharesRatio,
    'foreignSharesRatioChange': foreignSharesRatioChange,
    'concentrationRatio': concentrationRatio,
  };
}

/// 評分用批次資料封裝
///
/// 將 [ScoringService] 的 13 個 Map 參數整合為單一物件，
/// 消除 Data Clump 壞氣味並提高可讀性。
class ScoringBatchData {
  const ScoringBatchData({
    required this.pricesMap,
    required this.newsMap,
    this.institutionalMap,
    this.revenueMap,
    this.valuationMap,
    this.revenueHistoryMap,
    this.epsHistoryMap,
    this.roeHistoryMap,
    this.dividendHistoryMap,
    this.dayTradingMap,
    this.shareholdingMap,
    this.warningMap,
    this.insiderMap,
    this.maxHistoricalRevenueMap,
  });

  /// 股價歷史（symbol → 日K列表）
  final Map<String, List<DailyPriceEntry>> pricesMap;

  /// 新聞（symbol → 新聞列表）
  final Map<String, List<NewsItemEntry>> newsMap;

  /// 法人買賣超（symbol → 日法人列表）
  final Map<String, List<DailyInstitutionalEntry>>? institutionalMap;

  /// 最新月營收（symbol → 單筆營收）
  final Map<String, MonthlyRevenueEntry>? revenueMap;

  /// 最新估值（symbol → PE/PBR/殖利率）
  final Map<String, StockValuationEntry>? valuationMap;

  /// 營收歷史（symbol → 近6個月營收列表）
  final Map<String, List<MonthlyRevenueEntry>>? revenueHistoryMap;

  /// EPS 歷史（symbol → 近8季 EPS）
  final Map<String, List<FinancialDataEntry>>? epsHistoryMap;

  /// ROE 歷史（symbol → 近8季 ROE）
  final Map<String, List<FinancialDataEntry>>? roeHistoryMap;

  /// 股利歷史（symbol → 歷年股利）
  final Map<String, List<DividendHistoryEntry>>? dividendHistoryMap;

  /// 當沖比例（symbol → ratio）
  final Map<String, double>? dayTradingMap;

  /// 外資持股（symbol → 持股資料）
  final Map<String, ShareholdingData>? shareholdingMap;

  /// 警示資料（symbol → 警示上下文）
  final Map<String, WarningDataContext>? warningMap;

  /// 董監持股（symbol → 董監上下文）
  final Map<String, InsiderDataContext>? insiderMap;

  /// 歷史最高月營收（symbol → maxRevenue）
  final Map<String, double>? maxHistoricalRevenueMap;
}
