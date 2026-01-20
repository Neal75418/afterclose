import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/app/router.dart';
import 'package:afterclose/core/services/notification_service.dart';
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/presentation/providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Initialize notification service
  await NotificationService.instance.initialize();
  await NotificationService.instance.requestPermissions();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('zh', 'TW'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('zh', 'TW'),
      child: const ProviderScope(child: AfterCloseApp()),
    ),
  );
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
