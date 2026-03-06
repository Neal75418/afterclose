import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/presentation/providers/settings_provider.dart';
import 'package:afterclose/presentation/screens/settings/settings_screen.dart';

// =============================================================================
// Test Asset Loader — returns empty map so .tr() returns the key itself
// =============================================================================

class _EmptyAssetLoader extends AssetLoader {
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => {};
}

// =============================================================================
// Fake Notifier
// =============================================================================

class FakeSettingsNotifier extends SettingsNotifier {
  SettingsState initialState = const SettingsState();

  @override
  SettingsState build() => initialState;

  @override
  void setThemeMode(ThemeMode mode) {}

  @override
  void toggleTheme() {}

  @override
  void setLocale(AppLocale locale) {}

  @override
  void setShowWarningBadges(bool value) {}

  @override
  void setInsiderNotifications(bool value) {}

  @override
  void setDisposalUrgentAlerts(bool value) {}

  @override
  void setLimitAlerts(bool value) {}

  @override
  void setShowROCYear(bool value) {}

  @override
  void setCacheDurationMinutes(int minutes) {}

  @override
  void setAutoUpdateEnabled(bool value) {}
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    EasyLocalization.logger.enableLevels = [];
  });

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 8000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  Widget buildTestWidget({
    SettingsState? settingsState,
    Brightness brightness = Brightness.light,
  }) {
    final s = settingsState ?? const SettingsState();
    return ProviderScope(
      overrides: [
        settingsProvider.overrideWith(() {
          final n = FakeSettingsNotifier();
          n.initialState = s;
          return n;
        }),
      ],
      child: EasyLocalization(
        supportedLocales: const [Locale('zh', 'TW'), Locale('en')],
        path: 'assets/translations',
        fallbackLocale: const Locale('zh', 'TW'),
        assetLoader: _EmptyAssetLoader(),
        child: Builder(
          builder: (context) => MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            theme: brightness == Brightness.light
                ? AppTheme.lightTheme
                : AppTheme.darkTheme,
            home: const Scaffold(body: SettingsScreen()),
          ),
        ),
      ),
    );
  }

  group('SettingsScreen', () {
    testWidgets('renders all settings sections', (tester) async {
      widenViewport(tester);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(SettingsScreen), findsOneWidget);

      // Theme icon (system by default)
      expect(find.byIcon(Icons.brightness_auto_rounded), findsOneWidget);

      // Language icon
      expect(find.byIcon(Icons.language_rounded), findsOneWidget);

      // Warning badges icon
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

      // About icon
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);

      // Version icon
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    });

    testWidgets('shows warning badges switch as enabled', (tester) async {
      widenViewport(tester);

      await tester.pumpWidget(
        buildTestWidget(
          settingsState: const SettingsState(showWarningBadges: true),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      final switches = tester.widgetList<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(switches.isNotEmpty, isTrue);
      expect(switches.first.value, isTrue);
    });

    testWidgets('shows version info', (tester) async {
      widenViewport(tester);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('1.0.0'), findsOneWidget);
    });

    testWidgets('shows cache duration setting', (tester) async {
      widenViewport(tester);

      await tester.pumpWidget(
        buildTestWidget(
          settingsState: const SettingsState(cacheDurationMinutes: 30),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.cached_rounded), findsOneWidget);
    });

    testWidgets('shows back button', (tester) async {
      widenViewport(tester);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);

      await tester.pumpWidget(buildTestWidget(brightness: Brightness.dark));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('shows ROC year switch', (tester) async {
      widenViewport(tester);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.calendar_month_rounded), findsOneWidget);
    });

    testWidgets('shows dark theme icon when dark mode selected', (
      tester,
    ) async {
      widenViewport(tester);

      await tester.pumpWidget(
        buildTestWidget(
          settingsState: const SettingsState(themeMode: ThemeMode.dark),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
    });
  });
}
