import 'dart:io' show Platform;

import 'package:afterclose/core/services/notification_service.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/data/remote/rss_parser.dart';
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
import 'package:afterclose/domain/services/update_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

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
      AppLogger.debug('BackgroundUpdate', '當前平台不支援背景更新，跳過初始化');
      return;
    }

    await Workmanager().initialize(_callbackDispatcher, isInDebugMode: false);
    AppLogger.debug('BackgroundUpdate', '服務已初始化');
  }

  /// 啟用每日自動更新
  ///
  /// 排程每日 15:00（收盤後）執行背景更新。
  /// 在不支援的平台會直接返回。
  Future<void> enableAutoUpdate() async {
    if (!isSupported) {
      AppLogger.debug('BackgroundUpdate', '當前平台不支援背景更新');
      return;
    }

    // 取消舊的任務（如有）
    await Workmanager().cancelByUniqueName(kBackgroundUpdateTask);

    // 計算下次 15:00 的延遲時間
    final now = DateTime.now();
    var scheduledTime = DateTime(now.year, now.month, now.day, 15, 0);
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
      existingWorkPolicy: ExistingWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 15),
    );

    // 儲存設定
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoUpdateEnabled, true);

    AppLogger.info(
      'BackgroundUpdate',
      '已啟用自動更新，下次執行: $scheduledTime (${initialDelay.inMinutes} 分鐘後)',
    );
  }

  /// 停用自動更新
  Future<void> disableAutoUpdate() async {
    if (isSupported) {
      await Workmanager().cancelByUniqueName(kBackgroundUpdateTask);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoUpdateEnabled, false);

    AppLogger.info('BackgroundUpdate', '已停用自動更新');
  }

  /// 檢查是否啟用自動更新
  Future<bool> isAutoUpdateEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoUpdateEnabled) ?? false;
  }

  /// 立即執行一次背景更新（用於測試）
  Future<void> runOnce() async {
    if (!isSupported) {
      AppLogger.debug('BackgroundUpdate', '當前平台不支援背景更新');
      return;
    }

    await Workmanager().registerOneOffTask(
      '${kBackgroundUpdateTask}_once',
      kBackgroundUpdateTask,
      constraints: Constraints(networkType: NetworkType.connected),
    );
    AppLogger.info('BackgroundUpdate', '已排程一次性更新');
  }
}

/// Workmanager 回呼函式（必須是頂層函式）
@pragma('vm:entry-point')
void _callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    AppLogger.info('BackgroundUpdate', '開始執行背景更新任務: $task');

    try {
      // 在背景 isolate 中初始化所需服務
      final result = await _executeBackgroundUpdate();

      AppLogger.info('BackgroundUpdate', '背景更新完成: ${result.summary}');

      // 顯示通知（best-effort，失敗不影響更新結果）
      try {
        await _showUpdateNotification(result);
      } catch (notifError) {
        AppLogger.warning('BackgroundUpdate', '通知顯示失敗', notifError);
      }

      return true;
    } catch (e) {
      AppLogger.error('BackgroundUpdate', '背景更新失敗', e);
      return false;
    }
  });
}

/// 在背景執行更新
Future<UpdateResult> _executeBackgroundUpdate() async {
  // 初始化資料庫
  final database = AppDatabase();

  try {
    // 初始化 API 客戶端
    final finMindClient = FinMindClient();
    final twseClient = TwseClient();
    final tpexClient = TpexClient();

    // 載入 API Token（如有）
    try {
      final settingsRepo = SettingsRepository(database: database);
      final token = await settingsRepo.getFinMindToken();
      if (token != null && token.isNotEmpty) {
        finMindClient.token = token;
      }
    } catch (e) {
      AppLogger.warning('BackgroundUpdate', '載入 API Token 失敗', e);
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
    final rssParser = RssParser();
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
      finMindClient: finMindClient,
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
    final updateService = UpdateService(
      database: database,
      stockRepository: stockRepo,
      priceRepository: priceRepo,
      newsRepository: newsRepo,
      analysisRepository: analysisRepo,
      institutionalRepository: institutionalRepo,
      marketDataRepository: marketDataRepo,
      tradingRepository: tradingRepo,
      shareholdingRepository: shareholdingRepo,
      fundamentalRepository: fundamentalRepo,
      insiderRepository: insiderRepo,
      twseClient: twseClient,
    );

    // 執行更新
    return await updateService.runDailyUpdate();
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
    AppLogger.warning('BackgroundUpdate', '無通知權限，跳過通知');
    return;
  }

  String title;
  String body;

  if (result.skipped) {
    // 非交易日
    title = '今日無更新';
    body = result.message ?? '非交易日';
  } else if (result.success) {
    // 更新成功
    title = '盤後資料已更新';

    final parts = <String>[];
    if (result.recommendationsGenerated > 0) {
      parts.add('Top ${result.recommendationsGenerated} 推薦');
    }
    if (result.stocksAnalyzed > 0) {
      parts.add('分析 ${result.stocksAnalyzed} 檔');
    }
    if (result.errors.isNotEmpty) {
      parts.add('${result.errors.length} 個警告');
    }

    body = parts.isNotEmpty ? parts.join('，') : '更新完成';
  } else {
    // 更新失敗
    title = '更新失敗';
    body = result.message ?? '請稍後重試';
  }

  await NotificationService.instance.showNotification(
    id: _generateNotificationId(),
    title: title,
    body: body,
    payload: 'background_update',
  );
}

/// 產生通知 ID（使用當日日期）
int _generateNotificationId() {
  final now = DateTime.now();
  return now.year * 10000 + now.month * 100 + now.day;
}
