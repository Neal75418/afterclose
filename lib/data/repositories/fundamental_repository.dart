import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/presentation/providers/providers.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 基本面資料 Repository（營收、本益比、股價淨值比、殖利率）
class FundamentalRepository {
  FundamentalRepository({
    required AppDatabase db,
    required FinMindClient finMind,
    TwseClient? twse,
  }) : _db = db,
       _finMind = finMind,
       _twse = twse ?? TwseClient();

  final AppDatabase _db;
  final FinMindClient _finMind;
  final TwseClient _twse;

  /// 同步單檔股票的月營收資料
  ///
  /// 回傳同步筆數
  Future<int> syncMonthlyRevenue({
    required String symbol,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final data = await _finMind.getMonthlyRevenue(
        stockId: symbol,
        startDate: _formatDate(startDate),
        endDate: _formatDate(endDate),
      );

      if (data.isEmpty) return 0;

      // 計算成長率
      final withGrowth = FinMindRevenue.calculateGrowthRates(data);

      // 轉換為 Database 資料
      final entries = withGrowth.map((r) {
        // 使用當月第一天作為日期
        final date = DateTime(r.revenueYear, r.revenueMonth);
        return MonthlyRevenueCompanion.insert(
          symbol: symbol,
          date: date,
          revenueYear: r.revenueYear,
          revenueMonth: r.revenueMonth,
          revenue: r.revenue,
          momGrowth: Value(r.momGrowth),
          yoyGrowth: Value(r.yoyGrowth),
        );
      }).toList();

      await _db.insertMonthlyRevenue(entries);
      return entries.length;
    } catch (e) {
      AppLogger.warning('FundamentalRepo', '同步月營收失敗: $symbol', e);
      return 0;
    }
  }

  /// 同步單檔股票的估值資料（本益比/股價淨值比/殖利率）
  ///
  /// 回傳同步筆數
  Future<int> syncValuationData({
    required String symbol,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final data = await _finMind.getPERData(
        stockId: symbol,
        startDate: _formatDate(startDate),
        endDate: _formatDate(endDate),
      );

      if (data.isEmpty) return 0;

      // 轉換為 Database 資料
      final entries = data.map((r) {
        // 解析日期字串
        final parsedDate = DateTime.tryParse(r.date) ?? DateTime.now();
        return StockValuationCompanion.insert(
          symbol: symbol,
          date: parsedDate,
          per: Value(r.per),
          pbr: Value(r.pbr),
          dividendYield: Value(r.dividendYield),
        );
      }).toList();

      await _db.insertValuationData(entries);
      return entries.length;
    } catch (e) {
      AppLogger.warning('FundamentalRepo', '同步估值資料失敗: $symbol', e);
      return 0;
    }
  }

  /// 使用 TWSE BWIBBU_d 同步全市場估值資料（免費、無限制）
  ///
  /// 取代個別 FinMind 呼叫以進行每日更新。
  Future<int> syncAllMarketValuation(
    DateTime date, {
    bool force = false,
  }) async {
    try {
      // 強制同步以確保錯誤資料（錯誤的 PE/殖利率解析）被覆蓋
      // if (!force) {
      //   final existingCount = await _db.getValuationCountForDate(date);
      //   if (existingCount > 1000) return existingCount;
      // }
      final data = await _twse.getAllStockValuation(date: date);

      if (data.isEmpty) return 0;

      // 轉換為 Database 資料
      // 過濾無效資料（通常 PE > 0，殖利率 >= 0）
      final entries = data.map((r) {
        return StockValuationCompanion.insert(
          symbol: r.code,
          date: r.date,
          // TWSE 本益比若為負盈餘則顯示「-」，解析器回傳 null
          // FinMind 回傳 0 或 null？
          // 若無資料則儲存 null
          per: Value(r.per),
          pbr: Value(r.pbr),
          dividendYield: Value(r.dividendYield),
        );
      }).toList();

      await _db.insertValuationData(entries);
      return entries.length;
    } catch (e) {
      AppLogger.warning('FundamentalRepo', '同步全市場估值失敗: $date', e);
      return 0;
    }
  }

  /// 使用 TWSE Open Data 同步全市場月營收（免費、無限制）
  ///
  /// 取代個別 FinMind 呼叫以進行最新月份更新。
  /// API 端點：https://openapi.twse.com.tw/v1/opendata/t187ap05_L
  ///
  /// 回傳：同步筆數，或 -1 表示跳過（已有資料）
  Future<int> syncAllMarketRevenue(DateTime date, {bool force = false}) async {
    try {
      // 註：OpenData 僅回傳「最新」月份
      // 無法指定日期。我們只抓取可用的資料

      final data = await _twse.getAllMonthlyRevenue();

      if (data.isEmpty) return 0;

      // 版本檢查：檢查是否已有該月資料
      // 避免重複 API 呼叫和 Database 寫入
      final sample = data.first;
      final dataYear = sample.year;
      final dataMonth = sample.month;

      if (!force) {
        final existingCount = await _db.getRevenueCountForYearMonth(
          dataYear,
          dataMonth,
        );
        // 若該月已有 >1000 筆資料則跳過
        // （全市場通常有 ~1800+ 檔股票）
        if (existingCount > 1000) {
          AppLogger.info(
            'FundamentalRepo',
            '$dataYear/$dataMonth 營收資料已存在 ($existingCount 筆)，跳過同步',
          );
          return -1; // 訊號：已跳過
        }
      }

      // 過濾有效資料
      final stockList = await _db.getAllActiveStocks();
      final validSymbols = stockList.map((s) => s.symbol).toSet();
      final validData = data
          .where((r) => validSymbols.contains(r.code))
          .toList();

      AppLogger.info(
        'FundamentalRepo',
        '同步營收 $dataYear/$dataMonth (${validData.length}/${data.length} 檔)',
      );

      final entries = validData.map((r) {
        final recordDate = DateTime(r.year, r.month);
        return MonthlyRevenueCompanion.insert(
          symbol: r.code,
          date: recordDate,
          revenueYear: r.year,
          revenueMonth: r.month,
          revenue: r.revenue,
          momGrowth: Value(r.momGrowth),
          yoyGrowth: Value(r.yoyGrowth),
        );
      }).toList();

      await _db.insertMonthlyRevenue(entries);
      return entries.length;
    } catch (e) {
      AppLogger.warning('FundamentalRepo', '同步全市場營收失敗', e);
      return 0;
    }
  }

  /// 同步單檔股票的所有基本面資料
  Future<({int revenue, int valuation})> syncAll({
    required String symbol,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final results = await Future.wait([
      syncMonthlyRevenue(
        symbol: symbol,
        startDate: startDate,
        endDate: endDate,
      ),
      syncValuationData(symbol: symbol, startDate: startDate, endDate: endDate),
    ]);

    return (revenue: results[0], valuation: results[1]);
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// FundamentalRepository Provider
final fundamentalRepositoryProvider = Provider<FundamentalRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final finMind = ref.watch(finMindClientProvider);
  // TwseClient 通常不需要 Provider，因為它不保存狀態/認證
  // 但若有的話可以注入。目前 Repository 會自行建立或接受 null
  return FundamentalRepository(db: db, finMind: finMind);
});
