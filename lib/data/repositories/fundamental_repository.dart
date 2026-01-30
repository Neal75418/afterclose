import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/data/remote/tpex_client.dart';
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
    TpexClient? tpex,
  }) : _db = db,
       _finMind = finMind,
       _twse = twse ?? TwseClient(),
       _tpex = tpex ?? TpexClient();

  final AppDatabase _db;
  final FinMindClient _finMind;
  final TwseClient _twse;
  final TpexClient _tpex;

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
        startDate: DateContext.formatYmd(startDate),
        endDate: DateContext.formatYmd(endDate),
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
        startDate: DateContext.formatYmd(startDate),
        endDate: DateContext.formatYmd(endDate),
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
  /// 注意：此方法僅同步上市股票，上櫃股票需使用 [syncOtcValuation]。
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

      AppLogger.info('FundamentalRepo', '估值同步: ${entries.length} 筆 (上市, TWSE)');

      return entries.length;
    } catch (e) {
      AppLogger.warning('FundamentalRepo', '同步全市場估值失敗: $date', e);
      return 0;
    }
  }

  /// 補充上櫃股票的估值資料（使用 TPEX OpenAPI 批次取得）
  ///
  /// [symbols] 為要同步的上櫃股票代碼清單。
  /// 使用 TPEX 免費 OpenAPI 一次取得所有上櫃股票估值資料。
  /// 設定 [force] 為 true 可略過新鮮度檢查。
  ///
  /// 回傳成功同步的股票數量。
  Future<int> syncOtcValuation(
    List<String> symbols, {
    DateTime? date,
    bool force = false,
  }) async {
    if (symbols.isEmpty) return 0;

    final targetDate = date ?? DateTime.now();

    // 新鮮度檢查：過濾掉已有近期估值資料的股票（3 天內視為新鮮）
    List<String> symbolsToSync = symbols;
    if (!force) {
      final freshThreshold = targetDate.subtract(const Duration(days: 3));
      final needSync = <String>[];

      for (final symbol in symbols) {
        final latest = await _db.getLatestValuation(symbol);
        // 若無資料或資料過舊則需要同步
        if (latest == null || latest.date.isBefore(freshThreshold)) {
          needSync.add(symbol);
        }
      }
      symbolsToSync = needSync;

      if (symbolsToSync.isEmpty) {
        AppLogger.info('FundamentalRepo', '上櫃估值: 所有股票已有最新資料，跳過同步');
        return 0;
      }

      AppLogger.info(
        'FundamentalRepo',
        '上櫃估值新鮮度檢查: ${symbols.length} 檔中 ${symbolsToSync.length} 檔需同步',
      );
    }

    // 使用 TPEX OpenAPI 批次取得全市場估值（1 次 API 呼叫）
    final symbolSet = symbolsToSync.toSet();

    try {
      final allData = await _tpex.getAllValuation(date: targetDate);

      if (allData.isEmpty) {
        AppLogger.warning('FundamentalRepo', 'TPEX 估值 API 回傳空資料');
        return 0;
      }

      // 篩選出需要的股票
      final entries = <StockValuationCompanion>[];
      for (final item in allData) {
        if (!symbolSet.contains(item.code)) continue;

        entries.add(
          StockValuationCompanion.insert(
            symbol: item.code,
            date: item.date,
            per: Value(item.per),
            pbr: Value(item.pbr),
            dividendYield: Value(item.dividendYield),
          ),
        );
      }

      // 批次寫入資料庫
      if (entries.isNotEmpty) {
        await _db.insertValuationData(entries);
      }

      final skippedCount = symbols.length - symbolsToSync.length;
      AppLogger.info(
        'FundamentalRepo',
        '上櫃估值同步完成: ${entries.length}/${symbolsToSync.length} 檔 '
            '(API calls: 1, 跳過: $skippedCount)',
      );

      return entries.length;
    } catch (e) {
      AppLogger.warning('FundamentalRepo', '批次同步上櫃估值失敗', e);
      return 0;
    }
  }

  /// 使用 TWSE Open Data 同步全市場月營收（免費、無限制）
  ///
  /// 取代個別 FinMind 呼叫以進行最新月份更新。
  /// API 端點：https://openapi.twse.com.tw/v1/opendata/t187ap05_L
  /// 注意：此方法僅同步上市股票，上櫃股票需使用 [syncOtcRevenue]。
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
        '營收同步 $dataYear/$dataMonth: ${validData.length}/${data.length} 檔 (上市, TWSE)',
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

  /// 補充上櫃股票的營收資料（使用 TPEX OpenAPI）
  ///
  /// [symbols] 為要同步的上櫃股票代碼清單。
  /// 使用 TPEX OpenAPI 一次取得所有股票營收，免費無限制。
  /// 設定 [force] 為 true 可略過新鮮度檢查。
  ///
  /// 回傳成功同步的股票數量。
  Future<int> syncOtcRevenue(
    List<String> symbols, {
    DateTime? date,
    bool force = false,
  }) async {
    if (symbols.isEmpty) return 0;

    final targetDate = date ?? DateTime.now();

    // 新鮮度檢查：過濾掉已有當月營收資料的股票
    // 營收以年/月為單位，同月內不需重複同步
    List<String> symbolsToSync = symbols;
    if (!force) {
      final currentYear = targetDate.year;
      final currentMonth = targetDate.month;
      final needSync = <String>[];

      for (final symbol in symbols) {
        final latest = await _db.getLatestMonthlyRevenue(symbol);
        // 若無資料或資料不是當月則需要同步
        final isCurrentMonth =
            latest != null &&
            latest.revenueYear == currentYear &&
            latest.revenueMonth == currentMonth;
        if (!isCurrentMonth) {
          needSync.add(symbol);
        }
      }
      symbolsToSync = needSync;

      if (symbolsToSync.isEmpty) {
        AppLogger.info('FundamentalRepo', '上櫃營收: 所有股票已有當月資料，跳過同步');
        return 0;
      }

      AppLogger.info(
        'FundamentalRepo',
        '上櫃營收新鮮度檢查: ${symbols.length} 檔中 ${symbolsToSync.length} 檔需同步',
      );
    }

    // 使用 TPEX OpenAPI 一次取得所有股票營收（免費無限制）
    final symbolSet = symbolsToSync.toSet();

    try {
      final allData = await _tpex.getAllMonthlyRevenue();

      if (allData.isEmpty) {
        AppLogger.warning('FundamentalRepo', 'TPEX 營收 API 回傳空資料');
        return 0;
      }

      var successCount = 0;
      final entries = <MonthlyRevenueCompanion>[];

      for (final item in allData) {
        if (!symbolSet.contains(item.code)) continue;

        entries.add(
          MonthlyRevenueCompanion.insert(
            symbol: item.code,
            date: item.date,
            revenueYear: item.revenueYear,
            revenueMonth: item.revenueMonth,
            revenue: item.revenue,
            momGrowth: Value(item.momGrowth),
            yoyGrowth: Value(item.yoyGrowth),
          ),
        );
        successCount++;
      }

      // 批次寫入資料庫
      if (entries.isNotEmpty) {
        await _db.insertMonthlyRevenue(entries);
      }

      final skippedCount = symbols.length - symbolsToSync.length;
      AppLogger.info(
        'FundamentalRepo',
        '上櫃營收同步完成: $successCount/${symbolsToSync.length} 檔 '
            '(TPEX OpenAPI, 跳過: $skippedCount)',
      );

      return successCount;
    } catch (e) {
      AppLogger.warning('FundamentalRepo', '同步上櫃營收失敗', e);
      return 0;
    }
  }

  /// 同步單檔股票的股利歷史
  ///
  /// 從 FinMind API 取得近 5 年的股利資料並寫入 DB。
  /// 回傳同步筆數。
  Future<int> syncDividends({required String symbol}) async {
    try {
      // 新鮮度檢查：股利資料通常在次年公佈（如 2025 年股利在 2026 年公佈）
      // 使用 currentYear - 2 作為基準，確保能抓到最新公佈的資料
      final latestYear = await _db.getLatestDividendYear(symbol);
      final currentYear = DateTime.now().year;
      if (latestYear != null && latestYear >= currentYear - 2) {
        return 0; // 已有近期資料
      }

      final data = await _finMind.getDividends(stockId: symbol);

      if (data.isEmpty) return 0;

      final entries = data.map((d) {
        return DividendHistoryCompanion.insert(
          symbol: symbol,
          year: d.year,
          cashDividend: Value(d.cashDividend),
          stockDividend: Value(d.stockDividend),
          exDividendDate: Value(d.exDividendDate),
          exRightsDate: Value(d.exRightsDate),
        );
      }).toList();

      await _db.insertDividendData(entries);
      return entries.length;
    } catch (e) {
      AppLogger.warning('FundamentalRepo', '同步股利歷史失敗: $symbol', e);
      return 0;
    }
  }

  /// 同步單檔股票的損益表資料（含 EPS、營收、毛利等）
  ///
  /// 從 FinMind API 取得近 2 年的季度損益表資料並寫入 DB。
  /// 含 90 天新鮮度檢查，避免重複同步。
  Future<int> syncFinancialStatements({
    required String symbol,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      // 新鮮度檢查：若最新資料距今 < 60 天，跳過
      // 季報每 ~90 天發布，60 天確保不會錯過最新一季
      final latestDate = await _db.getLatestFinancialDataDate(symbol, 'INCOME');
      if (latestDate != null &&
          DateTime.now().difference(latestDate).inDays < 60) {
        return 0;
      }

      final data = await _finMind.getFinancialStatements(
        stockId: symbol,
        startDate: DateContext.formatYmd(startDate),
        endDate: DateContext.formatYmd(endDate),
      );
      if (data.isEmpty) return 0;

      final entries = <FinancialDataCompanion>[];
      for (final item in data) {
        try {
          entries.add(
            FinancialDataCompanion.insert(
              symbol: symbol,
              date: _parseQuarterDate(item.date),
              statementType: 'INCOME',
              dataType: item.type,
              value: Value(item.value),
              originName: Value(item.origin),
            ),
          );
        } catch (e) {
          AppLogger.debug(
            'FundamentalRepo',
            '$symbol: 跳過無法解析的財報項目 (date=${item.date})',
          );
        }
      }

      await _db.insertFinancialData(entries);
      return entries.length;
    } catch (e) {
      AppLogger.warning('FundamentalRepo', '同步財報失敗: $symbol', e);
      return 0;
    }
  }

  /// 解析季度日期字串（如 "2024-Q1" 或 "2024-01-01"）
  ///
  /// 與 MarketDataRepository._parseQuarterDate 保持一致：
  /// "2024-Q1" → DateTime(2024, 1, 1)（季度首日）
  DateTime _parseQuarterDate(String dateStr) {
    if (dateStr.contains('Q')) {
      final parts = dateStr.split('-Q');
      final year = int.parse(parts[0]);
      final quarter = int.parse(parts[1]);
      final month = (quarter - 1) * 3 + 1;
      return DateTime(year, month, 1);
    }
    return DateTime.parse(dateStr);
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
}

/// FundamentalRepository Provider
final fundamentalRepositoryProvider = Provider<FundamentalRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final finMind = ref.watch(finMindClientProvider);
  // TwseClient 通常不需要 Provider，因為它不保存狀態/認證
  // 但若有的話可以注入。目前 Repository 會自行建立或接受 null
  return FundamentalRepository(db: db, finMind: finMind);
});
