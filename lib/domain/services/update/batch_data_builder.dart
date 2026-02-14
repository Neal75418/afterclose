import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/repositories/insider_repository.dart';

/// 批次資料轉換工具
///
/// 將 DB entry 轉換為 Isolate 可用的 Map 格式，
/// 供 [ScoringBatchData] 使用。
class BatchDataBuilder {
  const BatchDataBuilder._();

  /// 建構外資持股 Map（含變化量計算 + 籌碼集中度）
  static Map<String, Map<String, double?>> buildShareholdingMap(
    Map<String, ShareholdingEntry> shareholdingEntries,
    Map<String, ShareholdingEntry> prevShareholdingEntries,
    Map<String, double> concentrationMap,
  ) {
    final result = <String, Map<String, double?>>{};
    final allSymbols = {...shareholdingEntries.keys, ...concentrationMap.keys};
    for (final k in allSymbols) {
      final entry = shareholdingEntries[k];
      final currentRatio = entry?.foreignSharesRatio;
      final prevEntry = prevShareholdingEntries[k];
      final prevRatio = prevEntry?.foreignSharesRatio;

      double? ratioChange;
      if (currentRatio != null && prevRatio != null) {
        ratioChange = currentRatio - prevRatio;
      }

      result[k] = {
        'foreignSharesRatio': currentRatio,
        'foreignSharesRatioChange': ratioChange,
        'concentrationRatio': concentrationMap[k],
      };
    }
    return result;
  }

  /// 建構董監持股狀態 Map（含連續減持/增持判斷）
  static Future<Map<String, Map<String, dynamic>>> buildInsiderMap(
    Map<String, InsiderHoldingEntry> insiderEntries,
    List<String> candidates,
    InsiderRepository? insiderRepo,
  ) async {
    final insiderStatusMap = insiderRepo != null
        ? await insiderRepo.calculateInsiderStatusBatch(candidates)
        : <String, InsiderStatus>{};

    return insiderEntries.map((k, v) {
      final status = insiderStatusMap[k];
      return MapEntry(k, {
        'insiderRatio': v.insiderRatio,
        'pledgeRatio': v.pledgeRatio,
        'hasSellingStreak': status?.hasSellingStreak ?? false,
        'sellingStreakMonths': status?.sellingStreakMonths ?? 0,
        'hasSignificantBuying': status?.hasSignificantBuying ?? false,
        'buyingChange': status?.buyingChange ?? v.sharesChange,
      });
    });
  }
}
