import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/taiwan_calendar.dart';
import 'package:afterclose/data/repositories/institutional_repository.dart';

/// 法人買賣超資料同步器
///
/// 負責同步外資、投信、自營商買賣超資料
class InstitutionalSyncer {
  const InstitutionalSyncer({
    required InstitutionalRepository institutionalRepository,
  }) : _institutionalRepo = institutionalRepository;

  final InstitutionalRepository _institutionalRepo;

  /// 同步法人資料
  ///
  /// 包含當日資料及近期回補
  /// [backfillDays] 指定回補天數，預設 15 天（覆蓋分析所需的 10 天回溯）
  Future<InstitutionalSyncResult> syncInstitutionalData({
    required DateTime date,
    bool force = false,
    int backfillDays = 15,
  }) async {
    var syncedDays = 0;
    final errors = <String>[];

    // force 模式下先清除所有舊資料，避免新舊資料單位混用
    if (force) {
      try {
        final cleared = await _institutionalRepo.clearAllData();
        AppLogger.info('InstitutionalSyncer', '已清除 $cleared 筆舊法人資料');
      } catch (e) {
        AppLogger.warning('InstitutionalSyncer', '清除舊法人資料失敗: $e');
      }
    }

    // 1. 同步當日資料
    try {
      await _institutionalRepo.syncAllMarketInstitutional(date, force: force);
      syncedDays++;
    } catch (e) {
      errors.add('當日法人資料同步失敗: $e');
      AppLogger.warning('InstitutionalSyncer', '當日法人資料同步失敗: $e');
    }

    // 2. 回補近期資料（force 模式下也強制重新下載）
    for (var i = 1; i < backfillDays; i++) {
      final backDate = date.subtract(Duration(days: i));

      if (TaiwanCalendar.isTradingDay(backDate)) {
        await Future.delayed(const Duration(milliseconds: 1000));

        try {
          await _institutionalRepo.syncAllMarketInstitutional(
            backDate,
            force: force,
          );
          syncedDays++;
        } catch (e) {
          final dateStr = '${backDate.month}/${backDate.day}';
          errors.add('法人資料回補失敗 ($dateStr): $e');
          AppLogger.warning('InstitutionalSyncer', '法人資料回補失敗 ($dateStr): $e');
        }
      }
    }

    AppLogger.info('InstitutionalSyncer', '法人資料同步 $syncedDays 天');

    return InstitutionalSyncResult(syncedDays: syncedDays, errors: errors);
  }

  /// 同步單日法人資料
  Future<bool> syncSingleDay({
    required DateTime date,
    bool force = false,
  }) async {
    try {
      await _institutionalRepo.syncAllMarketInstitutional(date, force: force);
      return true;
    } catch (e) {
      AppLogger.warning('InstitutionalSyncer', '法人資料同步失敗: $e');
      return false;
    }
  }
}

/// 法人資料同步結果
class InstitutionalSyncResult {
  const InstitutionalSyncResult({
    required this.syncedDays,
    this.errors = const [],
  });

  final int syncedDays;
  final List<String> errors;

  /// 估計同步的資料筆數（每天約 1000 檔股票）
  int get estimatedCount => syncedDays * 1000;

  bool get hasErrors => errors.isNotEmpty;
}
