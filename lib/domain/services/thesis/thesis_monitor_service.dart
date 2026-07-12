import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/thesis/thesis_invalidation_rules.dart';

/// 釘選論點監控服務（出場層 Phase 2）
///
/// 每日更新完成後由 `UpdateService` fail-safe 呼叫（比照
/// `RuleAccuracyService`：錯誤不中斷更新流程）。對每筆 ACTIVE 釘選
/// **從 pinnedDate 全量重算**失效條件（冪等、無增量狀態——App 跳幾天
/// 不更新也不會錯，spec §5）；已 INVALIDATED 者不在掃描範圍（凍結）。
class ThesisMonitorService {
  const ThesisMonitorService({required AppDatabase database}) : _db = database;

  final AppDatabase _db;

  /// 檢查所有 ACTIVE 釘選。回傳本次失效筆數。
  ///
  /// [asOf]：本次檢查時間（寫入 lastCheckedDate；staleness 顯示用）。
  Future<int> checkActiveTheses({required DateTime asOf}) async {
    final active = await _db.getActiveTheses();
    if (active.isEmpty) return 0;

    // 先蓋「本次已檢查」章（含即將失效者——它們確實在本輪被檢查過；
    // 失效後離開 ACTIVE 掃描範圍，lastCheckedDate 凍結在失效當輪）。
    await _db.touchLastChecked(asOf);

    var invalidated = 0;
    for (final thesis in active) {
      final prices = await _db.getPriceHistory(
        thesis.symbol,
        startDate: thesis.pinnedDate,
        endDate: asOf,
      );
      if (prices.isEmpty) continue;
      prices.sort((a, b) => a.date.compareTo(b.date));

      final result = ThesisInvalidationRules.evaluate(
        referencePrice: thesis.referencePrice,
        closesFromPinnedDate: [for (final p in prices) p.close],
      );
      if (result == null) continue;

      await _db.invalidateThesis(
        thesis.id,
        invalidatedDate: prices[result.triggerOffset].date,
        reason: result.reason.name,
      );
      invalidated++;
      AppLogger.info(
        'ThesisMonitor',
        '${thesis.symbol} 論點失效（${result.reason.name}，'
            '釘選 ${thesis.pinnedDate} → 觸發 ${prices[result.triggerOffset].date}）',
      );
    }

    if (invalidated > 0) {
      AppLogger.info('ThesisMonitor', '本次失效 $invalidated / ${active.length} 筆');
    }
    return invalidated;
  }
}
