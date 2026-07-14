import 'package:drift/drift.dart';

import 'package:afterclose/core/constants/data_freshness.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/taiwan_calendar.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/data/remote/tpex_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/domain/repositories/fundamental_repository.dart';

/// 基本面資料 Repository（營收、本益比、股價淨值比、殖利率）
class FundamentalRepository implements IFundamentalRepository {
  FundamentalRepository({
    required AppDatabase db,
    required FinMindClient finMind,
    required TwseClient twse,
    required TpexClient tpex,
    AppClock clock = const SystemClock(),
  }) : _db = db,
       _finMind = finMind,
       _twse = twse,
       _tpex = tpex,
       _clock = clock;

  final AppDatabase _db;
  final FinMindClient _finMind;
  final TwseClient _twse;
  final TpexClient _tpex;
  final AppClock _clock;

  /// 同步 API 資料的通用模板方法
  ///
  /// 自動處理：
  /// - 空資料檢查
  /// - RateLimitException 重拋
  /// - 一般異常記錄
  ///
  /// 範例：
  /// ```dart
  /// return _syncDataTemplate(
  ///   operationName: '月營收',
  ///   symbol: symbol,
  ///   fetchData: () => _finMind.getMonthlyRevenue(...),
  ///   mapToCompanion: (data) => data.map(...).toList(),
  ///   persistData: (entries) => _db.insertMonthlyRevenue(entries),
  /// );
  /// ```
  Future<int> _syncDataTemplate<T, C>({
    required String operationName,
    String? symbol,
    required Future<List<T>> Function() fetchData,
    required List<C> Function(List<T>) mapToCompanion,
    required Future<void> Function(List<C>) persistData,
  }) async {
    try {
      final data = await fetchData();
      if (data.isEmpty) return 0;

      final entries = mapToCompanion(data);
      await persistData(entries);
      return entries.length;
    } on RateLimitException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      // 之前 return 0 會讓 caller 把「DB/parse 失敗」當成「同步 0 筆」，
      // FundamentalSyncer 把錯誤降級為 info log 而不上報 ctx.result.errors，
      // 下游 EPS/ROE/dividend rule 靜默退化。改 throw DatabaseException 讓
      // upstream catch (e) 仍可優雅降級但保留 cause + 真實 stack。
      final symbolInfo = symbol != null ? ': $symbol' : '';
      throw DatabaseException('Failed to sync $operationName$symbolInfo', e);
    }
  }

  /// 同步單檔股票的月營收資料
  ///
  /// 回傳同步筆數
  @override
  Future<int> syncMonthlyRevenue({
    required String symbol,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return _syncDataTemplate(
      operationName: '月營收',
      symbol: symbol,
      fetchData: () => _finMind.getMonthlyRevenue(
        stockId: symbol,
        startDate: DateContext.formatYmd(startDate),
        endDate: DateContext.formatYmd(endDate),
      ),
      mapToCompanion: (data) {
        // 計算成長率
        final withGrowth = FinMindRevenue.calculateGrowthRates(data);

        // 轉換為 Database 資料
        return withGrowth.map((r) {
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
      },
      persistData: (entries) => _db.insertMonthlyRevenue(entries),
    );
  }

  /// 同步單檔股票的估值資料（本益比/股價淨值比/殖利率）
  ///
  /// 回傳同步筆數
  @override
  Future<int> syncValuationData({
    required String symbol,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return _syncDataTemplate(
      operationName: '估值資料',
      symbol: symbol,
      fetchData: () => _finMind.getPERData(
        stockId: symbol,
        startDate: DateContext.formatYmd(startDate),
        endDate: DateContext.formatYmd(endDate),
      ),
      mapToCompanion: (data) => data.map((r) {
        // 正規化到當日 00:00：r.date 解析失敗時 fallback 的 _clock.now() 含時間戳，
        // 會讓 PK (symbol,date) 每次不同、無法去重（同 valuation 重複膨脹根因）。
        final parsedDate = DateContext.normalize(
          DateTime.tryParse(r.date) ?? _clock.now(),
        );
        return StockValuationCompanion.insert(
          symbol: symbol,
          date: parsedDate,
          per: Value(r.per),
          pbr: Value(r.pbr),
          dividendYield: Value(r.dividendYield),
        );
      }).toList(),
      persistData: (entries) => _db.insertValuationData(entries),
    );
  }

  /// 使用 TWSE BWIBBU_d 同步全市場估值資料（免費、無限制）
  ///
  /// 取代個別 FinMind 呼叫以進行每日更新。
  /// 注意：此方法僅同步上市股票，上櫃股票需使用 [syncOtcValuation]。
  @override
  Future<int> syncAllMarketValuation(
    DateTime date, {
    bool force = false,
  }) async {
    try {
      final data = await _twse.getAllStockValuation(date: date);

      if (data.isEmpty) return 0;

      // 轉換為 Database 資料
      // 過濾無效資料（通常 PE > 0，殖利率 >= 0）
      final entries = data.map((r) {
        return StockValuationCompanion.insert(
          symbol: r.code,
          date: r.date,
          per: Value(r.per),
          pbr: Value(r.pbr),
          dividendYield: Value(r.dividendYield),
        );
      }).toList();

      await _db.insertValuationData(entries);

      AppLogger.info('FundamentalRepo', '估值同步: ${entries.length} 筆 (上市, TWSE)');

      return entries.length;
    } on RateLimitException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync TWSE all-market valuation', e);
    }
  }

  /// 補充上櫃股票的估值資料（使用 TPEX OpenAPI 批次取得）
  ///
  /// [symbols] 為要同步的上櫃股票代碼清單。
  /// 使用 TPEX 免費 OpenAPI 一次取得所有上櫃股票估值資料。
  /// 設定 [force] 為 true 可略過新鮮度檢查。
  ///
  /// 回傳成功同步的股票數量。
  @override
  Future<int> syncOtcValuation(
    List<String> symbols, {
    DateTime? date,
    bool force = false,
  }) async {
    if (symbols.isEmpty) return 0;

    final targetDate = date ?? _clock.now();

    // 新鮮度檢查：過濾掉已有近期估值資料的股票（3 天內視為新鮮）
    List<String> symbolsToSync = symbols;
    if (!force) {
      final freshThreshold = targetDate.subtract(
        const Duration(days: DataFreshness.otcValuationFreshDays),
      );
      final needSync = <String>[];

      final latestMap = await _db.getLatestValuationsBatch(symbols);
      for (final symbol in symbols) {
        final latest = latestMap[symbol];
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
    } on RateLimitException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync TPEX OTC valuation batch', e);
    }
  }

  /// 使用 TWSE Open Data 同步全市場月營收（免費、無限制）
  ///
  /// 取代個別 FinMind 呼叫以進行最新月份更新。
  /// API 端點：https://openapi.twse.com.tw/v1/opendata/t187ap05_L
  /// 注意：此方法僅同步上市股票，上櫃股票需使用 [syncOtcRevenue]。
  ///
  /// 回傳：同步筆數，或 null 表示跳過（已有資料）
  @override
  Future<int?> syncAllMarketRevenue(DateTime date, {bool force = false}) async {
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
        if (existingCount > DataFreshness.revenueRecordThreshold) {
          AppLogger.debug(
            'FundamentalRepo',
            '$dataYear/$dataMonth 營收資料已快取 ($existingCount 筆)，跳過同步',
          );
          return null;
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
    } on RateLimitException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync TWSE all-market revenue', e);
    }
  }

  /// 補充上櫃股票的營收資料（使用 TPEX OpenAPI）
  ///
  /// [symbols] 為要同步的上櫃股票代碼清單。
  /// 使用 TPEX OpenAPI 一次取得所有股票營收，免費無限制。
  /// 設定 [force] 為 true 可略過新鮮度檢查。
  ///
  /// 回傳成功同步的股票數量。
  @override
  Future<int> syncOtcRevenue(
    List<String> symbols, {
    DateTime? date,
    bool force = false,
  }) async {
    if (symbols.isEmpty) return 0;

    final targetDate = date ?? _clock.now();

    // 新鮮度檢查：過濾掉已有當月營收資料的股票
    // 營收以年/月為單位，同月內不需重複同步
    List<String> symbolsToSync = symbols;
    if (!force) {
      final currentYear = targetDate.year;
      final currentMonth = targetDate.month;
      final needSync = <String>[];

      final latestMap = await _db.getLatestMonthlyRevenuesBatch(symbols);
      for (final symbol in symbols) {
        final latest = latestMap[symbol];
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
    } on RateLimitException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync TPEX OTC revenue batch', e);
    }
  }

  /// 同步單檔股票的損益表資料（含 EPS、營收、毛利等）
  ///
  /// 從 FinMind API 取得近 2 年的季度損益表資料並寫入 DB。
  /// 新鮮度檢查為發布行事曆感知（[TaiwanCalendar.expectedLatestReportQuarter]），
  /// 已有應發布的最新一季即跳過。
  @override
  Future<int> syncFinancialStatements({
    required String symbol,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      // 新鮮度檢查：已有「此刻應已發布的最新一季」則跳過。
      // 不能用「距今 N 天」啟發式——財報日期是季度截止日，發布後只有
      // ~2-6 週會通過天數檢查，其餘時間每次更新都重抓全部候選股。
      final latestDate = await _db.getLatestFinancialDataDate(symbol, 'INCOME');
      final expectedQuarter = TaiwanCalendar.expectedLatestReportQuarter(
        _clock.now(),
      );
      if (latestDate != null && !latestDate.isBefore(expectedQuarter)) {
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
              date: DateContext.parseQuarterDate(item.date),
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
    } on RateLimitException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw DatabaseException(
        'Failed to sync financial statements: $symbol',
        e,
      );
    }
  }
}
