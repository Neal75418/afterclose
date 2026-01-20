import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ==================================================
// Settings Keys
// ==================================================

const _keyThemeMode = 'settings_theme_mode';
const _keyLocale = 'settings_locale';

// ==================================================
// Settings State
// ==================================================

/// Supported locales
enum AppLocale {
  zhTW('zh', 'TW', '繁體中文'),
  en('en', null, 'English');

  const AppLocale(this.languageCode, this.countryCode, this.displayName);

  final String languageCode;
  final String? countryCode;
  final String displayName;

  Locale toLocale() => Locale(languageCode, countryCode);

  static AppLocale fromLocale(Locale locale) {
    return AppLocale.values.firstWhere(
      (l) => l.languageCode == locale.languageCode,
      orElse: () => AppLocale.zhTW,
    );
  }

  static AppLocale fromString(String? value) {
    if (value == null) return AppLocale.zhTW;
    return AppLocale.values.firstWhere(
      (l) => l.name == value,
      orElse: () => AppLocale.zhTW,
    );
  }
}

/// Settings state
class SettingsState {
  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.locale = AppLocale.zhTW,
    this.isLoaded = false,
  });

  final ThemeMode themeMode;
  final AppLocale locale;
  final bool isLoaded;

  SettingsState copyWith({
    ThemeMode? themeMode,
    AppLocale? locale,
    bool? isLoaded,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

// ==================================================
// Settings Notifier
// ==================================================

/// Settings state notifier with persistence
class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _loadSettings();
  }

  /// Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final themeModeIndex = prefs.getInt(_keyThemeMode);
      final localeString = prefs.getString(_keyLocale);

      final themeMode = themeModeIndex != null && themeModeIndex < ThemeMode.values.length
          ? ThemeMode.values[themeModeIndex]
          : ThemeMode.system;

      final locale = AppLocale.fromString(localeString);

      state = SettingsState(
        themeMode: themeMode,
        locale: locale,
        isLoaded: true,
      );

      if (kDebugMode) {
        print('Settings loaded: theme=$themeMode, locale=${locale.displayName}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load settings: $e');
      }
      state = state.copyWith(isLoaded: true);
    }
  }

  /// Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyThemeMode, state.themeMode.index);
      await prefs.setString(_keyLocale, state.locale.name);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to save settings: $e');
      }
    }
  }

  /// Set theme mode
  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _saveSettings();
    if (kDebugMode) {
      print('Theme mode changed to: $mode');
    }
  }

  /// Toggle between light and dark theme
  void toggleTheme() {
    final newMode = switch (state.themeMode) {
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.light,
      ThemeMode.system => ThemeMode.dark,
    };
    setThemeMode(newMode);
  }

  /// Set locale
  void setLocale(AppLocale locale) {
    state = state.copyWith(locale: locale);
    _saveSettings();
    if (kDebugMode) {
      print('Locale changed to: ${locale.displayName}');
    }
  }
}

// ==================================================
// Provider
// ==================================================

/// Settings provider
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});

/// Theme mode provider (convenience)
final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(settingsProvider).themeMode;
});

/// Locale provider (convenience)
final localeProvider = Provider<Locale>((ref) {
  return ref.watch(settingsProvider).locale.toLocale();
});

/// Settings loaded provider
final settingsLoadedProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).isLoaded;
});

// ==================================================
// API Token Provider
// ==================================================

/// State for API token configuration
class ApiTokenState {
  const ApiTokenState({
    this.token,
    this.isLoading = false,
    this.testResult,
    this.testError,
  });

  final String? token;
  final bool isLoading;
  final int? testResult; // Number of stocks fetched in test
  final String? testError;

  bool get hasToken => token != null && token!.isNotEmpty;

  ApiTokenState copyWith({
    String? token,
    bool? isLoading,
    int? testResult,
    String? testError,
    bool clearToken = false,
    bool clearTestResult = false,
    bool clearTestError = false,
  }) {
    return ApiTokenState(
      token: clearToken ? null : (token ?? this.token),
      isLoading: isLoading ?? this.isLoading,
      testResult: clearTestResult ? null : (testResult ?? this.testResult),
      testError: clearTestError ? null : (testError ?? this.testError),
    );
  }
}

/// API Token notifier - manages token and connection testing
class ApiTokenNotifier extends StateNotifier<ApiTokenState> {
  ApiTokenNotifier() : super(const ApiTokenState());

  /// Load token from secure storage
  Future<void> loadToken(
    Future<String?> Function() getToken,
  ) async {
    final token = await getToken();
    state = state.copyWith(token: token, clearToken: token == null);
  }

  /// Save token to secure storage
  Future<void> saveToken(
    String token,
    Future<void> Function(String) setToken,
  ) async {
    await setToken(token);
    state = state.copyWith(token: token, clearTestResult: true, clearTestError: true);
  }

  /// Clear token from secure storage
  Future<void> clearToken(
    Future<void> Function() deleteToken,
  ) async {
    await deleteToken();
    state = state.copyWith(clearToken: true, clearTestResult: true, clearTestError: true);
  }

  /// Test connection with current token
  Future<void> testConnection(
    Future<int> Function() testFn,
  ) async {
    state = state.copyWith(isLoading: true, clearTestResult: true, clearTestError: true);
    try {
      final count = await testFn();
      state = state.copyWith(isLoading: false, testResult: count);
    } catch (e) {
      state = state.copyWith(isLoading: false, testError: e.toString());
    }
  }

  /// Clear test results
  void clearTestResults() {
    state = state.copyWith(clearTestResult: true, clearTestError: true);
  }
}

/// API Token provider
final apiTokenProvider =
    StateNotifierProvider<ApiTokenNotifier, ApiTokenState>((ref) {
  return ApiTokenNotifier();
});
