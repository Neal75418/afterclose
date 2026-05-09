import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:afterclose/app/router.dart';
import 'package:afterclose/core/constants/app_routes.dart';
import 'package:afterclose/core/constants/calibrated_scores/calibrated_scores_registry.dart';
import 'package:afterclose/core/constants/data_freshness.dart';
import 'package:afterclose/app/background_update_service.dart';
import 'package:afterclose/core/constants/reason_type.dart';
import 'package:afterclose/core/services/notification_service.dart';
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/presentation/providers/providers.dart';
import 'package:afterclose/presentation/providers/settings_provider.dart';
import 'package:afterclose/presentation/providers/today_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await EasyLocalization.ensureInitialized();

  // 設定通知點擊導航 — 必須在 initialize() 之前，避免 init 期間若 plugin
  // dispatch 到 _onNotificationTapped，callback 還是 null 而 silently 丟掉
  // payload。callback 是 plugin singleton 上的 property，在 init 前先 assign
  // 不影響 init 流程；init 內部註冊 onDidReceiveNotificationResponse 時
  // 屬性已就位。
  NotificationService.instance.onTapCallback = (symbol) {
    router.push(AppRoutes.stockDetail(symbol));
  };

  // Initialize notification service (權限請求延遲到使用者啟用通知時)
  await NotificationService.instance.initialize();

  // 初始化背景更新服務
  await BackgroundUpdateService.instance.initialize();

  // 建立 Container 以在 runApp 前初始化 Provider
  final container = ProviderContainer();

  // 從安全儲存載入 FinMind API Token
  await _initializeFinMindToken(container);

  // 檢查是否已完成引導流程
  await initOnboardingStatus();

  // 快取預熱（非阻塞）
  container
      .read(cacheWarmupServiceProvider)
      .warmup()
      .then((_) {
        AppLogger.info('Main', '快取預熱完成');
      })
      .catchError((error) {
        AppLogger.warning('Main', '快取預熱失敗（不影響使用）', error);
      });

  // Sentry DSN 由 --dart-define=SENTRY_DSN=xxx 編譯時注入
  const sentryDsn = String.fromEnvironment('SENTRY_DSN');

  if (sentryDsn.isNotEmpty) {
    await SentryFlutter.init((options) {
      options.dsn = sentryDsn;
      options.environment = kDebugMode ? 'development' : 'production';
      options.sendDefaultPii = false;
      options.tracesSampleRate = kDebugMode ? 1.0 : 0.2;
    }, appRunner: () => _runApp(container));
  } else {
    await _runApp(container);
  }
}

Future<void> _runApp(ProviderContainer container) async {
  // Stage 5a + OTA: 載入 calibrated scores JSON（放在 Sentry init 之後，
  // 讓 asset 載入錯誤能被 Sentry 捕獲上報）。
  //
  // 載入優先順序（design doc §3.2 fallback chain）：
  //   1. AppSettings DB cache（last successful OTA fetch）
  //   2. Bundled asset（最後一次 release 時 commit 進 repo 的 JSON）
  //   3. Empty table → hardcoded RuleScores
  //
  // loadWithOverride 會在 DB cache 有效時直接使用，否則自動 fall through
  // 到 loadFromAssets（原 Stage 5a 路徑）。
  final db = container.read(databaseProvider);
  final cached = await db.getCachedCalibration();
  await CalibratedScoresRegistry.instance.loadWithOverride(
    shortJsonOverride: cached.shortJson,
    longJsonOverride: cached.longJson,
    knownRuleIds: ReasonType.values.map((r) => r.code).toSet(),
    hardcodedScores: {for (final r in ReasonType.values) r.code: r.score},
  );

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('zh', 'TW'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('zh', 'TW'),
      child: UncontrolledProviderScope(
        container: container,
        child: const AfterCloseApp(),
      ),
    ),
  );

  // OTA calibration check — fire-and-forget（design doc §2 Q7 = A）
  //
  // 在 runApp 之後呼叫，不阻塞 UI。24h gate 在 CalibrationUpdater 內部
  // 處理，大部分 cold start 不會實際打網路。新 JSON 寫入 AppSettings
  // 但不 invalidate provider（Q5 = B, deferred swap），下次 cold start
  // 才會走 Tier 1 DB cache 路徑讀到新版本。
  unawaited(
    container
        .read(calibrationUpdaterProvider)
        .checkAndUpdate()
        .then((result) {
          AppLogger.info(
            'CalibrationUpdater',
            'OTA check: ${result.describe()}',
          );
        })
        .catchError((Object error) {
          // CalibrationUpdater.checkAndUpdate 內部已全 try/catch，這裡
          // 是最外層保底，理論上不會觸發。
          AppLogger.warning(
            'CalibrationUpdater',
            'OTA check outer error',
            error,
          );
        }),
  );
}

/// 從安全儲存載入 FinMind API Token 並設定至 Client
Future<void> _initializeFinMindToken(ProviderContainer container) async {
  try {
    final settingsRepo = container.read(settingsRepositoryProvider);
    final token = await settingsRepo.getFinMindToken();
    if (token != null && token.isNotEmpty) {
      container.read(finMindClientProvider).token = token;
    }
  } catch (e) {
    // Token 載入為選用，失敗不影響啟動
    AppLogger.warning('Main', '載入 FinMind Token 失敗', e);
  }
}

class AfterCloseApp extends ConsumerStatefulWidget {
  const AfterCloseApp({super.key});

  @override
  ConsumerState<AfterCloseApp> createState() => _AfterCloseAppState();
}

class _AfterCloseAppState extends ConsumerState<AfterCloseApp>
    with WidgetsBindingObserver {
  DateTime? _lastPausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _lastPausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed && _lastPausedAt != null) {
      final elapsed = DateTime.now().difference(_lastPausedAt!);
      if (elapsed.inMinutes >= DataFreshness.appStaleThresholdMinutes) {
        AppLogger.info('Lifecycle', '離開 ${elapsed.inMinutes} 分鐘，重新載入資料');
        ref.read(todayProvider.notifier).loadData();
      }
      _lastPausedAt = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'AfterClose',
      onGenerateTitle: (context) => 'app.name'.tr(),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
