import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/app/router.dart';
import 'package:afterclose/core/services/notification_service.dart';
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/presentation/providers/providers.dart';
import 'package:afterclose/presentation/providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Initialize notification service (權限請求延遲到使用者啟用通知時)
  await NotificationService.instance.initialize();

  // Create container to initialize providers before runApp
  final container = ProviderContainer();

  // Load FinMind API token from secure storage
  await _initializeFinMindToken(container);

  // Check if onboarding has been completed
  await initOnboardingStatus();

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
}

/// Load stored FinMind API token and set it on the client
Future<void> _initializeFinMindToken(ProviderContainer container) async {
  try {
    final settingsRepo = container.read(settingsRepositoryProvider);
    final token = await settingsRepo.getFinMindToken();
    if (token != null && token.isNotEmpty) {
      container.read(finMindClientProvider).token = token;
    }
  } catch (e) {
    // Token loading is optional, continue without it
    AppLogger.warning('Main', '載入 FinMind Token 失敗', e);
  }
}

class AfterCloseApp extends ConsumerWidget {
  const AfterCloseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'AfterClose', // Static title for system-level use
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
