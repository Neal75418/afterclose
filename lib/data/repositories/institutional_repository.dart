import 'package:drift/drift.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/safe_execution.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/data/remote/tpex_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';

/// 三大法人買賣超資料 Repository
class InstitutionalRepository {
  InstitutionalRepository({
    required AppDatabase database,
    required FinMindClient finMindClient,
    TwseClient? twseClient,
    TpexClient? tpexClient,
  }) : _db = database,
       _client = finMindClient,
       _twseClient = twseClient ?? TwseClient(),
       _tpexClient = tpexClient ?? TpexClient();

  final AppDatabase _db;
  final FinMindClient _client;
  final TwseClient _twseClient;
  final TpexClient _tpexClient;

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
        startDate: DateContext.formatYmd(startDate),
        endDate: endDate != null ? DateContext.formatYmd(endDate) : null,
      );

      final entries = data.map((item) {
        // 正規化日期，確保時間部分為 00:00:00（避免同日重複）
        final parsed = DateTime.parse(item.date);
        final normalizedDate = DateTime(parsed.year, parsed.month, parsed.day);
        return DailyInstitutionalCompanion.insert(
          symbol: item.stockId,
          date: normalizedDate,
          foreignNet: Value(item.foreignNet),
          investmentTrustNet: Value(item.investmentTrustNet),
          dealerNet: Value(item.dealerNet),
        );
      }).toList();

      await _db.insertInstitutionalData(entries);

      return entries.length;
    } on RateLimitException {
      AppLogger.warning('InstitutionalRepo', '$symbol: 法人資料同步觸發 API 速率限制');
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
  /// 使用 TWSE T86 API + TPEX API（免費、全市場）。
  /// 可分析非自選股的法人動向。
  Future<int> syncAllMarketInstitutional(
    DateTime date, {
    bool force = false,
  }) async {
    try {
      // 提高閾值至 1500 以涵蓋上市+上櫃股票
      if (!force) {
        final existingCount = await _db.getInstitutionalCountForDate(date);
        if (existingCount > 1500) return existingCount;
      }

      // 並行取得上市與上櫃法人資料（錯誤隔離，允許部分成功）
      final twseFuture = _twseClient.getAllInstitutionalData(date: date);
      final tpexFuture = _tpexClient.getAllInstitutionalData(date: date);

      final twseData = await safeAwait(
        twseFuture,
        <TwseInstitutional>[],
        tag: 'InstRepo',
        description: '上市法人資料取得失敗，繼續處理上櫃',
      );
      final tpexData = await safeAwait(
        tpexFuture,
        <TpexInstitutional>[],
        tag: 'InstRepo',
        description: '上櫃法人資料取得失敗，繼續處理上市',
      );

      if (twseData.isEmpty && tpexData.isEmpty) return 0;

      // 取得有效股票代碼以避免 Foreign Key 錯誤
      final stockList = await _db.getAllActiveStocks();
      final validSymbols = stockList.map((s) => s.symbol).toSet();

      // 過濾上市法人資料
      final validTwseData = twseData
          .where(
            (item) =>
                validSymbols.contains(item.code) &&
                (item.totalNet != 0 ||
                    item.foreignNet != 0 ||
                    item.investmentTrustNet != 0),
          )
          .toList();

      // 過濾上櫃法人資料
      final validTpexData = tpexData
          .where(
            (item) =>
                validSymbols.contains(item.code) &&
                (item.totalNet != 0 ||
                    item.foreignNet != 0 ||
                    item.investmentTrustNet != 0),
          )
          .toList();

      // 建立上市法人資料 entries
      // 注意：TWSE API 回傳的是股數，直接儲存股數以符合規則參數單位
      final twseEntries = validTwseData.map((item) {
        final normalizedDate = DateTime(
          item.date.year,
          item.date.month,
          item.date.day,
        );
        return DailyInstitutionalCompanion.insert(
          symbol: item.code,
          date: normalizedDate,
          // TWSE API 回傳股數，直接儲存（規則參數單位為股）
          foreignNet: Value(item.foreignNet.toDouble()),
          investmentTrustNet: Value(item.investmentTrustNet.toDouble()),
          dealerNet: Value(item.dealerNet.toDouble()),
        );
      }).toList();

      // 建立上櫃法人資料 entries
      // 注意：TPEX API 回傳的是股數，直接儲存股數以符合規則參數單位
      final tpexEntries = validTpexData.map((item) {
        final normalizedDate = DateTime(
          item.date.year,
          item.date.month,
          item.date.day,
        );
        return DailyInstitutionalCompanion.insert(
          symbol: item.code,
          date: normalizedDate,
          // TPEX API 回傳股數，直接儲存（規則參數單位為股）
          foreignNet: Value(item.foreignNet.toDouble()),
          investmentTrustNet: Value(item.investmentTrustNet.toDouble()),
          dealerNet: Value(item.dealerNet.toDouble()),
        );
      }).toList();

      // 合併並寫入
      final allEntries = [...twseEntries, ...tpexEntries];
      await _db.insertInstitutionalData(allEntries);

      AppLogger.info(
        'InstRepo',
        '法人同步: ${allEntries.length} 筆 (上市 ${twseEntries.length}, 上櫃 ${tpexEntries.length})',
      );

      return allEntries.length;
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

  /// 清除所有法人資料
  ///
  /// 用於單位修正後強制重新同步，避免新舊資料單位混用
  Future<int> clearAllData() => _db.clearAllInstitutionalData();
}
