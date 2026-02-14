import 'package:afterclose/data/database/app_database.dart';

/// 價格資料儲存庫介面
///
/// 支援測試時的 Mock 及不同實作（如本機資料庫、遠端 API、記憶體快取）
abstract class IPriceRepository {
  // ==================================================
  // 價格資料查詢
  // ==================================================

  /// 取得分析用的價格歷史
  ///
  /// 若有足夠資料，至少回傳 [RuleParams.lookbackPrice] 天
  Future<List<DailyPriceEntry>> getPriceHistory(
    String symbol, {
    int? days,
    DateTime? startDate,
    DateTime? endDate,
  });

  /// 取得股票最新價格
  Future<DailyPriceEntry?> getLatestPrice(String symbol);

  /// 取得股價漲跌幅
  Future<double?> getPriceChange(String symbol);

  /// 取得 20 日成交量移動平均
  Future<double?> getVolumeMA20(String symbol);

  /// 批次取得多檔股票的漲跌幅
  Future<Map<String, double?>> getPriceChangesBatch(List<String> symbols);

  /// 批次取得多檔股票的 20 日成交量均量
  Future<Map<String, double?>> getVolumeMA20Batch(List<String> symbols);

  // ==================================================
  // 同步作業
  // ==================================================

  /// 使用 TWSE 歷史 API 同步單一股票價格
  Future<int> syncStockPrices(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  });

  /// 批次同步今日所有股票價格
  Future<MarketSyncResult> syncTodayPrices({DateTime? date});

  /// 同步最新交易日所有價格並回傳快速篩選候選股
  Future<MarketSyncResult> syncAllPricesForDate(
    DateTime date, {
    List<String>? fallbackSymbols,
    bool force = false,
  });

  /// 同步多檔特定股票的價格
  Future<int> syncPricesForSymbols(
    List<String> symbols, {
    required DateTime targetDate,
    void Function(int current, int total, String symbol)? onProgress,
  });

  /// 取得需要更新價格的股票代碼清單
  Future<List<String>> getSymbolsNeedingUpdate(
    List<String> symbols,
    DateTime targetDate,
  );
}

/// 全市場價格同步結果
class MarketSyncResult {
  const MarketSyncResult({
    required this.count,
    required this.candidates,
    this.dataDate,
    this.tpexDataDate,
    this.skipped = false,
  });

  final int count;
  final List<String> candidates;

  /// 主要資料日期（優先 TWSE）
  final DateTime? dataDate;

  /// TPEX（上櫃）資料日期
  ///
  /// 用於上櫃股票的新鮮度檢查。
  /// TPEX 和 TWSE 的資料日期可能不同步。
  final DateTime? tpexDataDate;

  final bool skipped;
}
