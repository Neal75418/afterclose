import 'package:drift/drift.dart';
import 'package:intl/intl.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';

/// 三大法人買賣超資料 Repository
class InstitutionalRepository {
  InstitutionalRepository({
    required AppDatabase database,
    required FinMindClient finMindClient,
    TwseClient? twseClient,
  }) : _db = database,
       _client = finMindClient,
       _twseClient = twseClient ?? TwseClient();

  final AppDatabase _db;
  final FinMindClient _client;
  final TwseClient _twseClient;

  static final _dateFormat = DateFormat('yyyy-MM-dd');

  /// 取得法人資料歷史供分析使用
  ///
  /// 若可用，回傳 [RuleParams.lookbackPrice] 天的資料
  Future<List<DailyInstitutionalEntry>> getInstitutionalHistory(
    String symbol, {
    int? days,
  }) async {
    final lookback = days ?? RuleParams.lookbackPrice;
    final startDate = DateTime.now().subtract(Duration(days: lookback + 30));

    return _db.getInstitutionalHistory(symbol, startDate: startDate);
  }

  /// 取得股票最新法人資料
  Future<DailyInstitutionalEntry?> getLatestInstitutional(String symbol) {
    return _db.getLatestInstitutional(symbol);
  }

  /// 同步單檔股票的法人資料
  Future<int> syncInstitutionalData(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      final data = await _client.getInstitutionalData(
        stockId: symbol,
        startDate: _dateFormat.format(startDate),
        endDate: endDate != null ? _dateFormat.format(endDate) : null,
      );

      final entries = data.map((item) {
        return DailyInstitutionalCompanion.insert(
          symbol: item.stockId,
          date: DateTime.parse(item.date),
          foreignNet: Value(item.foreignNet),
          investmentTrustNet: Value(item.investmentTrustNet),
          dealerNet: Value(item.dealerNet),
        );
      }).toList();

      await _db.insertInstitutionalData(entries);

      return entries.length;
    } on RateLimitException {
      rethrow;
    } catch (e) {
      throw DatabaseException(
        'Failed to sync institutional data for $symbol',
        e,
      );
    }
  }

  /// 同步指定日期的全市場法人資料
  ///
  /// 使用 TWSE T86 API（免費、全市場）。
  /// 可分析非自選股的法人動向。
  Future<int> syncAllMarketInstitutional(
    DateTime date, {
    bool force = false,
  }) async {
    try {
      if (!force) {
        final existingCount = await _db.getInstitutionalCountForDate(date);
        if (existingCount > 1000) return existingCount;
      }
      // TWSE API（T86）回傳指定日期的資料
      // 註：T86 API 支援 date 參數（YYYYMMDD）
      // TwseClient.getAllInstitutionalData() 預設抓取「最新交易日」
      // 若需抓取歷史資料需修改 TwseClient 支援 date 參數

      // 假設目前僅同步 LATEST/目標日期
      // 若傳入日期非今日，需注意資料可能不正確
      // 但通常我們執行的是「今日更新」

      final data = await _twseClient.getAllInstitutionalData(date: date);

      if (data.isEmpty) return 0;

      // 取得有效股票代碼以避免 Foreign Key 錯誤
      final stockList = await _db.getAllActiveStocks();
      final validSymbols = stockList.map((s) => s.symbol).toSet();

      // 過濾無效或零成交量資料以節省 Database 空間
      final validData = data
          .where(
            (item) =>
                validSymbols.contains(item.code) &&
                (item.totalNet != 0 ||
                    item.foreignNet != 0 ||
                    item.investmentTrustNet != 0),
          )
          .toList();

      final entries = validData.map((item) {
        return DailyInstitutionalCompanion.insert(
          symbol: item.code,
          date: item.date,
          foreignNet: Value(item.foreignNet),
          investmentTrustNet: Value(item.investmentTrustNet),
          dealerNet: Value(item.dealerNet),
        );
      }).toList();

      await _db.insertInstitutionalData(entries);

      return entries.length;
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync all institutional data', e);
    }
  }

  /// 檢查法人買賣方向是否反轉
  ///
  /// 若近期淨買賣方向與前期相反則回傳 true
  Future<bool> hasDirectionReversal(String symbol, {int days = 5}) async {
    final history = await getInstitutionalHistory(symbol, days: days + 5);
    if (history.length < days) return false;

    final recent = history.reversed.take(days).toList();
    if (recent.length < 2) return false;

    // 計算近期淨買賣總額
    double recentNet = 0;
    for (final entry in recent) {
      recentNet +=
          (entry.foreignNet ?? 0) +
          (entry.investmentTrustNet ?? 0) +
          (entry.dealerNet ?? 0);
    }

    // 取得前期資料
    final previous = history.reversed.skip(days).take(days).toList();
    if (previous.isEmpty) return false;

    double previousNet = 0;
    for (final entry in previous) {
      previousNet +=
          (entry.foreignNet ?? 0) +
          (entry.investmentTrustNet ?? 0) +
          (entry.dealerNet ?? 0);
    }

    // 檢查方向反轉（正負號改變）
    return (recentNet > 0 && previousNet < 0) ||
        (recentNet < 0 && previousNet > 0);
  }

  /// 取得近期法人淨買賣總額
  Future<double?> getTotalNetBuying(String symbol, {int days = 5}) async {
    final history = await getInstitutionalHistory(symbol, days: days + 5);
    if (history.isEmpty) return null;

    final recent = history.reversed.take(days).toList();
    if (recent.isEmpty) return null;

    double totalNet = 0;
    for (final entry in recent) {
      totalNet +=
          (entry.foreignNet ?? 0) +
          (entry.investmentTrustNet ?? 0) +
          (entry.dealerNet ?? 0);
    }

    return totalNet;
  }
}
