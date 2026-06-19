import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'package:afterclose/app/headless_update_runner.dart';
import 'package:afterclose/core/constants/api_config.dart';
import 'package:afterclose/core/constants/calibrated_scores/calibrated_scores_registry.dart';
import 'package:afterclose/core/services/notification_service.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/database/app_database_flutter.dart';
import 'package:afterclose/data/repositories/settings_repository.dart';
import 'package:afterclose/domain/services/update_service.dart';

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
      // 共用 [runHeadlessUpdate]，與 macOS launchd CLI 同條 wiring。
      //
      // C 方案 refactor 2026-06-19：
      // - CalibratedScoresRegistry 已純 Dart 化，跨 isolate 不會繼承 main
      //   isolate 的 assetLoaderOverride，本 isolate 自己注入
      //   `rootBundle.loadString`（workmanager isolate 也有 Flutter binding）。
      // - AppDatabase 走 Flutter-flavoured executor `openDriftFlutterConnection()`
      //   讓 drift 跨 isolate share 連線（避免 SQLITE_BUSY 衝突）。CLI
      //   路徑用 `AppDatabase.forToolFile(path)` 不經此 callback。
      CalibratedScoresRegistry.instance.assetLoaderOverride =
          rootBundle.loadString;
      final database = AppDatabase(openDriftFlutterConnection());

      // C 方案 refactor 2026-06-19：runHeadlessUpdate 已不直接吃
      // SettingsRepository（拆掉 flutter_secure_storage 的依賴）。本層
      // 在 Flutter binding context 下用 SettingsRepository 走完整 fallback
      // chain（SecureStorage → env var → memory），再把結果傳進 runner。
      String? finMindToken;
      try {
        final settingsRepo = SettingsRepository(database: database);
        finMindToken = await settingsRepo.getFinMindToken();
      } catch (e) {
        AppLogger.warning(
          'BackgroundUpdateService',
          'FinMind token 載入失敗，將以無 token 模式跑 update',
          e,
        );
      }
      final result = await runHeadlessUpdate(
        database: database,
        finMindToken: finMindToken,
      );

      AppLogger.info('BackgroundUpdateService', '背景更新完成: ${result.summary}');

      // 顯示通知（best-effort，失敗不影響更新結果）— mobile-only
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
