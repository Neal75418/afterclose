import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'package:afterclose/core/constants/api_config.dart';
import 'package:afterclose/core/constants/calibrated_scores/calibrated_scores_registry.dart';
import 'package:afterclose/core/constants/reason_type.dart';
import 'package:afterclose/core/services/notification_service.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/taiwan_calendar.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/data/remote/rss_parser.dart';
import 'package:afterclose/data/remote/tdcc_client.dart';
import 'package:afterclose/data/remote/tpex_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/data/repositories/analysis_repository.dart';
import 'package:afterclose/data/repositories/fundamental_repository.dart';
import 'package:afterclose/data/repositories/insider_repository.dart';
import 'package:afterclose/data/repositories/institutional_repository.dart';
import 'package:afterclose/data/repositories/market_data_repository.dart';
import 'package:afterclose/data/repositories/news_repository.dart';
import 'package:afterclose/data/repositories/price_repository.dart';
import 'package:afterclose/data/repositories/settings_repository.dart';
import 'package:afterclose/data/repositories/shareholding_repository.dart';
import 'package:afterclose/data/repositories/stock_repository.dart';
import 'package:afterclose/data/repositories/trading_repository.dart';
import 'package:afterclose/domain/services/rule_accuracy_service.dart';
import 'package:afterclose/domain/services/update_service.dart';
import 'package:afterclose/domain/services/update_service_deps.dart';

/// 背景更新任務名稱
const kBackgroundUpdateTask = 'afterclose_daily_update';

/// 背景更新設定 key
const _keyAutoUpdateEnabled = 'settings_auto_update_enabled';

/// 背景更新服務
///
/// 使用 workmanager 在背景執行每日資料更新。
/// 預設於每日 15:00（收盤後）執行。
class BackgroundUpdateService {
  BackgroundUpdateService._();

  static final BackgroundUpdateService _instance = BackgroundUpdateService._();
  static BackgroundUpdateService get instance => _instance;

  /// 檢查當前平台是否支援背景更新
  ///
  /// workmanager 只支援 Android 和 iOS
  static bool get isSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// 初始化 workmanager
  ///
  /// 必須在 main() 中呼叫。
  /// 在不支援的平台（macOS、Windows、Linux、Web）會直接跳過。
  Future<void> initialize() async {
    if (!isSupported) {
      AppLogger.debug('BackgroundUpdateService', '當前平台不支援背景更新，跳過初始化');
      return;
    }

    await Workmanager().initialize(_callbackDispatcher);
    AppLogger.debug('BackgroundUpdateService', '服務已初始化');
  }

  /// 啟用每日自動更新
  ///
  /// 排程每日 15:00（收盤後）執行背景更新。
  /// 在不支援的平台會直接返回。
  Future<void> enableAutoUpdate() async {
    if (!isSupported) {
      AppLogger.debug('BackgroundUpdateService', '當前平台不支援背景更新');
      return;
    }

    // 取消舊的任務（如有）
    await Workmanager().cancelByUniqueName(kBackgroundUpdateTask);

    // 計算下次 15:00 的延遲時間
    final now = DateTime.now();
    var scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      ApiConfig.marketCloseHour,
      ApiConfig.marketCloseMinute,
    );
    if (now.isAfter(scheduledTime)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }
    final initialDelay = scheduledTime.difference(now);

    // 排程週期性任務
    await Workmanager().registerPeriodicTask(
      kBackgroundUpdateTask,
      kBackgroundUpdateTask,
      initialDelay: initialDelay,
      frequency: const Duration(days: 1),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(
        minutes: ApiConfig.backoffDelayMinutes,
      ),
    );

    AppLogger.info(
      'BackgroundUpdateService',
      '已啟用自動更新，下次執行: $scheduledTime (${initialDelay.inMinutes} 分鐘後)',
    );
  }

  /// 停用自動更新
  Future<void> disableAutoUpdate() async {
    if (isSupported) {
      await Workmanager().cancelByUniqueName(kBackgroundUpdateTask);
    }

    AppLogger.info('BackgroundUpdateService', '已停用自動更新');
  }

  /// 檢查是否啟用自動更新
  Future<bool> isAutoUpdateEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoUpdateEnabled) ?? false;
  }

  /// 立即執行一次背景更新（用於測試）
  Future<void> runOnce() async {
    if (!isSupported) {
      AppLogger.debug('BackgroundUpdateService', '當前平台不支援背景更新');
      return;
    }

    await Workmanager().registerOneOffTask(
      '${kBackgroundUpdateTask}_once',
      kBackgroundUpdateTask,
      constraints: Constraints(networkType: NetworkType.connected),
    );
    AppLogger.info('BackgroundUpdateService', '已排程一次性更新');
  }
}

/// Workmanager 回呼函式（必須是頂層函式）
@pragma('vm:entry-point')
void _callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    AppLogger.info('BackgroundUpdateService', '開始執行背景更新任務: $task');

    try {
      // 在背景 isolate 中初始化所需服務
      final result = await _executeBackgroundUpdate();

      AppLogger.info('BackgroundUpdateService', '背景更新完成: ${result.summary}');

      // 顯示通知（best-effort，失敗不影響更新結果）
      try {
        await _showUpdateNotification(result);
      } catch (notifError) {
        AppLogger.warning('BackgroundUpdateService', '通知顯示失敗', notifError);
      }

      return true;
    } catch (e, s) {
      AppLogger.error('BackgroundUpdateService', '背景更新失敗', e, s);
      return false;
    }
  });
}

/// 在背景執行更新
Future<UpdateResult> _executeBackgroundUpdate() async {
  // 先檢查是否為交易日，避免在非交易日建立完整服務圖
  final now = DateTime.now();
  if (!TaiwanCalendar.isTradingDay(now)) {
    AppLogger.info('BackgroundUpdateService', '非交易日，跳過更新');
    return UpdateResult(date: now)
      ..success = true
      ..skipped = true
      ..message = '非交易日';
  }

  // 初始化資料庫
  final database = AppDatabase();

  try {
    // Stage 5a OTA：seed CalibratedScoresRegistry。WorkManager 在獨立 isolate
    // 跑，singleton 是 fresh `_loaded=false` 狀態；若不 seed，`scoreStocksInIsolate`
    // 取到的 `snapshotForIsolate()` 是空 map，所有規則 fallback 到 hardcoded
    // `RuleScores`，跟前景路徑使用的 calibrated 分數靜默分歧 —— 夜間寫入的
    // recommendations 跟 user 開 app 看到的不一致。對齊 `main.dart` 的初始化邏輯。
    final cachedCalibration = await database.getCachedCalibration();
    await CalibratedScoresRegistry.instance.loadWithOverride(
      shortJsonOverride: cachedCalibration.shortJson,
      longJsonOverride: cachedCalibration.longJson,
      knownRuleIds: ReasonType.values.map((r) => r.code).toSet(),
      hardcodedScores: {for (final r in ReasonType.values) r.code: r.score},
    );

    // 初始化 API 客戶端（hoist 到 try 外讓 finally 可見；inline 構造的
    // TdccClient 改成有名 reference，否則 isolate 結束前無法 close）
    final finMindClient = FinMindClient();
    final twseClient = TwseClient();
    final tpexClient = TpexClient();
    final tdccClient = TdccClient();
    final rssParser = RssParser();

    try {
      // 載入 API Token（如有）
      try {
        final settingsRepo = SettingsRepository(database: database);
        final token = await settingsRepo.getFinMindToken();
        if (token != null && token.isNotEmpty) {
          finMindClient.token = token;
        }
      } catch (e) {
        AppLogger.warning('BackgroundUpdateService', '載入 API Token 失敗', e);
      }

      // 初始化 Repositories
      final stockRepo = StockRepository(
        database: database,
        finMindClient: finMindClient,
      );
      final priceRepo = PriceRepository(
        database: database,
        finMindClient: finMindClient,
        twseClient: twseClient,
        tpexClient: tpexClient,
      );
      final newsRepo = NewsRepository(database: database, rssParser: rssParser);
      final analysisRepo = AnalysisRepository(database: database);
      final institutionalRepo = InstitutionalRepository(
        database: database,
        finMindClient: finMindClient,
        twseClient: twseClient,
        tpexClient: tpexClient,
      );
      final marketDataRepo = MarketDataRepository(
        database: database,
        finMindClient: finMindClient,
      );
      final tradingRepo = TradingRepository(
        database: database,
        twseClient: twseClient,
        tpexClient: tpexClient,
      );
      final shareholdingRepo = ShareholdingRepository(
        database: database,
        finMindClient: finMindClient,
      );
      final fundamentalRepo = FundamentalRepository(
        db: database,
        finMind: finMindClient,
        twse: twseClient,
        tpex: tpexClient,
      );
      final insiderRepo = InsiderRepository(
        database: database,
        twseClient: twseClient,
        tpexClient: tpexClient,
      );

      // 建立 UpdateService
      final ruleAccuracyService = RuleAccuracyService(database: database);
      final updateService = UpdateService(
        database: database,
        repositories: UpdateRepositories(
          stock: stockRepo,
          price: priceRepo,
          news: newsRepo,
          analysis: analysisRepo,
          institutional: institutionalRepo,
          marketData: marketDataRepo,
          trading: tradingRepo,
          shareholding: shareholdingRepo,
          fundamental: fundamentalRepo,
          insider: insiderRepo,
        ),
        clients: UpdateClients(
          twse: twseClient,
          tpex: tpexClient,
          tdcc: tdccClient,
          finMind: finMindClient,
        ),
        services: UpdateServices(ruleAccuracy: ruleAccuracyService),
      );

      // 執行更新
      return await updateService.runDailyUpdate();
    } finally {
      // 釋放所有 API client 的 Dio 連線。Android WorkManager 每次都會
      // destroy FlutterEngine 連帶釋放 isolate，所以本質是 hygiene 而非
      // 累積 leak；顯式 close 仍有價值：iOS BGProcessingTask 時間更緊、
      // 任務內 keep-alive socket 提前歸還、未來把 runner 搬出 WorkManager
      // 時不需要再回頭補。
      finMindClient.close();
      twseClient.close();
      tpexClient.close();
      tdccClient.close();
      rssParser.close();
    }
  } finally {
    // 確保資料庫一定會被關閉
    await database.close();
  }
}

/// 顯示更新完成通知
Future<void> _showUpdateNotification(UpdateResult result) async {
  // 初始化通知服務
  await NotificationService.instance.initialize();

  // 檢查權限
  final hasPermission = await NotificationService.instance.hasPermission();
  if (!hasPermission) {
    AppLogger.warning('BackgroundUpdateService', '無通知權限，跳過通知');
    return;
  }

  String title;
  String body;

  // 背景 isolate 無法使用 EasyLocalization，
  // 以 platform locale 決定語系（zh → 中文，其餘 → 英文）
  final isChinese = Platform.localeName.startsWith('zh');

  if (result.skipped) {
    title = isChinese ? '今日無更新' : 'No update today';
    body = result.message ?? (isChinese ? '非交易日' : 'Non-trading day');
  } else if (result.success) {
    title = isChinese ? '盤後資料已更新' : 'Market data updated';

    final parts = <String>[];
    if (result.recommendationsGenerated > 0) {
      parts.add(
        isChinese
            ? 'Top ${result.recommendationsGenerated} 推薦'
            : 'Top ${result.recommendationsGenerated} picks',
      );
    }
    if (result.stocksAnalyzed > 0) {
      parts.add(
        isChinese
            ? '分析 ${result.stocksAnalyzed} 檔'
            : '${result.stocksAnalyzed} stocks analyzed',
      );
    }
    if (result.errors.isNotEmpty) {
      parts.add(
        isChinese
            ? '${result.errors.length} 個警告'
            : '${result.errors.length} warnings',
      );
    }

    body = parts.isNotEmpty
        ? parts.join(isChinese ? '，' : ', ')
        : (isChinese ? '更新完成' : 'Update complete');
  } else {
    title = isChinese ? '更新失敗' : 'Update failed';
    body = result.message ?? (isChinese ? '請稍後重試' : 'Please try again later');
  }

  // payload 故意留 null：背景更新通知非單一股票，沒有可導航目的地。
  // _onNotificationTapped 對 null / empty payload 會跳過 onTapCallback，
  // 避免導航到 /stock/background_update 這種不存在的 route。
  await NotificationService.instance.showNotification(
    id: _generateNotificationId(),
    title: title,
    body: body,
  );
}

/// 產生通知 ID（使用當日日期）
int _generateNotificationId() {
  final now = DateTime.now();
  return now.year * 10000 + now.month * 100 + now.day;
}
