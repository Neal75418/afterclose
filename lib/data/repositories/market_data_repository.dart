import 'package:drift/drift.dart';

import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/domain/repositories/market_data_repository.dart';

/// 市場資料 Repository
///
/// 處理：財報同步
class MarketDataRepository implements IMarketDataRepository {
  MarketDataRepository({
    required AppDatabase database,
    required FinMindClient finMindClient,
    AppClock clock = const SystemClock(),
  }) : _db = database,
       _client = finMindClient,
       _clock = clock;

  final AppDatabase _db;
  final FinMindClient _client;
  final AppClock _clock;

  // ==================================================
  // 日期輔助方法
  // ==================================================

  /// 根據當前日期取得預期最新季度日期
  ///
  /// 財報通常在季度結束後約 45 天公布：
  /// - Q1（1-3月）→ 約 5 月中公布
  /// - Q2（4-6月）→ 約 8 月中公布
  /// - Q3（7-9月）→ 約 11 月中公布
  /// - Q4（10-12月）→ 約隔年 3 月中公布
  DateTime _getExpectedLatestQuarter() {
    final now = _clock.now();
    final month = now.month;

    if (month >= 3 && month < 5) {
      return DateTime(now.year - 1, 10, 1);
    } else if (month >= 5 && month < 8) {
      return DateTime(now.year, 1, 1);
    } else if (month >= 8 && month < 11) {
      return DateTime(now.year, 4, 1);
    } else if (month >= 11) {
      return DateTime(now.year, 7, 1);
    } else {
      // 1-2 月：Q3（10-12月）已於前年 11 月公布
      return DateTime(now.year - 1, 10, 1);
    }
  }

  // ==================================================
  // 財報資料
  // ==================================================

  /// 同步資產負債表資料
  @override
  Future<int> syncBalanceSheet(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
  }) => _syncFinancialStatement(
    symbol,
    startDate: startDate,
    endDate: endDate,
    statementType: 'BALANCE',
    fetchFn: (id, start, end) =>
        _client.getBalanceSheet(stockId: id, startDate: start, endDate: end),
    extractFields: (item) => (
      stockId: item.stockId,
      date: item.date,
      type: item.type,
      value: item.value,
      origin: item.origin,
    ),
    logLabel: '資產負債表',
  );

  /// 財報同步共用邏輯
  ///
  /// 包含新鮮度檢查以避免不必要的 API 呼叫。
  /// 季度資料：若已有最新可用季度則跳過。
  Future<int> _syncFinancialStatement<T>(
    String symbol, {
    required DateTime startDate,
    DateTime? endDate,
    required String statementType,
    required Future<List<T>> Function(String stockId, String start, String? end)
    fetchFn,
    required ({
      String stockId,
      String date,
      String type,
      double value,
      String origin,
    })
    Function(T)
    extractFields,
    required String logLabel,
  }) async {
    try {
      final latestDate = await _db.getLatestFinancialDataDate(
        symbol,
        statementType,
      );
      final expectedQuarter = _getExpectedLatestQuarter();
      if (latestDate != null && !latestDate.isBefore(expectedQuarter)) {
        return 0;
      }

      final data = await fetchFn(
        symbol,
        DateContext.formatYmd(startDate),
        endDate != null ? DateContext.formatYmd(endDate) : null,
      );

      final entries = data.map((item) {
        final f = extractFields(item);
        return FinancialDataCompanion.insert(
          symbol: f.stockId,
          date: DateContext.parseQuarterDate(f.date),
          statementType: statementType,
          dataType: f.type,
          value: Value(f.value),
          originName: Value(f.origin),
        );
      }).toList();

      await _db.insertFinancialData(entries);
      return entries.length;
    } on RateLimitException {
      AppLogger.warning('MarketDataRepo', '$symbol: $logLabel同步觸發 API 速率限制');
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync $statementType for $symbol', e);
    }
  }

  // ==================================================
  // 市場 / 同步狀態查詢
  // ==================================================

  @override
  Future<DateTime?> getLatestDataDate() => _db.getLatestDataDate();

  @override
  Future<DateTime?> getLatestInstitutionalDate() =>
      _db.getLatestInstitutionalDate();

  @override
  Future<UpdateRunEntry?> getLatestUpdateRun() => _db.getLatestUpdateRun();

  @override
  Future<List<UpdateRunEntry>> getRecentUpdateRuns({int limit = 30}) =>
      _db.getRecentUpdateRuns(limit: limit);
}
