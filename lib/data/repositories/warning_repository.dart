import 'package:drift/drift.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/tpex_client.dart';
// TWSE 警示 API 已無法使用 (404)，暫時停用
// import 'package:afterclose/data/remote/twse_client.dart';

/// 注意股票/處置股票資料 Repository
///
/// 提供警示資料的存取與同步功能，用於風險控管。
/// 注意：目前僅支援上櫃 (TPEX) 警示資料，上市 (TWSE) API 已無法使用。
class WarningRepository {
  WarningRepository({required AppDatabase database, TpexClient? tpexClient})
    : _db = database,
      _tpexClient = tpexClient ?? TpexClient();

  final AppDatabase _db;
  final TpexClient _tpexClient;

  /// 取得股票的警示歷史
  Future<List<TradingWarningEntry>> getWarningHistory(
    String symbol, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _db.getWarningHistory(
      symbol,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// 取得股票目前生效的警示
  Future<List<TradingWarningEntry>> getActiveWarnings(String symbol) {
    return _db.getActiveWarnings(symbol);
  }

  /// 取得所有目前生效的警示（全市場）
  Future<List<TradingWarningEntry>> getAllActiveWarnings() {
    return _db.getAllActiveWarnings();
  }

  /// 取得所有目前生效的注意股票
  Future<List<TradingWarningEntry>> getActiveAttentionStocks() {
    return _db.getActiveWarningsByType('ATTENTION');
  }

  /// 取得所有目前生效的處置股票
  Future<List<TradingWarningEntry>> getActiveDisposalStocks() {
    return _db.getActiveWarningsByType('DISPOSAL');
  }

  /// 檢查股票是否有目前生效的警示
  Future<bool> hasActiveWarning(String symbol) {
    return _db.hasActiveWarning(symbol);
  }

  /// 檢查股票是否為處置股
  Future<bool> isDisposalStock(String symbol) {
    return _db.isDisposalStock(symbol);
  }

  /// 批次檢查多檔股票是否為處置股
  Future<Set<String>> getDisposalStocksBatch(List<String> symbols) {
    return _db.getDisposalStocksBatch(symbols);
  }

  /// 同步全市場警示資料
  ///
  /// 從 TPEX 取得最新的上櫃注意股票和處置股票資料。
  /// 使用免費 OpenAPI，無需 token。
  ///
  /// 注意：TWSE 上市警示 API 目前無法使用 (404)，已暫時停用。
  ///
  /// [force] - 若為 true，則無視新鮮度檢查強制同步
  Future<int> syncAllMarketWarnings({bool force = false}) async {
    try {
      final today = DateTime.now();
      final normalizedDate = DateTime(today.year, today.month, today.day);

      // 新鮮度檢查：檢查今日是否已有資料且最近 6 小時內同步過
      if (!force) {
        final lastSync = await _db.getLatestWarningSyncTime();
        if (lastSync != null) {
          final hoursSinceLastSync = today.difference(lastSync).inHours;
          if (hoursSinceLastSync < 6) {
            final existingCount = await _db.getWarningCountForDate(
              normalizedDate,
            );
            if (existingCount > 0) {
              AppLogger.info(
                'WarningRepo',
                '警示資料已是最新 ($existingCount 筆，${hoursSinceLastSync}h 前同步)',
              );
              return existingCount;
            }
          }
        }
      }

      // 取得上櫃警示資料 (TPEX OpenAPI)
      // 注意：TWSE 警示 API 已無法使用 (404)，暫時停用
      // TODO: 待找到可用的 TWSE 警示資料來源後再啟用
      final tpexWarningFuture = _tpexClient.getTradingWarnings();
      final tpexDisposalFuture = _tpexClient.getDisposalInfo();

      List<TpexTradingWarning> tpexWarnings = [];
      List<TpexTradingWarning> tpexDisposals = [];

      // 錯誤隔離，允許部分成功
      try {
        tpexWarnings = await tpexWarningFuture;
      } catch (e) {
        AppLogger.warning('WarningRepo', '上櫃注意股票取得失敗: $e');
      }

      try {
        tpexDisposals = await tpexDisposalFuture;
      } catch (e) {
        AppLogger.warning('WarningRepo', '上櫃處置股票取得失敗: $e');
      }

      // 使用 transaction 確保原子性，避免 FK 驗證與插入之間的 race condition
      return await _db.transaction(() async {
        // 取得有效股票代碼以避免 Foreign Key 錯誤
        final stockList = await _db.getAllActiveStocks();
        final validSymbols = stockList.map((s) => s.symbol).toSet();

        final entries = <TradingWarningCompanion>[];

        // 轉換 TPEX 注意股票 (上櫃)
        for (final item in tpexWarnings) {
          if (!validSymbols.contains(item.code)) continue;
          entries.add(
            _createWarningEntry(
              symbol: item.code,
              date: normalizedDate,
              referenceNow: today,
              warningType: 'ATTENTION',
              reasonCode: item.reasonCode,
              reasonDescription: item.reasonDescription,
            ),
          );
        }

        // 轉換 TPEX 處置股票
        for (final item in tpexDisposals) {
          if (!validSymbols.contains(item.code)) continue;
          entries.add(
            _createWarningEntry(
              symbol: item.code,
              date: normalizedDate,
              referenceNow: today,
              warningType: 'DISPOSAL',
              reasonCode: item.reasonCode,
              reasonDescription: item.reasonDescription,
              disposalMeasures: item.disposalMeasures,
              disposalStartDate: item.disposalStartDate,
              disposalEndDate: item.disposalEndDate,
            ),
          );
        }

        if (entries.isEmpty) {
          AppLogger.info('WarningRepo', '無新警示資料');
          return 0;
        }

        // 寫入資料庫
        await _db.insertWarningData(entries);

        // 更新過期的警示狀態
        await _db.updateExpiredWarnings();

        AppLogger.info(
          'WarningRepo',
          '警示同步: ${entries.length} 筆 '
              '(上櫃注意 ${tpexWarnings.length}, 上櫃處置 ${tpexDisposals.length})',
        );

        return entries.length;
      });
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to sync warning data', e);
    }
  }

  /// 建立警示資料 Companion
  ///
  /// [referenceNow] - 參考時間，用於判斷處置股是否仍生效，
  ///                  避免跨午夜同步時產生不一致的結果。
  TradingWarningCompanion _createWarningEntry({
    required String symbol,
    required DateTime date,
    required DateTime referenceNow,
    required String warningType,
    String? reasonCode,
    String? reasonDescription,
    String? disposalMeasures,
    DateTime? disposalStartDate,
    DateTime? disposalEndDate,
  }) {
    // 判斷是否生效（處置股檢查結束日期）
    bool isActive = true;
    if (warningType == 'DISPOSAL' && disposalEndDate != null) {
      isActive = referenceNow.isBefore(
        disposalEndDate.add(
          const Duration(days: RuleParams.disposalEndDateGraceDays),
        ),
      );
    }

    return TradingWarningCompanion.insert(
      symbol: symbol,
      date: date,
      warningType: warningType,
      reasonCode: Value(reasonCode),
      reasonDescription: Value(reasonDescription),
      disposalMeasures: Value(disposalMeasures),
      disposalStartDate: Value(disposalStartDate),
      disposalEndDate: Value(disposalEndDate),
      isActive: Value(isActive),
    );
  }

  /// 取得自選股中的警示股票
  ///
  /// 用於在自選股頁面顯示警示標記。
  Future<Map<String, TradingWarningEntry>> getWatchlistWarnings(
    List<String> watchlistSymbols,
  ) async {
    if (watchlistSymbols.isEmpty) return {};

    final warnings = await getAllActiveWarnings();
    final watchlistSet = watchlistSymbols.toSet();

    final result = <String, TradingWarningEntry>{};
    for (final warning in warnings) {
      if (watchlistSet.contains(warning.symbol)) {
        // 若已存在，處置股優先級高於注意股
        if (!result.containsKey(warning.symbol) ||
            warning.warningType == 'DISPOSAL') {
          result[warning.symbol] = warning;
        }
      }
    }

    return result;
  }
}
