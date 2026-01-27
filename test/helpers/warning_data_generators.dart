import 'package:afterclose/data/database/app_database.dart';

/// 測試資料生成工具 - Warning & Insider
///
/// 提供共用的警示與董監持股測試資料產生器。

// ==========================================
// 日期計算工具
// ==========================================

/// 計算往前 N 個月的日期
///
/// 使用 DateTime 構造函數處理跨年和月份溢位。
/// 例如：2026-01 往前 3 個月 = 2025-10
DateTime _monthsAgo(DateTime from, int months) {
  return DateTime(from.year, from.month - months, 1);
}

// ==========================================
// Warning 資料生成
// ==========================================

/// 建立單一 TradingWarningEntry
TradingWarningEntry createTestWarning({
  required String symbol,
  required DateTime date,
  String warningType = 'ATTENTION',
  String? reasonCode,
  String? reasonDescription,
  String? disposalMeasures,
  DateTime? disposalStartDate,
  DateTime? disposalEndDate,
  bool isActive = true,
}) {
  return TradingWarningEntry(
    symbol: symbol,
    date: date,
    warningType: warningType,
    reasonCode: reasonCode,
    reasonDescription: reasonDescription,
    disposalMeasures: disposalMeasures,
    disposalStartDate: disposalStartDate,
    disposalEndDate: disposalEndDate,
    isActive: isActive,
  );
}

/// 建立注意股票警示
TradingWarningEntry createAttentionWarning({
  required String symbol,
  DateTime? date,
  String reasonDescription = '成交量異常',
}) {
  return createTestWarning(
    symbol: symbol,
    date: date ?? DateTime.now(),
    warningType: 'ATTENTION',
    reasonDescription: reasonDescription,
    isActive: true,
  );
}

/// 建立處置股票警示
TradingWarningEntry createDisposalWarning({
  required String symbol,
  DateTime? date,
  String disposalMeasures = '分盤交易',
  DateTime? disposalStartDate,
  DateTime? disposalEndDate,
}) {
  final now = date ?? DateTime.now();
  return createTestWarning(
    symbol: symbol,
    date: now,
    warningType: 'DISPOSAL',
    disposalMeasures: disposalMeasures,
    disposalStartDate: disposalStartDate ?? now,
    disposalEndDate: disposalEndDate ?? now.add(const Duration(days: 30)),
    isActive: true,
  );
}

// ==========================================
// Insider Holding 資料生成
// ==========================================

/// 建立單一 InsiderHoldingEntry
InsiderHoldingEntry createTestInsiderHolding({
  required String symbol,
  required DateTime date,
  double? insiderRatio,
  double? pledgeRatio,
  double? sharesIssued,
}) {
  return InsiderHoldingEntry(
    symbol: symbol,
    date: date,
    insiderRatio: insiderRatio,
    pledgeRatio: pledgeRatio,
    sharesIssued: sharesIssued,
  );
}

/// 生成連續減持的持股歷史
///
/// 模擬董監連續減持的情況，用於測試 InsiderSellingStreakRule。
/// 使用 `_monthsAgo` 確保跨年月份計算正確。
///
/// [referenceDate] 參考日期，預設為當前時間。傳入固定日期可確保測試的確定性。
List<InsiderHoldingEntry> generateSellingStreak({
  required String symbol,
  required int months,
  double startRatio = 30.0,
  double decreasePerMonth = 2.0,
  DateTime? referenceDate,
}) {
  final refDate = referenceDate ?? DateTime.now();
  return List.generate(months, (i) {
    // 從最早月份開始生成：months-1 個月前 → 0 個月前（當月）
    final monthsBack = months - 1 - i;
    return createTestInsiderHolding(
      symbol: symbol,
      date: _monthsAgo(refDate, monthsBack),
      insiderRatio: startRatio - (decreasePerMonth * i),
      pledgeRatio: 10.0,
    );
  });
}

/// 生成連續增持的持股歷史
///
/// 使用 `_monthsAgo` 確保跨年月份計算正確。
///
/// [referenceDate] 參考日期，預設為當前時間。傳入固定日期可確保測試的確定性。
List<InsiderHoldingEntry> generateBuyingStreak({
  required String symbol,
  required int months,
  double startRatio = 20.0,
  double increasePerMonth = 3.0,
  DateTime? referenceDate,
}) {
  final refDate = referenceDate ?? DateTime.now();
  return List.generate(months, (i) {
    // 從最早月份開始生成：months-1 個月前 → 0 個月前（當月）
    final monthsBack = months - 1 - i;
    return createTestInsiderHolding(
      symbol: symbol,
      date: _monthsAgo(refDate, monthsBack),
      insiderRatio: startRatio + (increasePerMonth * i),
      pledgeRatio: 10.0,
    );
  });
}

/// 生成高質押比例的持股資料
InsiderHoldingEntry createHighPledgeHolding({
  required String symbol,
  DateTime? date,
  double pledgeRatio = 60.0,
  double insiderRatio = 25.0,
}) {
  return createTestInsiderHolding(
    symbol: symbol,
    date: date ?? DateTime.now(),
    insiderRatio: insiderRatio,
    pledgeRatio: pledgeRatio,
  );
}

/// 生成穩定的持股歷史（無明顯變化）
///
/// 使用 `_monthsAgo` 確保跨年月份計算正確。
///
/// [referenceDate] 參考日期，預設為當前時間。傳入固定日期可確保測試的確定性。
List<InsiderHoldingEntry> generateStableHoldings({
  required String symbol,
  required int months,
  double ratio = 25.0,
  double pledgeRatio = 10.0,
  DateTime? referenceDate,
}) {
  final refDate = referenceDate ?? DateTime.now();
  return List.generate(months, (i) {
    // 從最早月份開始生成：months-1 個月前 → 0 個月前（當月）
    final monthsBack = months - 1 - i;
    return createTestInsiderHolding(
      symbol: symbol,
      date: _monthsAgo(refDate, monthsBack),
      insiderRatio: ratio + (i % 2 == 0 ? 0.1 : -0.1), // 微幅波動
      pledgeRatio: pledgeRatio,
    );
  });
}
