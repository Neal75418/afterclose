import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';

/// 建立測試用 DailyReasonEntry
///
/// Stage 5b dual-horizon: 保留單一 `ruleScore` 參數為方便書寫，helper
/// 內部會同時賦值給 `ruleScoreShort` 跟 `ruleScoreLong`。測試若需要
/// 兩個 horizon 分化的值，使用 [createTestReasonDual]。
DailyReasonEntry createTestReason({
  String symbol = 'TEST',
  DateTime? date,
  int rank = 1,
  required String reasonType,
  String evidenceJson = '{}',
  double ruleScore = 10.0,
}) {
  return DailyReasonEntry(
    symbol: symbol,
    date: date ?? DateTime(2024, 6, 15),
    rank: rank,
    reasonType: reasonType,
    evidenceJson: evidenceJson,
    ruleScoreShort: ruleScore,
    ruleScoreLong: ruleScore,
  );
}

/// 建立測試用 DailyReasonEntry with 雙 horizon 分化分數
DailyReasonEntry createTestReasonDual({
  String symbol = 'TEST',
  DateTime? date,
  int rank = 1,
  required String reasonType,
  String evidenceJson = '{}',
  double ruleScoreShort = 10.0,
  double ruleScoreLong = 10.0,
}) {
  return DailyReasonEntry(
    symbol: symbol,
    date: date ?? DateTime(2024, 6, 15),
    rank: rank,
    reasonType: reasonType,
    evidenceJson: evidenceJson,
    ruleScoreShort: ruleScoreShort,
    ruleScoreLong: ruleScoreLong,
  );
}

/// 建立測試用 DailyAnalysisEntry
///
/// Stage 5b dual-horizon: 保留單一 `score` 參數為方便書寫，helper
/// 內部會同時賦值給 `scoreShort` 跟 `scoreLong`。
DailyAnalysisEntry createTestAnalysis({
  String symbol = 'TEST',
  DateTime? date,
  String trendState = 'UP',
  String reversalState = 'NONE',
  double? supportLevel,
  double? resistanceLevel,
  double score = 50.0,
}) {
  return DailyAnalysisEntry(
    symbol: symbol,
    date: date ?? DateTime(2024, 6, 15),
    trendState: trendState,
    reversalState: reversalState,
    supportLevel: supportLevel,
    resistanceLevel: resistanceLevel,
    scoreShort: score,
    scoreLong: score,
    computedAt: DateTime(2024, 6, 15, 10, 0),
  );
}

/// 建立測試用 DailyInstitutionalEntry
DailyInstitutionalEntry createTestInstitutional({
  String symbol = 'TEST',
  DateTime? date,
  double? foreignNet,
  double? investmentTrustNet,
  double? dealerNet,
}) {
  return DailyInstitutionalEntry(
    symbol: symbol,
    date: date ?? DateTime(2024, 6, 15),
    foreignNet: foreignNet,
    investmentTrustNet: investmentTrustNet,
    dealerNet: dealerNet,
  );
}

/// 建立測試用 FinMindRevenue
FinMindRevenue createTestRevenue({
  String stockId = 'TEST',
  double revenue = 1000000,
  double? yoyGrowth,
  double? momGrowth,
}) {
  return FinMindRevenue(
    stockId: stockId,
    date: '2024-06-15',
    revenue: revenue,
    revenueMonth: 6,
    revenueYear: 2024,
    yoyGrowth: yoyGrowth,
    momGrowth: momGrowth,
  );
}

/// 建立測試用 FinMindPER
FinMindPER createTestPER({
  String stockId = 'TEST',
  double per = 15.0,
  double pbr = 2.0,
  double dividendYield = 3.0,
}) {
  return FinMindPER(
    stockId: stockId,
    date: '2024-06-15',
    per: per,
    pbr: pbr,
    dividendYield: dividendYield,
  );
}
