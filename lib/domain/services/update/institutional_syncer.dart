import 'package:afterclose/core/constants/api_config.dart';
import 'package:afterclose/core/constants/data_freshness.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
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
  /// [backfillDays] 指定回補天數，預設 [ApiConfig.institutionalDailyBackfillDays]
  /// （日常更新 15 天）；強制同步由 caller 傳深一點的
  /// [ApiConfig.institutionalForceBackfillDays] 以補足下游信號所需的歷史深度。
  ///
  /// **非破壞式**：force 只對「當日」繞快取；歷史回補日一律走 per-day
  /// 完整性檢查——已完整的天直接跳過，中斷（rate limit / 斷網）後重跑
  /// 只補缺的天。全清僅由口徑版本檢核（[InstitutionalRepository
  /// .ensureDataVersion]）在版本變更時觸發一次；原本 force 每次
  /// clearAllData 再重抓 62 天，中斷會留下日常 15 天回補補不回的深度殘缺。
  /// [onProgress] 逐回補交易日回報（如「法人回補 3/62 天」）——force 深回補
  /// 全缺時約 2-3 分鐘，無回報 UI 會像當機。
  Future<InstitutionalSyncResult> syncInstitutionalData({
    required DateTime date,
    bool force = false,
    int backfillDays = ApiConfig.institutionalDailyBackfillDays,
    void Function(String message)? onProgress,
  }) async {
    var syncedDays = 0;
    final errors = <String>[];

    // 口徑版本檢核（每次入口，日常更新也會遷移）；失敗不中斷同步，
    // 下次入口重試
    try {
      await _institutionalRepo.ensureDataVersion();
    } catch (e) {
      AppLogger.warning('InstitutionalSyncer', '法人口徑版本檢核失敗', e);
    }

    // 1. 同步當日資料
    try {
      await _institutionalRepo.syncAllMarketInstitutional(date, force: force);
      syncedDays++;
    } on RateLimitException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      errors.add('當日法人資料同步失敗: $e');
      AppLogger.warning('InstitutionalSyncer', '當日法人資料同步失敗', e);
    }

    // 2. 回補近期資料（force:false——已完整的天跳過，形成斷點續傳）
    final backfillDates = [
      for (var i = 1; i < backfillDays; i++) date.subtract(Duration(days: i)),
    ].where(TaiwanCalendar.isTradingDay).toList();

    for (var i = 0; i < backfillDates.length; i++) {
      final backDate = backfillDates[i];
      await Future.delayed(
        const Duration(milliseconds: ApiConfig.retryDelayMs),
      );

      try {
        await _institutionalRepo.syncAllMarketInstitutional(
          backDate,
          force: false,
        );
        syncedDays++;
      } on RateLimitException {
        rethrow;
      } on NetworkException {
        rethrow;
      } catch (e) {
        final dateStr = '${backDate.month}/${backDate.day}';
        errors.add('法人資料回補失敗 ($dateStr): $e');
        AppLogger.warning('InstitutionalSyncer', '法人資料回補失敗 ($dateStr)', e);
      }

      onProgress?.call('法人回補 ${i + 1}/${backfillDates.length} 天');
    }

    AppLogger.info('InstitutionalSyncer', '法人資料同步完成: $syncedDays 天');

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
    } on RateLimitException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      AppLogger.warning('InstitutionalSyncer', '法人資料同步失敗', e);
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

  /// 估計同步的資料筆數（每天約 [DataFreshness.estimatedDailyInstitutionalRecords] 檔）
  ///
  /// ⚠️ 高估上限：syncedDays 含「已完整而被 per-day 檢查跳過」的天（repo
  /// 回傳值無法區分 skip/fetch），force 深回補時多數天已完整，此值會遠大
  /// 於實際新寫入。僅供 UI 摘要參考，精確化需改 repo 回傳語意。
  int get estimatedCount =>
      syncedDays * DataFreshness.estimatedDailyInstitutionalRecords;

  bool get hasErrors => errors.isNotEmpty;
}
