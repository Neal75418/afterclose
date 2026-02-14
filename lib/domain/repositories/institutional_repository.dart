import 'package:afterclose/data/database/app_database.dart';

/// 三大法人買賣超資料儲存庫介面
///
/// 提供法人資料的查詢、同步與分析功能。
/// 支援測試時的 Mock 及不同實作。
abstract class IInstitutionalRepository {
  /// 取得法人資料歷史供分析使用
  Future<List<DailyInstitutionalEntry>> getInstitutionalHistory(
    String symbol, {
    int? days,
  });

  /// 取得股票最新法人資料
  Future<DailyInstitutionalEntry?> getLatestInstitutional(String symbol);

  /// 同步單檔股票的法人資料
  Future<int> syncInstitutionalData(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  });

  /// 同步指定日期的全市場法人資料
  Future<int> syncAllMarketInstitutional(DateTime date, {bool force = false});

  /// 檢查法人買賣方向是否反轉
  Future<bool> hasDirectionReversal(String symbol, {int days = 5});

  /// 取得近期法人淨買賣總額
  Future<double?> getTotalNetBuying(String symbol, {int days = 5});

  /// 清除所有法人資料
  Future<int> clearAllData();
}
