import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/taiwan_calendar.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/repositories/insider_repository.dart';
import 'package:afterclose/domain/models/analysis_context.dart';
import 'package:afterclose/domain/models/scoring_batch_data.dart';

/// 批次資料轉換工具
///
/// 將 DB entry 轉換為型別安全的 DTO，供 [ScoringBatchData] 使用。
class BatchDataBuilder {
  const BatchDataBuilder._();

  /// 建構外資持股 Map（含變化量計算 + 籌碼集中度）
  ///
  /// [evaluationDate] 用於新鮮度閘門：外資持股超過
  /// [InstitutionalParams.foreignShareholdingMaxStaleTradingDays] 個交易日未更新
  /// 者，ratio 與 change 一律不供給——**陳舊資料主動製造假訊號比沒資料更危險**。
  ///
  /// 閘門設在此處而非各規則內，是為了一處攔截全部消費端（外資增持/減持、
  /// 內部人規則的兩條）；若逐條補，任何新規則都會再度繞過。籌碼集中度來自
  /// 不同資料源，不受此閘門影響。
  static Map<String, ShareholdingData> buildShareholdingMap(
    Map<String, ShareholdingEntry> shareholdingEntries,
    Map<String, ShareholdingEntry> prevShareholdingEntries,
    Map<String, double> concentrationMap, {
    required DateTime evaluationDate,
    Map<String, String> symbolMarkets = const {},
  }) {
    final result = <String, ShareholdingData>{};
    final allSymbols = {...shareholdingEntries.keys, ...concentrationMap.keys};
    final cutoff = TaiwanCalendar.subtractTradingDays(
      evaluationDate,
      InstitutionalParams.foreignShareholdingMaxStaleTradingDays,
    );
    // 分市場統計：閘門會把「靜默的錯訊號」換成「靜默的無訊號」，若不揭露
    // 覆蓋退化，使用者只會覺得「上櫃外資訊號怎麼變少了」而不知原因。
    // 2026-07-25 實測：被擋的 64 檔中 53 檔是上櫃（未被 20/269 配額覆蓋）。
    final fresh = <String, int>{};
    final stale = <String, int>{};
    var staleCount = 0;

    for (final k in allSymbols) {
      final entry = shareholdingEntries[k];
      final isStale = entry != null && entry.date.isBefore(cutoff);
      if (entry != null) {
        final market = symbolMarkets[k] ?? '?';
        final bucket = isStale ? stale : fresh;
        bucket[market] = (bucket[market] ?? 0) + 1;
      }
      if (isStale) staleCount++;

      final currentRatio = isStale ? null : entry?.foreignSharesRatio;
      final prevRatio = isStale
          ? null
          : prevShareholdingEntries[k]?.foreignSharesRatio;

      double? ratioChange;
      if (currentRatio != null && prevRatio != null) {
        ratioChange = currentRatio - prevRatio;
      }

      result[k] = ShareholdingData(
        foreignSharesRatio: currentRatio,
        foreignSharesRatioChange: ratioChange,
        concentrationRatio: concentrationMap[k],
      );
    }

    if (staleCount > 0) {
      final markets = {...fresh.keys, ...stale.keys}.toList()..sort();
      final breakdown = markets
          .map(
            (m) => '$m ${fresh[m] ?? 0}/${(fresh[m] ?? 0) + (stale[m] ?? 0)}',
          )
          .join(', ');
      AppLogger.info(
        'BatchDataBuilder',
        '外資持股新鮮度: $breakdown（新鮮/有資料；'
            '過期 $staleCount 檔早於 ${cutoff.toIso8601String().substring(0, 10)}，'
            '多為未被上櫃配額覆蓋者，其外資訊號本輪不計分）',
      );
    }
    return result;
  }

  /// 建構董監持股狀態（含連續減持/增持判斷）
  static Future<Map<String, InsiderDataContext>> buildInsiderMap(
    Map<String, InsiderHoldingEntry> insiderEntries,
    List<String> candidates,
    InsiderRepository? insiderRepo,
  ) async {
    final insiderStatusMap = insiderRepo != null
        ? await insiderRepo.calculateInsiderStatusBatch(candidates)
        : <String, InsiderStatus>{};

    return insiderEntries.map((k, v) {
      final status = insiderStatusMap[k];
      return MapEntry(
        k,
        InsiderDataContext(
          insiderRatio: v.insiderRatio,
          pledgeRatio: v.pledgeRatio,
          hasSellingStreak: status?.hasSellingStreak ?? false,
          sellingStreakMonths: status?.sellingStreakMonths ?? 0,
          hasSignificantBuying: status?.hasSignificantBuying ?? false,
          buyingChange: status?.buyingChange ?? v.sharesChange,
        ),
      );
    });
  }
}
