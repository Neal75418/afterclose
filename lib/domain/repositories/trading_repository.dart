import 'package:afterclose/data/database/app_database.dart';

/// 交易資料儲存庫介面
///
/// 處理當沖與融資融券資料的查詢、同步與分析功能。
/// 支援測試時的 Mock 及不同實作。
abstract class ITradingRepository {
  // ==================================================
  // 當沖
  // ==================================================

  /// 取得當沖歷史資料
  Future<List<DayTradingEntry>> getDayTradingHistory(
    String symbol, {
    int days = 30,
  });

  /// 取得最新當沖資料
  Future<DayTradingEntry?> getLatestDayTrading(String symbol);

  /// 從 TWSE 同步全市場當沖資料
  Future<int> syncAllDayTradingFromTwse({DateTime? date, bool force = false});

  /// 從 TPEX 同步全市場上櫃當沖資料
  Future<int> syncAllDayTradingFromTpex({DateTime? date, bool force = false});

  // ==================================================
  // 融資融券
  // ==================================================

  /// 取得融資融券歷史資料
  Future<List<MarginTradingEntry>> getMarginTradingHistory(
    String symbol, {
    int days = 30,
  });

  /// 取得最新融資融券資料
  Future<MarginTradingEntry?> getLatestMarginTrading(String symbol);

  /// 從 TWSE/TPEX 同步全市場融資融券資料
  Future<int> syncAllMarginTradingFromTwse({
    DateTime? date,
    bool force = false,
  });
}
