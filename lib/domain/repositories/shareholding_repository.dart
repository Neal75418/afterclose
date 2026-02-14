import 'package:afterclose/data/database/app_database.dart';

/// 持股資料儲存庫介面
///
/// 提供外資持股與股權分散表的查詢、同步與分析功能。
/// 支援測試時的 Mock 及不同實作。
abstract class IShareholdingRepository {
  /// 取得持股歷史
  Future<List<ShareholdingEntry>> getShareholdingHistory(
    String symbol, {
    int days = 60,
  });

  /// 取得最新持股資料
  Future<ShareholdingEntry?> getLatestShareholding(String symbol);

  /// 同步持股資料
  Future<int> syncShareholding(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  });

  /// 檢查外資持股是否增加中
  Future<bool> isForeignShareholdingIncreasing(String symbol, {int days = 5});

  /// 取得最新股權分散表
  Future<List<HoldingDistributionEntry>> getLatestHoldingDistribution(
    String symbol,
  );

  /// 同步股權分散表
  Future<int> syncHoldingDistribution(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  });

  /// 取得集中度比率
  Future<double?> getConcentrationRatio(
    String symbol, {
    int thresholdLevel = 400,
  });

  /// 批次取得集中度比率
  Future<Map<String, double>> getConcentrationRatioBatch(
    List<String> symbols, {
    int thresholdLevel = 400,
  });
}
