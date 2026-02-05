import 'package:afterclose/core/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ==================================================
// Settings Keys
// ==================================================

const _keyThemeMode = 'settings_theme_mode';
const _keyLocale = 'settings_locale';
const _keyShowWarningBadges = 'settings_show_warning_badges';
const _keyInsiderNotifications = 'settings_insider_notifications';
const _keyDisposalUrgentAlerts = 'settings_disposal_urgent_alerts';
const _keyLimitAlerts = 'settings_limit_alerts';
const _keyShowROCYear = 'settings_show_roc_year';
const _keyCacheDurationMinutes = 'settings_cache_duration_minutes';
const _keyAutoUpdateEnabled = 'settings_auto_update_enabled';

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
    this.showWarningBadges = true,
    this.insiderNotifications = true,
    this.disposalUrgentAlerts = true,
    this.limitAlerts = true,
    this.showROCYear = true,
    this.cacheDurationMinutes = 30,
    this.autoUpdateEnabled = false,
  });

  final ThemeMode themeMode;
  final AppLocale locale;
  final bool isLoaded;

  /// 在自選股顯示警示標記（注意/處置/高質押）
  final bool showWarningBadges;

  /// 當自選股董監持股有重大變化時發送通知
  final bool insiderNotifications;

  /// 當自選股被列入處置股時發送緊急通知
  final bool disposalUrgentAlerts;

  /// 當自選股觸及漲跌停時顯示標記
  final bool limitAlerts;

  /// 財報頁面使用民國年顯示
  final bool showROCYear;

  /// API 快取存活時間（分鐘）
  final int cacheDurationMinutes;

  /// 是否啟用每日自動背景更新
  final bool autoUpdateEnabled;

  SettingsState copyWith({
    ThemeMode? themeMode,
    AppLocale? locale,
    bool? isLoaded,
    bool? showWarningBadges,
    bool? insiderNotifications,
    bool? disposalUrgentAlerts,
    bool? limitAlerts,
    bool? showROCYear,
    int? cacheDurationMinutes,
    bool? autoUpdateEnabled,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      isLoaded: isLoaded ?? this.isLoaded,
      showWarningBadges: showWarningBadges ?? this.showWarningBadges,
      insiderNotifications: insiderNotifications ?? this.insiderNotifications,
      disposalUrgentAlerts: disposalUrgentAlerts ?? this.disposalUrgentAlerts,
      limitAlerts: limitAlerts ?? this.limitAlerts,
      showROCYear: showROCYear ?? this.showROCYear,
      cacheDurationMinutes: cacheDurationMinutes ?? this.cacheDurationMinutes,
      autoUpdateEnabled: autoUpdateEnabled ?? this.autoUpdateEnabled,
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

  /// 用於序列化儲存操作的互斥鎖
  /// 確保多個設定變更不會同時寫入造成競態條件
  Future<void>? _saveLock;

  /// Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final themeModeIndex = prefs.getInt(_keyThemeMode);
      final localeString = prefs.getString(_keyLocale);

      final themeMode =
          themeModeIndex != null && themeModeIndex < ThemeMode.values.length
          ? ThemeMode.values[themeModeIndex]
          : ThemeMode.system;

      final locale = AppLocale.fromString(localeString);

      // 進階功能設定（預設開啟）
      final showWarningBadges = prefs.getBool(_keyShowWarningBadges) ?? true;
      final insiderNotifications =
          prefs.getBool(_keyInsiderNotifications) ?? true;
      final disposalUrgentAlerts =
          prefs.getBool(_keyDisposalUrgentAlerts) ?? true;
      final limitAlerts = prefs.getBool(_keyLimitAlerts) ?? true;
      final showROCYear = prefs.getBool(_keyShowROCYear) ?? true;
      final cacheDurationMinutes = prefs.getInt(_keyCacheDurationMinutes) ?? 30;
      final autoUpdateEnabled = prefs.getBool(_keyAutoUpdateEnabled) ?? false;

      state = SettingsState(
        themeMode: themeMode,
        locale: locale,
        isLoaded: true,
        showWarningBadges: showWarningBadges,
        insiderNotifications: insiderNotifications,
        disposalUrgentAlerts: disposalUrgentAlerts,
        limitAlerts: limitAlerts,
        showROCYear: showROCYear,
        cacheDurationMinutes: cacheDurationMinutes,
        autoUpdateEnabled: autoUpdateEnabled,
      );

      AppLogger.debug(
        'Settings',
        '設定已載入: 主題=$themeMode, 語言=${locale.displayName}',
      );
    } catch (e) {
      AppLogger.warning('Settings', '載入設定失敗: $e');
      state = state.copyWith(isLoaded: true);
    }
  }

  /// Save settings to SharedPreferences
  ///
  /// 使用互斥鎖確保多個設定變更不會同時寫入。
  /// 每次儲存都會等待前一次儲存完成後再執行。
  Future<void> _saveSettings() async {
    // 等待前一次儲存完成
    final previousSave = _saveLock;
    if (previousSave != null) {
      await previousSave;
    }

    // 捕獲當前狀態快照（避免在 await 期間狀態被修改）
    final snapshot = state;

    // 建立新的儲存操作並捕獲引用
    final currentSave = _performSave(snapshot);
    _saveLock = currentSave;

    try {
      await currentSave;
    } finally {
      // 只有當前鎖仍是我們建立的鎖時才清除
      // 使用 identical 比較物件參照，避免 _saveLock == _saveLock 永遠為 true 的錯誤
      if (identical(_saveLock, currentSave)) {
        _saveLock = null;
      }
    }
  }

  /// 實際執行儲存操作
  Future<void> _performSave(SettingsState snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyThemeMode, snapshot.themeMode.index);
      await prefs.setString(_keyLocale, snapshot.locale.name);
      await prefs.setBool(_keyShowWarningBadges, snapshot.showWarningBadges);
      await prefs.setBool(
        _keyInsiderNotifications,
        snapshot.insiderNotifications,
      );
      await prefs.setBool(
        _keyDisposalUrgentAlerts,
        snapshot.disposalUrgentAlerts,
      );
      await prefs.setBool(_keyLimitAlerts, snapshot.limitAlerts);
      await prefs.setBool(_keyShowROCYear, snapshot.showROCYear);
      await prefs.setInt(
        _keyCacheDurationMinutes,
        snapshot.cacheDurationMinutes,
      );
      await prefs.setBool(_keyAutoUpdateEnabled, snapshot.autoUpdateEnabled);
    } catch (e) {
      AppLogger.warning('Settings', '儲存設定失敗: $e');
    }
  }

  /// Set theme mode
  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _saveSettings();
    AppLogger.debug('Settings', '主題已變更: $mode');
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
    AppLogger.debug('Settings', '語言已變更: ${locale.displayName}');
  }

  /// Set show warning badges
  void setShowWarningBadges(bool value) {
    state = state.copyWith(showWarningBadges: value);
    _saveSettings();
    AppLogger.debug('Settings', '警示標記顯示: $value');
  }

  /// Set insider notifications
  void setInsiderNotifications(bool value) {
    state = state.copyWith(insiderNotifications: value);
    _saveSettings();
    AppLogger.debug('Settings', '董監持股通知: $value');
  }

  /// Set disposal urgent alerts
  void setDisposalUrgentAlerts(bool value) {
    state = state.copyWith(disposalUrgentAlerts: value);
    _saveSettings();
    AppLogger.debug('Settings', '處置股票緊急警報: $value');
  }

  /// Set limit up/down alerts
  void setLimitAlerts(bool value) {
    state = state.copyWith(limitAlerts: value);
    _saveSettings();
    AppLogger.debug('Settings', '漲跌停提示: $value');
  }

  /// Set ROC year display
  void setShowROCYear(bool value) {
    state = state.copyWith(showROCYear: value);
    _saveSettings();
    AppLogger.debug('Settings', '民國年顯示: $value');
  }

  /// Set cache duration in minutes
  void setCacheDurationMinutes(int minutes) {
    state = state.copyWith(cacheDurationMinutes: minutes);
    _saveSettings();
    AppLogger.debug('Settings', '快取時間: $minutes 分鐘');
  }

  /// Set auto update enabled
  void setAutoUpdateEnabled(bool value) {
    state = state.copyWith(autoUpdateEnabled: value);
    _saveSettings();
    AppLogger.debug('Settings', '自動更新: $value');
  }
}

// ==================================================
// Provider
// ==================================================

/// Settings provider
final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) {
    return SettingsNotifier();
  },
);

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

/// Cache duration provider (convenience)
final cacheDurationProvider = Provider<int>((ref) {
  return ref.watch(settingsProvider).cacheDurationMinutes;
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

  bool get hasToken => token?.isNotEmpty ?? false;

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
  Future<void> loadToken(Future<String?> Function() getToken) async {
    final token = await getToken();
    state = state.copyWith(token: token, clearToken: token == null);
  }

  /// Save token to secure storage
  Future<void> saveToken(
    String token,
    Future<void> Function(String) setToken,
  ) async {
    await setToken(token);
    state = state.copyWith(
      token: token,
      clearTestResult: true,
      clearTestError: true,
    );
  }

  /// Clear token from secure storage
  Future<void> clearToken(Future<void> Function() deleteToken) async {
    await deleteToken();
    state = state.copyWith(
      clearToken: true,
      clearTestResult: true,
      clearTestError: true,
    );
  }

  /// Test connection with current token
  Future<void> testConnection(Future<int> Function() testFn) async {
    state = state.copyWith(
      isLoading: true,
      clearTestResult: true,
      clearTestError: true,
    );
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
final apiTokenProvider = StateNotifierProvider<ApiTokenNotifier, ApiTokenState>(
  (ref) {
    return ApiTokenNotifier();
  },
);
