import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:afterclose/core/constants/calibrated_scores/calibrated_scores_table.dart';
import 'package:afterclose/core/constants/calibrated_scores/horizon.dart';
import 'package:afterclose/core/utils/logger.dart';

/// 主 isolate 的 calibrated scores 單例登錄表
///
/// 負責在 app 啟動時從 assets 載入 `rule_scores_calibrated_{short,long}.json`，
/// 並提供 horizon-aware 的同步查詢 API。
///
/// ## 使用限制
///
/// **僅供主 isolate 使用**。Scoring 運算跑在 `Isolate.run()` 產生的新 isolate，
/// 那邊記憶體與主 isolate 完全隔離，此 singleton 在 scoring isolate 內
/// 是未初始化狀態。Stage 5b 才會處理 isolate 傳遞。
///
/// 目前 Stage 5a 的消費者僅為主 isolate 的 UI / debug / rule accuracy 頁面，
/// 透過 `ReasonType.scoreFor(Horizon)` extension（Commit 2 新增）間接讀取。
///
/// ## 生命週期
///
/// - `loadFromAssets` 在 `main()` 中被 await 呼叫，**idempotent**，重複
///   呼叫只執行一次 load，支援 hot reload
/// - 測試可透過 `resetForTesting` 清除狀態，或 `bindForTesting` 直接注入
///   fake table 跳過 asset bundle
///
/// ## Fallback 語意
///
/// - Registry 未載入時，`lookup` 永遠回 null
/// - Asset 缺失或 JSON malformed 時，`_loadOne` 會 log error 並
///   綁定 `CalibratedScoresTable.empty()`，使後續 `lookup` 仍回 null
/// - 呼叫端（`ReasonType.scoreFor`）遇到 null 會 fallback 到 hardcoded
///   `RuleScores`，因此任何失敗路徑都不會讓 app 崩潰或顯示錯誤分數
class CalibratedScoresRegistry {
  CalibratedScoresRegistry._();

  static final CalibratedScoresRegistry instance = CalibratedScoresRegistry._();

  CalibratedScoresTable? _short;
  CalibratedScoresTable? _long;
  bool _loaded = false;

  /// 從 assets 載入兩個 horizon 的 calibrated scores
  ///
  /// Idempotent — 重複呼叫會直接 return，不會重新讀檔。若需強制重載
  /// （例如測試），請先呼叫 [resetForTesting]。
  ///
  /// [knownRuleIds] 若提供，會傳入 `parseJson` 做 scenario 7 check
  /// （unknown ReasonType code 會產生 warning）。null 表示跳過此檢查。
  /// 正式啟動流程應由 `main.dart` 傳入
  /// `ReasonType.values.map((r) => r.code).toSet()`（Stage 5a Commit 2 啟用）。
  Future<void> loadFromAssets({Set<String>? knownRuleIds}) async {
    if (_loaded) return;
    _short = await _loadOne(Horizon.short, knownRuleIds);
    _long = await _loadOne(Horizon.long, knownRuleIds);
    _loaded = true;
  }

  /// Horizon-aware 的同步 rule 查詢
  ///
  /// - Registry 未載入 → null
  /// - Table 中無此 ruleId → null
  /// - 正常命中 → calibrated int
  ///
  /// 呼叫端遇 null 應 fallback 到 `RuleScores` hardcoded 值。
  int? lookup(Horizon horizon, String ruleId) => switch (horizon) {
    Horizon.short => _short?.lookup(ruleId),
    Horizon.long => _long?.lookup(ruleId),
  };

  /// 測試用：重置 registry 狀態
  ///
  /// Production code 不應呼叫此方法。
  @visibleForTesting
  void resetForTesting() {
    _short = null;
    _long = null;
    _loaded = false;
  }

  /// 測試用：直接注入 fake table，跳過 asset bundle
  ///
  /// 任何未提供的 horizon 會變成 null（`lookup` 回 null）。
  /// 呼叫此方法後 `_loaded = true`，後續 `loadFromAssets` 會 no-op。
  @visibleForTesting
  void bindForTesting({
    CalibratedScoresTable? short,
    CalibratedScoresTable? long,
  }) {
    _short = short;
    _long = long;
    _loaded = true;
  }

  Future<CalibratedScoresTable> _loadOne(
    Horizon horizon,
    Set<String>? knownRuleIds,
  ) async {
    try {
      final jsonStr = await rootBundle.loadString(horizon.assetPath);
      final (:table, :warnings) = CalibratedScoresTable.parseJson(
        jsonStr,
        horizon: horizon,
        knownRuleIds: knownRuleIds,
      );
      _logCappedWarnings(horizon, warnings);
      return table;
    } catch (e, st) {
      AppLogger.error(
        'CalibratedScoresRegistry',
        'Failed to load ${horizon.assetPath}',
        e,
        st,
      );
      return CalibratedScoresTable.empty(horizon);
    }
  }

  /// 限制每個 horizon 最多 log 10 個 warning，避免 JSON 出問題時洗版
  static const int _maxWarningsPerHorizon = 10;

  void _logCappedWarnings(Horizon horizon, List<String> warnings) {
    final toLog = warnings.take(_maxWarningsPerHorizon);
    for (final msg in toLog) {
      AppLogger.warning('CalibratedScoresRegistry', '[${horizon.name}] $msg');
    }
    if (warnings.length > _maxWarningsPerHorizon) {
      final suppressed = warnings.length - _maxWarningsPerHorizon;
      AppLogger.warning(
        'CalibratedScoresRegistry',
        '[${horizon.name}] $suppressed more warnings suppressed',
      );
    }
  }
}
