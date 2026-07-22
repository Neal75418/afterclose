import 'package:afterclose/core/constants/calibrated_scores/calibrated_scores_registry.dart';
import 'package:afterclose/core/constants/reason_type.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/taiwan_calendar.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/api_budget_tracker.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/data/remote/rss_parser.dart';
import 'package:afterclose/data/remote/tdcc_client.dart';
import 'package:afterclose/data/remote/tpex_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/domain/services/update_service.dart';
import 'package:afterclose/domain/services/update_service_factory.dart';

const _tag = 'HeadlessUpdateRunner';

/// Headless 跑一次每日更新，給 background isolate（WorkManager）+ macOS
/// launchd CLI（[tool/daily_update.dart]）共用。
///
/// 自管所有資源生命週期（DB、API clients、Registry seed）。可從任何
/// 沒有 Riverpod container / Flutter binding 的環境呼叫。
///
/// **非交易日 short-circuit**：建完整服務圖之前就 skip，回傳
/// `skipped=true` 的 [UpdateResult]。
///
/// **Token 來源**：透過 [SettingsRepository] 走預設 fallback chain
/// （SecureStorage → `FINMIND_TOKEN` env var → in-memory）。launchd
/// 跑 CLI 時要靠 env var 路徑（launchd 不讀 shell rc）。
///
/// **[database] 參數（C 方案 refactor 2026-06-19）**：caller 注入已建好的
/// [AppDatabase] 控制連線方式：
/// - WorkManager isolate / Flutter app：`AppDatabase(openDriftFlutterConnection())`
/// - macOS launchd CLI：`AppDatabase.forToolFile(sandboxDbPath)`
///
/// caller 也要負責**之前**設好 [CalibratedScoresRegistry.assetLoaderOverride]
/// （rootBundle 或 File-based loader）。
///
/// runner 自己管 DB 生命週期，**會在 finally 呼叫 `db.close()`**。
///
/// [finMindToken] 顯式注入 — 取代以前 [SettingsRepository.getFinMindToken]
/// 的 fallback chain（依賴 flutter_secure_storage 是 Flutter-only plugin）。
/// caller 規則：
/// - WorkManager isolate：caller 自己用 SettingsRepository 取 token 再傳進來
/// - macOS launchd CLI：直接讀 `FINMIND_TOKEN` env var 傳進來
/// - null 或空字串 → finMind client 沒 token，免費資料能跑、需 token 的
///   syncer 會在內部 skip
Future<UpdateResult> runHeadlessUpdate({
  required AppDatabase database,
  String? finMindToken,
}) async {
  final now = DateTime.now();
  if (!TaiwanCalendar.isTradingDay(now)) {
    AppLogger.info(_tag, '非交易日，跳過更新');
    return UpdateResult(date: now)
      ..success = true
      ..skipped = true
      ..message = '非交易日';
  }

  try {
    // Stage 5a OTA：seed CalibratedScoresRegistry。background isolate
    // / CLI process 是 fresh `_loaded=false` 狀態；若不 seed，
    // `scoreStocksInIsolate` 取到的 `snapshotForIsolate()` 是空 map，
    // 所有規則 fallback 到 hardcoded `RuleScores`，跟前景路徑使用的
    // calibrated 分數靜默分歧 — 寫入的 recommendations 跟 user 開 app
    // 看到的不一致。對齊 `main.dart` 的初始化邏輯。
    final cachedCalibration = await database.getCachedCalibration();
    await CalibratedScoresRegistry.instance.loadWithOverride(
      shortJsonOverride: cachedCalibration.shortJson,
      longJsonOverride: cachedCalibration.longJson,
      knownRuleIds: ReasonType.values.map((r) => r.code).toSet(),
      hardcodedScores: {for (final r in ReasonType.values) r.code: r.score},
    );

    // 初始化 API 客戶端（hoist 到 try 外讓 finally 可見）。
    // process-local ApiBudgetTracker，跨 isolate 不共享是有意設計。
    final budgetTracker = ApiBudgetTracker();
    final finMindClient = FinMindClient(budgetTracker: budgetTracker);
    final twseClient = TwseClient();
    final tpexClient = TpexClient();
    final tdccClient = TdccClient();
    final rssParser = RssParser();

    try {
      // 由 caller 顯式注入 token，避免在此處 import flutter_secure_storage
      // 把 dart:ui 拉進整個 type graph（C 方案 refactor 2026-06-19）。
      if (finMindToken != null && finMindToken.isNotEmpty) {
        finMindClient.token = finMindToken;
      } else {
        AppLogger.info(_tag, 'FinMind token 未注入，需 token 的 syncer 將 skip');
      }

      // 透過 UpdateServiceFactory 統一裝配，與 foreground
      // `updateServiceProvider` 共享同一條 wiring 路徑避免漂移。
      final updateService = UpdateServiceFactory.build(
        database: database,
        finMindClient: finMindClient,
        twseClient: twseClient,
        tpexClient: tpexClient,
        tdccClient: tdccClient,
        rssParser: rssParser,
      );

      return await updateService.runDailyUpdate();
    } finally {
      // 釋放所有 API client 的 Dio 連線。本質是 hygiene 而非累積 leak
      //（isolate / process 結束自然回收），但顯式 close 在 iOS
      // BGProcessingTask 時間緊 / launchd 短任務時值得做。
      finMindClient.close();
      twseClient.close();
      tpexClient.close();
      tdccClient.close();
      rssParser.close();
    }
  } finally {
    await database.close();
  }
}
