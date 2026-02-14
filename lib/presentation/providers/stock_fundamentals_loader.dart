import 'dart:async';

import 'package:drift/drift.dart';

import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';

/// 基本面資料的載入結果
typedef FundamentalsResult = ({
  List<FinMindRevenue> revenueData,
  List<FinMindDividend> dividendData,
  FinMindPER? latestPER,
  List<FinancialDataEntry> epsData,
  Map<String, double> quarterMetrics,
});

/// 基本面資料載入器
///
/// 負責從 DB 和 FinMind API 載入營收、股利、估值、EPS 等基本面資料。
/// 純資料取得邏輯，不管理 UI 狀態。
class StockFundamentalsLoader {
  StockFundamentalsLoader({
    required AppDatabase db,
    required FinMindClient finMind,
    AppClock clock = const SystemClock(),
  }) : _db = db,
       _finMind = finMind,
       _clock = clock;

  final AppDatabase _db;
  final FinMindClient _finMind;
  final AppClock _clock;

  /// 載入全部基本面資料
  ///
  /// 依序載入估值、營收、股利、EPS 與季度指標。
  /// 估值資料優先從 DB（TWSE 來源）取得，確保與規則評估一致。
  Future<FundamentalsResult> loadAll(String symbol) async {
    final today = _clock.now();
    final revenueStartDate = DateTime(today.year - 2, today.month, 1);

    // 1. 優先從資料庫取得估值資料（TWSE 來源，與規則評估一致）
    var latestPER = await _loadValuationData(symbol, today);

    // 2. 營收資料：優先從 DB，不足則 fallback FinMind API
    final revenueData = await _loadMonthlyRevenue(
      symbol,
      today: today,
      revenueStartDate: revenueStartDate,
    );

    // 3. 股利歷史：優先從 DB 取得，無資料則從 API 取得並存入 DB
    final dividendData = await _loadDividendHistory(symbol);

    // 4. EPS 歷史與季度財務指標（含 ROE 計算）
    final (:epsData, :quarterMetrics) = await _loadFinancialStatements(symbol);

    // 5. 若資料庫無估值資料，才用 FinMind API
    latestPER ??= await _loadValuationFromApi(symbol, today);

    return (
      revenueData: revenueData,
      dividendData: dividendData,
      latestPER: latestPER,
      epsData: epsData,
      quarterMetrics: quarterMetrics,
    );
  }

  /// 從資料庫取得估值資料（PER/PBR/殖利率）
  ///
  /// 優先使用 TWSE 來源的資料，確保與規則評估一致。
  /// 若資料庫無資料則回傳 null，後續由 [_loadValuationFromApi] 補充。
  Future<FinMindPER?> _loadValuationData(String symbol, DateTime today) async {
    try {
      final perStartDate = today.subtract(const Duration(days: 30));
      final dbValuations = await _db.getValuationHistory(
        symbol,
        startDate: perStartDate,
      );

      if (dbValuations.isNotEmpty) {
        final latest = dbValuations.last;
        final per = FinMindPER(
          stockId: latest.symbol,
          date: DateContext.formatYmd(latest.date),
          per: latest.per ?? 0,
          pbr: latest.pbr ?? 0,
          dividendYield: latest.dividendYield ?? 0,
        );
        AppLogger.debug(
          'StockDetail',
          '$symbol: 使用 DB 估值 (殖利率=${per.dividendYield.toStringAsFixed(2)}%)',
        );
        return per;
      }
    } catch (e) {
      AppLogger.warning('StockDetail', '$symbol: 取得 DB 估值失敗', e);
    }
    return null;
  }

  /// 載入月營收資料
  ///
  /// 優先從資料庫取得（已由 TWSE 同步）。
  /// 若 DB 資料少於 6 個月，改用 FinMind API 取得完整歷史。
  /// API 失敗時 fallback 至 DB 部分資料。
  Future<List<FinMindRevenue>> _loadMonthlyRevenue(
    String symbol, {
    required DateTime today,
    required DateTime revenueStartDate,
  }) async {
    try {
      final dbRevenues = await _db.getMonthlyRevenueHistory(
        symbol,
        startDate: revenueStartDate,
      );

      // 若 DB 有足夠資料（>=6 個月），使用 DB；否則用 FinMind API
      const minMonthsForDbUsage = 6;
      if (dbRevenues.length >= minMonthsForDbUsage) {
        final data = _convertDbRevenuesToFinMind(dbRevenues);
        AppLogger.debug('StockDetail', '$symbol: 使用 DB 營收 (${data.length} 筆)');
        return data;
      }

      // DB 資料不足時用 FinMind API（可取得歷史資料）
      try {
        var revenueData = await _finMind.getMonthlyRevenue(
          stockId: symbol,
          startDate: DateContext.formatYmd(revenueStartDate),
          endDate: DateContext.formatYmd(today),
        );
        if (revenueData.isNotEmpty) {
          revenueData = FinMindRevenue.calculateGrowthRates(revenueData);
        }
        AppLogger.debug(
          'StockDetail',
          '$symbol: 使用 FinMind 營收 (${revenueData.length} 筆，DB 僅 ${dbRevenues.length} 筆)',
        );
        return revenueData;
      } catch (apiError) {
        // API 失敗時，若 DB 有部分資料則使用之
        if (dbRevenues.isNotEmpty) {
          final data = _convertDbRevenuesToFinMind(dbRevenues);
          AppLogger.debug(
            'StockDetail',
            '$symbol: FinMind 失敗，fallback 使用 DB 營收 (${data.length} 筆)',
          );
          return data;
        }
        AppLogger.warning('StockDetail', '取得營收資料失敗: $symbol', apiError);
      }
    } catch (e) {
      AppLogger.warning('StockDetail', '$symbol: 載入營收資料失敗', e);
    }
    return [];
  }

  /// 載入股利歷史
  ///
  /// 優先從 DB 取得，無資料則從 FinMind API 取得並背景寫入 DB。
  Future<List<FinMindDividend>> _loadDividendHistory(String symbol) async {
    try {
      final dbDividends = await _db.getDividendHistory(symbol);
      if (dbDividends.isNotEmpty) {
        AppLogger.debug(
          'StockDetail',
          '$symbol: 使用 DB 股利歷史 (${dbDividends.length} 筆)',
        );
        return dbDividends
            .map(
              (d) => FinMindDividend(
                stockId: d.symbol,
                year: d.year,
                cashDividend: d.cashDividend,
                stockDividend: d.stockDividend,
                exDividendDate: d.exDividendDate,
                exRightsDate: d.exRightsDate,
              ),
            )
            .toList();
      }

      // DB 無資料，從 API 取得並存入 DB
      final apiData = await _finMind.getDividends(stockId: symbol);
      if (apiData.isNotEmpty) {
        // 背景寫入 DB（不阻塞 UI）
        unawaited(
          _db
              .insertDividendData(
                apiData
                    .map(
                      (d) => DividendHistoryCompanion.insert(
                        symbol: symbol,
                        year: d.year,
                        cashDividend: Value(d.cashDividend),
                        stockDividend: Value(d.stockDividend),
                        exDividendDate: Value(d.exDividendDate),
                        exRightsDate: Value(d.exRightsDate),
                      ),
                    )
                    .toList(),
              )
              .catchError((e) {
                AppLogger.warning('StockDetail', '$symbol: 背景寫入股利失敗', e);
              }),
        );
        AppLogger.debug(
          'StockDetail',
          '$symbol: 從 API 取得股利歷史 (${apiData.length} 筆) 並存入 DB',
        );
        return apiData;
      }
    } catch (e) {
      AppLogger.debug('StockDetail', '$symbol: 取得股利歷史失敗');
    }
    return [];
  }

  /// 載入 EPS 歷史與季度財務指標（含 ROE 計算）
  ///
  /// 從 DB 取得 EPS 資料與最新季度指標，
  /// 若有 NetIncome 但缺 ROE，則計算年化 ROE。
  Future<
    ({List<FinancialDataEntry> epsData, Map<String, double> quarterMetrics})
  >
  _loadFinancialStatements(String symbol) async {
    List<FinancialDataEntry> epsData = [];
    Map<String, double> quarterMetrics = {};
    try {
      epsData = await _db.getEPSHistory(symbol);
      if (epsData.isNotEmpty) {
        quarterMetrics = await _db.getLatestQuarterMetrics(symbol);
      }
      // 計算 ROE：從 Equity 歷史 join NetIncome（需同季日期對齊）
      if (quarterMetrics.containsKey('NetIncome') &&
          !quarterMetrics.containsKey('ROE') &&
          epsData.isNotEmpty) {
        final latestIncomeDate = epsData.first.date;
        final equityEntries = await _db.getEquityHistory(symbol);
        // 找到與最新 INCOME 同季的 Equity
        for (final eq in equityEntries) {
          if (eq.date == latestIncomeDate &&
              eq.value != null &&
              eq.value! > 0) {
            // 年化 ROE：季度 NetIncome × 4 / Equity × 100
            quarterMetrics['ROE'] =
                quarterMetrics['NetIncome']! * 4 / eq.value! * 100;
            break;
          }
        }
      }
    } catch (e) {
      AppLogger.debug('StockDetail', '$symbol: 取得 EPS 歷史失敗');
    }
    return (epsData: epsData, quarterMetrics: quarterMetrics);
  }

  /// 從 FinMind API 取得估值資料（PER/PBR/殖利率）
  ///
  /// 僅在 DB 無估值資料時呼叫，作為 fallback。
  Future<FinMindPER?> _loadValuationFromApi(
    String symbol,
    DateTime today,
  ) async {
    try {
      final perApiStart = today.subtract(const Duration(days: 5));
      final perData = await _finMind.getPERData(
        stockId: symbol,
        startDate: DateContext.formatYmd(perApiStart),
        endDate: DateContext.formatYmd(today),
      );

      if (perData.isNotEmpty) {
        perData.sort((a, b) => b.date.compareTo(a.date));
        final per = perData.first;
        AppLogger.debug(
          'StockDetail',
          '$symbol: 使用 FinMind 估值 (殖利率=${per.dividendYield.toStringAsFixed(2)}%)',
        );
        return per;
      }
    } catch (e) {
      AppLogger.warning('StockDetail', '取得估值資料失敗: $symbol', e);
    }
    return null;
  }

  /// 將資料庫營收資料轉換為 FinMindRevenue 格式
  List<FinMindRevenue> _convertDbRevenuesToFinMind(
    List<MonthlyRevenueEntry> dbRevenues,
  ) {
    return dbRevenues.map((r) {
      return FinMindRevenue(
        stockId: r.symbol,
        date: DateContext.formatYmd(r.date),
        revenueYear: r.revenueYear,
        revenueMonth: r.revenueMonth,
        revenue: r.revenue,
        momGrowth: r.momGrowth ?? 0,
        yoyGrowth: r.yoyGrowth ?? 0,
      );
    }).toList();
  }
}
