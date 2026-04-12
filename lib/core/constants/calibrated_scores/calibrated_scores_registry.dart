import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:afterclose/core/constants/calibrated_scores/calibrated_score_context.dart';
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
  Future<void>? _loading;

  /// 從 assets 載入兩個 horizon 的 calibrated scores
  ///
  /// Idempotent — 重複呼叫會直接 return，不會重新讀檔。若需強制重載
  /// （例如測試），請先呼叫 [resetForTesting]。
  ///
  /// **Re-entrancy safe**：並行呼叫會共享同一個 in-flight future，避免
  /// 重複讀 asset bundle；若 [bindForTesting] 在 load 進行中被呼叫，
  /// load 完成時會檢查 `_loaded` 狀態並尊重測試注入的 fake table。
  ///
  /// [knownRuleIds] 若提供，會傳入 `parseJson` 做 scenario 7 check
  /// （unknown ReasonType code 會產生 warning）。null 表示跳過此檢查。
  /// 正式啟動流程應由 `main.dart` 傳入
  /// `ReasonType.values.map((r) => r.code).toSet()`（Stage 5a Commit 2 啟用）。
  Future<void> loadFromAssets({Set<String>? knownRuleIds}) {
    if (_loaded) return Future.value();
    return _loading ??= _doLoad(knownRuleIds);
  }

  /// OTA-aware 載入：優先使用傳入的 JSON 字串覆蓋，失敗時 fall through 到
  /// bundled asset
  ///
  /// 呼叫端（`main.dart`）先從 `CalibrationCacheDaoMixin.getCachedCalibration`
  /// 拿到 cached short/long JSON，再傳進來。若兩個 override 都非 null 且都能
  /// 成功 parse，registry 會綁定 override 的 table；否則任一失敗即退回
  /// `loadFromAssets` 走 bundled 資產。
  ///
  /// ## Fallback 語意（design doc §3.2）
  ///
  /// 1. 兩個 override 皆 null → 直接走 `loadFromAssets`
  /// 2. 兩個 override 皆非 null 且都 parse 成功 → 綁 DB cache 版
  /// 3. 任一 override parse 失敗 / table empty → fall through 到
  ///    `loadFromAssets`（避免 half-loaded state 造成 short 新 / long 舊的
  ///    不一致）
  ///
  /// Idempotent — 與 [loadFromAssets] 共用 `_loaded` flag，重複呼叫 no-op。
  Future<void> loadWithOverride({
    String? shortJsonOverride,
    String? longJsonOverride,
    Set<String>? knownRuleIds,
  }) async {
    if (_loaded) return;

    // 任一 override 缺失就直接走 asset fallback — 避免 DB cache 半成品的
    // 不一致狀態。CalibrationCacheDaoMixin.writeCalibration 是 atomic，
    // 正常流程下要有就兩個都有；若遇到 half-state（例如早期 schema 遷移
    // 的遺跡）視同無 DB cache。
    if (shortJsonOverride == null || longJsonOverride == null) {
      return loadFromAssets(knownRuleIds: knownRuleIds);
    }

    final shortResult = CalibratedScoresTable.parseJson(
      shortJsonOverride,
      horizon: Horizon.short,
      knownRuleIds: knownRuleIds,
    );
    final longResult = CalibratedScoresTable.parseJson(
      longJsonOverride,
      horizon: Horizon.long,
      knownRuleIds: knownRuleIds,
    );

    // parseJson 不 throw，格式錯誤會回空 table + warnings。空 table 代表
    // override 實質無效 → fall through 到 bundled asset 保底，而不是綁一個
    // 空的 DB cache 上去。
    if (shortResult.table.ruleCount == 0 || longResult.table.ruleCount == 0) {
      AppLogger.warning(
        'CalibratedScoresRegistry',
        'DB cache override yielded empty table, falling back to bundled asset. '
            'short warnings: ${shortResult.warnings.length}, '
            'long warnings: ${longResult.warnings.length}',
      );
      return loadFromAssets(knownRuleIds: knownRuleIds);
    }

    _logCappedWarnings(Horizon.short, shortResult.warnings);
    _logCappedWarnings(Horizon.long, longResult.warnings);

    _short = shortResult.table;
    _long = longResult.table;
    _loaded = true;
    AppLogger.info(
      'CalibratedScoresRegistry',
      'Loaded calibrated scores from DB cache override '
          '(short: ${_short!.ruleCount} rules, long: ${_long!.ruleCount} rules)',
    );
  }

  Future<void> _doLoad(Set<String>? knownRuleIds) async {
    try {
      // 兩個 horizon 平行載入，省一個 frame 的 startup latency
      final results = await Future.wait([
        _loadOne(Horizon.short, knownRuleIds),
        _loadOne(Horizon.long, knownRuleIds),
      ]);
      // 若 bindForTesting 在 await 期間被呼叫，尊重測試注入的狀態
      if (_loaded) return;
      _short = results[0];
      _long = results[1];
      _loaded = true;
    } finally {
      _loading = null;
    }
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

  /// 打包兩個 horizon 的 calibrated score maps 為 isolate-safe DTO（Stage 5b）
  ///
  /// 主 isolate 在呼叫 scoring isolate 前呼叫此 method，把回傳的
  /// [CalibratedScoreContext] 塞進 `ScoringIsolateInput.calibratedScores`
  /// 欄位。Isolate 邊界序列化透過 [CalibratedScoreContext.toMap] 處理。
  ///
  /// 若某個 horizon 的 table 未載入（`_short` 或 `_long` 為 null），
  /// 對應欄位會是空 map — scoring isolate 內的查詢會回 null，進而
  /// fallback 到 hardcoded。這符合 Stage 5a 的 fallback 語意。
  ///
  /// **僅供主 isolate 呼叫**。scoring isolate 內已有 `CalibratedScoreContext`，
  /// 不需要再次存取 registry。
  CalibratedScoreContext snapshotForIsolate() {
    return CalibratedScoreContext(
      shortScores: _short?.scoresSnapshot() ?? const {},
      longScores: _long?.scoresSnapshot() ?? const {},
    );
  }

  /// 測試用：重置 registry 狀態
  ///
  /// Production code 不應呼叫此方法。
  @visibleForTesting
  void resetForTesting() {
    _short = null;
    _long = null;
    _loaded = false;
    _loading = null;
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
      // 故意使用 untyped catch：rootBundle.loadString 在 asset 缺失時 throw
      // `FlutterError`，它不是 Exception 的 subtype。收斂到 `on Exception` 會
      // 讓 asset-missing 的錯誤穿透到 Zone error handler，反而丟失診斷訊息。
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
