import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:afterclose/presentation/providers/settings_provider.dart';

// =============================================================================
// Tests
// =============================================================================

void main() {
  // ===========================================================================
  // AppLocale
  // ===========================================================================

  group('AppLocale', () {
    test('toLocale creates correct Locale for zhTW', () {
      final locale = AppLocale.zhTW.toLocale();
      expect(locale.languageCode, 'zh');
      expect(locale.countryCode, 'TW');
    });

    test('toLocale creates correct Locale for en', () {
      final locale = AppLocale.en.toLocale();
      expect(locale.languageCode, 'en');
      expect(locale.countryCode, isNull);
    });

    test('fromLocale finds matching locale', () {
      final result = AppLocale.fromLocale(const Locale('zh', 'TW'));
      expect(result, AppLocale.zhTW);
    });

    test('fromLocale defaults to zhTW for unknown locale', () {
      final result = AppLocale.fromLocale(const Locale('ja'));
      expect(result, AppLocale.zhTW);
    });

    test('fromString parses valid names', () {
      expect(AppLocale.fromString('zhTW'), AppLocale.zhTW);
      expect(AppLocale.fromString('en'), AppLocale.en);
    });

    test('fromString defaults to zhTW for null', () {
      expect(AppLocale.fromString(null), AppLocale.zhTW);
    });

    test('fromString defaults to zhTW for unknown', () {
      expect(AppLocale.fromString('unknown'), AppLocale.zhTW);
    });

    test('displayName returns readable names', () {
      expect(AppLocale.zhTW.displayName, '繁體中文');
      expect(AppLocale.en.displayName, 'English');
    });
  });

  // ===========================================================================
  // SettingsState
  // ===========================================================================

  group('SettingsState', () {
    test('has correct default values', () {
      const state = SettingsState();

      expect(state.themeMode, ThemeMode.system);
      expect(state.locale, AppLocale.zhTW);
      expect(state.isLoaded, isFalse);
      expect(state.showWarningBadges, isTrue);
      expect(state.insiderNotifications, isTrue);
      expect(state.disposalUrgentAlerts, isTrue);
      expect(state.limitAlerts, isTrue);
      expect(state.showROCYear, isTrue);
      expect(state.cacheDurationMinutes, 30);
      expect(state.autoUpdateEnabled, isFalse);
    });

    test('copyWith preserves unset values', () {
      const state = SettingsState(
        themeMode: ThemeMode.dark,
        locale: AppLocale.en,
        showWarningBadges: false,
      );

      final copied = state.copyWith();
      expect(copied.themeMode, ThemeMode.dark);
      expect(copied.locale, AppLocale.en);
      expect(copied.showWarningBadges, isFalse);
    });

    test('copyWith updates individual fields', () {
      const state = SettingsState();
      final updated = state.copyWith(
        themeMode: ThemeMode.dark,
        cacheDurationMinutes: 60,
        autoUpdateEnabled: true,
      );

      expect(updated.themeMode, ThemeMode.dark);
      expect(updated.cacheDurationMinutes, 60);
      expect(updated.autoUpdateEnabled, isTrue);
      // Unchanged
      expect(updated.locale, AppLocale.zhTW);
    });
  });

  // ===========================================================================
  // SettingsNotifier
  // ===========================================================================

  group('SettingsNotifier', () {
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state has default values', () {
      final state = container.read(settingsProvider);
      expect(state.themeMode, ThemeMode.system);
      expect(state.locale, AppLocale.zhTW);
    });

    test('loads settings from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'settings_theme_mode': ThemeMode.dark.index,
        'settings_locale': 'en',
        'settings_show_warning_badges': false,
        'settings_cache_duration_minutes': 60,
      });

      final container2 = ProviderContainer();
      addTearDown(container2.dispose);

      // Force provider to build and load
      container2.read(settingsProvider);

      // Wait for async _loadSettings to complete
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = container2.read(settingsProvider);
      expect(state.isLoaded, isTrue);
      expect(state.themeMode, ThemeMode.dark);
      expect(state.locale, AppLocale.en);
      expect(state.showWarningBadges, isFalse);
      expect(state.cacheDurationMinutes, 60);
    });

    test('setThemeMode changes theme', () async {
      final notifier = container.read(settingsProvider.notifier);
      notifier.setThemeMode(ThemeMode.dark);

      final state = container.read(settingsProvider);
      expect(state.themeMode, ThemeMode.dark);
    });

    test('toggleTheme cycles light to dark', () async {
      final notifier = container.read(settingsProvider.notifier);
      notifier.setThemeMode(ThemeMode.light);
      await Future<void>.delayed(Duration.zero);
      notifier.toggleTheme();
      await Future<void>.delayed(Duration.zero);

      final state = container.read(settingsProvider);
      expect(state.themeMode, ThemeMode.dark);
    });

    test('toggleTheme cycles dark to light', () async {
      final notifier = container.read(settingsProvider.notifier);
      notifier.setThemeMode(ThemeMode.dark);
      await Future<void>.delayed(Duration.zero);
      notifier.toggleTheme();
      await Future<void>.delayed(Duration.zero);

      final state = container.read(settingsProvider);
      expect(state.themeMode, ThemeMode.light);
    });

    test('toggleTheme cycles system to dark', () async {
      final notifier = container.read(settingsProvider.notifier);
      // Default is system
      notifier.toggleTheme();
      await Future<void>.delayed(Duration.zero);

      final state = container.read(settingsProvider);
      expect(state.themeMode, ThemeMode.dark);
    });

    test('setLocale changes locale', () {
      final notifier = container.read(settingsProvider.notifier);
      notifier.setLocale(AppLocale.en);

      final state = container.read(settingsProvider);
      expect(state.locale, AppLocale.en);
    });

    test('setShowWarningBadges changes value', () {
      final notifier = container.read(settingsProvider.notifier);
      notifier.setShowWarningBadges(false);

      expect(container.read(settingsProvider).showWarningBadges, isFalse);
    });

    test('setInsiderNotifications changes value', () {
      final notifier = container.read(settingsProvider.notifier);
      notifier.setInsiderNotifications(false);

      expect(container.read(settingsProvider).insiderNotifications, isFalse);
    });

    test('setDisposalUrgentAlerts changes value', () {
      final notifier = container.read(settingsProvider.notifier);
      notifier.setDisposalUrgentAlerts(false);

      expect(container.read(settingsProvider).disposalUrgentAlerts, isFalse);
    });

    test('setLimitAlerts changes value', () {
      final notifier = container.read(settingsProvider.notifier);
      notifier.setLimitAlerts(false);

      expect(container.read(settingsProvider).limitAlerts, isFalse);
    });

    test('setShowROCYear changes value', () {
      final notifier = container.read(settingsProvider.notifier);
      notifier.setShowROCYear(false);

      expect(container.read(settingsProvider).showROCYear, isFalse);
    });

    test('setCacheDurationMinutes changes value', () {
      final notifier = container.read(settingsProvider.notifier);
      notifier.setCacheDurationMinutes(120);

      expect(container.read(settingsProvider).cacheDurationMinutes, 120);
    });

    test('setAutoUpdateEnabled changes value', () {
      final notifier = container.read(settingsProvider.notifier);
      notifier.setAutoUpdateEnabled(true);

      expect(container.read(settingsProvider).autoUpdateEnabled, isTrue);
    });
  });

  // ===========================================================================
  // Derived Providers
  // ===========================================================================

  group('Derived providers', () {
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('themeModeProvider returns current theme', () {
      final themeMode = container.read(themeModeProvider);
      expect(themeMode, ThemeMode.system);
    });

    test('localeProvider returns current locale', () {
      final locale = container.read(localeProvider);
      expect(locale, const Locale('zh', 'TW'));
    });

    test('settingsLoadedProvider returns loaded state', () {
      final isLoaded = container.read(settingsLoadedProvider);
      // Initially false before async load completes
      expect(isLoaded, isFalse);
    });

    test('cacheDurationProvider returns cache minutes', () {
      final duration = container.read(cacheDurationProvider);
      expect(duration, 30);
    });
  });

  // ===========================================================================
  // ApiTokenState
  // ===========================================================================

  group('ApiTokenState', () {
    test('has correct default values', () {
      const state = ApiTokenState();

      expect(state.token, isNull);
      expect(state.isLoading, isFalse);
      expect(state.testResult, isNull);
      expect(state.testError, isNull);
      expect(state.hasToken, isFalse);
    });

    test('hasToken is true when token is non-empty', () {
      const state = ApiTokenState(token: 'abc123');
      expect(state.hasToken, isTrue);
    });

    test('hasToken is false for empty string', () {
      const state = ApiTokenState(token: '');
      expect(state.hasToken, isFalse);
    });

    test('copyWith preserves unset values', () {
      const state = ApiTokenState(token: 'abc', isLoading: true);
      final copied = state.copyWith();
      expect(copied.token, 'abc');
      expect(copied.isLoading, isTrue);
    });

    test('copyWith clearToken sets token to null', () {
      const state = ApiTokenState(token: 'abc');
      final cleared = state.copyWith(clearToken: true);
      expect(cleared.token, isNull);
    });

    test('copyWith clearTestResult sets testResult to null', () {
      const state = ApiTokenState(testResult: 100);
      final cleared = state.copyWith(clearTestResult: true);
      expect(cleared.testResult, isNull);
    });

    test('copyWith clearTestError sets testError to null', () {
      const state = ApiTokenState(testError: 'error');
      final cleared = state.copyWith(clearTestError: true);
      expect(cleared.testError, isNull);
    });
  });

  // ===========================================================================
  // ApiTokenNotifier
  // ===========================================================================

  group('ApiTokenNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is empty', () {
      final state = container.read(apiTokenProvider);
      expect(state.token, isNull);
      expect(state.hasToken, isFalse);
    });

    test('loadToken sets token from callback', () async {
      final notifier = container.read(apiTokenProvider.notifier);
      await notifier.loadToken(() async => 'my-token');

      final state = container.read(apiTokenProvider);
      expect(state.token, 'my-token');
      expect(state.hasToken, isTrue);
    });

    test('loadToken clears token when callback returns null', () async {
      final notifier = container.read(apiTokenProvider.notifier);
      await notifier.loadToken(() async => 'my-token');
      await notifier.loadToken(() async => null);

      final state = container.read(apiTokenProvider);
      expect(state.token, isNull);
      expect(state.hasToken, isFalse);
    });

    test('saveToken stores token and clears test results', () async {
      final notifier = container.read(apiTokenProvider.notifier);
      await notifier.saveToken('new-token', (_) async {});

      final state = container.read(apiTokenProvider);
      expect(state.token, 'new-token');
      expect(state.testResult, isNull);
      expect(state.testError, isNull);
    });

    test('clearToken removes token', () async {
      final notifier = container.read(apiTokenProvider.notifier);
      await notifier.saveToken('abc', (_) async {});
      await notifier.clearToken(() async {});

      final state = container.read(apiTokenProvider);
      expect(state.token, isNull);
      expect(state.hasToken, isFalse);
    });

    test('testConnection sets result on success', () async {
      final notifier = container.read(apiTokenProvider.notifier);
      await notifier.testConnection(() async => 42);

      final state = container.read(apiTokenProvider);
      expect(state.isLoading, isFalse);
      expect(state.testResult, 42);
      expect(state.testError, isNull);
    });

    test('testConnection sets error on failure', () async {
      final notifier = container.read(apiTokenProvider.notifier);
      await notifier.testConnection(
        () async => throw Exception('Connection failed'),
      );

      final state = container.read(apiTokenProvider);
      expect(state.isLoading, isFalse);
      expect(state.testResult, isNull);
      expect(state.testError, isNotNull);
    });

    test('clearTestResults clears test state', () async {
      final notifier = container.read(apiTokenProvider.notifier);
      await notifier.testConnection(() async => 42);

      notifier.clearTestResults();

      final state = container.read(apiTokenProvider);
      expect(state.testResult, isNull);
      expect(state.testError, isNull);
    });
  });
}
