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

  /// 從 TWSE 同步全市場當沖資料（上市）
  ///
  /// 無上櫃對等 method — TPEX 當沖端點被 Cloudflare 擋、OpenAPI 也無替代。
  Future<int> syncAllDayTradingFromTwse({DateTime? date, bool force = false});

  // ==================================================
  // 融資融券
  // ==================================================

  /// 取得融資融券歷史資料
  Future<List<MarginTradingEntry>> getMarginTradingHistory(
    String symbol, {
    int days = 30,
  });

  /// 從 TWSE/TPEX 同步全市場融資融券資料。回傳同步筆數，null 表示已快取（跳過同步）。
  Future<int?> syncAllMarginTradingFromTwse({
    DateTime? date,
    bool force = false,
  });
}
