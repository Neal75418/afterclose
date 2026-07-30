import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';

/// 流動性檢查工具 - 統一候選股票的流動性過濾邏輯
abstract final class LiquidityChecker {
  /// 檢查股票是否滿足候選流動性要求
  ///
  /// 回傳 null 表示通過檢查，回傳 String 表示失敗原因
  static String? checkCandidateLiquidity(DailyPriceEntry latest) {
    if (latest.close == null || latest.volume == null) {
      return 'MISSING_DATA';
    }
    if (latest.volume! < RuleParams.minCandidateVolumeShares) {
      return 'LOW_VOLUME';
    }
    final turnover = latest.close! * latest.volume!;
    if (turnover < RuleParams.minCandidateTurnover) {
      return 'LOW_TURNOVER';
    }
    return null;
  }
}
